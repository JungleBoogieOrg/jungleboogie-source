
% This MACROs are used to optionally log as much activity as possible

-define(debug, true).
-ifdef(debug).
-define(LOG(X), io:format(string:concat(string:concat("{~p,~p}: ", X), "~n"), [?MODULE,?LINE])).
-define(LOG(X,Y), io:format(string:concat(string:concat("{~p,~p}: ", X), "~n"), [?MODULE,?LINE, Y])).
-define(LOG(X,Y,Z), io:format(string:concat(string:concat("{~p,~p}: ", X), "~n"), [?MODULE,?LINE, Y, Z])).
-define(LOG(X,Y,Z,W), io:format(string:concat(string:concat("{~p,~p}: ", X), "~n"), [?MODULE,?LINE, Y, Z, W])).
-define(LOG(X,Y,Z,W,V), io:format(string:concat(string:concat("{~p,~p}: ", X), "~n"), [?MODULE,?LINE, Y, Z, W, V])).
-else.
-define(LOG(X), true).
-define(LOG(X,Y), true).
-define(LOG(X,Y,Z), true).
-define(LOG(X,Y,Z,W), true).
-define(LOG(X,Y,Z,W,V), true).
-endif.