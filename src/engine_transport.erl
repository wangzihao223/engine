
-module(engine_transport).
-export[recv_data/1].
-export[send_data/2].

% recv other sim data
% return all payload
recv_data(Sock) ->
    receive
        {tcp, Sock, Data} ->
            % unpack data
            % use jiffy
            ErlData = from_bin_to_erl(Data),
            inet:setopts(Sock, [{active, once}]),
            {ok, ErlData};
        % TODO:  timeout or
        % tcp close
        {tcp_closed, Sock} ->
            % need 
            {error, "Sim client close !"}
    end.


% send data to sim
send_data(Sock, Data) ->
    % data is erlang obj
    BinData = jiffy:encode(Data),
    gen_tcp:send(Sock, BinData).


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
    recv_data(Sock).


% Concurrency call remote func
% the sockList is dict:to_list(sockdict)
% sockList like:
% [{Sock_1, args}, {Sock_2, args2}]
call_many_sim(SockList, Table, Method) ->

    % loop call sim