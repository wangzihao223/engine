-module(sim_manager).

-export([manager/2]).
-export([new_manager/2]).
-export([sim_manager_monitor/1]).

-import(engine_transport, [connect_sim/3]).
-import(remote_func, [init_all_sim/2]).
-import(until, [sets_equal/2]).

% set time_out 
-define(TIME_OUT, 5000).

% make a manager
new_manager(ConfigList, UUid) ->
    % spawn manager process
    ManagerPid = spawn(sim_manager, manager, [ConfigList, UUid]),
    % spawn monitor process
    MonitorPid = spawn(fun() -> sim_manager_monitor(ManagerPid) end),
    {ManagerPid, MonitorPid}.



manager(ConfigList, UUid) ->
    io:format("DEBUG: Manager Pid is ~p ~n", [self()]),
    % init
    Table = manager_init(ConfigList, UUid),
    % get sidset
    [{<<"sid_set">>, SidSet}] = ets:lookup(Table, <<"sid_set">>),
    io:format("TEST: MANAGER INIT END ~n"),
    manager_process(SidSet, Table).

% manager init
% configList : [{Sid_1, [Addr_1, Timeout_1]}, {Sid_2, [Addr_2, Timeout_2]}]
manager_init(ConfigList, UUid) ->
    % make ets Table
    Table = make_new_table(),
    %  add UUid
    ets:insert(Table, {<<"uuid">>, UUid}),
    % manager process init
    manager_process_init(Table, ConfigList),
    Table.



% make ets table
make_new_table() ->
    Table = ets:new(?MODULE, [set, protected]),
    Table.

% configList : [{Sid_1, [Addr_1, Timeout_1]}, {Sid_2, [Addr_2, Timeout_2]}]
% manager process init
manager_process_init(Table, ConfigList) ->
    
    save_config_list(ConfigList, Table),
    % wait remote process registe and wait connect sim
    wait_connect_all_sim(Table, ConfigList),

    % init buffer
    init_buffer(Table),
    io:format("INFO: Wait init ! ~n"),
    % init sim 
    % wait init command
    SidArgs = wait_init(),
    % init all sim
    % now i don't care init resault
    [{_, SidSet}]= ets:lookup(Table, <<"sid_set">>),
    [{_, SidPidDic}] = ets:lookup(Table, <<"sid_pid">>),
    % remove lock
    SidPidList = dict:to_list(SidPidDic),
    remove_lock(SidPidList),
    call_proxy_init(SidPidDic, SidArgs, SidSet),
    % wait dep
    wait_dep(Table),
    % wait_start_comm
    wait_start_cmd(SidPidList),
    ok.

wait_start_cmd(SidPidList) ->
    receive
        {<<"start">>, MaxStep} ->
            tell_all_start(SidPidList, MaxStep)
    end.

tell_all_start([], _MaxStep) -> ok;
tell_all_start(SidPidList, MaxStep) ->
    [{_Sid, Pid} | NL] = SidPidList,
    Pid ! {<<"max_step">>, MaxStep},
    tell_all_start(NL, MaxStep).


call_proxy_init(_SidPidDic, [], SidSet)-> 
    RecvSet = sets:new(),
    wait_init_call(SidSet, RecvSet, []);
call_proxy_init(SidPidDic, SidArgs, SidSet) ->
    [{Sid, Args} | NextSidArgs] = SidArgs,
    {ok, Pid} = dict:find(Sid, SidPidDic), 
    Pid ! {<<"init_func">>, Sid, Args, self()},
    call_proxy_init(SidPidDic, NextSidArgs, SidSet). 

wait_init_call(SidSet, RecvSet, PidList) ->
    case sets_equal(SidSet, RecvSet) of
        false ->
            receive
                {<<"init_done">>, Sid, Pid} ->
                    NewPidList = [Pid | PidList],
                    NewSet = sets:add_element(Sid, RecvSet),
                    wait_init_call(SidSet,NewSet, NewPidList)
            end;
        true ->
            all_init_done(PidList)
    end.


% all_sim_init_done()
all_init_done([]) -> ok;
all_init_done(PidList) ->
    [Pid | NextPidList] = PidList,
    Pid ! {<<"all_done">>, self()},
    all_init_done(NextPidList).

% remove_lock
remove_lock([]) -> o;
remove_lock(SidPidList) ->
    [{_Sid, Pid} | NextSidPidList] = SidPidList,
    Pid ! {<<"ready_init">>},
    remove_lock(NextSidPidList).

wait_connect_all_sim(Table, ConfigList) ->
    save_sids(Table, ConfigList),
    SidSet = ets:lookup(Table, <<"sid_set">>),
    RecvSet = sets:new(),
    wait_proxy_regist(SidSet, RecvSet, Table),
    recv_sid_sock(SidSet, RecvSet, Table, []).

recv_sid_sock(SidSet, RecvSet, Table, PidList) ->
    case sets_equal(SidSet, RecvSet) of
        false ->
            receive
                {<<"send_sid_sock">>, Sid, Sock, Pid} ->
                    NextPidList = [Pid | PidList],
                    save_sid_sock(Sid, Sock, Table),
                    % save sock_sid
                    save_sock_sid(Sid, Sock, Table),
                    recv_sid_sock(SidSet, RecvSet, Table, NextPidList)
            end;
        true ->
           loop_send_ok(PidList) 
        end.

loop_send_ok([]) -> ok;
loop_send_ok(PidList) ->
    [Pid | NextPidList] = PidList,
    Pid ! {<<"all_end">>, self()},
    loop_send_ok(NextPidList).


% save sid
save_sids(_Table, []) -> ok;
save_sids(Table,  ConfigList) ->
    [{Sid, _} | NextConfigList] = ConfigList,
    save_sid_set(Table, Sid),
    save_sids(Table, NextConfigList). 


init_buffer(Table) ->
    % get sid_sets
    [{<<"sid_set">>, SidSet}] = ets:lookup(Table, <<"sid_set">>),
    io:format("DEBUG: SidSet ~p ~n", [SidSet]),
    SidList = sets:to_list(SidSet),
    init_buffer_loop(Table, SidList).
     
init_buffer_loop(_Table, []) -> ok;
init_buffer_loop(Table, SidList) ->
    [Sid| NextList] = SidList,
    % sid is string
    Key = unicode:characters_to_binary([Sid, <<"_buff">>]),
    % add ets
    ets:insert(Table, {Key, []}),
    init_buffer_loop(Table, NextList).


% wait dependency
wait_dep(Table) ->
    receive
        {<<"dep">>, DepList, BeDepList} ->
            save_statement_dep(DepList, BeDepList, Table),
            % tello other proxy
            [{<<"sid_pid">>, SidPidDic}] = est:look_up(Table, <<"sid_pid">>),
            SidPidList = dict:to_list(SidPidDic),
            tell_proxy_dep(Table, SidPidList);
        _ -> ok
    end.

% tell other proxy dep message
tell_proxy_dep(_Table, []) -> ok;
tell_proxy_dep(Table, SidPidList) ->
    [{Sid, Pid} | NextSidPidList] = SidPidList,
    handle_proxy_dep(Table, Sid, Pid),
    tell_proxy_dep(Table, NextSidPidList).

% statement dependency
% DepList [{sid_1, [xx, xxx, xxx]}, {sid_2, [xx, xxx, xxxx]}, ...]
% BeDep like up
save_statement_dep(DepList, BeDepList, Table) ->
    DepDict = dict:from_list(DepList),
    BeDepDict = dict:from_list(BeDepList),
    ets:insert(Table, {<<"dep_dict">>, DepDict}),
    ets:insert(Table, {<<"be_dep_dict">>, BeDepDict}).

% after init 
% main process
% manager_process(SidSet, Table) ->
%     % new RecvSet
%     RecvSet = sets:new(),
%     manager_process(SidSet, RecvSet, Table).

manager_process(SidSet, Table) ->
    % make a priority queue
    Pq = heapq:new(),
    % start
    % it's loop
    handle_req(Pq, SidSet, Table).


handle_req(Pq, SidSet, Table) ->
    % new RecvSidSet
    RecvSidSet = sets:new(),
    handle_req(Pq, SidSet, RecvSidSet, Table).

% handle all request:
% proxy request
% and other contral
handle_req(Pq, SidSet, RecvSidSet, Table) ->
    % sets equal
    case sets_equal(SidSet, RecvSidSet) of
        % equal
        true ->
            % pop sid from Pq has same step 
            % SidList : [
            %             {step_1, {sid_1, pid_1}}, 
            %            {step_2, {sid_2, pid_2}}
            %          ]

            % choice proxy process run
            {NewPq, SidPidList, NewSidSet} = choice_proxy_run(Pq),
            % call proxy process
            notice_process_run(SidPidList),
            % reset RecvSidSet
            NewRecvSidSet = sets:new(),
            handle_req(NewPq, NewSidSet, NewRecvSidSet, Table);

        % not equal
        false ->

            receive
                % handle_proxy_req
                {<<"proxy_run">>, Step, Sid, Pid} ->

                    {NewPq, NewRecvSidSet} = handle_proxy_req(Step, Sid, Pid, Pq, RecvSidSet),
                    handle_req(NewPq, SidSet, NewRecvSidSet, Table);
                

                % % handle proxy_dep 
                % % find proxy_dep and send proxy
                % {<<"proxy_dep">>, Sid, Pid} ->
                %     handle_proxy_dep(Table, Sid, Pid),
                %     handle_req(Pq, SidSet, RecvSidSet, Table);
                % update buffer
                {<<"update_buffer">>, UpdateList, Pid} ->
                    handle_update_buffer(Table, UpdateList, Pid),
                    handle_req(Pq, SidSet, RecvSidSet, Table);
                % stop manager
                {<<"stop">>} -> ok;
                % receive garbage message and give up
                _ -> handle_req(Pq, SidSet, RecvSidSet, Table)
            end
    end.


% handle proxy req
handle_proxy_req(Step, Sid, Pid, Pq, RecvSidSet) ->
        NewPq = heapq:push(Pq, {Step, {Sid, Pid}}),
        NewRecvSidSet = sets:add_element(Sid, RecvSidSet),
        {NewPq, NewRecvSidSet}.

% handle proxy dep
handle_proxy_dep(Table, Sid, Pid) ->
    [{<<"dep_dict">>, DepDict}] = ets:lookup(Table, <<"dep_dict">>),
    [{<<"be_dep_dict">>, BeDepDict}] = ets:lookup(Table, <<"be_dep_dict">>),
    % send dep to proxy_process
        % Dep : [sid_1, sid_2, ]
        % BeDep : [sid_3, sid]
    {ok, SidList} = dict:find(Sid, DepDict),
    {ok, BeSidList} = dict:find(Sid, BeDepDict),
    Pid ! {SidList, BeSidList}.

handle_update_buffer(_Table, [], Pid) -> 
    % send proxy process
    Pid ! {<<"update_success">>, self()},
    ok;
handle_update_buffer(Table, UpdateList, Pid) ->
    [{Sid, Value} | NextUpdateList] = UpdateList,
    Key = unicode:characters_to_binary([Sid, <<"_buff">>]),
    ets:insert(Table, {Key, Value}),
    handle_update_buffer(Table, NextUpdateList, Pid).


% notice process run
notice_process_run([]) -> ok;
notice_process_run(SidPidList) ->

    [{_Step, {_Sid, Pid}} | NextSidPidList] = SidPidList,
    Pid ! {<<"run">>, self()},
    notice_process_run(NextSidPidList).



% pop sid from has same step 
choice_proxy_run(Pq) ->
    % look priority queue top value
    % new Sid Set
    SidSet = sets:new(),
    case heapq:look_top(Pq) of
        % Pq is empty
        error -> {Pq, [], SidSet};
        {NowStep, _} -> choice_proxy_run(Pq, NowStep, [], SidSet)
    end.
            

choice_proxy_run(Pq, Step, Res, SidSet) ->
    case heapq:look_top(Pq) of
        % Pq is empty
        error ->
            % break
            {Pq, Res, SidSet};
        {NowStep, _} ->
            
            if NowStep =:= Step ->
                    % equal
                    {TopValue, NewPq} = heapq:pop(Pq),
                    % add TopValue to Res
                    NewRes = [TopValue | Res],
                    % add Sid to SidSet 
                    {_Step, {Sid, _Pid}} = TopValue,
                    NewSidSet = sets:add_element(Sid, SidSet),
                    choice_proxy_run(NewPq, Step, NewRes, NewSidSet);
                true ->
                    % not equal
                    {Pq, Res, SidSet}
            end
    end.


wait_proxy_regist(SidSet, RecvSet, Table) ->
    io:format("DEBUG: wait_proxy_regist ~n"),
    % compare sidset and recvset
    case sets_equal(SidSet, RecvSet) of
        % continue wait proxy regist
        false ->
            io:format("DEBUG: START ~n"),
            receive
                % get sid
                {<<"registe">>, Sid, Pid} ->
                    % receive proxy process registe
                    io:format("DEBUG: receive proxy process reigste ~n"),
                    % add recvset
                    NewRecvSet = sets:add_element(Sid, RecvSet),
                    % save sid_pid
                    save_sid_pid(Sid, Pid, Table),
                    % reply Proxy process 
                    Pid ! {ok, self(), Table},
                    wait_proxy_regist(SidSet, NewRecvSet, Table)
            end;
        % break
        true -> 
            io:format("DEBUGE: proxy regist is end"),
            ok
    end.

% save Table sid_pid
save_sid_pid(Sid, Pid, Table) ->
    % find the table
    case ets:lookup(Table, <<"sid_pid">>) of
        % not find
        [] ->
            Dict = dict:new(),
            NewDict = dict:store(Sid, Pid, Dict),
            % save ets
            ets:insert(Table, {<<"sid_pid">>, NewDict});
        [{<<"sid_pid">>, Dict}] ->
            NewDict = dict:store(Sid, Pid, Dict),
            % update
            ets:insert(Table, {<<"sid_pid">>, NewDict})
    end.


% wait init command
wait_init() ->
    receive
        {<<"init">>, SidArgs} ->
            SidArgs
    after ?TIME_OUT ->
        io:format("ERROR: TIMEOUT !! ~n"),
        throw("error: timeout !! ~n")
    end.


% configList : [{Sid_1, [Addr_1, Timeout_1]}, {Sid_2, [Addr_2, Timeout_2]}]

% save sid_sock
save_sid_sock(Sid, Sock, Table) ->
    % look up sid_sock
    case ets:lookup(Table, <<"sid_sock">>) of
        % not found  insert new sid_sock
        [] -> 
            % sid_sock is dict
            Dict = dict:new(),
            % insert now sid sock
            NewDict = dict:store(Sid, Sock, Dict),
            % insert NewDict to Table
            ets:insert(Table,{<<"sid_sock">>, NewDict});
        [{<<"sid_sock">>, Dict}] ->
            % insert now sid sock
            NewDict = dict:store(Sid, Sock, Dict),
            ets:insert(Table, {<<"sid_sock">>, NewDict})
    end.

% save config_list to table
% configList : [{Sid_1, [Addr_1, Timeout_1]}, {Sid_2, [Addr_2, Timeout_2]}],
% Addr_1: string
save_config_list(ConfigList, Table) ->
    ets:insert(Table, {<<"config_list">>, ConfigList}).


% save sock_sid
save_sock_sid(Sid, Sock, Table) ->
    % look up sock_sid
    case ets:lookup(Table, <<"sock_sid">>) of
        % not found  insert new sock_sid
        [] ->
            Dict = dict:new(),
            NewDict = dict:store(Sock, Sid, Dict),
            % insert NewDict to Table
            ets:insert(Table, {<<"sock_sid">>, NewDict});
        [{<<"sock_sid">>, Dict}] ->
            % insert now sid sock
            NewDict = dict:store(Sock, Sid, Dict),
            ets:insert(Table, {<<"sock_sid">>, NewDict})
    end.

% save sid set
save_sid_set(Table, Sid) ->
    case ets:lookup(Table, <<"sid_set">>) of
        % not found insert new sid_set
        [] ->
            SidSet = sets:new(),
            NewSidSet = sets:add_element(Sid, SidSet),
            % insert newSidSet to Table,
            ets:insert(Table, {<<"sid_set">>, NewSidSet}),
            io:format("DEBUG: sid_set save ~p ~n", [NewSidSet]);
        [{<<"sid_set">>, SidSet}] ->
            % insert now sid sock
            NewSidSet = sets:add_element(Sid, SidSet),
            % insert newSidSet to Table
            ets:insert(Table, {<<"sid_set">>, NewSidSet})
    end.


% TODO： add monitor 
sim_manager_monitor(MointoredPid) ->
    Ref = erlang:monitor(process, MointoredPid),
    io:format("INFO: MOINTOR START !! ~n"),
    receive
        {'DOWN', Ref, process, MointoredPid, Why} ->
            % handle_error(Why)
            io:format("INFO: sim manager is down ~p ~n", [Why])
    end.          

% % handle different errors
% handle_error(Why) ->
%     case Why of
%         {<<"func_error">>, Reason} ->
%             io:format("~s ~n", [Reason]),
%             % handle error method


% reset_process(Table) ->



