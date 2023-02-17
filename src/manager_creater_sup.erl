-module(manager_creater_sup).

-behaviour(supervisor).

-export([start_link/0]).

-export([init/1]).

-define(SERVER, ?MODULE).

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%% sup_flags() = #{strategy => strategy(),         % optional
%%                 intensity => non_neg_integer(), % optional
%%                 period => pos_integer()}        % optional
%% child_spec() = #{id => child_id(),       % mandatory
%%                  start => mfargs(),      % mandatory
%%                  restart => restart(),   % optional
%%                  shutdown => shutdown(), % optional
%%                  type => worker(),       % optional
%%                  modules => modules()}   % optional
init([]) ->
    SupFlags = #{strategy => one_for_one,
                 intensity => 1,
                 period => 10},
    ChildSpecs = [
        #{
            id => manager_creater,
            start => {manager_creater, start_link, []}
        }
    ],
    {ok, {SupFlags, ChildSpecs}}.

%% internal functions

make_managers(0, ChildList, _Table) -> ChildList;
make_managers(Num, ChildList, Table) ->
    Child = #{
        id => Num,
        start => {},
        type => worker
    },
    NewChildList = [Child | ChildList],
    make_managers(Num - 1, NewChildList, Table).