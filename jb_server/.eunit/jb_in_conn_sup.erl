%%% -------------------------------------------------------------------
%%% Author  : ECEJMTR
%%% Description :
%%%
%%% Created : 09/04/2013
%%% -------------------------------------------------------------------
-module(jb_in_conn_sup).

-include("jb_log.hrl").

-behaviour(supervisor).
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------

%% --------------------------------------------------------------------
%% External exports
%% --------------------------------------------------------------------
-export([start_link/1, start_socket/2, terminate_child/3]).

%% --------------------------------------------------------------------
%% Internal exports
%% --------------------------------------------------------------------
-export([init/1]).

%% --------------------------------------------------------------------
%% Macros
%% --------------------------------------------------------------------

%% --------------------------------------------------------------------
%% Records
%% --------------------------------------------------------------------

%% ====================================================================
%% External functions
%% ====================================================================

start_link(Args = {_FsmModule, _FsmRef, Type, MySid, _Port, _N, _TickTime, _SyncLimit}) ->
    supervisor:start_link({global, {?MODULE, Type, MySid}}, ?MODULE, Args).

start_socket(Type, MySid) ->
    supervisor:start_child({global, {?MODULE, Type, MySid}}, []).

terminate_child(Type, MySid, Pid) ->
    supervisor:terminate_child({global, {?MODULE, Type, MySid}}, Pid).

%% ====================================================================
%% Server functions
%% ====================================================================
%% --------------------------------------------------------------------
%% Func: init/1
%% Returns: {ok,  {SupFlags,  [ChildSpec]}} |
%%          ignore                          |
%%          {error, Reason}
%% --------------------------------------------------------------------
init({FsmModule, FsmRef, Type, MySid, HostPort, N, TickTime, SyncLimit}) ->
    {Host, Port} = HostPort,
    Res = gen_tcp:listen(Port, [{active,once}, {packet,line}, {reuseaddr, true}, {ip, Host}]),
    case Res of
        {ok, ListenSocket} ->
            spawn_link(fun() -> [start_socket(Type, MySid) || _ <- lists:seq(1,N)], ok end),
            InConns = {incoming_connection_handler,
                {Type,start_link,[{FsmModule, FsmRef, MySid, ListenSocket, TickTime, SyncLimit}]},
                permanent,
                1000,
                worker,
                [Type]},
            {ok,{{simple_one_for_one,10*N,10}, [InConns]}};
        Error ->
            ?ERROR("Couldn't start ~p listener, reason ~p.", Type, Error),
            {error, Error}
    end.

%% ====================================================================
%% Internal functions
%% ===================================================================
