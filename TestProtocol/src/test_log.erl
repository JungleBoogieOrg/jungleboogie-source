%% @author ECEGBB
%% @doc @todo Add description to test_log.


-module(test_log).

-include("zab_log.hrl").

%% ====================================================================
%% API functions
%% ====================================================================
-export([start/0]).



%% ====================================================================
%% Internal functions
%% ====================================================================


start() ->
    ?LOG("hola y adios.").