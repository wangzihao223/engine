-module(tcp_worker).


-export([start_worker/2]).
-export([start_worker1/0]).
-export([main/0]).
-export([start_main/1]).
-export([spwan_main/0]).

start_worker(Socket, ID) ->
    Pid = spawn(fun() -> accepter(Socket, ID) end),
    {ok, Pid}.

receiver(Socket) ->
    receive
        {tcp, Socket, Data} -> 
            Size = length(Data),
            io:format("length is ~.B ~n", [Size]),
            % TODO handle data
            inet:setopts(Socket, [{active, once}, 
                {packet, 4}]),
            receiver(Socket);
        {tcp_closed, Socket} ->
            io:format("socket closed  ~p", [[Socket]])
    end.

accepter(Listen, ID) ->
    io:format("listen is ~p ~n", [ID]),
    {ok, Socket} = gen_tcp:accept(Listen),
    io:format("~B get socket ~n", [ID]),
    Controller = spawn(fun() -> receiver(Socket) end),
    ok = gen_tcp:controlArg1ling_process(Socket, Controller),
    accepter(Listen, ID). 


main() ->
    {ok, Listen} = gen_tcp:listen(9999, [{active, once},{packet, 4}]),
    loop(Listen).

spwan_main() ->
    spawn(fun()-> main() end).

loop(Listen) ->
    receive
        {exit, Pid} -> Pid ! ok;
        {get, Pid} -> Pid ! Listen , loop(Listen)
    end.

start_main(P)->
    P  ! {get, self()}, 
    receive
        ok -> ok;
        Listen -> Listen
    end.

l() ->
        receive 
        exit -> ok
end.

start_worker1() ->
    
    Pid = spawn(fun() -> l() end),
    {ok, Pid}.