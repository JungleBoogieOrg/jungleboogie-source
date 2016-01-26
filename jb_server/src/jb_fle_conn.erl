%%% -------------------------------------------------------------------
%%% Author  : ECEJMTR
%%% Description :
%%%
%%% Created : 09/04/2013
%%% -------------------------------------------------------------------
-module(jb_fle_conn).

-behaviour(gen_server).

-define(MAXCONNTRYINTERVAL, 60000).

%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------

-include("jb_log.hrl").
-include("jb_records.hrl").

%% --------------------------------------------------------------------
%% External exports
-export([send_notification/2, start_link/2, start_link/1]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record(state, {fsm_module, fsm_ref, host_port, my_sid, socket, peer_sid, timeout, n_pending_retries, wait_period}).

%% ====================================================================
%% External functions
%% ====================================================================

send_notification(Pid, Notification) ->
	gen_server:cast(Pid, Notification).

start_link(Name, Args) ->
    gen_server:start_link(Name, ?MODULE, Args, []).

start_link(Args) ->
    gen_server:start_link(?MODULE, Args, []).

stop_on_socket_error(Conn, Error) ->
    gen_server:call(Conn, {stop, Error}).

process_notification(Conn, Not) ->
    Conn ! {process_not, Not}.

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
	?DEBUG("Sending a request to myself in order to connect."),
    {ok, #state{
            fsm_module = FsmModule, 
            fsm_ref = FsmRef, 
            my_sid = MySid, 
            peer_sid = PeerSid, 
            host_port = Port, 
            timeout = SyncLimit * TickTime,
            n_pending_retries = 600,
            wait_period = infinity
        },
    0};
init({FsmModule, FsmRef, MySid, ListenSocket, TickTime, SyncLimit}) ->
	?DEBUG("Sending a request to myself in order to accept connection."),
    gen_server:cast(self(), {accept, ListenSocket}),
	{ok, #state{fsm_module = FsmModule, fsm_ref = FsmRef, my_sid = MySid, timeout = SyncLimit * TickTime}}.


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
handle_cast({accept, ListenSocket}, State) ->
    ?DEBUG("Request to accept connections at ~p received.", ListenSocket),
    MySid = State#state.my_sid,
    case gen_tcp:accept(ListenSocket) of
        {ok, Socket} ->
            inet:setopts(Socket, [binary, {active, false}, {packet, raw}, {nodelay, true}, {reuseaddr, true}]),
            case gen_tcp:recv(Socket, 8, State#state.timeout) of
                {ok, <<PeerSid:64/integer>>} ->
                    if
                        %% Loopback doesn't use a socket, so if PeerSid equals MySid something strange happened.
                        (PeerSid < MySid) ->
                            gen_tcp:close(Socket),
                            ?DEBUG("Closing connection from a lower Sid ~p.", {PeerSid, MySid}),
                            case global:whereis_name({?MODULE, MySid, PeerSid}) of
                                undefined ->
                                    ?WARN("Couldn't find process id to connect to ~p from ~p. Must be restarting.", PeerSid, MySid);
                                ConnPid ->
                                    ?DEBUG("Sending a message to ~p to request a connection.", ConnPid),
                                    ConnPid ! timeout
                            end,
                            {stop, shutdown, State#state{socket = undefined}};
                        (PeerSid > MySid) ->
                            %% ZooKeeper sets the timeout twice on the FLE socket, after the connection is established it is set to no timeout.
                            link_and_start(State#state.fsm_module, State#state.fsm_ref, Socket, PeerSid, infinity),
                            {noreply, State#state{socket = Socket, peer_sid = PeerSid}}
                    end;
                _Error ->
                    gen_tcp:close(Socket),
                    {stop, shutdown, State#state{socket = undefined}}
            end;
        _Error ->
            {stop, shutdown, State#state{socket = undefined}}
    end;
handle_cast(Notification, State) ->
    Data = jute_utils:write_Notification(Notification),
    ?LMSG("To ~p, ~p.", State#state.socket, Notification),
    Result = gen_tcp:send(State#state.socket, Data),
    ?DEBUG("Result of send was ~p.", Result),
    case Result of
        ok ->
            {noreply, State};
        {error, _Error} ->
            ?WARN("Error (~p) in socket while sending. Closing down.", _Error),
            {stop, shutdown, State}
    end.

%% --------------------------------------------------------------------
%% Function: handle_info/2
%% Description: Handling all non call/cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
handle_info(timeout, State) when (State#state.socket /= undefined) ->
    ?DEBUG("Request to connect to ~p ignored, already connected.", State#state.host_port),
    {noreply, State};
handle_info(timeout, State) ->
    ?DEBUG("Request to connect to ~p received.", State#state.host_port),
    MySid = State#state.my_sid,
    PeerSid = State#state.peer_sid,
    {Host, FLEPort} = State#state.host_port,
    %% Time out value in ZooKeeper is 5 seconds, we need a shorter timeout since there could be incomming connect_now messages
    Res = gen_tcp:connect(Host, FLEPort, [binary, {active, false}, {packet, raw}, {nodelay, true}, {reuseaddr, true}], 1000),
    case Res of
        {ok, Socket} ->
            ?DEBUG("Connection to ~p:~p established.", Host, FLEPort),
            case gen_tcp:send(Socket, <<MySid:64/integer>>) of
                ok ->
                    if 
                        %% This connection will be closed by the peer, but it will trigger FLE. No need to link it.
                        %% If it is linked, then it may replace the good connection in FSM.
                        (PeerSid > MySid) ->
                            {noreply, State#state{socket = Socket}};
                        (PeerSid < MySid) ->
                            link_and_start(State#state.fsm_module, State#state.fsm_ref, Socket, State#state.peer_sid, infinity),
                            {noreply, State#state{socket = Socket}}
                    end;
                _Error ->
                    ?WARN("Error (~p) in socket while sending id. Closing down.", _Error),
                    {stop, shutdown, State}
            end;
        {error, econnrefused} when ((State#state.n_pending_retries =:= 1) and (State#state.wait_period =:= infinity)) ->
            {noreply, State, ?MAXCONNTRYINTERVAL};
        {error, econnrefused} when (State#state.n_pending_retries > 1) ->
            NextTimeout = case State#state.wait_period of
                infinity ->
                    (?MAXCONNTRYINTERVAL div State#state.n_pending_retries);
                _ ->
                    (State#state.wait_period div State#state.n_pending_retries)
            end,
            {noreply, State#state{n_pending_retries = State#state.n_pending_retries - 1}, NextTimeout};
        _Error ->
            ?WARN("Error (~p) in socket while connecting. Closing down.", _Error),
            {stop, shutdown, State}
    end;
handle_info({process_not, Not}, State) ->
    (State#state.fsm_module):process_fle_notify(State#state.fsm_ref, Not, State#state.peer_sid),
    {noreply, State}.

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
            inet:close(Socket),
            (State#state.fsm_module):process_fle_unlink(State#state.fsm_ref, State#state.peer_sid, self())
    end.

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
link_and_start(FsmModule, FsmRef, Socket, PeerSid, TimeOut) ->
    ?DEBUG("Linking this thread in FSM ~p for sid ~p using socket ~p.", FsmRef, PeerSid, Socket),
    WriterPid = self(),
    FsmModule:process_fle_link(FsmRef, PeerSid, WriterPid),
    spawn_link(fun() -> read_notifications(Socket, WriterPid, TimeOut) end).

read_notifications(Socket, WriterPid, TimeOut) ->
    case gen_tcp:recv(Socket, 40, TimeOut) of
        {ok, Data} -> 
            process_notification(WriterPid, jute_utils:read_Notification(Data)),
            read_notifications(Socket, WriterPid, TimeOut);
        {error, Error} ->
            stop_on_socket_error(WriterPid, Error)
    end.
