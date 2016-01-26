%% @author german
%% @doc @todo Add description to jb_fsm.
%% messages:
%%   {notify, ProposedLeaderSid, ProposedZxid, ProposedEpoch, Round, State, Epoch, Sid}

-module(jb_server_fsm).
-behaviour(gen_fsm).
-export([init/1, state_name/3, handle_event/3, handle_sync_event/4, handle_info/3, terminate/3, code_change/4]).
-export([looking/2, sync_leading/2, sync_following/2, leading/2, following/2]).

-include("jb_log.hrl").
-include("jb_msgs.hrl").
-include("jb_records.hrl").
-include("jb_fsm_state.hrl").
-include("org_apache_zookeeper_server_quorum.hrl").

-define(INITIAL_EPOCH, 0).

%% ====================================================================
%% API functions
%% ====================================================================
-export([process_fle_notify/3, start/2, start_link/2, process_fle_link/3, process_fle_unlink/3]).
-export([process_txn_msg/2, process_txn_link/3, process_txn_unlink/3]).

start(Name, Args) ->
	gen_fsm:start(Name, ?MODULE, Args, []).

start_link(Name, Args) ->
	gen_fsm:start_link(Name, ?MODULE, Args, []).

process_fle_link(Name, Sid, Pid) ->
	gen_fsm:send_all_state_event(Name, {fle_link, Sid, Pid}).

process_fle_unlink(Name, Sid, Pid) ->
	gen_fsm:send_all_state_event(Name, {fle_unlink, Sid, Pid}).

process_fle_notify(Name, Notification, Sid) ->
	gen_fsm:send_event(Name, {notify, Notification, Sid}).

process_txn_link(Name, Sid, Pid) ->
	gen_fsm:send_event(Name, {txn_link, Sid, Pid}).

process_txn_unlink(Name, Sid, Pid) ->
	gen_fsm:send_event(Name, {txn_unlink, Sid, Pid}).

process_txn_msg(Name, Msg) ->
    ?DEBUG("Msg ~p.", Msg),
	gen_fsm:send_event(Name, Msg).

%% ====================================================================
%% Behavioural functions
%% ====================================================================

%% init/1
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_fsm.html#Module:init-1">gen_fsm:init/1</a>
-spec init(Args :: term()) -> Result when
	Result :: {ok, StateName, StateData}
	| {ok, StateName, StateData, Timeout}
	| {ok, StateName, StateData, hibernate}
	| {stop, Reason}
	| ignore,
	StateName :: atom(),
	StateData :: term(),
	Timeout :: non_neg_integer() | infinity,
	Reason :: term().
%% ====================================================================
init({MySid, ServerList, IsParticipant, TickTime, InitialLimit, SyncLimit}) ->
	?INFO("Server for sid ~p starting.", MySid),
    StartTime = erlang:now(),
	MyVote = #vote{
        epoch = ?INITIAL_EPOCH, 
        zxid = 0, 
        sid = MySid
    },
	State = #state{
        myvote = MyVote, 
		election_epoch = ?INITIAL_EPOCH,
		election_start_time = StartTime,
		server_list = ServerList,
        fle_server_list = [], 
        timer = erlang:send_after(TickTime * SyncLimit, self(), {timeout}),
		leader_vote = MyVote,
		votes_in_election = [{MySid, MyVote}], 
		votes_out_of_election = [],
		is_participant = IsParticipant, 
        followers_list = undefined,
        leader_conn = undefined,
        tick_time = TickTime,
        initial_limit = InitialLimit,
        sync_limit = SyncLimit,
        outstanding_proposals = undefined,
		mydata = []
    },
    %% If there is only one, then the election needs to be kickstarted
    NPeers = length(ServerList),
    case NPeers of
        1 ->
            Notification = #notification{
                vote = MyVote,
                election_epoch = ?INITIAL_EPOCH,
                state = looking
            },
            gen_fsm:send_event(self(), {notify, Notification, MySid});
        _ ->
            ok
    end,
	?TRACE("Initial state ~p.", State),
	{ok, looking, State}.

%% looking/2
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_fsm.html#Module:StateName-2">gen_fsm:StateName/2</a>
-spec looking(Event :: timeout | term(), StateData :: term()) -> Result when
	Result :: {next_state, NextStateName, NewStateData}
	| {next_state, NextStateName, NewStateData, Timeout}
	| {next_state, NextStateName, NewStateData, hibernate}
	| {stop, Reason, NewStateData},
	NextStateName :: atom(),
	NewStateData :: term(),
	Timeout :: non_neg_integer() | infinity,
	Reason :: term().
%% ====================================================================
looking({notify, Notification, Sender}, State) ->
	Vote = Notification#notification.vote, 
	VoteEpoch = Notification#notification.election_epoch,
	?TRACE("Processing notification in looking state. Sender ~p.", Sender),
	NQuorum = ((length(State#state.server_list) div 2) + 1),
    SidPidTuple = lists:keyfind(Sender, 1, State#state.fle_server_list),
	SenderInList = case State#state.myvote#vote.sid of
        Sender -> 
            true;
        _ -> 
            (SidPidTuple /= false)
    end,
	?TRACE("Quorum is ~p.", NQuorum),
	case Notification#notification.state of
		_ when (not SenderInList) ->
			?WARN("Ignoring notification from outside of the cluster (~p).", Sender),
			{next_state, looking, State};
		observing ->
			?DEBUG("Notification from observer."),
			{next_state, looking, State};
		looking when (State#state.election_epoch > VoteEpoch) ->
            erlang:cancel_timer(State#state.timer),
			?DEBUG("Notification with an older election epoch (current ~p, received ~p), reply back.", State#state.election_epoch, VoteEpoch),
			NewNotification = #notification{vote=State#state.leader_vote,
				election_epoch=State#state.election_epoch,
				state=looking},
            {Sender, SenderPid} = SidPidTuple,
			jb_fle_conn:send_notification(SenderPid, NewNotification),
            {next_state, looking, State#state{timer = erlang:send_after(State#state.tick_time * State#state.sync_limit, self(), {timeout})}};
		looking ->
            erlang:cancel_timer(State#state.timer),
			?DEBUG("Adding vote ~p from ~p within election, proposed election epoch ~p.", Vote, Sender, VoteEpoch),
            SenderPid = case SidPidTuple of false -> undefined; {_,X} -> X end,
			handle_notification_from_someone_looking(State, Sender, SenderPid, Vote, VoteEpoch, NQuorum);
		X when (((X =:= leading) or (X =:= following)) and (State#state.election_epoch == VoteEpoch)) ->
            erlang:cancel_timer(State#state.timer),
			?DEBUG("Adding vote ~p from ~p out of election, same epoch.", Vote, Sender),
			handle_notification_from_someone_not_looking(State, Sender, Notification, NQuorum);
		X when ((X =:= leading) or (X =:= following)) -> 
            erlang:cancel_timer(State#state.timer),
			?DEBUG("Adding vote ~p from ~p leading or following, other epoch.", Vote, Sender),
			update_and_check_out_of_election(State, Sender, State#state.votes_in_election, Notification, NQuorum, false);
		_ ->
			?WARN("Ignoring notification with unrecognized state."),
			{next_state, looking, State}
	end;
looking(Msg, State) ->
	?DEBUG("Ignoring message ~p in looking state.", Msg),
	{next_state, looking, State}.

%% sync_leading/2
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_fsm.html#Module:StateName-2">gen_fsm:StateName/2</a>
-spec sync_leading(Event :: timeout | term(), StateData :: term()) -> Result when
	Result :: {next_state, NextStateName, NewStateData}
	| {next_state, NextStateName, NewStateData, Timeout}
	| {next_state, NextStateName, NewStateData, hibernate}
	| {stop, Reason, NewStateData},
	NextStateName :: atom(),
	NewStateData :: term(),
	Timeout :: non_neg_integer() | infinity,
	Reason :: term().
%% ====================================================================
sync_leading({ping, Sid}, StateData) ->
	?TRACE("Leader received ping from ~p.", Sid),
	{next_state, sync_leading, StateData};
sync_leading({txn_link, Sid, Pid}, State) ->
	?TRACE("Leader received follower information from ~p.", Sid),
    NewEpoch = (State#state.myvote#vote.epoch + 1),
	?TRACE("Sending Leader Info to ~p.", Sid),
    jb_txn_conn:send_quorum_packet(Pid, {leaderinfo, NewEpoch, 0}),
	?TRACE("Sending diff to ~p.", Sid),
    jb_txn_conn:send_quorum_packet(Pid, {diff, NewEpoch, 0}),
	?TRACE("Sending New Leader to ~p.", Sid),
    jb_txn_conn:send_quorum_packet(Pid, {newleader, NewEpoch, 0}),
	?TRACE("Sending up to date to ~p.", Sid),
    jb_txn_conn:send_quorum_packet(Pid, {uptodate}),
	?TRACE("Adding ~p to followers list.", Sid),
	NewFollowersList = lists:keystore(Sid, 1, State#state.followers_list, {Sid, Pid, no_acks}),
   	{next_state, sync_leading, State#state{followers_list = NewFollowersList}};
sync_leading({txn_unlink, Sid, Pid}, State) ->
	?DEBUG("Removing peer (~p) from the followers list.", {Sid, Pid}),
	{next_state, sync_leading, State#state{followers_list = lists:delete({Sid, Pid}, State#state.followers_list)}};
sync_leading({notify, RecNotification, Sender}, State) ->
    handle_event({notify, RecNotification, Sender}, sync_leading, State);
sync_leading({ackepoch, _Epoch, _Zxid, _Data, _Sid}, StateData) ->
	?TRACE("Leader received ack epoch from ~p.", _Sid),
	{next_state, sync_leading, StateData};
sync_leading({ack, _Epoch, _Zxid, Sid}, StateData) ->
	?TRACE("Leader received ack from ~p.", Sid),
    {Sid, Pid, Status} = lists:keyfind(Sid, 1, StateData#state.followers_list),
    NewTuple = case Status of
            no_acks ->
                {Sid, Pid, one_ack};
            one_ack ->
                {Sid, Pid, sync}
        end,
	?TRACE("Follower state changed to ~p.", NewTuple),
	NewFollowersList = lists:keystore(Sid, 1, StateData#state.followers_list, NewTuple),
	NQuorum = ((length(StateData#state.server_list) div 2) + 1),
    NInSync = lists:foldl(fun({_Sid, _Pid, St}, AccIn) -> case St of sync -> (AccIn + 1); _ -> AccIn end end, 0, NewFollowersList),
	?TRACE("Number of followers in sync is ~p.", NInSync),
    if 
        ((NInSync + 1) >= NQuorum) ->
	        ?INFO("Leader now attending requests."),
            erlang:cancel_timer(StateData#state.timer),
	        {next_state, leading, StateData#state{followers_list = NewFollowersList, timer = undefined}};
        ((NInSync + 1) < NQuorum) ->
	        {next_state, sync_leading, StateData#state{followers_list = NewFollowersList}}
    end;
sync_leading(Msg, State) ->
	?DEBUG("Ignoring message ~p in sync_leading state.", Msg),
	{next_state, sync_leading, State}.

%% leading/2
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_fsm.html#Module:StateName-2">gen_fsm:StateName/2</a>
-spec leading(Event :: timeout | term(), StateData :: term()) -> Result when
	Result :: {next_state, NextStateName, NewStateData}
	| {next_state, NextStateName, NewStateData, Timeout}
	| {next_state, NextStateName, NewStateData, hibernate}
	| {stop, Reason, NewStateData},
	NextStateName :: atom(),
	NewStateData :: term(),
	Timeout :: non_neg_integer() | infinity,
	Reason :: term().
%% ====================================================================
leading({ping, Sid}, StateData) ->
	?TRACE("Leader received ping from ~p.", Sid),
	{next_state, leading, StateData};
leading({txn_link, Sid, Pid}, State) ->
	?TRACE("Leader received follower information from ~p.", Sid),
    NewEpoch = (State#state.myvote#vote.epoch + 1),
    jb_txn_conn:send_quorum_packet(Pid, {leaderinfo, NewEpoch, 0}),
    jb_txn_conn:send_quorum_packet(Pid, {diff, NewEpoch, 0}),
    jb_txn_conn:send_quorum_packet(Pid, {newleader, NewEpoch, 0}),
    jb_txn_conn:send_quorum_packet(Pid, {uptodate}),
%% TODO:    lists:foreach(fun(E) -> jb_txn_conn:send_quorum_packet(Pid, E) end, StateData#state.outstanding_proposals),
	NewFollowersList = lists:keystore(Sid, 1, State#state.followers_list, {Sid, Pid, no_acks}),
   	{next_state, leading, State#state{followers_list = NewFollowersList}};
leading({txn_unlink, _Sid, Pid}, State) ->
	?DEBUG("Removing peer (~p) from the followers list.", {_Sid, Pid}),
    NewFollowersList = lists:keydelete(Pid, 2, State#state.followers_list),
    NFollowers = length(NewFollowersList),
	NQuorum = ((length(State#state.server_list) div 2) + 1),
    if 
        (NFollowers >= NQuorum) ->
	        {next_state, leading, State#state{followers_list = NewFollowersList}};
        (NFollowers < NQuorum) ->
            jb_server_sup:terminate_txn_acceptors(State#state.myvote#vote.sid),
	        {next_state, looking, connect_and_clear_for_new_election(State)}
    end;
leading({notify, RecNotification, Sender}, State) ->
    handle_event({notify, RecNotification, Sender}, leading, State);
leading({ackepoch, _Epoch, _Zxid, _Data, _Sid}, StateData) ->
	?TRACE("Leader received ack epoch from ~p.", _Sid),
	{next_state, leading, StateData};
leading(AckMsg = {ack, _Epoch, _Zxid, Sender}, State) ->
    ?TRACE("Leader received ack from ~p. Zxid is ~p. Outstanding proposals: ~p.", 
            Sender, _Zxid, State#state.outstanding_proposals),
    {Sender, Pid, Status} = lists:keyfind(Sender, 1, State#state.followers_list),
    case Status of 
        no_acks ->
	        NewFollowersList = lists:keystore(Sender, 1, State#state.followers_list, {Sender, Pid, one_ack}),
	        {next_state, leading, State#state{followers_list = NewFollowersList}};
        one_ack ->
	        NewFollowersList = lists:keystore(Sender, 1, State#state.followers_list, {Sender, Pid, sync}),
	        {next_state, leading, State#state{followers_list = NewFollowersList}};
        sync ->
            process_ack(AckMsg, State)
    end;
leading(Msg, State) ->
	?DEBUG("Ignoring message ~p in leading state.", Msg),
	{next_state, leading, State}.
%% TODO: fix process_ack
process_ack({ack, _Epoch, Zxid, Sender}, StateData) ->
    Proposal = proplists:lookup(Zxid, StateData#state.outstanding_proposals),
    case Proposal of
        {Zxid, Msg, AckList} ->
            NQuorum = ((length(StateData#state.server_list) div 2) + 1),
            NAcks = erlang:length(AckList) + 1,
            if
                (NQuorum =< NAcks) ->
                    ?TRACE("Quorum reached, sending commits."),
                    MySid = StateData#state.myvote#vote.sid,
                    {MsgType, Zxid, NewData, [], MySid} = Msg,
                    NewMsg = {?COMMIT, Zxid, [], [], MySid},
                    ServerList = StateData#state.followers_list,
                    NewOutstandingProposals = proplists:delete(Zxid, StateData#state.outstanding_proposals),
                    NewStateData = case MsgType of
                        (?PROPOSAL) ->
                            StateData#state{outstanding_proposals = NewOutstandingProposals, mydata = NewData};
                        (?NEWLEADER) ->
                            StateData#state{outstanding_proposals = NewOutstandingProposals}
                    end,
                    lists:foreach(fun({E}) -> E ! NewMsg, ?DEBUG("Sending commit to ~p.", E) end, ServerList),
                    {next_state, broadcast, NewStateData};
                (NQuorum > NAcks) ->
                    ?TRACE("Quorum not yet reached."),
                    NewAckList = lists:keystore(Sender, 1, AckList, {Sender}),
                    NewProposal = {Zxid, Msg, NewAckList},
                    NewOutstandingProposals = list:keystore(Zxid, 1, StateData#state.outstanding_proposals, NewProposal),
                    {next_state, leading, StateData#state{outstanding_proposals = NewOutstandingProposals}}
            end;
        none ->
            ?TRACE("Ignoring irrelevant ACK.")
    end.

%% sync_following/2
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_fsm.html#Module:StateName-2">gen_fsm:StateName/2</a>
-spec sync_following(Event :: timeout | term(), StateData :: term()) -> Result when
	Result :: {next_state, NextStateName, NewStateData}
	| {next_state, NextStateName, NewStateData, Timeout}
	| {next_state, NextStateName, NewStateData, hibernate}
	| {stop, Reason, NewStateData},
	NextStateName :: atom(),
	NewStateData :: term(),
	Timeout :: non_neg_integer() | infinity,
	Reason :: term().
%% ====================================================================
sync_following({ping,_ }, State) ->
    ?WARN("Ignoring ping request in sync_following state."),
    {next_state, sync_following, State};
sync_following({txn_link, _Sid, Pid}, State) ->
	?TRACE("Follower connected to leader ~p.", _Sid),
    jb_txn_conn:send_quorum_packet(Pid, {followerinfo, State#state.myvote#vote.epoch, State#state.myvote#vote.zxid}),
   	{next_state, sync_following, State#state{leader_conn = Pid}};
sync_following({txn_unlink, _Sid, Pid}, State) when ((Pid =:= State#state.leader_conn) or (State#state.leader_conn =:= undefined)) ->
	?TRACE("Follower disconnected from leader ~p (or connection not achieved).", _Sid),
    {next_state, looking, connect_and_clear_for_new_election(State)};
sync_following({notify, RecNotification, Sender}, State) ->
    handle_event({notify, RecNotification, Sender}, sync_following, State);
sync_following({leaderinfo, Epoch, _Zxid}, StateData) ->
    ?TRACE("LeaderInfo request received Epoch is ~p, Zxid is ~p.", Epoch, _Zxid),
    jb_txn_conn:send_quorum_packet(StateData#state.leader_conn, {ackepoch, 0, 0}),
    %% Update of the epoch should actually wait until "uptodate", but we save a variable this way.
    {next_state, sync_following, StateData#state{myvote = StateData#state.myvote#vote{epoch = Epoch}}};
sync_following({diff, _Epoch, _Zxid}, StateData) ->
    ?TRACE("Diff request received Epoch is ~p, Zxid is ~p. Local ~p.", _Epoch, _Zxid, StateData),
	{next_state, sync_following, StateData};
sync_following({trunc, _Epoch, _Zxid}, StateData) ->
    ?TRACE("Truncate request received Epoch is ~p, Zxid is ~p. Local ~p.", _Epoch, _Zxid, StateData),
	{next_state, sync_following, StateData};
sync_following({snap, _Epoch, _Zxid}, StateData) ->
    ?TRACE("Snap request received Epoch is ~p, Zxid is ~p. Local ~p.", _Epoch, _Zxid, StateData),
	{next_state, sync_following, StateData};
sync_following({newleader, Epoch, Zxid}, StateData)
    when (Epoch >= StateData#state.myvote#vote.epoch) or (Zxid >= StateData#state.myvote#vote.zxid) ->
    ?TRACE("New leader request received Epoch is ~p, Zxid is ~p.", Epoch, Zxid),
    jb_txn_conn:send_quorum_packet(StateData#state.leader_conn, {ack, Epoch, Zxid}),
	{next_state, sync_following, StateData};
sync_following({newleader, _Epoch, _Zxid}, StateData) ->
    ?TRACE("Wrong new leader request received. Req {~p, ~p}, Local {~p, ~p}.", _Epoch, _Zxid, StateData#state.myvote#vote.epoch, StateData#state.myvote#vote.zxid),
    jb_server_sup:terminate_txn_conn(StateData#state.myvote#vote.sid),
    {next_state, looking, connect_and_clear_for_new_election(StateData)};
sync_following(Msg = {proposal, _Epoch, _Zxid, _Data}, StateData) ->
    handle_event(Msg, sync_following, StateData);
sync_following(Msg = {commit, _Epoch, _Zxid}, StateData) ->
    handle_event(Msg, sync_following, StateData);
sync_following({uptodate}, StateData) ->
    ?TRACE("UpToDate request received."),
    jb_txn_conn:send_quorum_packet(StateData#state.leader_conn, {ack, StateData#state.myvote#vote.epoch, 0}),
	{next_state, following, StateData};
sync_following(Msg, State) ->
	?DEBUG("Ignoring message ~p in sync_following state.", Msg),
	{next_state, sync_following, State}.

%% following/2
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_fsm.html#Module:StateName-2">gen_fsm:StateName/2</a>
-spec following(Event :: timeout | term(), StateData :: term()) -> Result when
	Result :: {next_state, NextStateName, NewStateData}
	| {next_state, NextStateName, NewStateData, Timeout}
	| {next_state, NextStateName, NewStateData, hibernate}
	| {stop, Reason, NewStateData},
	NextStateName :: atom(),
	NewStateData :: term(),
	Timeout :: non_neg_integer() | infinity,
	Reason :: term().
%% ====================================================================
following({txn_unlink, _Sid, Pid}, State) when ((Pid =:= State#state.leader_conn) or (State#state.leader_conn =:= undefined)) ->
	?TRACE("Follower disconnected from leader ~p (or connection not achieved).", _Sid),
    {next_state, looking, connect_and_clear_for_new_election(State)};
following(Not = {notify, _RecNotification, _Sender}, State) ->
    handle_event(Not, following, State);
following({ping, _Sid}, StateData) ->
    ?TRACE("Ping request received from ~p.", _Sid),
    jb_txn_conn:send_quorum_packet(StateData#state.leader_conn, {ping}),
	{next_state, following, StateData};
following(Msg = {proposal, Epoch, Zxid, _Data}, StateData)
    when (Epoch =:= StateData#state.myvote#vote.epoch) andalso (Zxid > StateData#state.myvote#vote.zxid) ->
    handle_event(Msg, following, StateData);
following(Msg = {commit, Epoch, Zxid}, StateData) 
    when (Epoch =:= StateData#state.myvote#vote.epoch) andalso (Zxid > StateData#state.myvote#vote.zxid) ->
    handle_event(Msg, following, StateData);
following(Msg, State) ->
	?DEBUG("Ignoring message ~p in following state.", Msg),
	{next_state, following, State}.

%% state_name/3
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_fsm.html#Module:StateName-3">gen_fsm:StateName/3</a>
-spec state_name(Event :: term(), From :: {pid(), Tag :: term()}, StateData :: term()) -> Result when
	Result :: {reply, Reply, NextStateName, NewStateData}
	| {reply, Reply, NextStateName, NewStateData, Timeout}
	| {reply, Reply, NextStateName, NewStateData, hibernate}
	| {next_state, NextStateName, NewStateData}
	| {next_state, NextStateName, NewStateData, Timeout}
	| {next_state, NextStateName, NewStateData, hibernate}
	| {stop, Reason, Reply, NewStateData}
	| {stop, Reason, NewStateData},
	Reply :: term(),
	NextStateName :: atom(),
	NewStateData :: atom(),
	Timeout :: non_neg_integer() | infinity,
	Reason :: normal | term().
%% ====================================================================
state_name(_Event, _From, StateData) ->
	Reply = ok,
	{reply, Reply, state_name, StateData}.


%% handle_event/3
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_fsm.html#Module:handle_event-3">gen_fsm:handle_event/3</a>
-spec handle_event(Event :: term(), StateName :: atom(), StateData :: term()) -> Result when
	Result :: {next_state, NextStateName, NewStateData}
	| {next_state, NextStateName, NewStateData, Timeout}
	| {next_state, NextStateName, NewStateData, hibernate}
	| {stop, Reason, NewStateData},
	NextStateName :: atom(),
	NewStateData :: term(),
	Timeout :: non_neg_integer() | infinity,
	Reason :: term().
%% ====================================================================
handle_event({get_status, Pid}, StateName, State) ->
    Pid ! {res_status, StateName, State},
	{next_state, StateName, State};
handle_event({fle_link, Sid, Pid}, StateName, State) ->
	%% ZooKeeper does not send a notification to the server as soon as connection is established as done here.
	%% ZooKeeper keeps a list of all notifications sent to a server and it sends them at this point.
	%% Since only the last vote is relevant, this seems to be a better approach, besides it saves us from maintaining the queue of messages.
	?DEBUG("Adding a new peer (~p) to the server list.", {Sid, Pid}),
	Notification = #notification{
        vote = State#state.leader_vote,
		election_epoch = State#state.election_epoch,
		state = get_notif_state(StateName)
    },
	jb_fle_conn:send_notification(Pid, Notification),
	{next_state, StateName, State#state{fle_server_list = lists:keystore(Sid, 1, State#state.fle_server_list, {Sid, Pid})}};
handle_event({fle_unlink, Sid, Pid}, StateName, State) ->
	?DEBUG("Removing peer (~p) from the leader election server list, ~p.", {Sid, Pid}, State#state.fle_server_list),
	{next_state, StateName, State#state{fle_server_list = lists:delete({Sid, Pid}, State#state.fle_server_list)}};
handle_event({notify, RecNotification, Sender}, StateName, State) ->
	Notification = #notification{
        vote = State#state.leader_vote,
		election_epoch = State#state.election_epoch,
		state = get_notif_state(StateName)
    },
	SenderTuple = lists:keyfind(Sender, 1, State#state.fle_server_list),
 	case SenderTuple of
		_ when (RecNotification#notification.state /= looking) ->
			%% This is different from Zookeeper? avoids a endless loop between two notlooking peers
			?DEBUG("Ignoring notification from someone that is not looking.");
		{_Sid, Pid} ->
			?TRACE("Sending notifications back to server out of ensemble with vote for ~p.", Notification#notification.vote#vote.sid),
			jb_fle_conn:send_notification(Pid, Notification);
		false ->
			?WARN("Ignoring notification from outside of the cluster.")
	end,
	{next_state, StateName, State};
handle_event({proposal, Epoch, Zxid, Data}, StateName, StateData) ->
    ?TRACE("New proposal received Zxid is ~p", Zxid),
	NewOutstandingProposals = lists:keystore(Zxid, 1, StateData#state.outstanding_proposals, {Zxid, Data}),
    jb_txn_conn:send_quorum_packet(StateData#state.leader_conn, {ack, Epoch, Zxid}),
	{next_state, StateName, StateData#state{outstanding_proposals = NewOutstandingProposals}};
handle_event({commit, _Epoch, Zxid}, StateName, StateData) ->
    ?TRACE("New commit received Zxid is ~p. Proposals ~p.", Zxid, StateData#state.outstanding_proposals),
	NewData = proplists:get_value(Zxid, StateData#state.outstanding_proposals),
	NewOutstandingProposals = proplists:delete(Zxid, StateData#state.outstanding_proposals),
	{next_state, StateName, StateData#state{mydata = NewData, outstanding_proposals = NewOutstandingProposals}}.


%% handle_sync_event/4
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_fsm.html#Module:handle_sync_event-4">gen_fsm:handle_sync_event/4</a>
-spec handle_sync_event(Event :: term(), From :: {pid(), Tag :: term()}, StateName :: atom(), StateData :: term()) -> Result when
	Result :: {reply, Reply, NextStateName, NewStateData}
	| {reply, Reply, NextStateName, NewStateData, Timeout}
	| {reply, Reply, NextStateName, NewStateData, hibernate}
	| {next_state, NextStateName, NewStateData}
	| {next_state, NextStateName, NewStateData, Timeout}
	| {next_state, NextStateName, NewStateData, hibernate}
	| {stop, Reason, Reply, NewStateData}
	| {stop, Reason, NewStateData},
	Reply :: term(),
	NextStateName :: atom(),
	NewStateData :: term(),
	Timeout :: non_neg_integer() | infinity,
	Reason :: term().
%% ====================================================================
handle_sync_event(_Event, _From, StateName, StateData) ->
	Reply = ok,
	{reply, Reply, StateName, StateData}.


%% handle_info/3
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_fsm.html#Module:handle_info-3">gen_fsm:handle_info/3</a>
-spec handle_info(Info :: term(), StateName :: atom(), StateData :: term()) -> Result when
	Result :: {next_state, NextStateName, NewStateData}
	| {next_state, NextStateName, NewStateData, Timeout}
	| {next_state, NextStateName, NewStateData, hibernate}
	| {stop, Reason, NewStateData},
	NextStateName :: atom(),
	NewStateData :: term(),
	Timeout :: non_neg_integer() | infinity,
	Reason :: normal | term().
%% ====================================================================
handle_info({timeout}, StateName, StateData) ->
    case StateName of
        sync_leading ->
	        ?TRACE("Leader sync timed out."),
            jb_server_sup:terminate_txn_acceptors(StateData#state.myvote#vote.sid),
	        {next_state, looking, connect_and_clear_for_new_election(StateData)};
        looking ->
            erlang:cancel_timer(StateData#state.timer),
            send_notifications(StateData#state.fle_server_list, StateData#state.leader_vote, StateData#state.election_epoch),
            {next_state, looking, StateData#state{timer = erlang:send_after(StateData#state.tick_time * StateData#state.sync_limit, self(), {timeout})}};
        sync_following ->
	        {next_state, StateName, StateData};
        following ->
	        {next_state, StateName, StateData};
        leading ->
	        {next_state, StateName, StateData}
    end.

%% terminate/3
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_fsm.html#Module:terminate-3">gen_fsm:terminate/3</a>
-spec terminate(Reason, StateName :: atom(), StateData :: term()) -> Result :: term() when
	Reason :: normal
	| shutdown
	| {shutdown, term()}
	| term().
%% ====================================================================
terminate(_Reason, _State, _StateData) ->
    ok.

%% code_change/4
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_fsm.html#Module:code_change-4">gen_fsm:code_change/4</a>
-spec code_change(OldVsn, StateName :: atom(), StateData :: term(), Extra :: term()) -> {ok, NextStateName :: atom(), NewStateData :: term()} when
	OldVsn :: Vsn | {down, Vsn},
	Vsn :: term().
%% ====================================================================
code_change(_OldVsn, StateName, StateData, _Extra) ->
	{ok, StateName, StateData}.


%% ====================================================================
%% Internal functions
%% ====================================================================
 
send_notifications(ServerList, Vote, Epoch) ->
	Notification = #notification{
        vote = Vote,
		election_epoch = Epoch,
		state = looking
    },
	?TRACE("Sending notifications to all servers."),
	lists:foreach(fun({_Sid, Pid}) -> jb_fle_conn:send_notification(Pid, Notification), ?DEBUG("Sending notify to ~p.", _Sid) end, ServerList).

handle_notification_from_someone_not_looking(State, Sender, Notification, NQuorum) ->
	Vote = Notification#notification.vote,
	NewElectionVotes = lists:keystore(Sender, 1, State#state.votes_in_election, {Sender, Vote}),
	NVotes = get_number_of_votes(NewElectionVotes, Vote),
	LeaderCheck = check_leader(State#state.votes_out_of_election, Vote#vote.sid, true, State#state.myvote#vote.sid), 
	if
		((NVotes >= NQuorum) and LeaderCheck) ->
			looking_return_value_with_quorum(State, Vote);
		(true) ->
			update_and_check_out_of_election(State, Sender, NewElectionVotes, Notification, NQuorum, true)
	end.

handle_notification_from_someone_looking(State, Sender, SenderPid, Vote, VoteEpoch, NQuorum) ->
	{NewElectionVotes, NewProposedLeaderVote, NewElectionEpoch} = case State#state.election_epoch of
		VoteEpoch ->
            {ProposedVote, NewVoteList} = if
				(State#state.leader_vote > Vote) ->
					?DEBUG("Epoch is same, my proposal ~p is better.", State#state.leader_vote),
					%% This seems to be different in ZooKeeper. Apparently they don't send this notifications even this peer seems to need it.
                    ToSend = #notification{
                        vote = State#state.leader_vote,
                        election_epoch = State#state.election_epoch,
                        state = looking
                    },
                    jb_fle_conn:send_notification(SenderPid, ToSend),
                    {State#state.leader_vote, lists:keystore(Sender, 1, State#state.votes_in_election, {Sender, Vote})};
				(State#state.leader_vote < Vote) ->
					?DEBUG("Epoch is same, my proposal ~p is worse.", State#state.leader_vote),
					send_notifications(State#state.fle_server_list, Vote, State#state.election_epoch),
                    NewVoteListTemp = lists:keystore(Sender, 1, State#state.votes_in_election, {Sender, Vote}),
                    {Vote, lists:keystore(State#state.myvote#vote.sid, 1, NewVoteListTemp, {State#state.myvote#vote.sid, Vote})};
				(State#state.leader_vote == Vote) ->
					?DEBUG("Epoch is same, my proposal ~p is same.", State#state.leader_vote),
                    {Vote, lists:keystore(Sender, 1, State#state.votes_in_election, {Sender, Vote})}
			end,
			{NewVoteList, ProposedVote, State#state.election_epoch};
		_ ->
            {ProposedVote, NewVoteList} = if
				(State#state.myvote < Vote) ->
					?DEBUG("Epoch is newer, myvote ~p is worse.", State#state.myvote),
                    {Vote, [{Sender, Vote}, {State#state.myvote#vote.sid, Vote}]};
				(State#state.myvote >= Vote) ->
					?DEBUG("Epoch is newer, myvote ~p is better or same.", State#state.myvote),
                    {State#state.myvote, [{Sender, Vote}, {State#state.myvote#vote.sid, State#state.myvote}]}
			end,
			send_notifications(State#state.fle_server_list, ProposedVote, VoteEpoch),
			{NewVoteList, ProposedVote, VoteEpoch}
	end,
	NVotes = get_number_of_votes(NewElectionVotes, NewProposedLeaderVote),
	?DEBUG("Number of votes received for proposed leader (~p) is ~p.", NewProposedLeaderVote#vote.sid, NVotes),
    %% We don't check that there are no pending messages as ZK does.
    %% The reason is that in tests it is prooved to make election slower and it doesn't solve anything.
%%    {message_queue_len, MessageQueueLen} = process_info(self(), message_queue_len),    
%%    if
%%        ((NVotes >= NQuorum) and (MessageQueueLen =:= 0)) ->
	if
        (NVotes >= NQuorum) ->
			looking_return_value_with_quorum(State, NewProposedLeaderVote);
		true ->
			NewState = State#state{leader_vote = NewProposedLeaderVote, votes_in_election = NewElectionVotes, election_epoch = NewElectionEpoch},
            {next_state, looking, NewState#state{timer = erlang:send_after(State#state.tick_time * State#state.sync_limit, self(), {timeout})}}
	end.

get_number_of_votes(Dict, Vote) ->
	?TRACE("Searching for votes to ~p in current election.", Vote#vote.sid),
	lists:foldl(fun({_Key, Value}, AccIn) when (Value#vote.sid == Vote#vote.sid) -> 
				?TRACE("Found a vote (~p) from (~p).", Value, _Key),
				AccIn + 1;
			({_Key, _Value}, AccIn) -> 
				?TRACE("Non-matching vote (~p) from (~p).", _Value, _Key), 
				AccIn 
		end, 0, Dict).

looking_return_value_with_quorum(State, ProposedLeaderVote) ->
	NewStateName = if
		(not State#state.is_participant) ->
			sync_observing;
		(State#state.myvote == ProposedLeaderVote) and (length(State#state.server_list) > 1) ->
			sync_leading;
		(State#state.myvote == ProposedLeaderVote) and (length(State#state.server_list) =:= 1) ->
			leading;
		(true) ->
			sync_following
	end,
    NewEpoch = State#state.election_epoch + 1,
    TmpNewState = State#state{
        leader_vote = ProposedLeaderVote#vote{epoch = NewEpoch},
        myvote = State#state.myvote#vote{epoch = NewEpoch},
       	election_epoch = NewEpoch,
        outstanding_proposals = []
    },
    MySid = State#state.myvote#vote.sid,
    NewState = case NewStateName of
        leading ->
            TmpNewState#state{
                followers_list = [],
                timer = undefined
            };
        sync_leading ->
            {MySid, {Host, TXNPort, _FLEPort}} = lists:keyfind(MySid, 1, State#state.server_list),
            jb_server_sup:start_txn_acceptors(State#state.myvote#vote.sid, {Host, TXNPort}, (length(State#state.server_list) - 1), State#state.tick_time, State#state.sync_limit),
            TmpNewState#state{
                followers_list = [],
                timer = erlang:send_after(State#state.tick_time * State#state.initial_limit, self(), {timeout})
            };
        sync_following ->
            LeaderSid = ProposedLeaderVote#vote.sid,
            {LeaderSid, {Host, TXNPort, _FLEPort}} = lists:keyfind(LeaderSid, 1, State#state.server_list),
            FsmRef = {global, {?MODULE, State#state.myvote#vote.sid}},
            jb_server_sup:start_txn_conn(?MODULE, FsmRef, MySid, {Host, TXNPort}, LeaderSid, State#state.tick_time, State#state.sync_limit),
            TmpNewState#state{
                timer = undefined
            }
    end,
	_ElectionDuration = timer:now_diff(erlang:now(), State#state.election_start_time),
	?INFO("Election finished after ~p microseconds. New state is ~p. Leader is ~p.", _ElectionDuration, get_notif_state(NewStateName), NewState#state.leader_vote#vote.sid),
	{next_state, NewStateName, NewState#state{election_start_time = undefined}}.

update_and_check_out_of_election(State, Sender, NewElectionVotes, Notification, NQuorum, VoteEpochIsSame) -> 
	NewOutOfElectionVotes = lists:keystore(Sender, 1, State#state.votes_out_of_election, {Sender, Notification}),
	NVotes = lists:foldl(fun({_Key, Value}, AccIn) when (Value#notification.vote#vote.sid == Notification#notification.vote#vote.sid) -> 
				?TRACE("Found a vote (~p), from (~p).", Value#notification.vote, _Key),
				AccIn + 1;
			({_Key, _Value}, AccIn) -> 
				?TRACE("Non-matching vote (~p), from (~p).", _Value#notification.vote, _Key), 
				AccIn 
		end, 0, NewOutOfElectionVotes),
	?TRACE("A total of ~p votes for proposed leader (~p) out of the election.", NVotes, Notification#notification.vote#vote.sid),
	LeaderCheck = check_leader(NewOutOfElectionVotes, Notification#notification.vote#vote.sid, VoteEpochIsSame, State#state.myvote#vote.sid),
	if
		((NVotes >= NQuorum) and LeaderCheck) ->
			looking_return_value_with_quorum(State, Notification#notification.vote);
		(true) ->
			NewState = State#state{votes_in_election = NewElectionVotes, votes_out_of_election = NewOutOfElectionVotes},
            {next_state, looking, NewState#state{timer = erlang:send_after(State#state.tick_time * State#state.sync_limit, self(), {timeout})}}
	end.

check_leader(_Dict, ProposedLeader, VoteEpochIsSame, MySid) when (ProposedLeader == MySid) ->
	VoteEpochIsSame;
check_leader(Dict, ProposedLeader, _VoteEpochIsSame, _MySid) ->
	LeaderVote = proplists:lookup(ProposedLeader, Dict),
	case LeaderVote of 
		none -> 
			false;
		X when (X#notification.state /= leading) ->
			false;
		_ ->
			true
	end.

get_notif_state(StateName) ->
    case (StateName) of
        leading -> leading;
        sync_leading -> leading;
        following -> following;
        sync_following -> following;
        looking -> looking
    end.

-ifdef(no_leader).
-define(NEWELECTIONEPOCH, ?INITIAL_EPOCH).
-define(CURRENTZXID, 0).
-define(CURRENTEPOCH, ?INITIAL_EPOCH).
-define(CHECKSID, 1).
-else.
-define(NEWELECTIONEPOCH, State#state.election_epoch).
-define(CURRENTZXID, State#state.myvote#vote.zxid).
-define(CURRENTEPOCH, State#state.myvote#vote.epoch).
-define(CHECKSID, MySid).
-endif.

connect_and_clear_for_new_election(State) ->
    MySid = State#state.myvote#vote.sid,
    MySid = ?CHECKSID,
    FsmRef = {global, {?MODULE, MySid}},
    %% Connection to peers with a higher sid, only in order to trigger the connection back from them.
    %% This is required only for interoperability with ZooKeeper servers, since JungleBoogie keeps the FLE connection open at all times.
    ConnectList = [{X,Y} || {X,Y} <-  State#state.server_list, MySid < X],
    jb_fle_out_conn_sup:connect(?MODULE, FsmRef, MySid, ConnectList, State#state.tick_time, State#state.sync_limit),
    MyVote = State#state.myvote#vote{
        zxid = ?CURRENTZXID,
        epoch = ?CURRENTEPOCH
    },
	send_notifications(State#state.fle_server_list, MyVote, State#state.election_epoch),
    State#state{
        timer = erlang:send_after(State#state.tick_time * State#state.sync_limit, self(), {timeout}),
		leader_vote = MyVote,
        election_epoch = ?NEWELECTIONEPOCH,
		votes_in_election = [{State#state.myvote#vote.sid, MyVote}], 
		votes_out_of_election = [],
        followers_list = undefined,
        leader_conn = undefined, 
        election_start_time = erlang:now()
    }.
