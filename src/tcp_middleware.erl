-module(tcp_middleware).


-export([handle_data/2]).


handle_data(Msg, Sock) ->
    {Command, Args} = bin_to_term(Msg),
    handle_command(Command, Args, Sock).

% use json
bin_to_term(Msg) ->

    ETerm = jiffy:decode(Msg),
    [Command, Args] = ETerm,
    {Command, Args}.

term_to_bin(T) ->
    jiffy:encode(T).


handle_command(Command, Args, Sock) ->
    case Command of
        <<"make_task">> ->
            make_task(Args, Sock);
        <<"config_sim">> ->
            config_sim(Args, Sock);
        <<"make_dep">> ->
            make_dep(Args, Sock);
        <<"start">> ->
            start_sim(Args, Sock)
    end.


make_task(Args, Sock) ->
    [ConfigList] = Args,
    {ConfigList1} = ConfigList,
    UUid = until:make_uuid(),
    tasker_center ! {<<"req">>, UUid, self()},
    {Name, _Pid} = get_tasker(),
    Reply = gen_server:call(Name, {<<"make_task">>, UUid, ConfigList1}),
    BR = term_to_bin(Reply),
    gen_tcp:send(Sock, BR).

config_sim(Args, Sock) ->
    [UUid, {SidArgs}] = Args,
    task_center ! {<<"req">>, UUid, self()},
    {Name, _Pid} = get_tasker(),
    {Reply} = gen_server:call(Name, {<<"config_sim">>, UUid, SidArgs}),
    BR = term_to_bin(Reply),
    gen_tcp:send(Sock, BR).

make_dep(Args, Sock) ->
    [UUid, {DepList}, {BeDepList}] = Args, 
    task_center ! {<<"req">>, UUid, self()},
    {Name, _Pid} = get_tasker(),
    {Reply} = gen_server:call(Name, {<<"make_dep">>, 
        UUid, DepList, BeDepList}),
    BR = term_to_bin(Reply), 
    gen_tcp:send(Sock, BR).

start_sim(Args, Sock) ->
    [UUid, MaxStep] = Args,
    task_center ! {<<"req">>, UUid, self()},
    {Name, _Pid} = get_tasker(),
    {Reply} = gen_server:call(Name, {<<"start">>, UUid, MaxStep}),
    BR = term_to_bin(Reply),
    gen_tcp:send(Sock, BR).

    


get_tasker() ->
    receive
        {Name, Pid} -> {Name, Pid}
    end.