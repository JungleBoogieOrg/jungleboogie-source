%% Author: ecejmtr
%% Created: 22/02/2013
%% Description: TODO: Add description to jute_code_gen
-module(jute_code_gen).

%%
%% Include files
%%

%%
%% Exported Functions
%%
-export([file/1, compose/2]).

%%
%% API Functions
%%

% TODO Move magic strings to defines 

% Module corresponds to module
% Class corresponds to record
% encode/decode functions: get length + consume from a byte array + spit out "rest"

file(ModuleList) when is_list(ModuleList) ->
	_Results = lists:map(fun(Module) -> create_module(Module) end, ModuleList).

replace_mod_dots(ModuleName) ->
	lists:map(fun($.) -> $_; (X) -> X end, ModuleName).
modularize(QualClassName) ->
	case string:rchr(QualClassName, $.) of
		0 ->
			{"", QualClassName};
		1 ->
			{"", QualClassName};
		P ->
			{replace_mod_dots(string:substr(QualClassName, 1, P-1)), string:substr(QualClassName, P+1)}
	end.

create_module({module, {module_name, ModuleName, _}, ModuleBody}) ->
	ModuleNameErl = replace_mod_dots(ModuleName),
	ErlFile = ModuleNameErl ++ ".erl",
	HrlFile = ModuleNameErl ++ ".hrl",
	case {filelib:is_file(ErlFile), filelib:is_file(HrlFile)} of
		{false, false} ->
			{ok, ErlIo} = file:open(ErlFile, [write]),
			{ok, HrlIo} = file:open(HrlFile, [write]),
			write_module(ModuleName, ModuleBody, ErlIo, HrlIo),
			file:close(ErlIo),
			file:close(HrlIo),
		    {module_files, ErlFile, HrlFile};
	    _ ->
		    {error, module_already_exists}
	end.

write_module(ModuleName, ModuleBody, ErlIo, HrlIo) ->
	write_erl(ModuleName, ModuleBody, ErlIo),
	write_hrl(ModuleBody, HrlIo).

%% read_token/1 on binary -> {Token, Rest}

write_erl(ModuleName, ModuleBody, ErlIo) when is_list(ModuleBody)->
	GenFile1 = "-module(" ++ replace_mod_dots(ModuleName) ++ ").~n",
    GenFile2 = GenFile1 ++ "-include(\"" ++ replace_mod_dots(ModuleName) ++".hrl\").~n~n",
	RdClasses = lists:map(fun({class, {class_name, ClassName, _}, AttribList}) -> gen_read(ClassName, AttribList) end, ModuleBody),
	WrClasses = lists:map(fun({class, {class_name, ClassName, _}, AttribList}) -> gen_write(ClassName, AttribList) end, ModuleBody),
	FunNames = lists:map(fun({class, {class_name, ClassName, _},_}) ->
		"read_" ++ ClassName ++ "/1, write_" ++ ClassName ++ "/1" 
		end,
        ModuleBody),
	GenExport = "-export([" ++ compose({"", "         ", ",~n", ""}, FunNames) ++ "]).~n~n",	
    GenFile3 = lists:foldl(fun(E, A) -> A++E end, "", RdClasses),
    GenFile4 = lists:foldl(fun(E, A) -> A++E end, "", WrClasses),
	io:format(ErlIo, GenFile2, []),
	io:format(ErlIo, GenExport, []),
	io:format(ErlIo, GenFile3, []),
	io:format(ErlIo, "~n~n" ++ GenFile4, []).


gen_write(ClassName, AttribList) ->
 	GenRead = "write_" ++ ClassName ++ "(R) when is_record(R, '" ++ ClassName ++ "') ->~n",
	GenLines = lists:foldl(
		fun(Attr, Lines) -> Lines ++ write_attr(ClassName, Attr) end,
		GenRead,
		AttribList),
	compose({GenLines ++ "  <<", "    ", ",~n", ">>.~n~n"},
		lists:map(fun({attrib,_,{type_or_id_name,Name,_}}) ->  
						  "V" ++ Name ++ "/binary" 
				  end, AttribList)).

write_attr(ClassName, Attr = {attrib,_,{type_or_id_name,AttrName,_}}) ->
	write_attr_pref(AttrName) ++ write_attr_fun(Attr, "R#'" ++ ClassName ++ "'." ++ AttrName) ++ ",~n".

write_attr_pref(AttrName) ->
	"  V" ++ AttrName ++ " = ".

write_attr_fun({attrib, C = {class, {class_name, _}},{type_or_id_name,AttrName,_}}, Arg) ->
	gen_wfun(C, Arg);
write_attr_fun({attrib, C = {class, {qual_class_name, _}},{type_or_id_name,AttrName,_}}, Arg) ->
	gen_wfun(C, Arg);
write_attr_fun({attrib, V = {vector, _},{type_or_id_name,AttrName,_}}, Arg) ->
	gen_wfun(V, Arg);
write_attr_fun({attrib,T,{type_or_id_name,AttrName,_}}, Arg) ->
	gen_wfun(T, Arg).


gen_wfun({class, {qual_class_name, Name,_}}, Arg) ->
	{Mod, CName} = modularize(Name),
	Mod ++ ":write_" ++ CName ++ "(" ++ Arg ++ ")";
gen_wfun({class, {class_name, Name,_}}, Arg) ->
	"write_" ++ Name ++ "(" ++ Arg ++ ")";
gen_wfun({vector, OrigType}, Arg) ->
	"jute_utils:write_vector(" ++ Arg ++ ", fun(B)-> " ++ gen_fun(OrigType, "B") ++ " end)";
gen_wfun(Type, Arg) ->
	io_lib:format("jute_utils:write_~p(", [Type]) ++ Arg ++ ")".
	

gen_read(ClassName, AttribList) ->
	GenRead = "read_" ++ ClassName ++ "(<<Binary0/binary>>) ->~n",
	{GenLines, LastN} = lists:foldl(
		fun(Attr, {Lines, N}) -> {Lines ++ read_attr(Attr, N), N+1} end,
		{GenRead, 1},
		AttribList),
	GenLines2 = GenLines ++ "  {#'" ++ ClassName ++ "'{~n  ",
	compose({GenLines2, "  ", ",~n", "}, Binary" ++ integer_to_list(LastN-1) ++ "}.~n~n"},
		lists:map(fun({attrib,_,{type_or_id_name,Name,_}}) ->  
						  Name ++ " = V" ++ Name 
				  end, AttribList)).

read_attr(Attr = {attrib,_,{type_or_id_name,AttrName,_}}, N) ->
	read_attr_pref(AttrName, N) ++ read_attr_fun(Attr, N) ++ ",~n".

read_attr_pref(AttrName, N) ->
	"  {V" ++ AttrName ++ io_lib:format(", Binary~p} = ", [N]).

read_attr_fun({attrib, C = {class, {class_name, _}},_}, N) ->
	gen_fun(C, io_lib:format("Binary~p", [N-1]));
read_attr_fun({attrib, C = {class, {qual_class_name, _}},_}, N) ->
	gen_fun(C, io_lib:format("Binary~p", [N-1]));
read_attr_fun({attrib, V = {vector, _},_}, N) ->
	gen_fun(V, io_lib:format("Binary~p", [N-1]));
read_attr_fun({attrib,T,_}, N) ->
	gen_fun(T, io_lib:format("Binary~p", [N-1])).


gen_fun({class, {qual_class_name, Name,_}}, Arg) ->
	{Mod, CName} = modularize(Name),
	Mod ++ ":read_" ++ CName ++ "(" ++ Arg ++ ")";
gen_fun({class, {class_name, Name,_}}, Arg) ->
	"read_" ++ Name ++ "(" ++ Arg ++ ")";
gen_fun({vector, OrigType}, Arg) ->
	"jute_utils:read_vector(" ++ Arg ++ ", fun(B)-> " ++ gen_fun(OrigType, "B") ++ " end)";
gen_fun(Type, Arg) ->
	io_lib:format("jute_utils:read_~p(", [Type]) ++ Arg ++ ")".



write_hrl(ModuleBody, HrlIo) when is_list(ModuleBody)->
	lists:map(fun({class, {class_name, ClassName, _Line}, AttribList}) -> write_record(ClassName, AttribList, HrlIo) end, ModuleBody).

write_record(ClassName, AttribList, HrlIo) when is_list(AttribList) ->
	io:format(HrlIo, "-record('" ++ ClassName ++ "',~n", []),
	FormattedAttrList = compose({"        {", "         ", ",~n", "})."}, lists:map(fun({attrib,_T,{type_or_id_name,Name,_}}) -> Name end, AttribList)),
	io:format(HrlIo, FormattedAttrList++"~n", []).


compose({Pre, In1, In2, Su}, [Elem|T]) ->
	Pre ++ Elem ++ suf({In2, Su}, T) ++ compose({Pre, In1, In2, Su}, T, not_first).
compose({_Pre, _In1, _In2, _Su}, [], not_first) ->
	"";
compose({Pre, In1, In2, Su}, [Elem|T], not_first) ->
	In1 ++ Elem ++ suf({In2, Su}, T) ++ compose({Pre, In1, In2, Su}, T, not_first).

suf({_In2, Su}, []) ->
	Su;
suf({In2, _Su}, _) ->
	In2.


%%
%% Local Functions
%%



