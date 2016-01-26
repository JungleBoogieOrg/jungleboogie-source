%% Author: ECEJMTR
%% Created: 08/05/2013
%% Description: TODO: Add description to jb_store_mnesia
-module(jb_store_mnesia).

%%
%% Include files
%%

-include("jb_store.hrl").

%%
%% Exported Functions
%%
-export([init_store/0, create/4, create_fun/2, split_path/1,
		 delete/2, set_data/2, exists/1]).

%%
%% API Functions
%%

init_store() ->
	mnesia:start(),
	mnesia:create_table(datanodePersistentT, [
    	{attributes, record_info(fields, datanodeR)},
		{record_name, datanodeR}
		% {disc_copies, node()}
											 ]),
	mnesia:create_table(datanodeEphemeralT, [
		{attributes, record_info(fields, datanodeR)},
		{record_name, datanodeR}
											]),
	mnesia:create_table(watcherT, [
		{attributes, record_info(fields, watcherR)},
		{record_name, watcherR}
											]),
	mnesia:create_table(treeT, [
		{attributes, record_info(fields, treeR)},
		{record_name, treeR}
							   ]),
	mnesia:activity(
	  	{transaction, 100},
		fun() ->
			RootNodeT = #treeR{path = "/", children = []},
			RootNodeDP = #datanodeR{path = "/", admindata = #admindataR{version = 0}},
			mnesia:write(treeT, RootNodeT, write),
			mnesia:write(datanodePersistentT, RootNodeDP, write)
		end
	).


reinit_store() ->
	ok.

% EPHEMERAL
% EPHEMERAL_SEQUENTIAL
% PERSISTENT
% PERSISTENT_SEQUENTIAL 

% TODO transient process call

split_path(Path = [$/ | _]) ->
	Pivot = case string:rchr(Path, $/) of
		1 ->
			1;
		N ->
			N-1
	end,
	{string:substr(Path, 1, Pivot), string:substr(Path, Pivot+1)}.

create(Path, Data, _Acl, _CreateMode) ->
	mnesia:activity(
	  	{transaction, 100},
		fun create_fun/2,
		[Path, Data]
	  ).

create_fun(Path, Data) ->
	case mnesia:read(datanodePersistentT, Path, read) of
		[] ->
 			NewAdmin = #admindataR{version = 0},
			NewNodeDP = #datanodeR{path = Path, data = Data, admindata = NewAdmin},
			io:format("~p~n", [element(1, NewNodeDP)]),
			mnesia:write(datanodePersistentT, NewNodeDP, write),
			update_parent_add_fun(Path),
			NewNodeT = #treeR{path = Path, children = []},
			mnesia:write(treeT, NewNodeT, write);	    
		[_Val] ->
			{error, node_exists}
	end.
		
% TODO optimize this
update_parent_add_fun(Path) ->
    {Parent, Child} = split_path(Path),
	io:format("updating... ~p~n", [{Parent, Child}]),
	case mnesia:read(treeT, Parent, read) of
		[] ->
			mnesia:abort(no_parent);
		[Val = #treeR{children = Children}] ->
			mnesia:write(treeT, Val#treeR{children = [Child | Children]}, write)
	end.

delete(Path, Version) ->
	mnesia:activity(
	  	{transaction, 100},
		fun delete_fun/2,
		[Path, Version]
	  ).

delete_fun(Path, _Version) ->
	case mnesia:read(datanodePersistentT, Path, read) of
		[DataVal] ->
			io:format("delete_fun: ~p - ~p~n", [Path, DataVal]),
			case mnesia:read(treeT, Path, read) of
				[] ->
					mnesia:abort(internal_error);
				[TreeVal] ->
					io:format("delete_fun: ~p - ~p~n", [TreeVal, TreeVal#treeR.children]),
					case TreeVal#treeR.children of
						[] ->
							mnesia:delete(datanodePersistentT, Path, write),
							mnesia:delete(treeT, Path, write),
							update_parent_del_fun(Path);
						_ ->
							mnesia:abort(has_children)
					end
			end;
		[] ->
			{error, node_does_not_exist}
	end.

update_parent_del_fun(Path) ->
    {Parent, Child} = split_path(Path),
	case mnesia:read(treeT, Parent, read) of
		[] ->
			mnesia:abort(no_parent);
		[Val = #treeR{children = Children}] ->
			mnesia:write(treeT, Val#treeR{children = lists:delete(Child, Children)}, write)
	end.

set_data(Path, Data) ->
	mnesia:activity(
	  	{transaction, 100},
		fun set_data_fun/2,
		[Path, Data]
	  ).

set_data_fun(Path, Data) ->
	case mnesia:read(datanodePersistentT, Path, read) of
		[Val] ->
			io:format("set_data: ~p~n", [Val]),
			mnesia:write(datanodePersistentT, Val#datanodeR{data = Data}, write);
		[] ->
			{error, node_does_not_exist}
	end.

exists(Path) ->
	mnesia:activity(
	  	{transaction, 100},
		fun exists_fun/1,
		[Path]
	  ).

exists_fun(Path) ->
	case mnesia:read(datanodePersistentT, Path, read) of
		[_Val] ->
 			ok;
		[] ->
			nok
	end.

register(Watcher) ->
	ok.

