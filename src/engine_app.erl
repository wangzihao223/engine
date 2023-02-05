%%%-------------------------------------------------------------------
%% @doc engine public API
%% @end
%%%-------------------------------------------------------------------

-module(engine_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    engine_sup:start_link().

stop(_State) ->
    ok.

%% internal functions
