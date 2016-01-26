%% Zab protocol messaging definitions

-define(REQUEST, 1).
-define(PROPOSAL, 2).
-define(ACK, 3).
-define(COMMIT, 4).
-define(PING, 5).
-define(REVALIDATE, 6).
-define(SYNC, 7).
-define(INFORM, 8).
-define(NEWLEADER, 10).
-define(FOLLOWERINFO, 11).
-define(UPTODATE, 12).
-define(DIFF, 13).
-define(TRUNC, 14).
-define(SNAP, 15).
-define(OBSERVERINFO, 16).
-define(LEADERINFO, 17).
-define(ACKEPOCH, 18).

%% Definitions for messages used in the test program

-define(WRITEDATA, 7701).
-define(READDATA, 7702).

