%% @author ECEGBB

%% @doc  This is a prototype of the Zookeeper Zab protocol.
% PA1 - assume all the servers are alive, the first (empty list) becomes leader
%       updates are of the entire znode data tree
%       pseudo 3PC implemented
%       Zxid implemented
% Note: Erlang ordering of messages within a process is guaranteed
% PA2 - Negotiation added.
%       The list of all servers is sent to all of them on start
%       Three types of activity (Candidate, Leader, Worker)
%       Clients are outside agents that send read or write requests
%       Read or write request can be received by any server.
%       This module includes some fake Clients.

% Messages:
%       {followme, data, zxid, pid}
%       {yesifollow, zid, pid}
%       {checkcandidate, pid}
%       {readData, pid}
%       {writeData, data, pid}
%       {prepareData, prepared, pid}
%       {commitData, zxid, pid}
%       {ackPrepare, zxid, pid}
%       {timeout}

-module(zab).

-include("zab_log.hrl").

%% ====================================================================
%% API functions
%% ====================================================================
-export([start/1]).

%% ====================================================================
%% Internal functions
%% ====================================================================

start(N) ->
  ServerList = start(N, []),
  ?LOG("All servers started."),
  ok = check_all_candidates(sets:from_list(ServerList), ServerList),
  ?LOG("Server list updated in all servers."),
  timer:sleep(1000),
  check_performance(write, ServerList, 1),
  check_performance(read, ServerList, 1).

start(N, List) ->
  if (N == 0) -> List;
     (N > 0) -> start(N-1, [spawn (zab_candidate, start, []) | List])
  end.

%% ====================================================================
%% Internal functions
%% ====================================================================

check_all_candidates( _ , []) ->
  ok;
check_all_candidates(ServerSet, Remaining) ->
  [Server | Rest ] = Remaining,
  ok = check_loop(Server, ServerSet),
  check_all_candidates(ServerSet, Rest).

check_loop(Server, ServerSet) ->
  Server ! {ready, ServerSet, self()},
  receive
    ok ->
      ?LOG("Server is up."),
      ok;
    nok ->
      ?LOG("Server is not up."),
      timer:sleep(1000),
      check_loop(Server, ServerSet)
  after (2000) ->
    ?LOG("One initial candidate down."),
    nok
  end.

check_performance( _ , _ , 0) ->
  ok;
check_performance( Op , ServerList, N) ->
  check_performance_loop(Op, ServerList),
  check_performance(Op, ServerList, N-1).

check_performance_loop( _ , []) ->
  ok;
check_performance_loop(Op, ServerList) ->
  [ Server | Rest ] = ServerList,
  case Op of
    write -> 
      Data = {root, [{app1, [{node1, []}, {node2, []}]}, {app2, [{node3, []}, {node4, []}]}]},
      write_loop(Server, Data);
    read ->
      read_loop(Server)
  end,
  check_performance_loop(Op, Rest).

write_loop(Server, Data) ->
  Server ! {writeData, Data, self()},
  receive
  busy ->
    timer:sleep(1000),
    write_loop(Server, Data);
  ok ->
    ok
  end.

read_loop(Server) ->
  Server ! {readData, self()},
  receive
    busy ->
      timer:sleep(1000),
      read_loop(Server);
    _ ->
      ok
  end.
