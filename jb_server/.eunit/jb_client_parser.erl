%% Author: ECEJMTR
%% Created: 18/02/2013
%% Description: TODO: Add description to jb_client_parser
-module(jb_client_parser).

%%
%% Include files
%%

%%
%% Exported Functions
%%
-export([debug_server/1]).

%%
%% API Functions
%%

debug_server(Port) ->
	gen_fsm:start({local, jb_client_test}, jb_client_fsm, [], []),
	{ok, ListenSocket} = gen_tcp:listen(Port, [binary]),
	case gen_tcp:accept(ListenSocket) of
		{ok,Socket} ->
			read_loop(Socket, <<>>);
		{error, Reason} ->
			io:format("Socket failed: ~p~n", [Reason])
	end.

read_loop(Socket, Rest) ->
	receive
		{tcp, Socket, Data} ->
			io:format("Received binary: ~p~n", [Data]),
			{Msg, NewRest} = jute_utils:read_buffer(<<Rest/binary, Data/binary>>),
			{_EncResp, Response} = gen_fsm:sync_send_event(jb_client_test, {msg, Msg}),
			case Response of
				none ->
					ok;
				B when is_binary(B) ->
					gen_tcp:send(Socket, jute_utils:write_buffer(Response))
			end,
			read_loop(Socket, NewRest);
		{tcp_closed, Socket} ->
			io:format("Socket closed, exiting~n");
		{tcp_error, Socket, Reason} ->
			io:format("Socket error, exiting: ~n~p", [Reason])
	end.
  
  
  


%%
%% Local Functions
%%

