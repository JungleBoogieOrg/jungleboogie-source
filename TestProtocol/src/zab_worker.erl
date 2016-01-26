%% @author ECEGBB
%% @doc Workers follow leaders
%       Workers forward write request to leaders
%       Workers attend read request
%       Workers forward leader negotiation to leaders
%       Workers process transactions

-module(zab_worker).

-include("zab_log.hrl").
-include("zab_records.hrl").

%% ====================================================================
%% API functions
%% ====================================================================
-export([start/4]).

start(AllServersSet, Leader, Data, Zxid) ->
  ?LOG("Worker (~p): Started!", self()),
  loop_withtimer(AllServersSet, Leader, Data, undefined, Zxid).                                

%% ====================================================================
%% Internal functions
%% ====================================================================

loop_withtimer(AllServersSet, Leader, Data, Prepared, Zxid) ->
  {ok, TRef} = timer:send_after(2000, {timeout}),
  loop(AllServersSet, Leader, Data, Prepared, Zxid, TRef).

loop(AllServersSet, Leader, Data, Prepared, Zxid, TRef) ->
  receive
    {readData, Client} ->
       ?LOG("Worker (~p): Sending data (~p) back to ~p.", self(), Data, Client),
       Client ! Data,
       loop(AllServersSet, Leader, Data, Prepared, Zxid, TRef);
    {writeData, NewData, Client} ->
       ?LOG("Worker (~p): A client wants to update.", self()),
       Leader ! {writeData, NewData, Client},
       loop(AllServersSet, Leader, Data, Prepared, Zxid, TRef);
    {prepareData, NewPrepared, Leader} ->
       {ok, cancel} = timer:cancel(TRef),
       ?LOG("Worker (~p): Leader (~p) is requesting a prepare of ~p.", self(), Leader, NewPrepared#prepared.zxid),
       Leader ! {ackPrepare, NewPrepared#prepared.zxid, self()},
       loop_withtimer(AllServersSet, Leader, Data, NewPrepared, Zxid);
    {commitData, SenderZxid, Leader} when (Prepared#prepared.zxid == SenderZxid) -> 
       {ok, cancel} = timer:cancel(TRef),
       ?LOG("Worker (~p): Leader is requesting a commit.", self()),
       loop_withtimer(AllServersSet, Leader, Prepared#prepared.data, undefined, Prepared#prepared.zxid);
    {followme, SenderData, Zxid, Leader} ->
       {ok, cancel} = timer:cancel(TRef),
       ?LOG("Worker (~p): Keepalive received from leader (~p).", self(), Leader),
       Leader ! {yesifollow, Zxid, self()},
       loop_withtimer(AllServersSet, Leader, SenderData, undefined, Zxid);
    {commitData, _ , Leader} -> 
       ?LOG("Worker (~p): Invalid commit received from leader.", self()),
       Leader ! {followme, Data, Zxid, self()},
       zab_candidate:start(AllServersSet, sets:new(), Data, Zxid);
    {commitData, _ , Sender} -> 
       ?LOG("Worker (~p): Invalid commit received from stranger.", self()),
       Leader ! {checkcandidate, Sender},
       loop(AllServersSet, Leader, Data, Prepared, Zxid, TRef);
    {prepareData, _ , Sender} ->
       ?LOG("Worker (~p): Prepared requested by stranger (~p).", self(), Sender),
       Leader ! {checkcandidate, Sender},
       loop(AllServersSet, Leader, Data, Prepared, Zxid, TRef);
    {followme, SenderData, SenderZxid, Leader} when ((Zxid#zxid.epoch < SenderZxid#zxid.epoch) or 
                                                      ((Zxid#zxid.epoch == SenderZxid#zxid.epoch) and 
                                                        (SenderZxid#zxid.counter < SenderZxid#zxid.counter))) ->
       {ok, cancel} = timer:cancel(TRef),
       ?LOG("Worker (~p): Newer Zxid received from leader (~p).", self(), Leader),
       Leader ! {yesifollow, SenderZxid, self()},
       loop_withtimer(AllServersSet, Leader, SenderData, undefined, SenderZxid);
    {followme, _ , _ , Leader} ->
       ?LOG("Worker (~p): Older Zxid received from leader (~p).", self(), Leader),
       Leader ! {followme, Data, Zxid, self()},
       zab_candidate:start(AllServersSet, sets:new(), Data, Zxid);
    {followme, _ , _ , Sender} ->
       ?LOG("Worker (~p): redirecting candidate ~p to leader (~p).", self(), Sender, Leader),
       Leader ! {checkcandidate, Sender},
       loop(AllServersSet, Leader, Data, Prepared, Zxid, TRef);
    {yesifollow, _ , Leader} ->
       ?LOG("Worker (~p): Leader (~p), no longer leader.", self(), Leader),
       Leader ! {followme, Data, Zxid, self()},
       zab_candidate:start(AllServersSet, sets:new(), Data, Zxid);
    {yesifollow, _ , Sender} ->
       ?LOG("Worker (~p): Redirecting worker ~p to leader (~p).", self(), Sender, Leader),
       Leader ! {checkcandidate, Sender},
       loop(AllServersSet, Leader, Data, Prepared, Zxid, TRef);
    {timeout} ->
       {ok, cancel} = timer:cancel(TRef),
       ?LOG("Worker (~p): No message from leader (~p) in a while.", self(), Leader),
       Leader ! {yesifollow, Zxid, self()},
       loop_withtimer(AllServersSet, Leader, Data, Prepared, Zxid)
  after
    3000 ->
      ?LOG("Worker (~p): Timer is not working!", self()),
      {ok, cancel} = timer:cancel(TRef),
      loop_withtimer(AllServersSet, Leader, Data, Prepared, Zxid)
  end.
    
