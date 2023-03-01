-module(remote_func).

-export([init_all_sim/2]).
-export([call_setup_done/2]).
-export([call_step/4]).
-export([call_get_data/3]).
-export([call_stop/2]).

-import(engine_transport, [call_many_sim/3]).
-import(engine_transport, [call_sim/4]).
-import(engine_transport, [counter_up/0]).


% all sim call init func 
% sid : ["sid_1", "sid_2", "sid_3"...]
% sidArgs : [{sid1, Args1}, ...]
% Args1 : [arg1, arg2, arg3 ...]
% return :
% [{Sock1, Data1}, {Sock2, Data2}, ...]
init_all_sim(SidArgs, Table) ->
    % SidArgs transformation SockArgs
    SockArgs = get_sock_args(SidArgs, Table),
    call_many_sim(SockArgs, Table, <<"init">>).

% get SockArgs
%
get_sock_args(SidArgs, Table) ->
    SockList = [],
    get_sock_args(SidArgs, Table, [], SockList).

get_sock_args([], Table, SockArgs, SockList) ->
    save_sock_list(Table, SockList),
    % ets:insert(Table, {<<"sock_list">>, SockList}),
    SockArgs;
get_sock_args(SidArgs, Table, SockArgs, SockList) ->
    % get sid-sock from table
    [{Sid, Args}| NextSidArgs] = SidArgs,
    [{<<"sid_sock">>, Sid_Sock}] = ets:lookup(Table, <<"sid_sock">>),
    % Sid_Sock is dict
    {ok, Sock} = dict:find(Sid, Sid_Sock),
    NewSockArgs = [{Sock, Args}| SockArgs],
    NewSockList = [Sock | SockList],
    get_sock_args(NextSidArgs, Table, NewSockArgs, NewSockList).

save_sock_list(Table, SockList) ->
    ets:insert(Table, {<<"sock_list">>, SockList}).

% call setup_done
call_setup_done(Sock, _Table) ->
    % get message id
    Id = counter_up(),
    call_sim(Sock, Id, <<"setup_done">>, []).


% call setp
call_step(Sock, _Table, Time, Inputs) ->
    % get message id
    Id = counter_up(),
    % ToDo: error handle
    {ok, Data} = call_sim(Sock, Id, <<"step">>, [Time, Inputs]),
    [_MsgId, Type, NextTime] = Data,
    if Type =:= 1 ->
        % success
            NextTime;
        % error
        true ->
            throw({<<"func_error">>, "step remote error !"})
    end.


% call get data
% return:
% jiffy makde {[{"sid_1", V_1}, {"sid_2", V_2}]}
call_get_data(Sock, _Table, _OutPuts) ->
    % get message id
    Id = counter_up(),
    % OutPuts 先设置为空
    {ok, Data} = call_sim(Sock, Id, <<"get_data">>, [_OutPuts]),
    [_MsgId, Type, GetData] = Data,
    if Type =:= 1 ->
        % success
            {GetData1} = GetData,
            GetData1;
        % error
        true ->
            throw({<<"func_error">>, "get_data error"})
    end.

% call_get_data(Sock, Table, o) ->
%     call_get_data(Sock, Table, []).


% call stop func
call_stop(Sock, _Table) ->
    % get message id
    Id = counter_up(),
    {ok, Data} = call_sim(Sock, Id, <<"stop">>, []),
    [_MsgId, Type, _GetData] = Data,
    if Type =:= 1 ->
        % success
        ok;
        true ->
            throw({<<"func_error">>, "stop error"})
    end.