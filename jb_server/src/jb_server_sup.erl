%% @author ecegbb
%% @doc @todo Add description to jb_server_sup.

-module(jb_server_sup).
-behaviour(supervisor).
-export([init/1]).

-define(SERVER_FSM, jb_server_fsm).

%%
%% Include files
%%
-include("jb_log.hrl").

%%
%% Exported Functions
%%
-export([]).

%% ====================================================================
%% API functions
%% ====================================================================
-export([start_link/1, start_txn_acceptors/5, terminate_txn_acceptors/1, start_txn_conn/7, terminate_txn_conn/1]).

start_link(Args = {MySid, _ServerList, _TickTime, _InitialLimit, _SyncLimit}) ->
    supervisor:start_link({global, {?MODULE, MySid}}, ?MODULE, Args).

start_txn_acceptors(_MySid, _TXNPort, 0, _TickTime, _SyncLimit) ->
    ok;
start_txn_acceptors(MySid, TXNPort, NTXNAcceptors, TickTime, SyncLimit) ->
    FsmRef = {global, {?SERVER_FSM, MySid}},
    InTXNConns = {txn_in_conn_sup,
              {jb_in_conn_sup,start_link,[{?SERVER_FSM, FsmRef, jb_txn_conn, MySid, TXNPort, NTXNAcceptors, TickTime, SyncLimit}]},
              permanent,
              infinity,
              supervisor,
              [jb_in_conn_sup]},
    supervisor:start_child({global, {?MODULE, MySid}}, InTXNConns).

terminate_txn_acceptors(MySid) ->
    supervisor:terminate_child({global, {?MODULE, MySid}}, txn_in_conn_sup),
    supervisor:delete_child({global, {?MODULE, MySid}}, txn_in_conn_sup).

start_txn_conn(FsmModule, FsmRef, MySid, Port, PeerSid, TickTime, SyncLimit) ->
    OutTXNConn = {txn_out_conn_sup,
               {jb_txn_out_conn_sup,start_link,[MySid]},
               permanent,
               infinity,
               supervisor,
               [jb_txn_out_conn_sup]},
    supervisor:start_child({global, {?MODULE, MySid}}, OutTXNConn),
    jb_txn_out_conn_sup:start_conn(FsmModule, FsmRef, MySid, Port, PeerSid, TickTime, SyncLimit).

terminate_txn_conn(MySid) ->
    supervisor:terminate_child({global, {?MODULE, MySid}}, txn_out_conn_sup),
    supervisor:delete_child({global, {?MODULE, MySid}}, txn_out_conn_sup),
    jb_txn_out_conn_sup:terminate_conn(MySid).


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
init({MySid, ServerList, TickTime, InitialLimit, SyncLimit}) ->
    FsmRef = {global, {?SERVER_FSM, MySid}},
    {MySid, {Host, _TXNPort, FLEPort}} = lists:keyfind(MySid, 1, ServerList), 
    NServers = length(ServerList),
    NFLEAcceptors = (NServers - MySid),
    Fsm = {fsm,
          {?SERVER_FSM,start_link,[FsmRef, {MySid, ServerList, true, TickTime, InitialLimit, SyncLimit}]},
          permanent,
          1000,
          worker,
          [?SERVER_FSM]},
    OutFLEConns = {fle_out_conn_sup,
               {jb_fle_out_conn_sup,start_link,[{?SERVER_FSM, FsmRef, MySid, ServerList, TickTime, SyncLimit}]},
               permanent,
               infinity,
               supervisor,
               [jb_fle_out_conn_sup]},
    ChildSpecs = case NFLEAcceptors of
        0 -> 
            [Fsm, OutFLEConns];
        _ ->
            InFLEConns = {fle_in_conn_sup,
                         {jb_in_conn_sup,start_link,[{?SERVER_FSM, FsmRef, jb_fle_conn, MySid, {Host, FLEPort}, NFLEAcceptors, TickTime, SyncLimit}]},
                         permanent,
                         infinity,
                         supervisor,
                         [jb_in_conn_sup]},
            [Fsm, InFLEConns, OutFLEConns]
    end,
    {ok,{{one_for_all,3,10}, ChildSpecs}}.

%% ====================================================================
%% Internal functions
%% ====================================================================

