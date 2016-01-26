
% This MACROs are used to optionally log as much activity as possible
% They are here also as an example of the WETT coding practice

-define(ERROR(X),io:format(standard_error, "ERROR {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE])).
-define(ERROR(X,Y),io:format(standard_error, "ERROR {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE,Y])).
-define(ERROR(X,Y,Z),io:format(standard_error, "ERROR {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE,Y,Z])).
-define(ERROR(X,Y,Z,W),io:format(standard_error, "ERROR {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE,Y,Z,W])).
-define(ERROR(X,Y,Z,W,V),io:format(standard_error, "ERROR {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE,Y,Z,W,V])).
-define(ERROR(X,Y,Z,W,V,U),io:format(standard_error, "ERROR {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE,Y,Z,W,V,U])).
-define(ERROR(X,Y,Z,W,V,U,T),io:format(standard_error, "ERROR {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE,Y,Z,W,V,U,T])).
-define(ERROR(X,Y,Z,W,V,U,T,S),io:format(standard_error, "ERROR {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE,Y,Z,W,V,U,T,S])).

%%-define(log_debug, true).
-ifdef(log_debug).
-define(DEBUG(X),io:format("DEBUG {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE])).
-define(DEBUG(X,Y),io:format("DEBUG {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE,Y])).
-define(DEBUG(X,Y,Z),io:format("DEBUG {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE,Y,Z])).
-define(DEBUG(X,Y,Z,W),io:format("DEBUG {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE,Y,Z,W])).
-define(DEBUG(X,Y,Z,W,V),io:format("DEBUG {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE,Y,Z,W,V])).
-define(DEBUG(X,Y,Z,W,V,U),io:format("DEBUG {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE,Y,Z,W,V,U])).
-define(DEBUG(X,Y,Z,W,V,U,T),io:format("DEBUG {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE,Y,Z,W,V,U,T])).
-define(DEBUG(X,Y,Z,W,V,U,T,S),io:format("DEBUG {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE,Y,Z,W,V,U,T,S])).
-else.
-define(DEBUG(X),true).
-define(DEBUG(X,Y),true).
-define(DEBUG(X,Y,Z),true).
-define(DEBUG(X,Y,Z,W),true).
-define(DEBUG(X,Y,Z,W,V,U),true).
-define(DEBUG(X,Y,Z,W,V,U,T),true).
-define(DEBUG(X,Y,Z,W,V,U,T,S),true).
-endif.

%%-define(log_info, true).
-ifdef(log_info).
-define(INFO(X),io:format("INFO  {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE])).
-define(INFO(X,Y),io:format("INFO  {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE,Y])).
-define(INFO(X,Y,Z),io:format("INFO  {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE,Y,Z])).
-define(INFO(X,Y,Z,W),io:format("INFO  {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE,Y,Z,W])).
-define(INFO(X,Y,Z,W,V),io:format("INFO  {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE,Y,Z,W,V])).
-define(INFO(X,Y,Z,W,V,U),io:format("INFO  {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE,Y,Z,W,V,U])).
-define(INFO(X,Y,Z,W,V,U,T),io:format("INFO  {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE,Y,Z,W,V,U,T])).
-else.
-define(INFO(X),true).
-define(INFO(X,Y),true).
-define(INFO(X,Y,Z),true).
-define(INFO(X,Y,Z,W),true).
-define(INFO(X,Y,Z,W,V),true).
-define(INFO(X,Y,Z,W,V,U),true).
-define(INFO(X,Y,Z,W,V,U,T),true).
-endif.

%%-define(log_trace, true).
-ifdef(log_trace).
-define(TRACE(X),io:format("TRACE {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE])).
-define(TRACE(X,Y),io:format("TRACE {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE,Y])).
-define(TRACE(X,Y,Z),io:format("TRACE {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE,Y,Z])).
-define(TRACE(X,Y,Z,W),io:format("TRACE {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE,Y,Z,W])).
-define(TRACE(X,Y,Z,W,V),io:format("TRACE {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE,Y,Z,W,V])).
-define(TRACE(X,Y,Z,W,V,U),io:format("TRACE {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE,Y,Z,W,V,U])).
-define(TRACE(X,Y,Z,W,V,U,T),io:format("TRACE {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE,Y,Z,W,V,U,T])).
-else.
-define(TRACE(X),true).
-define(TRACE(X,Y),true).
-define(TRACE(X,Y,Z),true).
-define(TRACE(X,Y,Z,W),true).
-define(TRACE(X,Y,Z,W,V),true).
-define(TRACE(X,Y,Z,W,V,U),true).
-define(TRACE(X,Y,Z,W,V,U,T),true).
-endif.

%%-define(log_warn, true).
-ifdef(log_warn).
-define(WARN(X),io:format("WARN  {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE])).
-define(WARN(X,Y),io:format("WARN  {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE,Y])).
-define(WARN(X,Y,Z),io:format("WARN  {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE,Y,Z])).
-define(WARN(X,Y,Z,W),io:format("WARN  {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE,Y,Z,W])).
-define(WARN(X,Y,Z,W,V),io:format("WARN  {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE,Y,Z,W,V])).
-define(WARN(X,Y,Z,W,V,U),io:format("WARN  {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE,Y,Z,W,V,U])).
-define(WARN(X,Y,Z,W,V,U,T),io:format("WARN  {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE,Y,Z,W,V,U,T])).
-else.
-define(WARN(X),true).
-define(WARN(X,Y),true).
-define(WARN(X,Y,Z),true).
-define(WARN(X,Y,Z,W),true).
-define(WARN(X,Y,Z,W,V),true).
-define(WARN(X,Y,Z,W,V,U),true).
-define(WARN(X,Y,Z,W,V,U,T),true).
-endif.

%%-define(log_msgs, true).
-ifdef(log_msgs).
-define(LMSG(X),io:format("LMSG  {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE])).
-define(LMSG(X,Y),io:format("LMSG  {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE,Y])).
-define(LMSG(X,Y,Z),io:format("LMSG  {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE,Y,Z])).
-define(LMSG(X,Y,Z,W),io:format("LMSG  {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE,Y,Z,W])).
-define(LMSG(X,Y,Z,W,V),io:format("LMSG  {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE,Y,Z,W,V])).
-define(LMSG(X,Y,Z,W,V,U),io:format("LMSG  {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE,Y,Z,W,V,U])).
-define(LMSG(X,Y,Z,W,V,U,T),io:format("LMSG  {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE,Y,Z,W,V,U,T])).
-define(LMSG(X,Y,Z,W,V,U,T,S),io:format("LMSG  {~p,~p,~p,~p}: "++X++"~n",[self(),erlang:time(),?MODULE,?LINE,Y,Z,W,V,U,T,S])).
-else.
-define(LMSG(X),true).
-define(LMSG(X,Y),true).
-define(LMSG(X,Y,Z),true).
-define(LMSG(X,Y,Z,W),true).
-define(LMSG(X,Y,Z,W,V,U),true).
-define(LMSG(X,Y,Z,W,V,U,T),true).
-define(LMSG(X,Y,Z,W,V,U,T,S),true).
-endif.

