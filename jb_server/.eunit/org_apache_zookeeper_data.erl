-module(org_apache_zookeeper_data).
-include("org_apache_zookeeper_data.hrl").

-export([read_Id/1, write_Id/1,
         read_ACL/1, write_ACL/1,
         read_Stat/1, write_Stat/1,
         read_StatPersisted/1, write_StatPersisted/1,
         read_StatPersistedV1/1, write_StatPersistedV1/1]).

read_Id(<<Binary0/binary>>) ->
  {Vscheme, Binary1} = jute_utils:read_ustring(Binary0),
  {Vid, Binary2} = jute_utils:read_ustring(Binary1),
  {#'Id'{
  scheme = Vscheme,
  id = Vid}, Binary2}.

read_ACL(<<Binary0/binary>>) ->
  {Vperms, Binary1} = jute_utils:read_int(Binary0),
  {Vid, Binary2} = read_Id(Binary1),
  {#'ACL'{
  perms = Vperms,
  id = Vid}, Binary2}.

read_Stat(<<Binary0/binary>>) ->
  {Vczxid, Binary1} = jute_utils:read_long(Binary0),
  {Vmzxid, Binary2} = jute_utils:read_long(Binary1),
  {Vctime, Binary3} = jute_utils:read_long(Binary2),
  {Vmtime, Binary4} = jute_utils:read_long(Binary3),
  {Vversion, Binary5} = jute_utils:read_int(Binary4),
  {Vcversion, Binary6} = jute_utils:read_int(Binary5),
  {Vaversion, Binary7} = jute_utils:read_int(Binary6),
  {VephemeralOwner, Binary8} = jute_utils:read_long(Binary7),
  {VdataLength, Binary9} = jute_utils:read_int(Binary8),
  {VnumChildren, Binary10} = jute_utils:read_int(Binary9),
  {Vpzxid, Binary11} = jute_utils:read_long(Binary10),
  {#'Stat'{
  czxid = Vczxid,
  mzxid = Vmzxid,
  ctime = Vctime,
  mtime = Vmtime,
  version = Vversion,
  cversion = Vcversion,
  aversion = Vaversion,
  ephemeralOwner = VephemeralOwner,
  dataLength = VdataLength,
  numChildren = VnumChildren,
  pzxid = Vpzxid}, Binary11}.

read_StatPersisted(<<Binary0/binary>>) ->
  {Vczxid, Binary1} = jute_utils:read_long(Binary0),
  {Vmzxid, Binary2} = jute_utils:read_long(Binary1),
  {Vctime, Binary3} = jute_utils:read_long(Binary2),
  {Vmtime, Binary4} = jute_utils:read_long(Binary3),
  {Vversion, Binary5} = jute_utils:read_int(Binary4),
  {Vcversion, Binary6} = jute_utils:read_int(Binary5),
  {Vaversion, Binary7} = jute_utils:read_int(Binary6),
  {VephemeralOwner, Binary8} = jute_utils:read_long(Binary7),
  {Vpzxid, Binary9} = jute_utils:read_long(Binary8),
  {#'StatPersisted'{
  czxid = Vczxid,
  mzxid = Vmzxid,
  ctime = Vctime,
  mtime = Vmtime,
  version = Vversion,
  cversion = Vcversion,
  aversion = Vaversion,
  ephemeralOwner = VephemeralOwner,
  pzxid = Vpzxid}, Binary9}.

read_StatPersistedV1(<<Binary0/binary>>) ->
  {Vczxid, Binary1} = jute_utils:read_long(Binary0),
  {Vmzxid, Binary2} = jute_utils:read_long(Binary1),
  {Vctime, Binary3} = jute_utils:read_long(Binary2),
  {Vmtime, Binary4} = jute_utils:read_long(Binary3),
  {Vversion, Binary5} = jute_utils:read_int(Binary4),
  {Vcversion, Binary6} = jute_utils:read_int(Binary5),
  {Vaversion, Binary7} = jute_utils:read_int(Binary6),
  {VephemeralOwner, Binary8} = jute_utils:read_long(Binary7),
  {#'StatPersistedV1'{
  czxid = Vczxid,
  mzxid = Vmzxid,
  ctime = Vctime,
  mtime = Vmtime,
  version = Vversion,
  cversion = Vcversion,
  aversion = Vaversion,
  ephemeralOwner = VephemeralOwner}, Binary8}.



write_Id(R) when is_record(R, 'Id') ->
  Vscheme = jute_utils:write_ustring(R#'Id'.scheme),
  Vid = jute_utils:write_ustring(R#'Id'.id),
  <<Vscheme/binary,
    Vid/binary>>.

write_ACL(R) when is_record(R, 'ACL') ->
  Vperms = jute_utils:write_int(R#'ACL'.perms),
  Vid = write_Id(R#'ACL'.id),
  <<Vperms/binary,
    Vid/binary>>.

write_Stat(R) when is_record(R, 'Stat') ->
  Vczxid = jute_utils:write_long(R#'Stat'.czxid),
  Vmzxid = jute_utils:write_long(R#'Stat'.mzxid),
  Vctime = jute_utils:write_long(R#'Stat'.ctime),
  Vmtime = jute_utils:write_long(R#'Stat'.mtime),
  Vversion = jute_utils:write_int(R#'Stat'.version),
  Vcversion = jute_utils:write_int(R#'Stat'.cversion),
  Vaversion = jute_utils:write_int(R#'Stat'.aversion),
  VephemeralOwner = jute_utils:write_long(R#'Stat'.ephemeralOwner),
  VdataLength = jute_utils:write_int(R#'Stat'.dataLength),
  VnumChildren = jute_utils:write_int(R#'Stat'.numChildren),
  Vpzxid = jute_utils:write_long(R#'Stat'.pzxid),
  <<Vczxid/binary,
    Vmzxid/binary,
    Vctime/binary,
    Vmtime/binary,
    Vversion/binary,
    Vcversion/binary,
    Vaversion/binary,
    VephemeralOwner/binary,
    VdataLength/binary,
    VnumChildren/binary,
    Vpzxid/binary>>.

write_StatPersisted(R) when is_record(R, 'StatPersisted') ->
  Vczxid = jute_utils:write_long(R#'StatPersisted'.czxid),
  Vmzxid = jute_utils:write_long(R#'StatPersisted'.mzxid),
  Vctime = jute_utils:write_long(R#'StatPersisted'.ctime),
  Vmtime = jute_utils:write_long(R#'StatPersisted'.mtime),
  Vversion = jute_utils:write_int(R#'StatPersisted'.version),
  Vcversion = jute_utils:write_int(R#'StatPersisted'.cversion),
  Vaversion = jute_utils:write_int(R#'StatPersisted'.aversion),
  VephemeralOwner = jute_utils:write_long(R#'StatPersisted'.ephemeralOwner),
  Vpzxid = jute_utils:write_long(R#'StatPersisted'.pzxid),
  <<Vczxid/binary,
    Vmzxid/binary,
    Vctime/binary,
    Vmtime/binary,
    Vversion/binary,
    Vcversion/binary,
    Vaversion/binary,
    VephemeralOwner/binary,
    Vpzxid/binary>>.

write_StatPersistedV1(R) when is_record(R, 'StatPersistedV1') ->
  Vczxid = jute_utils:write_long(R#'StatPersistedV1'.czxid),
  Vmzxid = jute_utils:write_long(R#'StatPersistedV1'.mzxid),
  Vctime = jute_utils:write_long(R#'StatPersistedV1'.ctime),
  Vmtime = jute_utils:write_long(R#'StatPersistedV1'.mtime),
  Vversion = jute_utils:write_int(R#'StatPersistedV1'.version),
  Vcversion = jute_utils:write_int(R#'StatPersistedV1'.cversion),
  Vaversion = jute_utils:write_int(R#'StatPersistedV1'.aversion),
  VephemeralOwner = jute_utils:write_long(R#'StatPersistedV1'.ephemeralOwner),
  <<Vczxid/binary,
    Vmzxid/binary,
    Vctime/binary,
    Vmtime/binary,
    Vversion/binary,
    Vcversion/binary,
    Vaversion/binary,
    VephemeralOwner/binary>>.

