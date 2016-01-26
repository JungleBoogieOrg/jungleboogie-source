%% @author german
%% @doc @todo Add description to jb_test.


-module(jb_txn_conn_test).

-include("jb_log.hrl").
-include("jb_msgs.hrl").
-include("jb_records.hrl").
-include("org_apache_zookeeper_server_quorum.hrl").
-include("org_apache_zookeeper_data.hrl").
-include_lib("eunit/include/eunit.hrl").

%% ====================================================================
%% API functions
%% ====================================================================
-export([start/0, process_txn_link/3, process_txn_unlink/3, process_txn_msg/2]).

-spec start() -> Result when
    Result :: atom().

start() ->
    txn_conn_1_test().

process_txn_link(Name, Sid, Pid) ->
    Name ! {txn_link, Sid, Pid}.

process_txn_unlink(_Name, _Sid, _Pid) ->
    ok.

process_txn_msg(Name, Msg) ->
    Name ! Msg.

%% ====================================================================
%% Internal functions
%% ====================================================================

txn_conn_1_test() ->
    {ok, ListenSocket} = gen_tcp:listen(7777, [{active,once}, {packet,line}, {reuseaddr, true}, {ip, {127,0,0,1}}]),
    {ok, RecPid} = gen_server:start({local,rcvr},jb_txn_conn,{?MODULE,self(),1,ListenSocket,5000, 1},[]),
    {ok, SndPid} = gen_server:start({local,sndr},jb_txn_conn,{?MODULE,self(),2,{{127,0,0,1},7777},1,5000, 1},[]),
    receive 
        {txn_link, 1, LeaderPid} -> 
            ?INFO("First link received."),
            jb_txn_conn:send_quorum_packet(LeaderPid, {followerinfo, 0, 0}),
            jb_txn_conn:send_quorum_packet(LeaderPid, {ack, 0, 0})
    end,
    receive
        {txn_link, 2, _FollowerPid} ->
            ?INFO("Second link received.")
    end,
    receive
        {ack, 0, 0, 2} -> 
            ?INFO("ACK received.")
    end,
    exit(RecPid, shutdown),
    exit(SndPid, shutdown).
