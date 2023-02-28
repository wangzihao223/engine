
-module(engine_transport).
-export[recv_data/1].
-export[send_data/2].
-export([connect_sim/3]).

-export([call_many_sim/3]).
-export([waiter/2]).
-export([call_sim_add_reply/5]).
-export([call_sim/4]).

-import(until, [sets_equal/2]).


% recv other sim data
% return all payload
recv_data(Socket) ->
    io:format("DEBUG: XXXXX ~n"),
    receive
        {tcp, Socket, Data} ->
            io:format("DDDDDDDDDDDDDDDDD~n"),
            % unpack data
            % use jiffy
            ErlData = from_bin_to_erl(Data),
            io:format("DEBUG:RECV ~p ~n", ErlData),
            inet:setopts(Socket, [{active, once}, {packet, 4}]),
            {ok, ErlData};
        % TODO:  timeout or
        % tcp close
        {tcp_closed, Socket} ->
            % need 
            {error, "Sim client close !"}
    end.


% send data to sim
send_data(Socket, Data) ->
    % data is erlang obj
    BinData = jiffy:encode(Data),
    io:format("DEBUG: send bin_data ~p ~n", [BinData]),
    gen_tcp:send(Socket, BinData).


% from binary to erlang obj
from_bin_to_erl(Data) ->
    jiffy:decode(Data).


% pack data

% request remote sim do some
% method , need method name 
% args and message id
req_sim_method(Id, Method, Args) ->
    % req message so type is 0
    [Id, 0, [Method, Args]].

% rpc sim
call_sim(Sock, Id, Method, Args) ->
    Package = req_sim_method(Id, Method, Args),
    send_data(Sock, Package),
    io:format("TEST: socket ~p ~n", [Sock]),
    recv_data(Sock).


% Concurrency call remote func
% sockArgs like:
% [{Sock_1, args}, {Sock_2, args2}]
call_many_sim(SockArgs, Table, Method) ->

    put(<<"counter">>, 0),
    % get socket list from table 
    [{<<"sock_list">>, Sockets}] = ets:lookup(Table, <<"sock_list">>),
    % list to set
    SocketSet = sets:from_list(Sockets),
    % spwan new waiter
    Waiter = spawn(engine_transport, waiter, [self(), SocketSet]),
    % all sim reply
    % [{Sock_1, Data_1}, {Sock_2, Data_2}, ...]
    Res = loop_call_sim(SockArgs, SocketSet, Table, Method, Waiter),
    Res.


% reply waiter 
reply_waiter(Waiter, Sock, Data) ->
    Waiter ! {ok, Sock, Data}.


% call sim func have reply module 
call_sim_add_reply(Sock, Id, Method, Args, Waiter) ->
    Response = call_sim(Sock, Id, Method, Args),
    io:format("DEBUG: RESPONSE IS  ~p ~n", [Response]),
    reply_waiter(Waiter, Sock, Response).

waiter(Master, Set) ->
    RecvSet = sets:new(),
    Res = [],
    waiter(Master, Set, RecvSet, Res).

% waiter wait all process done
waiter(Master, Set, RecvSet, Res) ->
    R = sets_equal(Set, RecvSet),
    if R -> 
        % done
        % child process done
        % send Master message   
        % waiter break
        Master ! {ok, Res};

        % wait all process done
        true ->

            receive
                {ok, Sock, Data} ->
                    NewRes = [{Sock, Data}|Res],
                    % NewResSet = sets:add_element(Res, {Sock, Data}),
                    NewRecvSet = sets:add_element(RecvSet, Sock),
                    waiter(Master, Set, NewRecvSet, NewRes)
            end
    end.

% loop call sim
% sockargs [{sock_1, Args_1}, {sock_2, Args_2}, ...]
loop_call_sim([], _Sockets, _Table, _Method, _Waiter) ->
    % wait Water reply
    receive
        {ok, Res} ->
            io:format("DEBUG: RES IS ~p ~n", [Res]),
            Res
    end;
loop_call_sim(SockArgs, SocketSet, Table, Method, Waiter) ->
    [{Sock, Args} | NextSockArgs] = SockArgs,
    % get id from table
    Id = counter_up(),
    %  spawn new process
    spawn(engine_transport, call_sim_add_reply, [Sock, Id, Method, Args, Waiter]),
    loop_call_sim(NextSockArgs, SocketSet, Table, Method, Waiter).

% counter up
counter_up() ->
    % get id from table
    MsgId = get(<<"counter">>),
    % io:format("DEBUG: MsgId  is ~d ~n", [MsgId]),
    io:format("DEBUG: MsgId is ~b ~n", [MsgId]),
    put(<<"counter">>, MsgId+1),
    MsgId.

% connect sim 
% Addr : {Ip, Port}
% Ip: {0..255, 0..255, 0..255, 0..255} or string
% Port: int
connect_sim(Addr, Port, Timeout) ->
    Option = [{active, once}, {packet, 4}],
    % {IP, Port} = Addr,
    % connect sim
    Addr1 = erlang:binary_to_list(Addr),
    Response = gen_tcp:connect(Addr1, Port, Option, Timeout),
    io:format("DEBUG: response is ~p ~n", [Response]),
    case Response of
        % connect sucess
        {ok, Socket} -> 
            Socket;
        {error, Reason} ->
            throw({<<"connect_error">>, Reason})
    end.
