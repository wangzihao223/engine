-module(tcp_listener).

-behaviour(supervisor).


-export([start_link/0]).

-export([init/1]).

-define(PORT, 9989).

-define(WORKERS, 100).

start_link()->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).
init([]) ->
    {ok, Listen} = gen_tcp:listen(?PORT, [{active, once},{packet, 4}]),
    io:format("INFO: tcp listener start ~n"),
    % start works
    ChildList = make_workers(?WORKERS, Listen),
    Super = #{
            strategy => one_for_one,
            intensity => 5,
            period => 1
        },
    {ok, {Super,ChildList}}.


make_workers(Num, Listen) ->
    make_workers(Num, [], Listen).
make_workers(0, ChildList, _Listen) -> ChildList;
make_workers(Num, ChildList, Listen) ->
    Child = #{
            id => Num,
            start => {tcp_worker, start_worker, [Listen, Num]},
            type => worker
        },
    NewChildList = [Child | ChildList],
    make_workers(Num-1, NewChildList, Listen).