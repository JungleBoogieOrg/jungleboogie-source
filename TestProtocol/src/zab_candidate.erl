%% @author german
%% @doc Candidates are looking for followers to become Leaders.
%       Candidates have a list of followers (not yet a quorum)
%       When they have enough followers they become leaders
%       They send messages to the rest of servers, one by one
%       They ask other servers to follow them
%       Other servers reply with a yes or again with followme
%       Requests from Clients are postponed

-module(zab_candidate).

-include("zab_log.hrl").
-include("zab_records.hrl").

%% ====================================================================
%% API functions
%% ====================================================================
-export([start/0, start/4]).

start() ->
  Zxid = #zxid{epoch = erlang:now(), counter = 0},
  Data = {root, [{app1, [{node1, []}, {node2, []}]}, {app2, [{node3, []}]}]},
  ?LOG("Candidate (~p): Server started with Zxid ~p!", self(), Zxid),
  notready(Data, Zxid).                                

start(ServersDownSet, Followers, Data, Zxid) ->
  ?LOG("Candidate (~p): Moved to candidate with Zxid ~p!", self(), Zxid),
  ServersDownList = sets:to_list(ServersDownSet),
  loop_withtimer(ServersDownList, Followers, Data, Zxid).

%% ====================================================================
%% Internal functions
%% ====================================================================

notready(Data, Zxid) ->
  receive
    {ready, ServerSet, Sender} ->
      ?LOG("Candidate (~p): Updating server list (~p).", self(), ServerSet),
      ServersDownList = sets:to_list(sets:del_element(self(), ServerSet)),
      Sender ! ok,
	  loop_withtimer(ServersDownList, sets:new(), Data, Zxid)
  end.

loop_withtimer([], Followers, Data, Zxid) ->
  {ok, TRef} = timer:send_after(2000, {timeout}),
  loop([], Followers, Data, Zxid, TRef);
loop_withtimer(ServersDownList, Followers, Data, Zxid) ->
  lists:last(ServersDownList) ! {followme, Data, Zxid, self()},
  {ok, TRef} = timer:send_after(2000, {timeout}),
  loop(ServersDownList, Followers, Data, Zxid, TRef).

loop(ServersDownList, Followers, Data, Zxid, TRef) ->
  receive
    {yesifollow, Zxid, Sender} ->
	   timer:cancel(TRef),
       ?LOG("Candidate (~p): Adding ~p to followers.", self(), Sender),
       add_follower(ServersDownList, Followers, Data, Zxid, Sender);
    {followme, _ , SenderZxid, Sender} when ((Zxid#zxid.epoch > SenderZxid#zxid.epoch) or 
                                              ((Zxid#zxid.epoch == SenderZxid#zxid.epoch) and 
                                                (SenderZxid#zxid.counter > SenderZxid#zxid.counter))) ->
	   timer:cancel(TRef),
       ?LOG("Candidate (~p): Candidate ~p with zxid ~p should follow us (~p).", self(), Sender, SenderZxid, Zxid),
       Sender ! {followme, Data, Zxid, self()},
       loop_withtimer(ServersDownList, Followers, Data, Zxid);
    {followme, SenderData, SenderZxid, Sender} ->
	   timer:cancel(TRef),
       ?LOG("Candidate (~p): Following ~p with zxid ~p, ours was (~p).", self(), Sender, SenderZxid, Zxid),
       Sender ! {yesifollow, SenderZxid, self()},
       zab_worker:start(sets:union(Followers, sets:from_list(ServersDownList)), Sender, SenderData, SenderZxid);
    {yesifollow, _ , Sender} ->
       ?LOG("Candidate (~p): Inconsistency in Zxid from server.", self(), Sender),
       Sender ! {followme, Data, Zxid, self()},
       loop(ServersDownList, Followers, Data, Zxid, TRef);
    {readData, Client } ->
       ?LOG("Candidate (~p): Not able to reply to client read.", self()),
	   Client ! busy,
       loop(ServersDownList, Followers, Data, Zxid, TRef);
    {writeData, _ , Client } ->
       ?LOG("Candidate (~p): Not able to reply to client write.", self()),
	   Client ! busy,
       loop(ServersDownList, Followers, Data, Zxid, TRef);
    {prepareData, _ , _ , Sender} -> 
       ?LOG("Candidate (~p): A leader is requesting a prepare.", self()),
       Sender ! {followme, Data, Zxid, self()},
       loop(ServersDownList, Followers, Data, Zxid, TRef);
    {commitData, _ , Sender} ->
  % This candidate has been part of a quorum and never received the commit
  % anyway, transaction will be lost only if all other members die!
      ?LOG("Candidate (~p): A leader is requesting a commit.", self()),
      Sender ! {followme, Data, Zxid, self()},
      loop(ServersDownList, Followers, Data, Zxid, TRef);
   {timeout} ->
      timer:cancel(TRef),
      ?LOG("Candidate (~p): timeout while looking for quorum, trying again.", self()),
      [First | Rest ] = ServersDownList,
      First ! {followme, Data, Zxid, self()},
      loop_withtimer(lists:append(Rest, [First]), Followers, Data, Zxid)
  after
    3000 ->
      timer:cancel(TRef),
      ?LOG("Candidate (~p): Timer is not working!", self()),
      loop_withtimer(ServersDownList, Followers, Data, Zxid)
  end.

add_follower(ServersDownList, Followers, Data, Zxid, Follower) ->
   Nquorum = ((sets:size(Followers) + erlang:length(ServersDownList) + 1) div 2), % Leader is part of the quorum (+1)
   NewFollowers = sets:add_element(Follower, Followers),
   NFollowers = sets:size(NewFollowers),
   ?LOG("Candidate (~p): Quorum is ~p, I have ~p followers.", self(), Nquorum, NFollowers),
   NewServersDownList = lists:delete(Follower, ServersDownList),
   if 
     (NFollowers >= Nquorum) ->
       zab_leader:start(NewServersDownList, NewFollowers, Data, Zxid);
     true ->
       loop_withtimer(NewServersDownList, NewFollowers, Data, Zxid)
   end.

