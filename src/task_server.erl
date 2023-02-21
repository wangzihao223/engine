-module(task_server).

-behaviour(gen_server).

-export([start_link/2]).

-export([init/1]).
-export([handle_call/3]).



-define(SERVER, ?MODULE).

start_link(MonitorPid, Name) ->
    Server = make_server_name(Name),
    gen_server:start_link({local, Server}, ?MODULE, [MonitorPid, Server], []).

init([MonitorPid, Name]) ->
    % registe
    MonitorPid ! {<<"register">>, Name, self()},
    Table = ets:new(?MODULE, [set, protected]), 
    {ok,Table}.
% configList : [{Sid_1, [Addr_1, Timeout_1]}, {Sid_2, [Addr_2, Timeout_2]}]
handle_call({<<"make_task">>, UUid, ConfigList}, _From, Table)->
    handle_make_task(ConfigList, Table, UUid);
% SidArgs
handle_call({<<"config_sim">>, UUid, SidArgs}, _From, Table) ->
    % save sid_list
    save_sid_list(Table, SidArgs, UUid),
    % init and save sidargs
    handle_start_manager(Table, UUid, SidArgs);
handle_call({<<"make_dep">>, UUid, DepList, BeDepList}, _From, Table) ->
    handle_dep(Table, UUid, DepList, BeDepList);
handle_call({<<"start">>, UUid, MaxStep}, _From, Table) ->
    handle_start(Table, UUid, MaxStep).

handle_make_task(ConfigList, Table, UUid) ->
    % new manager
    try 
        {ManagerPid, MonitorPid} = sim_manager:new_manager(ConfigList, UUid),
        Dict = dict:new(),
        NewDict = dict:append(<<"pid">>, {ManagerPid, MonitorPid}, Dict),
        Dict1 = dict:append(<<"manager_pid">>, ManagerPid, NewDict),
        ets:insert(Table, {UUid, Dict1}),
        {reply, {<<"ok">>, UUid}, Table}
    catch
        throw:X -> {reply, {<<"thrown">>, X}, Table};
        exit:X -> {reply, {<<"exited">>, X}, Table};
        error:X -> {reply, {<<"error">>, X}, Table}
    end.


save_sid_list(Table, SidArgs, UUid) ->
    SidList = get_sid_set(SidArgs),
    [{UUid, Dict}] = ets:lookup(Table, UUid),
    Dict1 =  dict:append(<<"sid_list">>, SidList, Dict),
    ets:insert(Table, {UUid, Dict1}).

handle_start_manager(Table, UUid, SidArgs) ->
    case ets:lookup(Table, UUid) of
        [] ->
            {reply, {<<"uuid_error">>, "uuid is not exist"},Table};
        [{UUid, Dict}] ->
            {ok, {ManagerPid, _}} = dict:find(<<"pid">>, Dict),
            ManagerPid ! {<<"init">>, SidArgs},
            NewDict = dict:append(<<"sim_args">>, SidArgs, Dict),
            ets:insert(Table, {UUid, NewDict}),
            {reply, {<<"ok">>}, Table}
    end.

% get sid list
get_sid_set(SidArgs) ->
    get_sid_set(SidArgs, []).
get_sid_set([], SidList) -> SidList;
get_sid_set(SidArgs, SidList) ->
    [{Sid, _} | NewSidArgs] = SidArgs,
    NewSidList = [Sid | SidList],
    get_sid_set(NewSidArgs, NewSidList).


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
            {reply, {<<"ok">>},Table}
    end.

% start func
handle_start(Table, UUid, MaxStep) ->
    [{UUid, Dict}] = ets:lookup(Table, UUid),
    {ok, ManagerPid} = dict:find(<<"manager_pid">>, Dict),
    {ok, SidList} = dict:find(<<"sid_list">>, Dict),
    proxy_process:create_group_process(
        ManagerPid, SidList, MaxStep),
    {reply, {<<"ok">>}, Table}.

% atom server name
make_server_name(Name) ->
    Bin = erlang:atom_to_binary(?SERVER),
    N = integer_to_list(Name),
    B = unicode:characters_to_binary([Bin, N]),
    Server = binary_to_atom(B),
    Server.