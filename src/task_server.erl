-module(task_server).

-behaviour(gen_server).

-export([start_link/0]).

-export([init/1]).
-export([handle_call/3]).
% -export([handle_cast/2]).

-export([make_task/1]).

-define(SERVER, ?MODULE).

start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

init([]) ->
    Table = ets:new(?MODULE, [set, protected]), 
    {ok,Table}.
% configList : [{Sid_1, [Addr_1, Timeout_1]}, {Sid_2, [Addr_2, Timeout_2]}]
handle_call({<<"make_task">>, ConfigList}, _From, _Table)->
    {UUid, ManagerPid} = handle_make_task(ConfigList),
    Dict = dict:new(),
    Dict1 = dict:append(<<"manager_pid">>, ManagerPid, Dict),
    ets:insert(_Table, {UUid, Dict1}),
    {reply, {UUid}, _Table};
% SidArgs
handle_call({<<"config_sim">>, UUid, SidArgs}, _From, Table) ->
    % init and save sidargs
    Res = manager_creater:init_sim(UUid, SidArgs),
    % save sid_list
    save_sid_list(Table, SidArgs, UUid),
    {reply, Res, Table};
handle_call({<<"make_dep">>, UUid, DepList, BeDepList}, _From, _Table) ->
    manager_creater:send_dep(UUid, DepList, BeDepList),
    {noreply, _Table};
handle_call({<<"start">>, UUid, MaxStep}, _From, _Table) ->
    [{UUid, Dict}] = ets:lookup(_Table, UUid), 
    SidList = dict:find(<<"sid_list">>, Dict),
    Manager = dict:find(<<"manager_pid">>, Dict),
    % make a group proxy process
    proxy_creater:create_proxy_group(Manager, SidList, MaxStep),
    {noreply, _Table}.

handle_make_task(ConfigList ) ->
    UUid = until:make_uuid(),

    ManagerPid = manager_creater:make_new_manager(UUid, ConfigList),
    
    {UUid, ManagerPid}.

save_sid_list(Table, SidArgs, UUid) ->
    SidList = get_sid_set(SidArgs),
    [{UUid, Dict}] = ets:lookup(Table, UUid),
    Dict1 =  dict:append(<<"sid_list">>, SidList, Dict),
    ets:insert(Table, {UUid, Dict1}).

% get sid list
get_sid_set(SidArgs) ->
    get_sid_set(SidArgs, []).
get_sid_set([], SidList) -> SidList;
get_sid_set(SidArgs, SidList) ->
    [{Sid, _} | NewSidArgs] = SidArgs,
    NewSidList = [Sid | SidList],
    get_sid_set(NewSidArgs, NewSidList).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Interface
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
make_task(ConfigList) ->
    UUid = gen_server:call(?SERVER, {<<"make_task">>, ConfigList}),
    UUid.

config_sim(UUid, SidArgs) ->
    Res = gen_server:call(?SERVER, {<<"config_sim">>, UUid, SidArgs}),
    Res.

make_dep()