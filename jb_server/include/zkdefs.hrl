-define(NOTIFICATION, 0).
-define(CREATE, 1).
-define(DELETE, 2).
-define(EXISTS, 3).
-define(GET_DATA, 4).
-define(SET_DATA, 5).
-define(GET_ACL, 6).
-define(SET_ACL, 7).
-define(GET_CHILDREN, 8).
-define(SYNC, 9).
-define(PING, 11).
-define(GET_CHILDREN_2, 12).
-define(CHECK, 13).
-define(MULTI, 14).
-define(AUTH, 100).
-define(SET_WATCHES, 101).
-define(SASL, 102).
-define(CREATE_SESSION, -10).
-define(CLOSE_SESSION, -11).
-define(ERROR, -1).

-define(PERM_READ, 1 << 0).
-define(PERM_WRITE, 1 << 1).
-define(PERM_CREATE, 1 << 2).
-define(PERM_DELETE, 1 << 3).
-define(PERM_ADMIN, 1 << 4).
-define(PERM_ALL, PERM_READ | PERM_WRITE | PERM_CREATE | PERM_DELETE | PERM_ADMIN).
%%         public final Id ANYONE_ID_UNSAFE = new Id("world", "anyone");
%%         public final Id AUTH_IDS = new Id("auth", "");
%%         public final ArrayList<ACL> OPEN_ACL_UNSAFE = new ArrayList<ACL>(
%%                 Collections.singletonList(new ACL(Perms.ALL, ANYONE_ID_UNSAFE)));
%%         public final ArrayList<ACL> CREATOR_ALL_ACL = new ArrayList<ACL>(
%%                 Collections.singletonList(new ACL(Perms.ALL, AUTH_IDS)));
%%         public final ArrayList<ACL> READ_ACL_UNSAFE = new ArrayList<ACL>(
%%                 Collections
%%                         .singletonList(new ACL(Perms.READ, ANYONE_ID_UNSAFE)));

-record('Notification',
		{state,
		 leader,
		 zxid,
		 epoch}).