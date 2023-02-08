-module(heapq).

-export([new/0]).
-export([from_array/1]).
-export([pop/1]).
-export([push/2]).
-export([test_from_array/0]).
-export([test_pop/0]).
-export([look_top/1]).



new() -> array:new().

% ceate heap from array
from_array(Array)->
    Length = array:size(Array),
    {NewArray, _} = loop_find_small(Array, 0, Length),
    NewArray.

% compare a and b
small_one({LeftIndex, LeftValue}, {RightIndex, RightValue}) ->
    % get priority
    {LeftPriority, _} = LeftValue,
    {RightPriority, _} = RightValue,
    if LeftPriority < RightPriority ->
        {LeftIndex, LeftValue};
        true ->
            {RightIndex, RightValue}
    end.

% exchange a and b
exchange_node({AIndex, AValue}, {BIndex, BValue}, Array) ->
    Array2 = array:set(AIndex, BValue, Array),
    Array3 = array:set(BIndex, AValue, Array2),
    Array3.

% find small 
find_small(Array , ParentIndex, Length) ->
    % three condition
    LeftTreeIndex = ParentIndex * 2 + 1,
    RightTreeIndex = ParentIndex * 2 + 2,

    % get parent value
    ParentValue = array:get(ParentIndex, Array),
    {ParentPriority, _} = ParentValue,

    % first: not exist child
    if LeftTreeIndex >= Length ->
        % return parent index and Array
        {ParentIndex, Array};
    % second: both exist child
        RightTreeIndex < Length ->
            % find left child tree and right child tree
            % small value
            {LeftIndex, Array1} = find_small(Array, LeftTreeIndex, Length),
            {RightIndex, Array2} = find_small(Array1, RightTreeIndex, Length),
            % get left and right value
            LeftValue = array:get(LeftIndex, Array2),
            RightValue = array:get(RightIndex, Array2),
            % compare left and right value
            {SmallIndex, SmallValue} = small_one({LeftIndex, LeftValue},
                {RightIndex, RightValue}),
            {SmallPriority, _} = SmallValue,
            % compare small child and parent
            if ParentPriority > SmallPriority ->
                % excange value
                Array3 = exchange_node({ParentIndex, ParentValue}, 
                    {SmallIndex, SmallValue}, Array2);
                true -> 
                    Array3 = Array2
            end,
            {ParentIndex, Array3};
    % third: have left child
        true ->
            % not exist child 
            % get left value 
            LeftIndex =  LeftTreeIndex,
            LeftValue = array:get(LeftIndex, Array),
            % compare left and parent value
            {LeftPriority, _} = LeftValue,
            if ParentPriority > LeftPriority->
                % excange value
                Array1 = exchange_node({ParentIndex, ParentValue},
                    {LeftIndex, LeftValue}, Array);
                true -> Array1 = Array
            end,
            {ParentIndex, Array1}
    end.

% loop sort all arry
loop_find_small(Array, StartIndex, Length) when StartIndex >= Length ->
    {Array, StartIndex};
loop_find_small(Array, StartIndex, Length) ->
    {PIndex, Array1} = find_small(Array , StartIndex, Length),
    NextIndex = PIndex + 1,
    loop_find_small(Array1, NextIndex, Length).

% push value in heap
push(Heap, Value) ->
    % caculate size 
    OldSize = array:size(Heap),
    % put Value to last index
    Heap1 = array:set(OldSize, Value, Heap),

    Length = OldSize + 1,
    % go up
    NewHeap = go_up(Heap1, OldSize, Length),
    NewHeap.

% go up
go_up(Heap, 0, _Length) -> Heap;
go_up(Heap, NodeIndex, Length) ->
    % get parent index
    ParentIndex = (NodeIndex - 1) div 2,
    ParentValue = array:get(ParentIndex, Heap),
    NodeValue = array:get(NodeIndex, Heap),
    {ParentPriority, _} = ParentValue,
    {NodePriority, _} = NodeValue,
    % compare priority value
    if NodePriority < ParentPriority ->
        % go up
        Heap1 = exchange_node({NodeIndex, NodeValue}, {ParentIndex, ParentValue}
        , Heap),
        go_up(Heap1, ParentIndex, Length);
        % else
        true ->
            % stop go up
            Heap
    end.

% pop value
pop(Heap) ->
    Size = array:size(Heap),
    pop(Heap, Size).

pop(Heap, Size) when Size =< 0 ->
    {error, Heap};
% heap can't null
pop(Heap, Size) when Size > 0 ->

    TopValue = array:get(0, Heap),
    % put the last one on the top
    OldSize = Size,
    LastValue = array:get(OldSize-1, Heap),

    % new heap
    Heap1 = array:set(0, LastValue, Heap),
    % resize heap
    NewSize = OldSize - 1,
    Heap2 = array:resize(OldSize-1, Heap1),
    % godown
    Heap3 = go_down(Heap2, 0, NewSize),
    % return  new heap and top value
    {TopValue, Heap3}.

% go down 
go_down(Heap, NodeIndex, Size) when NodeIndex >= Size -> Heap;
go_down(Heap, NodeIndex, Size) -> 
    % get left and right index
    LeftIndex = NodeIndex * 2 + 1,
    RightIndex = NodeIndex * 2 + 2,
    NodeValue = array:get(NodeIndex, Heap),
    {NodePriority, _value} = NodeValue,

    % three conditons
    if
        % not exist child
        LeftIndex >= Size ->
            % stop go down
            Heap;
        % both exist
        RightIndex < Size ->
            % compare left and right 
            LeftValue = array:get(LeftIndex, Heap),
            RightValue = array:get(RightIndex, Heap),
            % find small one
            {SmallIndex, SmallValue} = small_one({LeftIndex, LeftValue}, 
                {RightIndex, RightValue}),
            {SmallPriority, _value1} = SmallValue,
            % compare small one and go_down node
            if 
                % need go down
                NodePriority > SmallPriority ->
                    % exchange node
                    % get new heap
                    Heap1 = exchange_node({SmallIndex, SmallValue}, 
                    {NodeIndex, NodeValue}, Heap),
                    % continue go down
                    go_down(Heap1, SmallIndex, Size);
                % don't need go down
                true ->
                    % stop go down 
                    % return new Heap
                    Heap
            end;
        % have left child 
        true ->
            % get Left Value
            LeftValue = array:get(LeftIndex, Heap),
            {LeftPriority, _value2} = LeftValue,
            % compare Left and go down node
            if 
                NodePriority > LeftPriority ->
                    % exchange node
                    Heap1 = exchange_node({LeftIndex, LeftValue}, 
                    {NodeIndex, NodeValue}, Heap),
                    % because the left ndoe is end 
                    % so stop go down
                    Heap1;
                % don't need go down
                true ->
                    % stop go down
                    Heap
            end
    end.

% look the priority queue top value
% but not pop            
look_top(Heap) ->
    Size = array:size(Heap),
    look_top(Heap, Size).

look_top(Heap, Size) when Size > 0 ->
    array:get(0, Heap);
look_top(_Heap, _Size) ->
    error.

            


%  test from_array
test_from_array() -> 
    List = [{100,0}, {1, 0}, {5, 0}, {44,0}, {0, 0}, {10,0}, {9,0}],
    Array = array:from_list(List),
    Array1 = from_array(Array),
    Array2 = array:to_list(Array1),
    io:format("~p ~n", [Array2]),
    Array2.

create_heap(List) ->
    Heap = new(),
    create_heap(Heap, List).

create_heap(Heap, []) ->
    Heap;
create_heap(Heap, List)->
    [Head| NextList] = List,
    Heap1 = push(Heap, {Head, 0}),
    create_heap(Heap1, NextList).

loop_pop(Heap) ->
    Count = array:size(Heap),
    loop_pop(Heap, Count).

loop_pop(_Heap, 0) -> ok;
loop_pop(Heap, Count) ->
    {V, Heap1} = pop(Heap),
    io:format("pop value ~p ~n", [V]),
    loop_pop(Heap1, Count-1).
% test pop func
test_pop() ->
    % List = [80, 60, 1, 30, 25, 40, 2, 7],
    List = [100, 3, 4, 5, 7, 66, 88, 1],
    Heap = create_heap(List),
    List1 = array:to_list(Heap),
    io:format("create heap is ~p ~n", [List1]),
    loop_pop(Heap).