-module(manager_creater).

-behaviour(gen_server).

-export([start_link/0]).

-export([init/1]).
-export([handle_call/3]).
-export([handle_cast/2]).

-define(SERVER, ?MODULE).
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).


init([]) ->
    % make ets table
    Table = ets:new(?MODULE, [set, protected]),
    {ok, Table}.


% configList : [{Sid_1, [Addr_1, Timeout_1]}, {Sid_2, [Addr_2, Timeout_2]}]
handle_call({<<"make_new_manager">>, UUid, ConfigList}, _From, Table) ->
    % save uuid_Pid
    {ManagerPid, MonitorPid} = sim_manager:new_manager(ConfigList, UUid),
    Dict = dict:new(),
    NewDict = dict:append(<<"pid">>, {ManagerPid, MonitorPid}, Dict),
    ets:insert(Table, {UUid, NewDict}),
    {noreply, Table};
% sidArgs : [{sid1, Args1}, ...]
% Args1 : [arg1, arg2, arg3 ...]
handle_call({<<"init_sim">>, UUid, SidArgs}, _From, Table) ->
    % get monitor Pid
    handle_start_manager(Table, UUid, SidArgs);
% send dependency 
handle_call({<<"dep">>, UUid, DepList, BeDepList}, _From, Table) ->
    handle_dep(Table, UUid, DepList, BeDepList).

handle_cast(_, _State) ->
    {noreply, 404}.

% handle init_manager and start
handle_start_manager(Table, UUid, SidArgs) ->
    case ets:lookup(Table, UUid) of
        [] ->
            {reply, {<<"uuid_error">>, "uuid is not exist"},Table};
        [{UUid, Dict}] ->
            {ok, {ManagerPid, _}} = dict:find(<<"pid">>, Dict),
            ManagerPid ! {<<"init">>, SidArgs},
            NewDict = dict:append(<<"sim_args">>, SidArgs, Dict),
            ets:insert(Table, {UUid, NewDict}),
            {noreply, Table}
    end.

handle_dep(Table, UUid, DepList, BeDepList) ->
    case ets:lookup(Table, UUid) of
        [] ->
            {reply, {<<"uuid_error">>, "uuid is not exist"},Table};
        [{UUid, Dict}] ->
            {ok, {ManagerPid, _}} = dict:find(<<"pid">>, Dict),
            ManagerPid ! {<<"dep">>, DepList, BeDepList},
            % save DepList and BeDepList
            Dict_1 = dict:append(<<"dep_list">>, DepList, Dict),
            Dict_2 = dict:append(<<"be_dep_list">>, BeDepList, Dict_1),
            ets:insert(Table, {UUid, Dict_2}),
            {noreply, Table}
    end.
