-module(test_timeout).
-export([test/0]).


test() ->
    receive
        {ok} ->ok
    after 1000 ->
        io:format("time out ~n")
    end.

