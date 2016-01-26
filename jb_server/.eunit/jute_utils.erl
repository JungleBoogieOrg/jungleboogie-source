%% Author: ecejmtr
%% Created: 27/02/2013
%% Description: TODO: Add description to jute_utils
-module(jute_utils).

%%
%% Include files
%%

-include("zkdefs.hrl").
-include("jb_records.hrl").
-include("jb_log.hrl").
-include("org_apache_zookeeper_server_quorum.hrl").
-include("org_apache_zookeeper_data.hrl").

%%
%% Exported Functions
%%
-export([read_int/1, read_long/1, read_boolean/1,
		 read_buffer/1, read_vector/2, read_ustring/1,
		 write_int/1, write_long/1, write_boolean/1,
		 write_buffer/1, write_vector/2, write_ustring/1,
		 fold_test/0, read_Notification/1, write_Notification/1,
         tcp_read_QuorumPacket/2, tcp_read_vector/3, tcp_read_snapshot/2,
         tcp_read_ustring/2, tcp_read_vecelem/5, tcp_read_Id/2]).

%%
%% API Functions
%%


write_int(N) when is_integer(N) ->
	<<N:32/integer>>.
write_long(N) when is_integer(N) ->
	<<N:64/integer>>.
write_boolean(true) ->
	<<1:8/integer>>;
write_boolean(false) ->
	<<0:8/integer>>.
write_buffer(<<B/binary>>) ->
	S = size(B),
	<<S:32/integer, B/binary>>.
write_ustring(S) when is_list(S) ->
	L = length(S),
	B = list_to_binary(S),
	<<L:32/integer, B/binary>>.
write_vector(L, TypeFun) ->
	Len = length(L),
    case Len of
        0 ->
            <<255,255,255,255>>;
        _ ->
            lists:foldl(fun(E,A) -> NewB = TypeFun(E), <<A/binary, NewB/binary>> end, <<Len:32/integer>>, L)
    end.
%% read_vecelem(<<B/binary>>, _, 0, List) ->
%% 	{List, B};
%% read_vecelem(<<B/binary>>, TypeFun, L, List) ->
%% 	{Elem, Rest} = TypeFun(B),
%% 	read_vecelem(Rest, TypeFun, L-1, List ++ [Elem]).



read_int(<<I:32/integer, B/binary>>) ->
	{I, B}.

read_long(<<I:64/integer, B/binary>>) ->
	{I, B}.

read_boolean(<<0:8/integer, B/binary>>) ->
	{false, B};
read_boolean(<<1:8/integer, B/binary>>) ->
	{true, B};
read_boolean(<<I:8/integer, _/binary>>) ->
	{error, {not_boolean, I}}.

read_buffer(<<L:32/integer, B/binary>>) ->
	<<Bin:L/binary, Rest/binary>> = B,
	{Bin, Rest}.

read_vector(<<255, 255, 255, 255, Rest/binary>>, _TypeFun) ->
	{[], Rest};
read_vector(<<L:32/integer, B/binary>>, TypeFun) ->
	read_vecelem(<<B/binary>>, TypeFun, L, []).
read_vecelem(<<B/binary>>, _, 0, List) ->
	{List, B};
read_vecelem(<<B/binary>>, TypeFun, L, List) ->
	{Elem, Rest} = TypeFun(B),
	read_vecelem(Rest, TypeFun, L-1, List ++ [Elem]).

read_ustring(<<L:32/integer, B/binary>>) ->
	<<Bin:L/binary, Rest/binary>> = B,
	{binary_to_list(Bin), Rest}.

%% "Manual" parsers

write_Notification(Notification) ->
    NSt = case Notification#notification.state of
        looking -> 0; following -> 1; leading -> 2; observing -> 3
    end,
    NSi = Notification#notification.vote#vote.sid,
    NZ = Notification#notification.vote#vote.zxid,
    NE = Notification#notification.vote#vote.epoch,
    NEE = Notification#notification.election_epoch,
    <<36:32/integer, NSt:32/integer, NSi:64/integer, NZ:64/integer, NE:64/integer, NEE:64/integer>>.

read_Notification(<<36:32/integer, SI:32/integer, NSi:64/integer, NZ:64/integer, NE:64/integer, NEE:64/integer>>) ->
    NSt = case SI of
        0 -> looking; 1 -> following; 2 -> leading; 3 -> observing
    end,
    #notification{vote = #vote{sid = NSi, zxid = NZ, epoch = NE}, election_epoch = NEE, state = NSt}.

tcp_read_QuorumPacket2(Socket, Vtype, Vzxid, L, TimeOut) ->
    Recv = case L of
        <<255, 255, 255, 255>> ->
            {ok, undefined};
        <<0:32/integer>> ->
            {ok, <<>>};
        <<Len:32/integer>> ->
            gen_tcp:recv(Socket, Len, TimeOut)
    end,
    case Recv of
        {ok, Vdata} ->
            case tcp_read_vector(Socket, fun()-> tcp_read_Id(Socket, TimeOut) end, TimeOut) of
                {ok, Vauthinfo} ->
                    {ok, #'QuorumPacket'{type = Vtype, zxid = Vzxid, data = Vdata, authinfo = Vauthinfo}};
                Error2 ->
                    Error2
            end;
        Error3 ->
            Error3
    end.

tcp_read_QuorumPacket(Socket, TimeOut) ->
    case gen_tcp:recv(Socket, 16, TimeOut) of
        {ok, <<Vtype:32/integer, Vzxid:64/integer, L/binary>>} ->
            tcp_read_QuorumPacket2(Socket, Vtype, Vzxid, L, TimeOut);
        Error ->
            Error
    end.

tcp_read_vector(Socket, TypeFun, TimeOut) ->
    case gen_tcp:recv(Socket, 4, TimeOut) of
        {ok, Data} ->
            case Data of
                <<255, 255, 255, 255>> ->
                    {ok, []};
                <<L:32/integer>> ->
                    tcp_read_vecelem(Socket, TypeFun, L, [], TimeOut)
            end;
        Error ->
            Error
    end.

tcp_read_vecelem(_Socket, _, 0, List, _TimeOut) ->
    {ok, List};
tcp_read_vecelem(Socket, TypeFun, L, List, TimeOut) ->
    case TypeFun() of
        {ok, Elem} ->
            tcp_read_vecelem(Socket, TypeFun, L-1, List ++ [Elem], TimeOut);
        Error ->
            Error
    end.

tcp_read_ustring(Socket, TimeOut) ->
    case gen_tcp:recv(Socket, 4, TimeOut) of
        {ok, <<L:32/integer>>} ->
            case L of
                0 ->
                    {ok, ""};
                _ ->
                    case gen_tcp:recv(Socket, L, TimeOut) of
                        {ok, Bin} ->
                            {ok, binary_to_list(Bin)};
                        Error ->
                            Error
                    end
            end;
        Error ->
            Error
    end.

tcp_read_buffer(Socket, TimeOut) ->
    case gen_tcp:recv(Socket, 4, TimeOut) of
        {ok, <<L:32/integer>>} ->
            case L of
                0 ->
                    {ok, <<>>};
                _ ->
                    gen_tcp:recv(Socket, L, TimeOut)
            end;
        Error ->
            Error
    end.

tcp_read_Id(Socket, TimeOut) ->
    case tcp_read_ustring(Socket, TimeOut) of
        {ok, Vscheme} ->
            case tcp_read_ustring(Socket, TimeOut) of
                {ok, Vid} ->
                    #'Id'{scheme = Vscheme, id = Vid};
                Error ->
                    Error
            end;
        Error ->
            Error
    end.

tcp_read_ACL(Socket, TimeOut) ->
    case gen_tcp:recv(Socket, 4, TimeOut) of
        {ok, <<Vperms:32/integer>>} ->
            case tcp_read_Id(Socket, TimeOut) of
                {ok, Vid} ->
                    #'ACL'{perms = Vperms, id = Vid};
                Error ->
                    Error
            end;
        Error ->
            Error
    end.

tcp_read_acelem(Socket, TimeOut) ->
    case gen_tcp:recv(Socket, 8, TimeOut) of
        {ok, <<Key:64/integer>>} ->
            tcp_read_vector(Socket, fun() -> tcp_read_ACL(Socket, TimeOut) end, TimeOut);
        Error ->
            Error
    end.

fold_read_acelem_fun(Socket, TimeOut, Acc) ->
    case Acc of
        {ok, L} ->
            case tcp_read_acelem(Socket, TimeOut) of
                {ok, E} ->
                    {ok, [E | L]};
                Error ->
                    Error
            end;
        Error ->
            Error
    end.

tcp_read_acl_list(Socket, TimeOut) ->
    case gen_tcp:recv(Socket, 4, TimeOut) of
        {ok, <<MapSize:32/integer>>} ->
            case MapSize of
                0 ->
                    {ok, ok};
                _ ->
                    lists:foldl(fun(_, Acc) -> fold_read_acelem_fun(Socket, TimeOut, Acc) end, [], lists:seq(1, MapSize))
            end;
        Error ->
            Error
    end.

tcp_read_StatPersisted(Socket, TimeOut) ->
    gen_tcp:recv(Socket, 60, TimeOut).

tcp_read_node_record(Socket, TimeOut) ->
    case tcp_read_buffer(Socket, TimeOut) of
        {ok, _ } ->
            case gen_tcp:recv(Socket, 8, TimeOut) of 
                {ok, _ } ->
                    tcp_read_StatPersisted(Socket, TimeOut);
                Error ->
                    Error
            end;
        Error ->
            Error
    end.

tcp_read_datanode(Socket, Path, TimeOut) ->
    case Path of
        "/" -> 
            {ok, ok};
        _ -> 
            case tcp_read_node_record(Socket, TimeOut) of
                {ok, _ } ->
                    case tcp_read_ustring(Socket, TimeOut) of
                        {ok, NewPath} ->
                            tcp_read_datanode(Socket, NewPath, TimeOut);
                        Error ->
                            Error
                    end;
                Error2 ->
                    Error2
            end
    end.

tcp_read_datatree(Socket, TimeOut) ->
    case tcp_read_acl_list(Socket, TimeOut) of
        {ok, _ } ->
            case tcp_read_ustring(Socket, TimeOut) of
                {ok, Path} ->
                    tcp_read_datanode(Socket, Path, TimeOut);
                Error ->
                    Error
            end;
        Error2 ->
            Error2
    end.

tcp_read_snapshot(Socket, TimeOut) ->
    case gen_tcp:recv(Socket, 4, TimeOut) of
        {ok, <<Count:32/integer>>} ->
            case Count of
                0 ->
                    ok;
                _ ->
                    %% TODO: parse sessions
                    case gen_tcp:recv(Socket, (Count * (4 + 8)), TimeOut) of
                        {ok, Sessions} ->
                            tcp_read_datatree(Socket, TimeOut);
                        Error ->
                            Error
                    end
            end;
        Error2 ->
            Error2
    end.
  
%%
%% Local Functions
%%

fold_test() ->
	B = <<0,0,0,7,1,0,0,0,4,1,0,0,1>>,
	Fun = fun(Elem, {ItemList, <<Binary/binary>>}) -> {Item, Rest} = Elem(Binary), {ItemList ++ [Item], Rest} end,
	Acc0 = {[], B},
	List = [fun read_int/1,
			fun read_boolean/1,
			fun (X) -> read_vector(X, fun read_boolean/1) end],
	lists:foldl(Fun, Acc0, List).
