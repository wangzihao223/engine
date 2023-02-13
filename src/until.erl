-module(until).
-export([sets_equal/2]).

% Compare two sets for equality
sets_equal(Set1, Set2) ->
    sets:is_subset(Set1, Set2) andalso
    sets:is_subset(Set2, Set1).


% error catch
error_catcher(F, Args) ->
    try apply(F, Args) of
        Val -> Val
    catch
        throw:X -> {thrown, X};
        exit:X -> {exited, X};
        error:X -> {error, X}
    end.