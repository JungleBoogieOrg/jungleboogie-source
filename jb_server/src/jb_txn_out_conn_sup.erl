%%% -------------------------------------------------------------------
%%% Author  : ECEJMTR
%%% Description :
%%%
%%% Created : 09/04/2013
%%% -------------------------------------------------------------------
-module(jb_txn_out_conn_sup).

-include("jb_log.hrl").

-behaviour(supervisor).
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------

%% --------------------------------------------------------------------
%% External exports
%% --------------------------------------------------------------------
-export([start_link/1, start_conn/7, terminate_conn/1]).

%% --------------------------------------------------------------------
%% Internal exports
%% --------------------------------------------------------------------
-export([init/1]).

%% --------------------------------------------------------------------
%% Macros
%% --------------------------------------------------------------------
-define(SERVER, jb_txn_conn).

%% --------------------------------------------------------------------
%% Records
%% --------------------------------------------------------------------

%% ====================================================================
%% External functions
%% ====================================================================

start_link(MySid) ->
    supervisor:start_link({global, {?MODULE, MySid}}, ?MODULE, {}).

start_conn(FsmModule, FsmRef, MySid, Port, PeerSid, TickTime, SyncLimit) ->
    Name = {global, {?SERVER, MySid, PeerSid}},
    ConnChild = {outgoing_connection_handler,
                {?SERVER,start_link,[Name, {FsmModule, FsmRef, MySid, Port, PeerSid, TickTime, SyncLimit}]},
	            temporary,
				2000,
				worker,
				[?SERVER]},
    supervisor:start_child({global, {?MODULE, MySid}}, ConnChild).

terminate_conn(MySid) ->
    supervisor:terminate_child({global, {?MODULE, MySid}}, outgoing_connection_handler),
    supervisor:delete_child({global, {?MODULE, MySid}}, outgoing_connection_handler).

%% ====================================================================
%% Server functions
%% ====================================================================
%% --------------------------------------------------------------------
%% Func: init/1
%% Returns: {ok,  {SupFlags,  [ChildSpec]}} |
%%          ignore                          |
%%          {error, Reason}
%% --------------------------------------------------------------------
init({}) ->
	%% Connection retries are handled within jb_txn_conn, if they fail it is over.
    {ok,{{one_for_one,1,10000}, []}}.

%% ====================================================================
%% Internal functions
%% ====================================================================

