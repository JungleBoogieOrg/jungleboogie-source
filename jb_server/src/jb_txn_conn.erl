%%% -------------------------------------------------------------------
%%% Author  : ECEJMTR
%%% Description :
%%%
%%% Created : 09/04/2013
%%% -------------------------------------------------------------------
-module(jb_txn_conn).

-behaviour(gen_server).

-include("jb_log.hrl").
-include("jb_records.hrl").
-include("jb_msgs.hrl").
-include("org_apache_zookeeper_server_quorum.hrl").
-include("org_apache_zookeeper_data.hrl").

-define(PROTOCOLVERSION, 65536).

%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------

%% --------------------------------------------------------------------
%% External exports
-export([send_quorum_packet/2, start_link/2, start_link/1]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record(state, {fsm_module, fsm_ref, my_sid, socket, peer_sid, n_outstanding_acks, txn_timer, tick_time, sync_limit}).

%% ====================================================================
%% External functions
%% ====================================================================

send_quorum_packet(Pid, QuorumPacket) ->
	gen_server:cast(Pid, QuorumPacket).

start_link(Name, Args) ->
    gen_server:start_link(Name, ?MODULE, Args, []).

start_link(Args) ->
    gen_server:start_link(?MODULE, Args, []).

stop_on_socket_error(Conn, Error) ->
    gen_server:call(Conn, {stop, Error}).

process_quorum_packet(Conn, Msg) ->
    Conn ! {process_msg, Msg}.

%% ====================================================================
%% Server functions
%% ====================================================================

%% --------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%% --------------------------------------------------------------------
init({FsmModule, FsmRef, MySid, Port, PeerSid, TickTime, SyncLimit}) ->
	?DEBUG("Sending a request to myself in order to connect. MySid ~p. PeerSid ~p.", MySid, PeerSid),
    gen_server:cast(self(), {connect, Port}),
    {ok, #state{
            fsm_module = FsmModule, 
            fsm_ref = FsmRef, 
            my_sid = MySid, 
            peer_sid = PeerSid,
            txn_timer = undefined, 
            tick_time = TickTime, 
            sync_limit = SyncLimit}};
init({FsmModule, FsmRef, MySid, ListenSocket, TickTime, SyncLimit}) ->
	?DEBUG("Sending a request to myself in order to accept connection. MySid ~p.", MySid),
    gen_server:cast(self(), {accept, ListenSocket}),
    {ok, #state{
            n_outstanding_acks = 0,
            fsm_module = FsmModule, 
            fsm_ref = FsmRef, 
            my_sid = MySid, 
            txn_timer = undefined, 
            tick_time = TickTime, 
            sync_limit = SyncLimit}}.


%% --------------------------------------------------------------------
%% Function: handle_call/3
%% Description: Handling call messages
%% Returns: {reply, Reply, State}          |
%%          {reply, Reply, State, Timeout} |
%%          {noreply, State}               |
%%          {noreply, State, Timeout}      |
%%          {stop, Reason, Reply, State}   | (terminate/2 is called)
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
handle_call({stop, _Error}, _From, State) ->
    ?WARN("Closing connection handler due to error ~p.", _Error),
    {stop, shutdown, State}.

%% --------------------------------------------------------------------
%% Function: handle_cast/2
%% Description: Handling cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
handle_cast({connect, Port}, State) ->
    retry_connect(Port, 5, State#state.tick_time * State#state.sync_limit, State);
handle_cast({accept, ListenSocket}, State) ->
    ?DEBUG("Request to accept connections received."),
    %% This doesn't look too good. The gen_server hangs in here until a connection arrives.
    case gen_tcp:accept(ListenSocket) of
        {ok, Socket} ->
            ?DEBUG("Connection accepted."),
            inet:setopts(Socket, [binary, {active, false}, {packet, raw}, {nodelay, true}, {reuseaddr, true}]),
            case jute_utils:tcp_read_QuorumPacket(Socket, State#state.tick_time * State#state.sync_limit) of
                {ok, QP} ->
                    ?DEBUG("Got a quorum packet (~p).", QP),
                    {LearnerInfo, <<>>} = org_apache_zookeeper_server_quorum:read_LearnerInfo(QP#'QuorumPacket'.data),
                    ?DEBUG("Got learner info (~p).", LearnerInfo),
                    PeerSid = LearnerInfo#'LearnerInfo'.serverid,
                    ?DEBUG("Connection received from ~p to ~p.", PeerSid, State#state.my_sid),
                    link_and_start(State#state.fsm_module, State#state.fsm_ref, Socket, PeerSid, State#state.tick_time * State#state.sync_limit),
                    {noreply, State#state{socket = Socket, peer_sid = PeerSid}};
                Error ->
                    ?WARN("Closing socket due to error ~p.", Error),
                    inet:close(Socket),
                    {stop, shutdown, State}
            end;
        Error ->
            ?WARN("Accept socket failed with error ~p.", Error),
            {stop, shutdown, State}
    end;
handle_cast({request, Epoch, Zxid, Data}, State) ->
    QP = org_apache_zookeeper_server_quorum:write_QuorumPacket(#'QuorumPacket'{
            type = ?REQUEST,
            zxid = make_long_zxid(Epoch, Zxid),
            data = Data,
            authinfo = []
        }),
    send_data(QP, State);
handle_cast({proposal, Epoch, Zxid, Data}, State) ->
    QP = org_apache_zookeeper_server_quorum:write_QuorumPacket(#'QuorumPacket'{
            type = ?PROPOSAL,
            zxid = make_long_zxid(Epoch, Zxid),
            data = Data,
            authinfo = []
        }),
    send_data(QP, State#state{n_outstanding_acks = (State#state.n_outstanding_acks + 1)});
handle_cast({ack, Epoch, Zxid}, State) ->
    QP = org_apache_zookeeper_server_quorum:write_QuorumPacket(#'QuorumPacket'{
            type = ?ACK,
            zxid = make_long_zxid(Epoch, Zxid),
            data = <<>>,
            authinfo = []
        }),
    send_data(QP, State);
handle_cast({commit, Epoch, Zxid}, State) ->
    QP = org_apache_zookeeper_server_quorum:write_QuorumPacket(#'QuorumPacket'{
            type = ?COMMIT,
            zxid = make_long_zxid(Epoch, Zxid),
            data = <<>>,
            authinfo = []
        }),
    send_data(QP, State);
handle_cast({ping}, State) ->
    QP = org_apache_zookeeper_server_quorum:write_QuorumPacket(#'QuorumPacket'{
            type = ?PING,
            zxid = 0,
            data = <<>>,
            authinfo = []
        }),
    send_data(QP, State);
%%		?REVALIDATE ->
%%		?SYNC ->
handle_cast({inform, Epoch, Zxid, Data}, State) ->
    QP = org_apache_zookeeper_server_quorum:write_QuorumPacket(#'QuorumPacket'{
            type = ?INFORM,
            zxid = make_long_zxid(Epoch, Zxid),
            data = Data,
            authinfo = []
        }),
    send_data(QP, State);
handle_cast({newleader, Epoch, Zxid}, State) ->
    QP = org_apache_zookeeper_server_quorum:write_QuorumPacket(#'QuorumPacket'{
            type = ?NEWLEADER,
            zxid = make_long_zxid(Epoch, Zxid),
            data = <<>>,
            authinfo = []
        }),
    ?DEBUG("Increasing n_acks. Was ~p.", State#state.n_outstanding_acks),
    send_data(QP, State#state{n_outstanding_acks = (State#state.n_outstanding_acks + 1)});
handle_cast({uptodate}, State) ->
    QP = org_apache_zookeeper_server_quorum:write_QuorumPacket(#'QuorumPacket'{
            type = ?UPTODATE,
            zxid = 0,
            data = <<>>,
            authinfo = []
        }),
    send_data(QP, State);
handle_cast({diff, Epoch, Zxid}, State) ->
    QP = org_apache_zookeeper_server_quorum:write_QuorumPacket(#'QuorumPacket'{
            type = ?DIFF,
            zxid = make_long_zxid(Epoch, Zxid),
            data = <<>>,
            authinfo = []
        }),
    ?DEBUG("Increasing n_acks. Was ~p.", State#state.n_outstanding_acks),
    send_data(QP, State#state{n_outstanding_acks = (State#state.n_outstanding_acks + 1)});
handle_cast({trunc, Epoch, Zxid}, State) ->
    QP = org_apache_zookeeper_server_quorum:write_QuorumPacket(#'QuorumPacket'{
            type = ?TRUNC,
            zxid = make_long_zxid(Epoch, Zxid),
            data = <<>>,
            authinfo = []
        }),
    ?DEBUG("Increasing n_acks. Was ~p.", State#state.n_outstanding_acks),
    send_data(QP, State#state{n_outstanding_acks = (State#state.n_outstanding_acks + 1)});
handle_cast({snap, Epoch, Zxid}, State) ->
    QP = org_apache_zookeeper_server_quorum:write_QuorumPacket(#'QuorumPacket'{
            type = ?SNAP,
            zxid = make_long_zxid(Epoch, Zxid),
            data = <<>>,
            authinfo = []
        }),
    ?DEBUG("Increasing n_acks. Was ~p.", State#state.n_outstanding_acks),
    send_data(QP, State#state{n_outstanding_acks = (State#state.n_outstanding_acks + 1)});
handle_cast({observerinfo, Epoch, Zxid, Data}, State) ->
    QP = org_apache_zookeeper_server_quorum:write_QuorumPacket(#'QuorumPacket'{
            type = ?OBSERVERINFO,
            zxid = make_long_zxid(Epoch, Zxid),
            data = Data,
            authinfo = []
        }),
    send_data(QP, State);
handle_cast({leaderinfo, Epoch, Zxid}, State) ->
    QP = org_apache_zookeeper_server_quorum:write_QuorumPacket(#'QuorumPacket'{
            type = ?LEADERINFO,
            zxid = make_long_zxid(Epoch, Zxid),
            data = <<?PROTOCOLVERSION:32/integer>>,
            authinfo = []
        }),
    send_data(QP, State);
handle_cast({ackepoch, Epoch, Zxid}, State) ->
    QP = org_apache_zookeeper_server_quorum:write_QuorumPacket(#'QuorumPacket'{
            type = ?ACKEPOCH,
            zxid = make_long_zxid(Epoch, Zxid),
            data = <<Epoch:32/integer>>,
            authinfo = []
        }),
    send_data(QP, State);
handle_cast({followerinfo, Epoch, Zxid}, State) ->
    MySid = State#state.my_sid,
    Data = org_apache_zookeeper_server_quorum:write_LearnerInfo(#'LearnerInfo'{serverid = MySid, protocolVersion = ?PROTOCOLVERSION}),
    QP = org_apache_zookeeper_server_quorum:write_QuorumPacket(#'QuorumPacket'{
            type = ?FOLLOWERINFO,
            zxid = make_long_zxid(Epoch, Zxid),
            data = Data,
            authinfo = []
        }),
    send_data(QP, State).

%% --------------------------------------------------------------------
%% Function: handle_info/2
%% Description: Handling all non call/cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
handle_info({process_msg, Msg}, State) ->
    ?LMSG("From ~p, ~p.", State#state.peer_sid, Msg),
    FsmModule = State#state.fsm_module,
    FsmRef = State#state.fsm_ref,
    case Msg of
        {ack, _, _, _} when (State#state.n_outstanding_acks =:= 1) ->
            FsmModule:process_txn_msg(FsmRef, Msg),
            {noreply, State#state{txn_timer = timer:send_after(State#state.tick_time, {timeout}), n_outstanding_acks = 0}};
        {ack, _, _, _} ->
            FsmModule:process_txn_msg(FsmRef, Msg),
            {noreply, State#state{n_outstanding_acks = (State#state.n_outstanding_acks - 1)}};
        _ ->
            FsmModule:process_txn_msg(FsmRef, Msg),
            {noreply, State}
    end;
handle_info({timeout}, State) ->
    case State#state.n_outstanding_acks of
        0 ->
            QP = org_apache_zookeeper_server_quorum:write_QuorumPacket(#'QuorumPacket'{
                type = ?PING,
                zxid = 0,
                data = <<>>,
                authinfo = []
            }),
            send_data(QP, State),
            {noreply, State#state{txn_timer = timer:send_after(State#state.tick_time, {timeout})}};
        _ ->
            {noreply, State}
    end.

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(_Reason, State) ->
    case State#state.socket of
        undefined -> 
            ok;
        Socket -> 
            inet:close(Socket)
    end,
    (State#state.fsm_module):process_txn_unlink(State#state.fsm_ref, State#state.peer_sid, self()).

%% --------------------------------------------------------------------
%% Func: code_change/3
%% Purpose: Convert process state when code is changed
%% Returns: {ok, NewState}
%% --------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% --------------------------------------------------------------------
%%% Internal functions
%% --------------------------------------------------------------------
 
make_long_zxid(Epoch, Zxid) ->
    <<LongZxid:64/integer>> = <<Epoch:32/integer, Zxid:32/integer>>,
    LongZxid.

make_short_zxid(LongZxid) ->
    <<Epoch:32/integer, Zxid:32/integer>> = <<LongZxid:64/integer>>,
    {Epoch, Zxid}.

send_data(Data, State) ->
	Result = gen_tcp:send(State#state.socket, Data),
	case Result of
		ok ->
			{noreply, State};
		{error, _Error} ->
            ?WARN("Error (~p) in socket while sending. Closing down.", _Error),
			{stop, shutdown, State}
	end.

retry_connect(Port, NTimes, Wait, State) ->
	?DEBUG("Request to connect to ~p received.", Port),
    {Host, TXNPort} = Port,
	Res = gen_tcp:connect(Host, TXNPort, [binary, {active, false}, {packet, raw}, {nodelay, true}, {reuseaddr, true}], State#state.tick_time * State#state.sync_limit),
    case Res of
        {ok, Socket} ->
        	?DEBUG("Connection to port ~p established.", Port),
        	link_and_start(State#state.fsm_module, State#state.fsm_ref, Socket, State#state.peer_sid, State#state.tick_time * State#state.sync_limit),
            {noreply, State#state{socket = Socket}};
        {error, econnrefused} when (NTimes > 1) ->
            timer:sleep(Wait div NTimes),
            retry_connect(Port, NTimes - 1, Wait, State);
        _Error ->
            ?WARN("Error (~p) in socket while connecting. Closing down.", _Error),
            {stop, shutdown, State}
    end.

link_and_start(FsmModule, FsmRef, Socket, PeerSid, TimeOut) ->
	?DEBUG("Linking this thread in FSM ~p for sid ~p using socket ~p.", FsmRef, PeerSid, Socket),
    WriterPid = self(),
	FsmModule:process_txn_link(FsmRef, PeerSid, WriterPid),
    spawn_link(fun() -> read_quorum_packets(Socket, PeerSid, WriterPid, TimeOut) end).

read_quorum_packets(Socket, PeerSid, WriterPid, TimeOut) ->
    case jute_utils:tcp_read_QuorumPacket(Socket, TimeOut) of
        {error, Error} ->
            stop_on_socket_error(WriterPid, Error);
        {ok, QP} ->
            Msg = quorum_packet_to_msg(QP, PeerSid),
            case Msg of
                {snap, _, _} ->
                    case dump_snap(Socket, TimeOut) of
                        ok ->
                            process_quorum_packet(WriterPid, Msg),
                            read_quorum_packets(Socket, PeerSid, WriterPid, TimeOut);
                        Error2 ->
                            stop_on_socket_error(WriterPid, Error2)
                    end;
                _ ->
                    process_quorum_packet(WriterPid, Msg),
                    read_quorum_packets(Socket, PeerSid, WriterPid, TimeOut)
            end
    end.

quorum_packet_to_msg(Recv, PeerSid) ->
    {Epoch, Zxid} = make_short_zxid(Recv#'QuorumPacket'.zxid),
    Data = Recv#'QuorumPacket'.data,
    case Recv#'QuorumPacket'.type of
        ?REQUEST ->
            {request, Epoch, Zxid, Data};
		?PROPOSAL ->
            {proposal, Epoch, Zxid, Data};
		?ACK ->
            {ack, Epoch, Zxid, PeerSid};
		?COMMIT ->
            {commit, Epoch, Zxid};
		?PING ->
            {ping, PeerSid};
%%		?REVALIDATE ->
%%		?SYNC ->
		?INFORM ->
            {inform, Epoch, Zxid, Data};
		?NEWLEADER ->
            {newleader, Epoch, Zxid};
		?FOLLOWERINFO ->
            {followerinfo, Epoch, Zxid, Data, PeerSid};
		?UPTODATE ->
            {uptodate};
		?DIFF ->
            {diff, Epoch, Zxid};
		?TRUNC ->
            {trunc, Epoch, Zxid};
		?SNAP ->
            {snap, Epoch, Zxid};
		?OBSERVERINFO ->
            {observerinfo, Epoch, Zxid, Data, PeerSid};
		?LEADERINFO ->
            <<?PROTOCOLVERSION:32/integer>> = Data,
            {leaderinfo, Epoch, Zxid};
		?ACKEPOCH ->
            {ackepoch, Epoch, Zxid, Data, PeerSid}
    end.

dump_snap(Socket, TimeOut) ->
    jute_utils:tcp_read_snapshot(Socket, TimeOut),
    case gen_tcp:recv(Socket, 10, TimeOut) of
        {ok, Data} -> 
            check_signature(Socket, Data, 10, TimeOut),
            ok;
        Error ->
            Error
    end.
    
check_signature(Socket, Data, L, TimeOut) ->
    {ToRead, StartOrTotalLen} = case Data of
        <<"BenWasHere">> -> ?LMSG("Snap signature found!"), {0, L};
        << _:8, "BenWasHer">> -> {1, <<"BenWasHer">>};
        << _:16, "BenWasHe">> -> {2, <<"BenWasHe">>};
        << _:24, "BenWasH">> -> {3, <<"BenWasH">>};
        << _:32, "BenWas">> -> {4, <<"BenWas">>};
        << _:40, "BenWa">> -> {5, <<"BenWa">>};
        << _:48, "BenW">> -> {6, <<"BenW">>};
        << _:56, "Ben">> -> {7, <<"Ben">>};
        << _:64, "Be">> -> {8, <<"Be">>};
        << _:72, "B">> -> {9, <<"B">>};
        _ -> 
            case gen_tcp:recv(Socket, 10, TimeOut) of
                {ok, MoreData} ->
                    {0, check_signature(Socket, MoreData, L + 10, TimeOut)};
                Error ->
                    Error
            end
    end,
    case ToRead of
        0 ->
            StartOrTotalLen;
        N ->
            case gen_tcp:recv(Socket, N, TimeOut) of
                {ok, Rest} ->
                    check_signature(Socket, <<StartOrTotalLen/binary, Rest/binary>>, L + N, TimeOut);
                Error2 ->
                    Error2
            end
    end.
