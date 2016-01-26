%% @author ECEGBB
%% @doc Leaders process transactions.
%       Transactions are processed using a pseudo 2PC.
%       The transaction is committed as soon as there is quorum.
%       Requests from Servers that are not following are replied with followme.
%       There CAN'T be other Server with a higher Zxid.
%       If a higher Zxid is received, then change to candidate (and log).
%       Requests to write when there is a pending transaction are postponed.
%       There is a timer to handle timeout of a transaction.
%       If not enough followers ack a transaction, change back to Candidate.

-module(zab_leader).

-include("zab_log.hrl").
-include("zab_records.hrl").

-record(preparedinfo, {data, tobeprepared, nacks, client, zxid}).

%% ====================================================================
%% API functions
%% ====================================================================
-export([start/4]).

start(ServersDownList, Followers, Data, Zxid) ->
  ?LOG("Leader ~p started with zxid ~p!", self(), Zxid),
  Nquorum = ((sets:size(Followers) + erlang:length(ServersDownList) + 1) div 2), % Leader is part of the quorum (+1)
  loop(sets:from_list(ServersDownList), Followers, Data, undefined, Zxid, undefined, Nquorum).

%% ====================================================================
%% Internal functions
%% ====================================================================

loop(ServersDownSet, Followers, Data, PreparedInfo, Zxid, TRef, Nquorum) ->
  receive
    {yesifollow, Zxid, Sender} when (PreparedInfo == undefined) -> 
      ?LOG("Leader (~p): Adding follower ~p.", self(), Sender),
      loop(sets:del_element(Sender, ServersDownSet), sets:add_element(Sender, Followers), Data, PreparedInfo, Zxid, TRef, Nquorum);
    {yesifollow, Zxid, Sender} -> 
      ?LOG("Leader (~p): Adding follower ~p and sending current transaction.", self(), Sender),
	  NewPrepared = #prepared{data = PreparedInfo#preparedinfo.data, zxid = PreparedInfo#preparedinfo.zxid},
      Sender ! {prepareData, NewPrepared, self()},
      loop(sets:del_element(Sender, ServersDownSet), sets:add_element(Sender, Followers), Data, PreparedInfo, Zxid, TRef, Nquorum);
    {checkcandidate, Candidate} ->
      ?LOG("Leader (~p): Checking (~p).", self(), Candidate),
      Candidate ! {followme, Data, Zxid, self()},
      loop(ServersDownSet, Followers, Data, PreparedInfo, Zxid, TRef, Nquorum);
    {readData, Client} ->
      ?LOG("Leader (~p): Sending data (~p) back to ~p.", self(), Data, Client),
      Client ! Data,
      loop(ServersDownSet, Followers, Data, PreparedInfo, Zxid, TRef, Nquorum);
    {writeData, NewData, Client} when (PreparedInfo == undefined) ->
      ?LOG("Leader (~p): A client wants to update with ~p, Zxid is ~p.", self(), NewData, Zxid),
      {ok, NewTRef} = timer:send_after(2000, {timeout}),
	  NewZxid = #zxid{epoch = erlang:now(), counter = (Zxid#zxid.counter + 1)},
	  NewPrepared = #prepared{data = NewData, zxid = NewZxid},
      sets:fold(fun(E, AccIn) -> E ! {prepareData, NewPrepared, self()}, ?LOG("Sending prepare to ~p.", E), AccIn end, ok, Followers),
      sets:fold(fun(E, AccIn) -> E ! {prepareData, NewPrepared, self()}, ?LOG("Sending prepare to ~p.", E), AccIn end, ok, ServersDownSet),
	  NewPreparedInfo = #preparedinfo{
									  data = NewData, 
									  tobeprepared = Followers, 
									  nacks = 0, 
									  client = Client, 
									  zxid = NewZxid},
      loop(ServersDownSet, Followers, Data, NewPreparedInfo, Zxid, NewTRef, Nquorum);
    {writeData, _ , Client} ->
      ?LOG("Leader (~p): Unable to process write from ~p.", self(), Client),
      Client ! busy,
      loop(ServersDownSet, Followers, Data, PreparedInfo, Zxid, TRef, Nquorum);
    {ackPrepare, PrepareZxid, Sender} when ((PrepareZxid == PreparedInfo#preparedinfo.zxid) and ((PreparedInfo#preparedinfo.nacks + 1) < Nquorum)) ->
      ?LOG("Leader (~p): Ack received from ~p with zxid ~p.", self(), Sender, PrepareZxid),
      NewToPrepareServers = sets:del_element(Sender, PreparedInfo#preparedinfo.tobeprepared),
      NewNacks = PreparedInfo#preparedinfo.nacks + 1,
      ?LOG("Leader: Acks ~p quorum ~p.", NewNacks, Nquorum),
	  NewPreparedInfo = #preparedinfo{
									  data = PreparedInfo#preparedinfo.data, 
									  tobeprepared = NewToPrepareServers, 
									  nacks = NewNacks, 
									  client = PreparedInfo#preparedinfo.client, 
									  zxid = PrepareZxid},
      loop(ServersDownSet, Followers, Data, NewPreparedInfo, Zxid, TRef, Nquorum);
    {ackPrepare, PrepareZxid, _ } when ((PrepareZxid == PreparedInfo#preparedinfo.zxid) and ((PreparedInfo#preparedinfo.nacks + 1) == Nquorum)) ->
      timer:cancel(TRef),
      ?LOG("Leader (~p): Quorum reached with zxid ~p.", self(), PrepareZxid),
      PreparedInfo#preparedinfo.client ! ok,
      sets:fold(fun(E, AccIn) -> E ! {commitData, PrepareZxid, self()}, ?LOG("Sending commit to ~p.", E), AccIn end, ok, Followers),
      sets:fold(fun(E, AccIn) -> E ! {commitData, PrepareZxid, self()}, ?LOG("Sending commit to ~p.", E), AccIn end, ok, ServersDownSet),
      loop(ServersDownSet, Followers, PreparedInfo#preparedinfo.data, undefined, PrepareZxid, undefined, Nquorum);
    {ackPrepare, Zxid, _ } ->
      ?LOG("Leader (~p): Ack not needed for quorum of zxid ~p.", self(), Zxid),
      loop(ServersDownSet, Followers, Data, PreparedInfo, Zxid, TRef, Nquorum);
    {Op, SenderZxid, Sender} when (((Op == prepareData) or (Op == commitData) or (Op == yesifollow) or (Op == ackPrepare)) and 
                                    ((Zxid#zxid.epoch > SenderZxid#zxid.epoch) or 
                                      ((Zxid#zxid.epoch == SenderZxid#zxid.epoch) and 
                                        (SenderZxid#zxid.counter > SenderZxid#zxid.counter)))) ->
      ?LOG("Leader (~p): Old zxid received from ~p.", self(), Sender),
      Sender ! {followme, Data, Zxid, self()},
      loop(ServersDownSet, Followers, Data, PreparedInfo, Zxid, TRef, Nquorum);
    {Op, _ , Sender}  when ((Op == prepareData) or (Op == commitData) or (Op == yesifollow) or (Op == ackPrepare)) -> 
      ?LOG("Leader (~p): Newer zxid received from ~p! Ours is ~p", self(), Sender, Zxid),
      Sender ! {followme, Data, Zxid, self()},
      zab_candidate:start(sets:union(Followers, ServersDownSet), sets:new(), Data, Zxid);
    {followme, SenderData, SenderZxid, Sender} when ((Zxid#zxid.epoch < SenderZxid#zxid.epoch) or 
                                                      ((Zxid#zxid.epoch == SenderZxid#zxid.epoch) and 
                                                        (SenderZxid#zxid.counter < SenderZxid#zxid.counter))) ->
      ?LOG("Leader (~p): Newer zxid received from ~p!", self(), Sender),
      Sender ! {yesifollow, SenderZxid, self()},
      zab_worker:start(sets:union(Followers, ServersDownSet), Sender, SenderData, SenderZxid);
    {followme, _ , _ , Sender} -> 
      ?LOG("Leader (~p): Candidate ~p should follow us.", self(), Sender),
      Sender ! {followme, Data, Zxid, self()},
      loop(ServersDownSet, Followers, Data, PreparedInfo, Zxid, TRef, Nquorum);
    {timeout} when (PreparedInfo /= undefined) ->
      timer:cancel(TRef),
      ?LOG("Leader (~p): Transaction timeout.", self()),
      PreparedInfo#preparedinfo.client ! busy,
	  NewServersDownSet = sets:union(ServersDownSet, PreparedInfo#preparedinfo.tobeprepared),
	  NewFollowers = sets:subtract(Followers, PreparedInfo#preparedinfo.tobeprepared),
      zab_candidate:start(NewServersDownSet, NewFollowers, Data, Zxid)
  after
    2000 ->
      sets:fold(fun(E, AccIn) -> E ! {followme, Data, Zxid, self()}, ?LOG("Sending keepalive to ~p.", E), AccIn end, ok, Followers),
      sets:fold(fun(E, AccIn) -> E ! {followme, Data, Zxid, self()}, ?LOG("Sending keepalive to ~p.", E), AccIn end, ok, ServersDownSet),
      loop(ServersDownSet, Followers, Data, PreparedInfo, Zxid, TRef, Nquorum)
  end.

