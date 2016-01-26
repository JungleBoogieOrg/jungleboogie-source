%%% -------------------------------------------------------------------
%%% Author  : ECEJMTR
%%% Description :
%%%
%%% Created : 09/04/2013
%%% -------------------------------------------------------------------
-module(jb_fle_out_conn_sup).

-include("jb_log.hrl").

-behaviour(supervisor).
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------

%% --------------------------------------------------------------------
%% External exports
%% --------------------------------------------------------------------
-export([start_link/1, connect/6]).

%% --------------------------------------------------------------------
%% Internal exports
%% --------------------------------------------------------------------
-export([init/1]).

%% --------------------------------------------------------------------
%% Macros
%% --------------------------------------------------------------------
-define(SERVER, jb_fle_conn).

%% --------------------------------------------------------------------
%% Records
%% --------------------------------------------------------------------

%% ====================================================================
%% External functions
%% ====================================================================

start_link(Args = {_FsmModule, _FsmRef, MySid, _ServerList, _TickTime, _SyncLimit}) ->
	supervisor:start_link({global, {?MODULE, MySid}}, ?MODULE, Args).

start_child(Args = {_FsmModule, _FsmRef, MySid, _Port, PeerSid, _TickTime, _SyncLimit}, Type) ->
    Name = {global, {?SERVER, MySid, PeerSid}},
    ConnChild = {{outgoing_connection_handler, MySid, PeerSid},
				{?SERVER,start_link,[Name, Args]},
	            Type,
				2000,
				worker,
				[?SERVER]},
    supervisor:start_child({global, {?MODULE, MySid}}, ConnChild).

%% ====================================================================
%% Server functions
%% ====================================================================
%% --------------------------------------------------------------------
%% Func: init/1
%% Returns: {ok,  {SupFlags,  [ChildSpec]}} |
%%          ignore                          |
%%          {error, Reason}
%% --------------------------------------------------------------------
init({FsmModule, FsmRef, MySid, ServerList, TickTime, SyncLimit}) ->
    spawn_link(fun() -> connect(FsmModule, FsmRef, MySid, ServerList, TickTime, SyncLimit), ok end),
	%% Connections to peers should be tried ad infinitum
	%% Within jb_fle_conn there are retries that will space out connection attempts
    %% Since the retries in jb_fle_conn take more than one second, unless there is
    %% another error, the connection will be restarted forever.
    {ok,{{one_for_one,100,1}, []}}.

%% ====================================================================
%% Internal functions
%% ====================================================================

connect(_FsmModule, _FsmRef, _MySid, [], _TickTime, _SyncLimit) ->
    ok;
connect(FsmModule, FsmRef, MySid, [{PeerSid, _Port} | Rest], TickTime, SyncLimit) when (MySid =:= PeerSid) ->
    %% The loopback link is skipped. Safer for the FSM to insert its own vote in the list.
    connect(FsmModule, FsmRef, MySid, Rest, TickTime, SyncLimit);
connect(FsmModule, FsmRef, MySid, [{PeerSid, Port} | Rest], TickTime, SyncLimit) when (MySid < PeerSid) ->
    %% The connection to a peer with a higher sid is established and then dropped by the other peer.
    {Host, _TXNPort, FLEPort} = Port,
    start_child({FsmModule, FsmRef, MySid, {Host, FLEPort}, PeerSid, TickTime, SyncLimit}, transient),
    connect(FsmModule, FsmRef, MySid, Rest, TickTime, SyncLimit);
connect(FsmModule, FsmRef, MySid, [{PeerSid, Port} | Rest], TickTime, SyncLimit) when (MySid > PeerSid) ->
    {Host, _TXNPort, FLEPort} = Port,
    start_child({FsmModule, FsmRef, MySid, {Host, FLEPort}, PeerSid, TickTime, SyncLimit}, permanent),
    connect(FsmModule, FsmRef, MySid, Rest, TickTime, SyncLimit).
