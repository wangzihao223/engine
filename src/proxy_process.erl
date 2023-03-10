-module(proxy_process).

-export([new_process/3]).
-export([create_group_process/2]).

-import(until, [sets_equal/2]).
-import(engine_transport, [connect_sim/3]).
-import(engine_transport, [counter_up/0]).

-define(TIMEOUT, 30000).

create_group_process(_, []) -> ok;
create_group_process(Manager, SidList) ->
    [Sid| NextSidList] = SidList,
    new_process(Manager, Sid, 0),
    create_group_process(Manager, NextSidList).


new_process(Manager, Sid, Step) ->
    spawn(fun() -> proxy_process(Manager, Sid,
        Step) end).

proxy_process(Manager, Sid, Step) ->
    % process init
    {Table, DepTuple} = process_init(Manager, Sid),
    io:format("INFO: PROXY INTI OK ~n"),
    {Dep, BeDep} = DepTuple,
    % Dep is list , BeDep also list
    WaitSet = sets:from_list(Dep),
    SendList = BeDep,
    % get Sock
    [{<<"sid_sock">>, SidSock}] = ets:lookup(Table, <<"sid_sock">>),
    {ok, Sock} = dict:find(Sid, SidSock),
    % get buffer key
    BufferKey = unicode:characters_to_binary([Sid, <<"_buff">>]),
    % wait process start
    MaxStep = wait_process_start(),
    main_loop(Manager, Sid, WaitSet, Sock, SendList, Table, BufferKey, Step,
        MaxStep).

wait_process_start() ->
    receive
        {<<"max_step">>, MaxStep} ->
            MaxStep
    end.


process_init(Manager, Sid) ->

    % use process dic
    use_process_dict(),
    % link manager
    link(Manager),
    Table = registe_manager(Manager, Sid),
    % connect_remote_sim
    Sock = connect_remote_sim(Table, Sid, Manager),
    % wait init
    wait_init(),
    % init sim
    init_sim(Table, Sid, Sock),
    % wait dep
    DepTuple = get_dep_relationship(Manager, Sid),
    {Table, DepTuple}. 

wait_init() ->
    receive
        {<<"ready_init">>} ->
            ok         
    end.

use_process_dict() ->
    % insert counter
    put(<<"counter">>, 0).

% registe self to manager
registe_manager(Manager, Sid) ->
    Manager ! {<<"registe">>, Sid, self()},
    receive
        {ok, _Manager, Table} -> Table
    after 
        ?TIMEOUT ->
            throw({<<"registe_time_out_error">>, <<"time out">>})
    end.

% connect remote sim
connect_remote_sim(Table, Sid, Monitor) ->
    [{<<"config_list">>, ConfigList}] = ets:lookup(Table, <<"config_list">>),
    ConfigDic = dict:from_list(ConfigList),
    {ok, [Address, Port,Timeout]} = dict:find(Sid, ConfigDic),
    Sock = connect_sim(Address, Port, Timeout),
    Monitor ! {<<"send_sid_sock">>, Sid, Sock, self()},
    wait_connect_end(),
    Sock.

init_sim(_Table, Sid, Sock) ->
    % [{<<"sid_sock">>, SidSockDic}] = ets:lookup(Table, <<"sid_sock">>),
    % {ok, Sock} = dict:find(Sid, SidSockDic),
    receive
        {<<"init_func">>, Sid, Args, Manager} ->
            Id = counter_up(),
            Res = engine_transport:call_sim(Sock, Id, <<"init">>, Args),
            %reply ok
            Manager ! {<<"init_done">>, Sid, self()},
            % wait other sim
            wait_other_sim()
    end. 


% wait_connect_end
wait_connect_end() ->
    receive
        {<<"all_end">>, _Pid} ->
            io:format("INFO:ALL END ~n"),
            ok
    end.

wait_other_sim() ->
    receive
        {<<"all_down">>, _Pid} ->
            ok
    end.
% get dependency
get_dep_relationship(_Manager, _Sid) ->
    receive
        {Dep, BeDep} ->
            % Dep : [sid_1, sid_2, ]
            % BeDep : [sid_3, sid]
            {Dep, BeDep}
    end.


% send request to manager 
req_run(Manager, Step, Sid) ->
    Manager ! {<<"proxy_run">>, Step, Sid, self()},
    receive
        {<<"run">>, Manager} -> ok
    end.


% WaitSet : which sidSet the current sid depends on
% SendList: which sidList are the current sid dependent on
main_loop(Manager, Sid, WaitSet, Sock, SendList, Table, BufferKey, 
    Step, MaxStep)  when MaxStep > Step ->
    req_run(Manager, Step, Sid),
    % wait dep
    wait_other_dep(WaitSet),
    % get input data from manager
    Buffer = get_input_data(Table, BufferKey),
    % simulation step
    NextStep = sim_step(Sock, Table, Step, Buffer),
    % get outputdata 
    UpdateList = get_output_data(SendList, Sock, Table),
    % update buffer 
    update_buffer(Manager, UpdateList),
    main_loop(Manager, Sid, WaitSet, Sock, SendList, Table, BufferKey,
        NextStep, MaxStep);
main_loop(Manager, _Sid, _WaitSet, _Sock, _SendList, _Table, _BufferKey, 
    _Step, _MaxStep) ->
    % send stop message to manager
    Manager ! {<<"stop">>}.


wait_other_dep(WaitSet) ->
    RecvSet = sets:new(),
    wait_other_dep(WaitSet, RecvSet).
wait_other_dep(WaitSet, RecvSet) ->
    case sets_equal(WaitSet, RecvSet) of
        false ->
            receive
                {<<"ready">>, WaitSid} ->
                    NewRecvSet = sets:add_element(WaitSid, RecvSet),
                    wait_other_dep(WaitSet, NewRecvSet)
            end;
        true -> ok
    end.              

% get input data from manager
get_input_data(Table, BufferKey) ->
    [{BufferKey, Buffer}] = ets:lookup(Table, BufferKey),
    Buffer.

% call step
sim_step(Sock, Table, Time, Inputs) ->
    remote_func:call_step(Sock, Table, Time, Inputs).

get_output_data(BeDepSidList, Sock, Table) ->
    GetData = remote_func:call_get_data(Sock, Table, BeDepSidList),
    GetData.

% UpdateList [{<<"Sidxxx">>, Value1}, {} ...]
update_buffer(Manager, UpdateList) ->
    Manager ! {<<"update_buffer">>, UpdateList, self()},
    receive 
        {<<"update_success">>, Manager} -> ok
    end.
