%%% -------------------------------------------------------------------
%%% Author  : ECEJMTR
%%% Description :
%%%
%%% Created : 04/03/2013
%%% -------------------------------------------------------------------
-module(jb_client_fsm).

-behaviour(gen_fsm).
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------

-include("org_apache_zookeeper_proto.hrl").
-include("org_apache_zookeeper_data.hrl").
-include("zkdefs.hrl").

%% --------------------------------------------------------------------
%% External exports
-export([waiting/3, connected/3]).

%% gen_fsm callbacks
-export([init/1, state_name/2, handle_event/3,
	 handle_sync_event/4, handle_info/3, terminate/3, code_change/4]).

%% ====================================================================
%% External functions
%% ====================================================================

-record(zkstate, {zxid}).

%% ====================================================================
%% Server functions
%% ====================================================================
%% --------------------------------------------------------------------
%% Func: init/1
%% Returns: {ok, StateName, StateData}          |
%%          {ok, StateName, StateData, Timeout} |
%%          ignore                              |
%%          {stop, StopReason}
%% --------------------------------------------------------------------
init(State) ->
    {ok, waiting, {#zkstate{zxid = 0}, State}}.

%% --------------------------------------------------------------------
%% Func: StateName/2
%% Returns: {next_state, NextStateName, NextStateData}          |
%%          {next_state, NextStateName, NextStateData, Timeout} |
%%          {stop, Reason, NewStateData}
%% --------------------------------------------------------------------
state_name(Event, StateData) ->
    {next_state, state_name, StateData}.

%% --------------------------------------------------------------------
%% Func: StateName/3
%% Returns: {next_state, NextStateName, NextStateData}            |
%%          {next_state, NextStateName, NextStateData, Timeout}   |
%%          {reply, Reply, NextStateName, NextStateData}          |
%%          {reply, Reply, NextStateName, NextStateData, Timeout} |
%%          {stop, Reason, NewStateData}                          |
%%          {stop, Reason, Reply, NewStateData}
%% --------------------------------------------------------------------
waiting({msg, Msg}, _From, StateData) ->
    io:format("State: waiting~n"),
	{DecMsg, Rest} = org_apache_zookeeper_proto:read_ConnectRequest(Msg),
    {ReadOnly, <<>>} = jute_utils:read_boolean(Rest),
    io:format("Received: ~p - ~p~n", [DecMsg, ReadOnly]),
    _Response = #'ConnectResponse'{
		 protocolVersion = 0,
         timeOut = DecMsg#'ConnectRequest'.timeOut,
         sessionId = DecMsg#'ConnectRequest'.sessionId,
         passwd = generate_passwd()},
    RsProto = jute_utils:write_int(0),
    RsTimeOut = jute_utils:write_int(DecMsg#'ConnectRequest'.timeOut),
    RsSessionId = jute_utils:write_long(DecMsg#'ConnectRequest'.sessionId),
    RsPasswd = jute_utils:write_buffer(generate_passwd()),
    ResponseBin = <<RsProto/binary, RsTimeOut/binary, RsSessionId/binary, RsPasswd/binary>>,
	{reply, {{DecMsg, ReadOnly}, ResponseBin}, connected, StateData}.

connected({msg, Msg}, _From, {State, OtherState}) when is_record(State, zkstate) ->
    io:format("State: connected~n"),
	{DecHdr, Rest1} = org_apache_zookeeper_proto:read_RequestHeader(Msg),
	case DecHdr#'RequestHeader'.type of
		0 ->
			DecReq = undef,
			ResponseBin = none;
		1 ->
		    {DecReq, Rest2} = org_apache_zookeeper_proto:read_CreateRequest(Rest1),
			io:format("Rest of the message: ~p~n", [Rest2]),
			ResponseBin = create_resp(DecHdr, DecReq, State#zkstate.zxid);
		2 ->
		    {DecReq, Rest2} = org_apache_zookeeper_proto:read_DeleteRequest(Rest1),
			io:format("Rest of the message: ~p~n", [Rest2]),
			ResponseBin = create_resp(DecHdr, DecReq, State#zkstate.zxid);
		3 ->
		    {DecReq, Rest2} = org_apache_zookeeper_proto:read_ExistsRequest(Rest1),
			io:format("Rest of the message: ~p~n", [Rest2]),
			ResponseBin = create_resp(DecHdr, DecReq, State#zkstate.zxid);
		4 ->
		    {DecReq, Rest2} = org_apache_zookeeper_proto:read_GetDataRequest(Rest1),
			io:format("Rest of the message: ~p~n", [Rest2]),
			ResponseBin = create_resp(DecHdr, DecReq, State#zkstate.zxid);
		_ ->
			io:format("Unknown msg type~n"),
			DecReq = undef,
			ResponseBin = none
    end,
    io:format("Received: ~p - ~p~n", [DecHdr, DecReq]),
	NewState = State#zkstate{zxid = State#zkstate.zxid + 1},
    % Take epoch and count into account...	
	{reply, {{DecHdr, DecReq}, ResponseBin}, connected, {NewState, OtherState}};
connected({tcp_closed}, _From, SD = {State, _OtherState}) when is_record(State, zkstate) ->
	{stop, tcp_closed, ok, SD}.


%% --------------------------------------------------------------------
%% Func: handle_event/3
%% Returns: {next_state, NextStateName, NextStateData}          |
%%          {next_state, NextStateName, NextStateData, Timeout} |
%%          {stop, Reason, NewStateData}
%% --------------------------------------------------------------------
handle_event(Event, StateName, StateData) ->
    {next_state, StateName, StateData}.

%% --------------------------------------------------------------------
%% Func: handle_sync_event/4
%% Returns: {next_state, NextStateName, NextStateData}            |
%%          {next_state, NextStateName, NextStateData, Timeout}   |
%%          {reply, Reply, NextStateName, NextStateData}          |
%%          {reply, Reply, NextStateName, NextStateData, Timeout} |
%%          {stop, Reason, NewStateData}                          |
%%          {stop, Reason, Reply, NewStateData}
%% --------------------------------------------------------------------
handle_sync_event(Event, From, StateName, StateData) ->
    Reply = ok,
    {reply, Reply, StateName, StateData}.

%% --------------------------------------------------------------------
%% Func: handle_info/3
%% Returns: {next_state, NextStateName, NextStateData}          |
%%          {next_state, NextStateName, NextStateData, Timeout} |
%%          {stop, Reason, NewStateData}
%% --------------------------------------------------------------------
handle_info(Info, StateName, StateData) ->
    {next_state, StateName, StateData}.

%% --------------------------------------------------------------------
%% Func: terminate/3
%% Purpose: Shutdown the fsm
%% Returns: any
%% --------------------------------------------------------------------
terminate(Reason, StateName, StatData) ->
    ok.

%% --------------------------------------------------------------------
%% Func: code_change/4
%% Purpose: Convert process state when code is changed
%% Returns: {ok, NewState, NewStateData}
%% --------------------------------------------------------------------
code_change(OldVsn, StateName, StateData, Extra) ->
    {ok, StateName, StateData}.

%% --------------------------------------------------------------------
%%% Internal functions
%% --------------------------------------------------------------------

generate_passwd() ->
    <<0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0>>.

create_resp(ReqHdr, CreateReq, Zxid) when is_record(CreateReq, 'CreateRequest') ->
    RHxid = jute_utils:write_int(ReqHdr#'RequestHeader'.xid),
    RHzxid  = jute_utils:write_long(Zxid),
    RHerr = jute_utils:write_int(0),
	% CR = jute_utils:write_ustring(CreateReq#'CreateRequest'.path),
	Resp = #'CreateResponse'{path = CreateReq#'CreateRequest'.path},
	CR = org_apache_zookeeper_proto:write_CreateResponse(Resp),
    <<RHxid/binary, RHzxid/binary, RHerr/binary, CR/binary>>;
create_resp(ReqHdr, DeleteReq, Zxid) when is_record(DeleteReq, 'DeleteRequest') ->
    RHxid = jute_utils:write_int(ReqHdr#'RequestHeader'.xid),
    RHzxid  = jute_utils:write_long(Zxid),
    RHerr = jute_utils:write_int(0),
	% DR = jute_utils:write_ustring(DeleteReq#'DeleteRequest'.path),
	Resp = #'CreateResponse'{path = DeleteReq#'DeleteRequest'.path},
	DR = org_apache_zookeeper_proto:write_CreateResponse(Resp),
    <<RHxid/binary, RHzxid/binary, RHerr/binary, DR/binary>>;
create_resp(ReqHdr, ExistsReq, Zxid) when is_record(ExistsReq, 'ExistsRequest') ->
    RHxid = jute_utils:write_int(ReqHdr#'RequestHeader'.xid),
    RHzxid  = jute_utils:write_long(Zxid),
    RHerr = jute_utils:write_int(0),
	Stat = #'Stat'{czxid = 0,
         mzxid = 0,
         ctime = 0,
         mtime = 0,
         version = 1,
         cversion = 0,
         aversion = 0,
         ephemeralOwner = 0,
         dataLength = 3, % "789"
         numChildren = 0,
         pzxid = 0},
	Resp = #'ExistsResponse'{stat = Stat},
	ER = org_apache_zookeeper_proto:write_ExistsResponse(Resp),
    <<RHxid/binary, RHzxid/binary, RHerr/binary, ER/binary>>;
create_resp(ReqHdr, GetDataReq, Zxid) when is_record(GetDataReq, 'GetDataRequest') ->
    RHxid = jute_utils:write_int(ReqHdr#'RequestHeader'.xid),
    RHzxid  = jute_utils:write_long(Zxid),
    RHerr = jute_utils:write_int(0),
	Data = <<"789">>,
	Stat = #'Stat'{czxid = 0,
         mzxid = 0,
         ctime = 0,
         mtime = 0,
         version = 1,
         cversion = 0,
         aversion = 0,
         ephemeralOwner = 0,
         dataLength = size(Data), % "789"
         numChildren = 0,
         pzxid = 0},
	Resp = #'GetDataResponse'{stat = Stat, data = Data},
	GDR = org_apache_zookeeper_proto:write_GetDataResponse(Resp),
    <<RHxid/binary, RHzxid/binary, RHerr/binary, GDR/binary>>.