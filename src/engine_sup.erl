%%%-------------------------------------------------------------------
%% @doc engine top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(engine_sup).

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
                 intensity => 5,
                 period => 1},
    ChildSpecs = [
        #{
            id => "tcp_listener",
            start => {tcp_listener, start_link, []}
            % type => supervisor
        },
        #{
            id => "task_center_sup",
            start => {task_center_sup, start_link, []}
            % type => supervisor
        }
    ],

    {ok, {SupFlags, ChildSpecs}}.

%% internal functions