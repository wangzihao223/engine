-module(proxy_creater).

-behaviour(gen_server).

-export([start_link/0]).

-export([init/1]).
-export([handle_call/3]).
-export([handle_cast/2]).

-define(SERVER, ?MODULE).

start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

init([]) ->
    Table = ets:new(?MODULE, [set, protected]), 
    {ok,Table}.

handle_cast({<<"proxy_group">>, Manager, SidList, MaxStep}, _Table)->
    proxy_process:create_group_process(Manager,
        SidList, MaxStep).
handle_call({<<"new_proxy">>, Manager, Sid, Step, MaxStep}, 
    _From, _Table) ->
    proxy_process:new_process(Manager, Sid, Step, MaxStep).
