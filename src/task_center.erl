-module(task_center).



-export([start_center/0]).
-export([create_worker/1]).

-define(WORKER_NUM, 5).



start_center() ->

    Center = spawn(fun() -> center_main() end),
    register(tasker_center, Center),
    create_worker(?WORKER_NUM).



center_main() ->
    Table = init(),
    Queue = init_queue(Table),
    loop(Table, Queue).

create_worker(0) -> ok;
create_worker(Num) ->
    task_server:start_link(),
    create_worker(Num-1).

    
init()->
    % wait tasker
    Num = ?WORKER_NUM,
    Table = ets:new(?MODULE, [set]),
    wait_tasker(Table, Num),
    Table.


% register
wait_tasker(Table, Num) ->
    wait_tasker(Table, Num, []).
wait_tasker(Table, 0, List)->
    ets:insert(Table, {<<"worker_list">>, List}),
    List;
wait_tasker(Table, Num, List) ->
    receive
        {<<"register">>, Name, Pid} ->
            monitor(process, Pid),
            % save Name-Pid
            ets:insert(Table, {Name, Pid}),
            Num1 = Num - 1,
            NewList = [Name | List],
            wait_tasker(Table, Num1, NewList)
    end.


loop(Table, Queue) ->   
    receive
        {<<"req">>, UUid, From} ->
            Queue_2 = handle_req(Table, UUid, Queue, From),
            loop(Table, Queue_2)
        % TODO worker dead
    end.

handle_req(Table, UUid, Queue, From) ->
    case ets:lookup(Table, UUid) of
        [] ->
            {{value, {Name, Pid}}, Queue_1} = queue:out(Queue),
            ets:insert(Table, {UUid, {Name, Pid}}),
            From ! {Name, Pid},
            Queue_2 = queue:in({Name, Pid}, Queue_1),
            Queue_2;
        [{_UUid, {Name, Pid}}] -> 
            From ! {Name, Pid},
            Queue
end.

    


% return new queue
init_queue(Table) ->
    [{<<"worker_list">>, List}] = ets:lookup(Table, {<<"worker_list">>, 
        Table}),
    Q = queue:new(),
    init_queue(Table, List, Q). 

init_queue(_Table, [], Q) -> Q;
init_queue(Table, L, Q) ->
    [Name | NextList] = L,
    [{Name, Pid}] = ets:lookup(Table, Name),
    Q1 = queue:in({Name, Pid}, Q),
    init_queue(Table, NextList, Q1).

% handle_call({<<"req">>, UUid, From}, From, {Table, Queue}) ->
%     {{value, {Name, Pid}}, Queue_0} = queue:out(Queue),
%     ets:insert(Table, {UUid, {Name, Pid}}),
%     From ! {Name, Pid},
%     Queue_1 = queue:in({Name, Pid}, Queue_1),
%     {reply, {<<"ok">>, Name, Pid}, {Table, Queue_1}}.







