-module(task_center_sup).

-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

-define(SUP, ?MODULE).


start_link()->
    supervisor:start_link({local, ?SUP}, ?MODULE, [], []).

init([]) ->
    % start works
    % ChildList = make_workers(?WORKERS, Listen),
    ChildList = #{
        id => ?SUP,
        start => {task_center, start_center, []}
    },
    Super = #{
            strategy => one_for_one,
            intensity => 5,
            period => 1
        },
    {ok, {Super,ChildList}}.
