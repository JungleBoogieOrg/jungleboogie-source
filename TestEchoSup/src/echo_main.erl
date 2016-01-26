%% @author german
%% @doc @todo Add description to echo_main.


-module(echo_main).

%% ====================================================================
%% API functions
%% ====================================================================
-export([start/0, stop/1]).

%% ====================================================================
%% Internal functions
%% ====================================================================

start() ->
	io:format("Hello~n"),
	echo_sup:start_link({7777}).

stop(Pid) ->
	echo_sup:stop(Pid),
	io:format("Bye~n").
