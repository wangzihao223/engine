-module(sim_manager).

-export([manager/1]).
-export([new_manager/1]).
-export([sim_manager_monitor/1]).

-import(engine_transport, [connect_sim/2]).
-import(remote_func, [init_all_sim/2]).
-import(until, [sets_equal/2]).

% set time_out 
-define(TIME_OUT, 300000).

% make a manager
new_manager(ConfigList) ->
    % spawn manager process
    ManagerPid = spawn(sim_manager, manager, [ConfigList]),
    % spawn monitor process
    MonitorPid = spawn(fun() -> sim_manager_monitor(ManagerPid) end),
    {ManagerPid, MonitorPid} .



manager(ConfigList) ->
    % init
    Table = manager_init(ConfigList),
    % get sidset
    [{<<"sid_set">>, SidSet}] = ets:lookup(Table, <<"sid_set">>),
    manager_process(SidSet, Table).

% manager init
% configList : [{Sid_1, [Addr_1, Timeout_1]}, {Sid_2, [Addr_2, Timeout_2]}]
manager_init(ConfigList) ->
    % make ets Table
    Table = make_new_table(),
    % manager process init
    manager_process_init(Table, ConfigList),
    Table.


% make ets table
make_new_table() ->
    Table = ets:new(?MODULE, [set, protected]),
    Table.


% manager process init
manager_process_init(Table, ConfigList) ->
    % connect sim
    connect_all_sim(ConfigList, Table),

    % save ConfigList 
    save_config_list(ConfigList, Table),
    % init sim 
    % wait init command
    SidArgs = wait_init(),
    % init all sim
    % now i don't care init resault
    init_all_sim(SidArgs, Table),
    ok.


% after init 
% main process
manager_process(SidSet, Table) ->
    % new RecvSet
    RecvSet = sets:new(),
    manager_process(SidSet, RecvSet, Table).

manager_process(SidSet, RecvSet, Table) ->
    % wait proxy regist
    wait_proxy_regist(SidSet, RecvSet, Table),
    % make a priority queue
    Pq = heapq:new(),
    % start
    % it's loop
    handle_req(Pq, SidSet).


handle_req(Pq, SidSet) ->
    % new RecvSidSet
    RecvSidSet = sets:new(),
    handle_req(Pq, SidSet, RecvSidSet).

% handle all request:
% proxy request
% and other contral
handle_req(Pq, SidSet, RecvSidSet) ->
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
            handle_req(NewPq, NewSidSet, NewRecvSidSet);

        % not equal
        false ->

            receive
                % handle_proxy_req
                {<<"proxy_run">>, Step, Sid, Pid} ->

                    {NewPq, NewRecvSidSet} = handle_proxy_req(Step, Sid, Pid, Pq, RecvSidSet),
                    handle_req(NewPq, SidSet, NewRecvSidSet)
                
                % TODO : add other request
            end
    end.


% handle proxy req
handle_proxy_req(Step, Sid, Pid, Pq, RecvSidSet) ->
        NewPq = heapq:push(Pq, {Step, {Sid, Pid}}),
        NewRecvSidSet = sets:add_element(Sid, RecvSidSet),
        {NewPq, NewRecvSidSet}.


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
    % compare sidset and recvset
    case sets_equal(SidSet, RecvSet) of
        % continue wait proxy regist
        false ->
            receive
                % get sid
                {<<"registe">>, Sid, Pid} ->
                    % add recvset
                    NewRecvSet = sets:add_element(Sid, RecvSet),
                    % save sid_pid
                    save_sid_pid(Sid, Pid, Table),
                    % reply Proxy process 
                    Pid ! {ok, self()},
                    wait_proxy_regist(SidSet, NewRecvSet, Table)
            end;
        % break
        true -> 
            ok
    end.

% save Table sid_pid
save_sid_pid(Sid, Pid, Table) ->
    % find the table
    case ets:lookup(Table, <<"sid_pid">>) of
        % not find
        [] ->
            Dict = dict:new(),
            NewDict = dict:append(Sid, Pid, Dict),
            % save ets
            ets:insert(Table, {<<"sid_pid">>, NewDict});
        [{<<"sid_pid">>, Dict}] ->
            NewDict = dict:append(Sid, Pid, Dict),
            % update
            ets:insert(Table, {<<"sid_pid">>, NewDict})
    end.


% wait init command
wait_init() ->
    receive
        % sidArgs : [{sid1, Args1}, ...]
        % Args1 : [arg1, arg2, arg3 ...]
        {init, SidArgs} -> SidArgs
        % set timeout
        after ?TIME_OUT ->
            throw({error, <<"wait init time out !">>})
    end.


% configList : [{Sid_1, [Addr_1, Timeout_1]}, {Sid_2, [Addr_2, Timeout_2]}]
connect_all_sim([], _Table) -> ok;
connect_all_sim(ConfigList, Table) ->
    [{Sid, [Address, Timeout]} | NextConfigList] = ConfigList,
    [IP, Port] = Address,
    % IP allow string
    ClientSock = connect_sim({IP, Port}, Timeout),
    % save sid_sock
    save_sid_sock(Sid, ClientSock, Table),
    % save sock_sid
    save_sock_sid(Sid, ClientSock, Table),
    % save_sid_set
    save_sid_set(Table, Sid),
    % loop
    connect_all_sim(NextConfigList, Table).

% save sid_sock
save_sid_sock(Sid, Sock, Table) ->
    % look up sid_sock
    case ets:lookup(Table, <<"sid_sock">>) of
        % not found  insert new sid_sock
        [] -> 
            % sid_sock is dict
            Dict = dict:new(),
            % insert now sid sock
            NewDict = dict:append(Sid, Sock, Dict),
            % insert NewDict to Table
            ets:insert(Table,{<<"sid_sock">>, NewDict});
        [{<<"sid_sock">>, Dict}] ->
            % insert now sid sock
            NewDict = dict:append(Sid, Sock, Dict),
            ets:insert(Table, {<<"sid_sock">>, NewDict})
    end.

% save config_list to table
% configList : [{Sid_1, [Addr_1, Timeout_1]}, {Sid_2, [Addr_2, Timeout_2]}],
% Addr_1: string
save_config_list(ConfigList, Table) ->
    ets:insert(Table, ConfigList).


% save sock_sid
save_sock_sid(Sid, Sock, Table) ->
    % look up sock_sid
    case ets:lookup(Table, <<"sock_sid">>) of
        % not found  insert new sock_sid
        [] ->
            Dict = dict:new(),
            NewDict = dict:append(Sock, Sid, Dict),
            % insert NewDict to Table
            ets:insert(Table, {<<"sock_sid">>, NewDict});
        [{<<"sock_sid">>, Dict}] ->
            % insert now sid sock
            NewDict = dict:append(Sock, Sid, Dict),
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
            ets:insert(Table, {<<"sid_set">>, NewSidSet});
        [{<<"sid_set">>, SidSet}] ->
            % insert now sid sock
            NewSidSet = sets:add_element(Sid, SidSet),
            % insert newSidSet to Table
            ets:insert(Table, {<<"sid_set">>, NewSidSet})
    end.


% TODO： add monitor 
sim_manager_monitor(MointoredPid) ->
    Ref = erlang:monitor(process, MointoredPid),
    receive
        {'DOWN', Ref, process, MointoredPid, Why} ->
            handle_error(Why)
    end.          

% handle different errors
handle_error(_Why) ->
    ok.