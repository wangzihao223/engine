-module(proxy_process).

-export([new_process/4]).

-import(until, [sets_equal/2]).


new_process(Manager, Sid, Step, MaxStep) ->
    spawn(fun() -> proxy_process(Manager, Sid,
        Step, MaxStep) end).

proxy_process(Manager, Sid, Step, MaxStep) ->
    % process init
    {Table, DepTuple} = process_init(Manager, Sid),
    {Dep, BeDep} = DepTuple,
    % Dep is list , BeDep also list
    WaitSet = sets:from_list(Dep),
    SendList = BeDep,
    % get Sock
    [{<<"sid_sock">>, SidSock}] = ets:lookup(Table, <<"sid_sock">>),
    Sock = dict:find(Sid, SidSock),
    % get buffer key
    BufferKey = unicode:characters_to_binary([Sid, <<"_buff">>]),
    main_loop(Manager, Sid, WaitSet, Sock, SendList, Table, BufferKey, Step,
        MaxStep).

process_init(Manager, Sid) ->
    % link manager
    link(Manager),
    Table = registe_manager(Manager, Sid),
    DepTuple = get_dep_relationship(Manager, Sid),
    {Table, DepTuple}. 


% registe self to manager
registe_manager(Manager, Sid) ->
    Manager ! {<<"registe">>, Sid, self()},
    receive
        {ok, _Manager, Table} -> Table
    end.

% get dependency
get_dep_relationship(Manager, Sid) ->
    Manager ! {<<"proxy_dep">>, Sid, self()},
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
