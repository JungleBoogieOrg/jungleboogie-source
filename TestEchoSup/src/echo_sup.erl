%% @author german
%% @doc @todo Add description to echo_sup.


-module(echo_sup).
-behaviour(supervisor).
-export([init/1]).

%% ====================================================================
%% API functions
%% ====================================================================
-export([start_link/1, stop/1, start_socket/0]).

start_link(Port) ->
	supervisor:start_link({local, ?MODULE}, ?MODULE, Port).

start_socket() ->
    supervisor:start_child(?MODULE, []).

stop(Pid) ->
	exit(Pid, shutdown).

%% ====================================================================
%% Behavioural functions 
%% ====================================================================

%% init/1
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/supervisor.html#Module:init-1">supervisor:init/1</a>
-spec init(Args :: term()) -> Result when
	Result :: {ok, {SupervisionPolicy, [ChildSpec]}} | ignore,
	SupervisionPolicy :: {RestartStrategy, MaxR :: non_neg_integer(), MaxT :: pos_integer()},
	RestartStrategy :: one_for_all
					 | one_for_one
					 | rest_for_one
					 | simple_one_for_one,
	ChildSpec :: {Id :: term(), StartFunc, RestartPolicy, Type :: worker | supervisor, Modules},
	StartFunc :: {M :: module(), F :: atom(), A :: [term()] | undefined},
	RestartPolicy :: permanent
				   | transient
				   | temporary,
	Modules :: [module()] | dynamic.
%% ====================================================================
init({Port}) ->
    EchoChild = {reader,
        {echo_conn,start_link,[{Port, self()}]},
        permanent,
        20000,
        worker,
        [echo_conn]},
    spawn_link(fun() -> io:format("spawned."), start_socket() end),
    {ok,{{simple_one_for_one,1,1}, [EchoChild]}}.

%% ====================================================================
%% Internal functions
%% ====================================================================


