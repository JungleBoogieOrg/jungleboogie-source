%% @author german
%% @doc @todo Add description to jb_test.


-module(jb_server_test).

-include("jb_log.hrl").
-include("jb_records.hrl").
-include("jb_fsm_state.hrl").
-include_lib("eunit/include/eunit.hrl").

%% ====================================================================
%% API functions
%% ====================================================================
-export([start/0, start/1, start_one/2]).

-spec start() -> Result when
    Result :: atom().

start() ->
    random:seed(erlang:now()),
    N = random:uniform(10),
    ?INFO("Starting test with ~p servers.", N),
    start(N).

-spec start(N :: non_neg_integer()) -> Result when
	Result :: atom().

start(N) ->
    PidList = start_n_servers(N),
    ?INFO("All servers started."),
    broadcast_get_status(PidList), 
    loop_wait_for_end(PidList, [], stop_servers, undefined, N*N).

start_one(Sid, NPeers) ->
    ServerList = create_peer_list(37777 + NPeers, NPeers, []),
    ?INFO("Starting server ~p with these ~p servers.", Sid, ServerList),
    jb_server_sup:start_link({Sid, ServerList, 200, 10, 3}).

%% ====================================================================
%% Internal functions
%% ====================================================================

create_peer_list( _ , 0, List) ->
    List;
create_peer_list(Port, N, List) ->
    create_peer_list(Port - 1, N - 1, [{N, {{127,0,0,1}, Port-10000, Port}} | List]).

broadcast_get_status(PidList) ->
    MyPid = self(),
    lists:foreach(fun({_Pid, Sid}) -> gen_fsm:send_all_state_event({global, {jb_server_fsm, Sid}}, {get_status, MyPid}) end, PidList).

loop_wait_for_end(PidList, ElectionFinishedList, Stop, LeaderVote, NTotalTimeouts) ->
    NFSMs = length(PidList),
    ?INFO("~p servers.", NFSMs),
    case length(ElectionFinishedList) of 
        NFSMs when (Stop =:= no_stop) ->
            ?INFO("Election Finished.");
        NFSMs when (Stop =:= stop_servers) ->
            ?INFO("Election Finished. Supervisors killed."),
            lists:foreach(fun({Pid, _Sid}) -> Pid ! stop_server end, PidList),
            lists:foreach(fun({_Pid, Sid}) -> loop_until_sup_stops(Sid) end, PidList);
        _ ->
            receive
                {res_status, StateName, StateData} ->
                    FSMSid = StateData#state.myvote#vote.sid,
                    if
                        (StateName =:= leading) or (StateName =:= following)-> 
                            ?INFO("Election Finished for ~p.", FSMSid),
                            loop_wait_for_end(PidList, lists:keystore(FSMSid, 1, ElectionFinishedList, {FSMSid}), Stop, StateData#state.leader_vote, NTotalTimeouts);
                        true -> 
                            ?INFO("Election ongoing for ~p. state ~p.", FSMSid, StateName),
                            loop_wait_for_end(PidList, ElectionFinishedList, Stop, LeaderVote, NTotalTimeouts)
                    end
            after 500 ->
                    case NTotalTimeouts of 
                        0 ->
                            lists:foreach(fun({Pid, _Sid}) -> exit(Pid, fle_test_timeout) end, PidList),
                            exit(fle_test_timeout);
                        _ ->
                            ?INFO("Timeout. Sending broadcast again."),
                            broadcast_get_status(PidList), 
                            loop_wait_for_end(PidList, ElectionFinishedList, Stop, LeaderVote, NTotalTimeouts-1)
                    end
            end
    end.

start_server(Sid, ServerList) ->
    jb_server_sup:start_link({Sid, ServerList, 200, 10, 3}),
    receive stop_server -> ok end.

start_n_servers(N) ->
    ServerList = create_peer_list(38887 + N, N, []),
    ?INFO("These ~p servers.", ServerList),
    random:seed(erlang:now()),
    lists:foldr(fun({Sid, _Port}, PidList) -> 
                ?INFO("Launching ~p, ~p.", Sid, _Port), 
                Pid = spawn(fun() -> start_server(Sid, ServerList) end),
                [{Pid, Sid} | PidList] end, [], ServerList).

start_conn_sup(Sid, Origin) ->
    jb_txn_out_conn_sup:start_link(Sid),
    Origin ! go,
    receive stop_server -> ok end.

fle_join_established_quorum_test() ->
    NPeers = 3,
    ServerList = create_peer_list(38887 + NPeers, NPeers, []),
    Pid1 = spawn(fun() -> start_server(1, ServerList) end),
    Pid2 = spawn(fun() -> start_server(2, ServerList) end),
    loop_wait_for_end([{Pid1, 1},{Pid2,2}], [], no_stop, undefined, 20),
    Pid3 = spawn(fun() -> start_server(3, ServerList) end),
    loop_wait_for_end([{Pid1, 1},{Pid2,2},{Pid3,3}], [], stop_servers, undefined, 20),
    ok.

fle_one_missing_test() ->
    NPeers = 3,
    ServerList = create_peer_list(38887 + NPeers, NPeers, []),
    Pid1 = spawn(fun() -> start_server(1, ServerList) end),
    Pid2 = spawn(fun() -> start_server(2, ServerList) end),
    loop_wait_for_end([{Pid1, 1},{Pid2,2}], [], stop_servers, undefined, 20).

fle_join_with_new_epoch_test() ->
    NPeers = 4,
    ServerList = create_peer_list(38887 + NPeers, NPeers, []),
    Pid1 = spawn(fun() -> start_server(1, ServerList) end),
    Pid2 = spawn(fun() -> start_server(2, ServerList) end),
    Pid3 = spawn(fun() -> start_server(3, ServerList) end),
    loop_wait_for_end([{Pid1, 1},{Pid2,2},{Pid3,3}], [], no_stop, undefined, 20),
    Pid1 ! stop_server,
    loop_until_sup_stops(1),
    Pid1bis = spawn(fun() -> start_server(1, ServerList) end),
    loop_wait_for_end([{Pid1bis, 1},{Pid2,2},{Pid3,3}], [], no_stop, undefined, 20),
    Pid4 = spawn(fun() -> start_server(4, ServerList) end),
    loop_wait_for_end([{Pid1bis, 1},{Pid2,2},{Pid3,3},{Pid4,4}], [], stop_servers, undefined, 20),
    ok.

loop_until_sup_stops(Sid) ->
    SupPid = global:whereis_name({jb_server_sup, Sid}),
    FsmPid = global:whereis_name({jb_server_fsm, Sid}),
    OutConns1Pid = global:whereis_name({jb_txn_out_conn_sup, Sid}),
    OutConns2Pid = global:whereis_name({jb_fle_out_conn_sup, Sid}),
    InConns1Pid = global:whereis_name({jb_in_conn_sup, jb_txn_conn, Sid}),
    InConns2Pid = global:whereis_name({jb_in_conn_sup, jb_fle_conn, Sid}),
    case {SupPid,FsmPid,OutConns1Pid,OutConns2Pid,InConns1Pid,InConns2Pid} of
        {undefined,undefined,undefined,undefined,undefined,undefined} ->
            ok;
        _ ->
            timer:sleep(10),
            loop_until_sup_stops(Sid)
    end.

fle_one_restart_test() ->
    NPeers = 3,
    ServerList = create_peer_list(38887 + NPeers, NPeers, []),
    Pid1 = spawn(fun() -> start_server(1, ServerList) end),
    Pid2 = spawn(fun() -> start_server(2, ServerList) end),
    Pid3 = spawn(fun() -> start_server(3, ServerList) end),
    loop_wait_for_end([{Pid1,1},{Pid2,2},{Pid3,3}], [], no_stop, undefined, 20),
    Pid1 ! stop_server,
    loop_until_sup_stops(1),
    Pid1bis = spawn(fun() -> start_server(1, ServerList) end),
    loop_wait_for_end([{Pid1bis,1},{Pid2,2},{Pid3,3}], [], stop_servers, undefined, 20),
    ok.

fle_round_of_restarting_one_test_() ->
    {timeout, 10, fun() -> fle_round_of_restarting_one_test_impl() end}.

fle_round_of_restarting_one_test_impl() ->
    NPeers = 3,
    ServerList = create_peer_list(38887 + NPeers, NPeers, []),
    Pid1 = spawn(fun() -> start_server(1, ServerList) end),
    Pid2 = spawn(fun() -> start_server(2, ServerList) end),
    Pid3 = spawn(fun() -> start_server(3, ServerList) end),
    loop_wait_for_end([{Pid1,1},{Pid2,2},{Pid3,3}], [], no_stop, undefined, 20),
    ?INFO("First election of fle_round_of_restarting_one_test finished."),
    Pid1 ! stop_server,
    loop_until_sup_stops(1),
    ?INFO("Supervisor 1 killed."),
    Pid1bis = spawn(fun() -> start_server(1, ServerList) end),
    loop_wait_for_end([{Pid1bis,1},{Pid2,2},{Pid3,3}], [], no_stop, undefined, 20),
    ?INFO("Second election of fle_round_of_restarting_one_test finished."),
    Pid2 ! stop_server,
    loop_until_sup_stops(2),
    ?INFO("Supervisor 2 killed."),
    Pid2bis = spawn(fun() -> start_server(2, ServerList) end),
    loop_wait_for_end([{Pid1bis,1},{Pid2bis,2},{Pid3,3}], [], no_stop, undefined, 20),
    ?INFO("Third election of fle_round_of_restarting_one_test finished."),
    Pid3 ! stop_server,
    loop_until_sup_stops(3),
    ?INFO("Supervisor 3 killed."),
    Pid3bis = spawn(fun() -> start_server(3, ServerList) end),
    loop_wait_for_end([{Pid1bis,1},{Pid2bis,2},{Pid3bis,3}], [], stop_servers, undefined, 20),
    ?INFO("Fourth election of fle_round_of_restarting_one_test finished."),
    ok.

fle_round_of_restarting_two_test_() ->
    {timeout, 15, fun() -> fle_round_of_restarting_two_test_impl() end}.

fle_round_of_restarting_two_test_impl() ->
    NPeers = 3,
    ServerList = create_peer_list(38887 + NPeers, NPeers, []),
    Pid1 = spawn(fun() -> start_server(1, ServerList) end),
    Pid2 = spawn(fun() -> start_server(2, ServerList) end),
    Pid3 = spawn(fun() -> start_server(3, ServerList) end),
    loop_wait_for_end([{Pid1,1},{Pid2,2},{Pid3,3}], [], no_stop, undefined, 20),
    Pid1 ! stop_server,
    Pid2 ! stop_server,
    loop_until_sup_stops(1),
    loop_until_sup_stops(2),
    Pid1bis = spawn(fun() -> start_server(1, ServerList) end),
    Pid2bis = spawn(fun() -> start_server(2, ServerList) end),
    loop_wait_for_end([{Pid1bis,1},{Pid2bis,2},{Pid3,3}], [], no_stop, undefined, 20),
    Pid2bis ! stop_server,
    Pid3 ! stop_server,
    loop_until_sup_stops(3),
    loop_until_sup_stops(2),
    Pid2bisbis = spawn(fun() -> start_server(2, ServerList) end),
    Pid3bis = spawn(fun() -> start_server(3, ServerList) end),
    loop_wait_for_end([{Pid1bis,1},{Pid2bisbis,2},{Pid3bis,3}], [], stop_servers, undefined, 20),
    ok.

txn_connect_to_leader_test() ->
    NPeers = 3,
    ServerList = create_peer_list(38887 + NPeers, NPeers, []),
    Pid1 = spawn(fun() -> start_server(1, ServerList) end),
    Pid2 = spawn(fun() -> start_server(2, ServerList) end),
    loop_wait_for_end([{Pid1, 1},{Pid2,2}], [], no_stop, undefined, 20),
    MyPid = self(),
    Pid_sup = spawn(fun() -> start_conn_sup(3, MyPid) end),
    receive 
        go ->
            jb_txn_out_conn_sup:start_conn(?MODULE, self(), 3, {{127,0,0,1}, 27777}, 3, 2000, 2),
            Pid_sup ! stop_server,
            loop_wait_for_end([{Pid1, 1},{Pid2,2}], [], stop_servers, undefined, 20)
    end,
    ok.

fle_test_() ->
    [{timeout, N*N, fun() -> start(N) end} || N <- lists:seq(2,9)].

