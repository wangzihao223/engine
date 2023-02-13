-module(proxy_process).





% main_loop(Table, ) ->





% registe self to manager
registe_manager(Manager, Sid) ->
    Manager ! {<<"registe">>, Sid, self()},
    receive
        {ok, Manager} -> ok
    end.

% get dependency
get_dep_relationship(Manager, Sid) ->
    Manager ! {<<"proxy_dep">>, Sid, self()},
    receive
        {Dep, BeDep} ->
            % Dep : [sid_1, sid_2, ]
            % BeDep : [sid_3, sid]
            {Dep, BeDep}
    end.


% send request to manager 
req_run(Manager, Step, Sid) ->
    Manager ! {<<"proxy_run">>, Step, Sid, self()},
    receive
        {<<"run">>, Manager} -> ok
    end.