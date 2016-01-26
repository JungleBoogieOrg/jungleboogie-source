-module(org_apache_zookeeper_proto).
-include("org_apache_zookeeper_proto.hrl").

-export([read_ConnectRequest/1, write_ConnectRequest/1,
         read_ConnectResponse/1, write_ConnectResponse/1,
         read_SetWatches/1, write_SetWatches/1,
         read_RequestHeader/1, write_RequestHeader/1,
         read_MultiHeader/1, write_MultiHeader/1,
         read_AuthPacket/1, write_AuthPacket/1,
         read_ReplyHeader/1, write_ReplyHeader/1,
         read_GetDataRequest/1, write_GetDataRequest/1,
         read_SetDataRequest/1, write_SetDataRequest/1,
         read_SetDataResponse/1, write_SetDataResponse/1,
         read_GetSASLRequest/1, write_GetSASLRequest/1,
         read_SetSASLRequest/1, write_SetSASLRequest/1,
         read_SetSASLResponse/1, write_SetSASLResponse/1,
         read_CreateRequest/1, write_CreateRequest/1,
         read_DeleteRequest/1, write_DeleteRequest/1,
         read_GetChildrenRequest/1, write_GetChildrenRequest/1,
         read_GetChildren2Request/1, write_GetChildren2Request/1,
         read_CheckVersionRequest/1, write_CheckVersionRequest/1,
         read_GetMaxChildrenRequest/1, write_GetMaxChildrenRequest/1,
         read_GetMaxChildrenResponse/1, write_GetMaxChildrenResponse/1,
         read_SetMaxChildrenRequest/1, write_SetMaxChildrenRequest/1,
         read_SyncRequest/1, write_SyncRequest/1,
         read_SyncResponse/1, write_SyncResponse/1,
         read_GetACLRequest/1, write_GetACLRequest/1,
         read_SetACLRequest/1, write_SetACLRequest/1,
         read_SetACLResponse/1, write_SetACLResponse/1,
         read_WatcherEvent/1, write_WatcherEvent/1,
         read_ErrorResponse/1, write_ErrorResponse/1,
         read_CreateResponse/1, write_CreateResponse/1,
         read_ExistsRequest/1, write_ExistsRequest/1,
         read_ExistsResponse/1, write_ExistsResponse/1,
         read_GetDataResponse/1, write_GetDataResponse/1,
         read_GetChildrenResponse/1, write_GetChildrenResponse/1,
         read_GetChildren2Response/1, write_GetChildren2Response/1,
         read_GetACLResponse/1, write_GetACLResponse/1]).

read_ConnectRequest(<<Binary0/binary>>) ->
  {VprotocolVersion, Binary1} = jute_utils:read_int(Binary0),
  {VlastZxidSeen, Binary2} = jute_utils:read_long(Binary1),
  {VtimeOut, Binary3} = jute_utils:read_int(Binary2),
  {VsessionId, Binary4} = jute_utils:read_long(Binary3),
  {Vpasswd, Binary5} = jute_utils:read_buffer(Binary4),
  {#'ConnectRequest'{
  protocolVersion = VprotocolVersion,
  lastZxidSeen = VlastZxidSeen,
  timeOut = VtimeOut,
  sessionId = VsessionId,
  passwd = Vpasswd}, Binary5}.

read_ConnectResponse(<<Binary0/binary>>) ->
  {VprotocolVersion, Binary1} = jute_utils:read_int(Binary0),
  {VtimeOut, Binary2} = jute_utils:read_int(Binary1),
  {VsessionId, Binary3} = jute_utils:read_long(Binary2),
  {Vpasswd, Binary4} = jute_utils:read_buffer(Binary3),
  {#'ConnectResponse'{
  protocolVersion = VprotocolVersion,
  timeOut = VtimeOut,
  sessionId = VsessionId,
  passwd = Vpasswd}, Binary4}.

read_SetWatches(<<Binary0/binary>>) ->
  {VrelativeZxid, Binary1} = jute_utils:read_long(Binary0),
  {VdataWatches, Binary2} = jute_utils:read_vector(Binary1, fun(B)-> jute_utils:read_ustring(B) end),
  {VexistWatches, Binary3} = jute_utils:read_vector(Binary2, fun(B)-> jute_utils:read_ustring(B) end),
  {VchildWatches, Binary4} = jute_utils:read_vector(Binary3, fun(B)-> jute_utils:read_ustring(B) end),
  {#'SetWatches'{
  relativeZxid = VrelativeZxid,
  dataWatches = VdataWatches,
  existWatches = VexistWatches,
  childWatches = VchildWatches}, Binary4}.

read_RequestHeader(<<Binary0/binary>>) ->
  {Vxid, Binary1} = jute_utils:read_int(Binary0),
  {Vtype, Binary2} = jute_utils:read_int(Binary1),
  {#'RequestHeader'{
  xid = Vxid,
  type = Vtype}, Binary2}.

read_MultiHeader(<<Binary0/binary>>) ->
  {Vtype, Binary1} = jute_utils:read_int(Binary0),
  {Vdone, Binary2} = jute_utils:read_boolean(Binary1),
  {Verr, Binary3} = jute_utils:read_int(Binary2),
  {#'MultiHeader'{
  type = Vtype,
  done = Vdone,
  err = Verr}, Binary3}.

read_AuthPacket(<<Binary0/binary>>) ->
  {Vtype, Binary1} = jute_utils:read_int(Binary0),
  {Vscheme, Binary2} = jute_utils:read_ustring(Binary1),
  {Vauth, Binary3} = jute_utils:read_buffer(Binary2),
  {#'AuthPacket'{
  type = Vtype,
  scheme = Vscheme,
  auth = Vauth}, Binary3}.

read_ReplyHeader(<<Binary0/binary>>) ->
  {Vxid, Binary1} = jute_utils:read_int(Binary0),
  {Vzxid, Binary2} = jute_utils:read_long(Binary1),
  {Verr, Binary3} = jute_utils:read_int(Binary2),
  {#'ReplyHeader'{
  xid = Vxid,
  zxid = Vzxid,
  err = Verr}, Binary3}.

read_GetDataRequest(<<Binary0/binary>>) ->
  {Vpath, Binary1} = jute_utils:read_ustring(Binary0),
  {Vwatch, Binary2} = jute_utils:read_boolean(Binary1),
  {#'GetDataRequest'{
  path = Vpath,
  watch = Vwatch}, Binary2}.

read_SetDataRequest(<<Binary0/binary>>) ->
  {Vpath, Binary1} = jute_utils:read_ustring(Binary0),
  {Vdata, Binary2} = jute_utils:read_buffer(Binary1),
  {Vversion, Binary3} = jute_utils:read_int(Binary2),
  {#'SetDataRequest'{
  path = Vpath,
  data = Vdata,
  version = Vversion}, Binary3}.

read_SetDataResponse(<<Binary0/binary>>) ->
  {Vstat, Binary1} = org_apache_zookeeper_data:read_Stat(Binary0),
  {#'SetDataResponse'{
  stat = Vstat}, Binary1}.

read_GetSASLRequest(<<Binary0/binary>>) ->
  {Vtoken, Binary1} = jute_utils:read_buffer(Binary0),
  {#'GetSASLRequest'{
  token = Vtoken}, Binary1}.

read_SetSASLRequest(<<Binary0/binary>>) ->
  {Vtoken, Binary1} = jute_utils:read_buffer(Binary0),
  {#'SetSASLRequest'{
  token = Vtoken}, Binary1}.

read_SetSASLResponse(<<Binary0/binary>>) ->
  {Vtoken, Binary1} = jute_utils:read_buffer(Binary0),
  {#'SetSASLResponse'{
  token = Vtoken}, Binary1}.

read_CreateRequest(<<Binary0/binary>>) ->
  {Vpath, Binary1} = jute_utils:read_ustring(Binary0),
  {Vdata, Binary2} = jute_utils:read_buffer(Binary1),
  {Vacl, Binary3} = jute_utils:read_vector(Binary2, fun(B)-> org_apache_zookeeper_data:read_ACL(B) end),
  {Vflags, Binary4} = jute_utils:read_int(Binary3),
  {#'CreateRequest'{
  path = Vpath,
  data = Vdata,
  acl = Vacl,
  flags = Vflags}, Binary4}.

read_DeleteRequest(<<Binary0/binary>>) ->
  {Vpath, Binary1} = jute_utils:read_ustring(Binary0),
  {Vversion, Binary2} = jute_utils:read_int(Binary1),
  {#'DeleteRequest'{
  path = Vpath,
  version = Vversion}, Binary2}.

read_GetChildrenRequest(<<Binary0/binary>>) ->
  {Vpath, Binary1} = jute_utils:read_ustring(Binary0),
  {Vwatch, Binary2} = jute_utils:read_boolean(Binary1),
  {#'GetChildrenRequest'{
  path = Vpath,
  watch = Vwatch}, Binary2}.

read_GetChildren2Request(<<Binary0/binary>>) ->
  {Vpath, Binary1} = jute_utils:read_ustring(Binary0),
  {Vwatch, Binary2} = jute_utils:read_boolean(Binary1),
  {#'GetChildren2Request'{
  path = Vpath,
  watch = Vwatch}, Binary2}.

read_CheckVersionRequest(<<Binary0/binary>>) ->
  {Vpath, Binary1} = jute_utils:read_ustring(Binary0),
  {Vversion, Binary2} = jute_utils:read_int(Binary1),
  {#'CheckVersionRequest'{
  path = Vpath,
  version = Vversion}, Binary2}.

read_GetMaxChildrenRequest(<<Binary0/binary>>) ->
  {Vpath, Binary1} = jute_utils:read_ustring(Binary0),
  {#'GetMaxChildrenRequest'{
  path = Vpath}, Binary1}.

read_GetMaxChildrenResponse(<<Binary0/binary>>) ->
  {Vmax, Binary1} = jute_utils:read_int(Binary0),
  {#'GetMaxChildrenResponse'{
  max = Vmax}, Binary1}.

read_SetMaxChildrenRequest(<<Binary0/binary>>) ->
  {Vpath, Binary1} = jute_utils:read_ustring(Binary0),
  {Vmax, Binary2} = jute_utils:read_int(Binary1),
  {#'SetMaxChildrenRequest'{
  path = Vpath,
  max = Vmax}, Binary2}.

read_SyncRequest(<<Binary0/binary>>) ->
  {Vpath, Binary1} = jute_utils:read_ustring(Binary0),
  {#'SyncRequest'{
  path = Vpath}, Binary1}.

read_SyncResponse(<<Binary0/binary>>) ->
  {Vpath, Binary1} = jute_utils:read_ustring(Binary0),
  {#'SyncResponse'{
  path = Vpath}, Binary1}.

read_GetACLRequest(<<Binary0/binary>>) ->
  {Vpath, Binary1} = jute_utils:read_ustring(Binary0),
  {#'GetACLRequest'{
  path = Vpath}, Binary1}.

read_SetACLRequest(<<Binary0/binary>>) ->
  {Vpath, Binary1} = jute_utils:read_ustring(Binary0),
  {Vacl, Binary2} = jute_utils:read_vector(Binary1, fun(B)-> org_apache_zookeeper_data:read_ACL(B) end),
  {Vversion, Binary3} = jute_utils:read_int(Binary2),
  {#'SetACLRequest'{
  path = Vpath,
  acl = Vacl,
  version = Vversion}, Binary3}.

read_SetACLResponse(<<Binary0/binary>>) ->
  {Vstat, Binary1} = org_apache_zookeeper_data:read_Stat(Binary0),
  {#'SetACLResponse'{
  stat = Vstat}, Binary1}.

read_WatcherEvent(<<Binary0/binary>>) ->
  {Vtype, Binary1} = jute_utils:read_int(Binary0),
  {Vstate, Binary2} = jute_utils:read_int(Binary1),
  {Vpath, Binary3} = jute_utils:read_ustring(Binary2),
  {#'WatcherEvent'{
  type = Vtype,
  state = Vstate,
  path = Vpath}, Binary3}.

read_ErrorResponse(<<Binary0/binary>>) ->
  {Verr, Binary1} = jute_utils:read_int(Binary0),
  {#'ErrorResponse'{
  err = Verr}, Binary1}.

read_CreateResponse(<<Binary0/binary>>) ->
  {Vpath, Binary1} = jute_utils:read_ustring(Binary0),
  {#'CreateResponse'{
  path = Vpath}, Binary1}.

read_ExistsRequest(<<Binary0/binary>>) ->
  {Vpath, Binary1} = jute_utils:read_ustring(Binary0),
  {Vwatch, Binary2} = jute_utils:read_boolean(Binary1),
  {#'ExistsRequest'{
  path = Vpath,
  watch = Vwatch}, Binary2}.

read_ExistsResponse(<<Binary0/binary>>) ->
  {Vstat, Binary1} = org_apache_zookeeper_data:read_Stat(Binary0),
  {#'ExistsResponse'{
  stat = Vstat}, Binary1}.

read_GetDataResponse(<<Binary0/binary>>) ->
  {Vdata, Binary1} = jute_utils:read_buffer(Binary0),
  {Vstat, Binary2} = org_apache_zookeeper_data:read_Stat(Binary1),
  {#'GetDataResponse'{
  data = Vdata,
  stat = Vstat}, Binary2}.

read_GetChildrenResponse(<<Binary0/binary>>) ->
  {Vchildren, Binary1} = jute_utils:read_vector(Binary0, fun(B)-> jute_utils:read_ustring(B) end),
  {#'GetChildrenResponse'{
  children = Vchildren}, Binary1}.

read_GetChildren2Response(<<Binary0/binary>>) ->
  {Vchildren, Binary1} = jute_utils:read_vector(Binary0, fun(B)-> jute_utils:read_ustring(B) end),
  {Vstat, Binary2} = org_apache_zookeeper_data:read_Stat(Binary1),
  {#'GetChildren2Response'{
  children = Vchildren,
  stat = Vstat}, Binary2}.

read_GetACLResponse(<<Binary0/binary>>) ->
  {Vacl, Binary1} = jute_utils:read_vector(Binary0, fun(B)-> org_apache_zookeeper_data:read_ACL(B) end),
  {Vstat, Binary2} = org_apache_zookeeper_data:read_Stat(Binary1),
  {#'GetACLResponse'{
  acl = Vacl,
  stat = Vstat}, Binary2}.



write_ConnectRequest(R) when is_record(R, 'ConnectRequest') ->
  VprotocolVersion = jute_utils:write_int(R#'ConnectRequest'.protocolVersion),
  VlastZxidSeen = jute_utils:write_long(R#'ConnectRequest'.lastZxidSeen),
  VtimeOut = jute_utils:write_int(R#'ConnectRequest'.timeOut),
  VsessionId = jute_utils:write_long(R#'ConnectRequest'.sessionId),
  Vpasswd = jute_utils:write_buffer(R#'ConnectRequest'.passwd),
  <<VprotocolVersion/binary,
    VlastZxidSeen/binary,
    VtimeOut/binary,
    VsessionId/binary,
    Vpasswd/binary>>.

write_ConnectResponse(R) when is_record(R, 'ConnectResponse') ->
  VprotocolVersion = jute_utils:write_int(R#'ConnectResponse'.protocolVersion),
  VtimeOut = jute_utils:write_int(R#'ConnectResponse'.timeOut),
  VsessionId = jute_utils:write_long(R#'ConnectResponse'.sessionId),
  Vpasswd = jute_utils:write_buffer(R#'ConnectResponse'.passwd),
  <<VprotocolVersion/binary,
    VtimeOut/binary,
    VsessionId/binary,
    Vpasswd/binary>>.

write_SetWatches(R) when is_record(R, 'SetWatches') ->
  VrelativeZxid = jute_utils:write_long(R#'SetWatches'.relativeZxid),
  VdataWatches = jute_utils:write_vector(R#'SetWatches'.dataWatches, fun(B)-> jute_utils:read_ustring(B) end),
  VexistWatches = jute_utils:write_vector(R#'SetWatches'.existWatches, fun(B)-> jute_utils:read_ustring(B) end),
  VchildWatches = jute_utils:write_vector(R#'SetWatches'.childWatches, fun(B)-> jute_utils:read_ustring(B) end),
  <<VrelativeZxid/binary,
    VdataWatches/binary,
    VexistWatches/binary,
    VchildWatches/binary>>.

write_RequestHeader(R) when is_record(R, 'RequestHeader') ->
  Vxid = jute_utils:write_int(R#'RequestHeader'.xid),
  Vtype = jute_utils:write_int(R#'RequestHeader'.type),
  <<Vxid/binary,
    Vtype/binary>>.

write_MultiHeader(R) when is_record(R, 'MultiHeader') ->
  Vtype = jute_utils:write_int(R#'MultiHeader'.type),
  Vdone = jute_utils:write_boolean(R#'MultiHeader'.done),
  Verr = jute_utils:write_int(R#'MultiHeader'.err),
  <<Vtype/binary,
    Vdone/binary,
    Verr/binary>>.

write_AuthPacket(R) when is_record(R, 'AuthPacket') ->
  Vtype = jute_utils:write_int(R#'AuthPacket'.type),
  Vscheme = jute_utils:write_ustring(R#'AuthPacket'.scheme),
  Vauth = jute_utils:write_buffer(R#'AuthPacket'.auth),
  <<Vtype/binary,
    Vscheme/binary,
    Vauth/binary>>.

write_ReplyHeader(R) when is_record(R, 'ReplyHeader') ->
  Vxid = jute_utils:write_int(R#'ReplyHeader'.xid),
  Vzxid = jute_utils:write_long(R#'ReplyHeader'.zxid),
  Verr = jute_utils:write_int(R#'ReplyHeader'.err),
  <<Vxid/binary,
    Vzxid/binary,
    Verr/binary>>.

write_GetDataRequest(R) when is_record(R, 'GetDataRequest') ->
  Vpath = jute_utils:write_ustring(R#'GetDataRequest'.path),
  Vwatch = jute_utils:write_boolean(R#'GetDataRequest'.watch),
  <<Vpath/binary,
    Vwatch/binary>>.

write_SetDataRequest(R) when is_record(R, 'SetDataRequest') ->
  Vpath = jute_utils:write_ustring(R#'SetDataRequest'.path),
  Vdata = jute_utils:write_buffer(R#'SetDataRequest'.data),
  Vversion = jute_utils:write_int(R#'SetDataRequest'.version),
  <<Vpath/binary,
    Vdata/binary,
    Vversion/binary>>.

write_SetDataResponse(R) when is_record(R, 'SetDataResponse') ->
  Vstat = org_apache_zookeeper_data:write_Stat(R#'SetDataResponse'.stat),
  <<Vstat/binary>>.

write_GetSASLRequest(R) when is_record(R, 'GetSASLRequest') ->
  Vtoken = jute_utils:write_buffer(R#'GetSASLRequest'.token),
  <<Vtoken/binary>>.

write_SetSASLRequest(R) when is_record(R, 'SetSASLRequest') ->
  Vtoken = jute_utils:write_buffer(R#'SetSASLRequest'.token),
  <<Vtoken/binary>>.

write_SetSASLResponse(R) when is_record(R, 'SetSASLResponse') ->
  Vtoken = jute_utils:write_buffer(R#'SetSASLResponse'.token),
  <<Vtoken/binary>>.

write_CreateRequest(R) when is_record(R, 'CreateRequest') ->
  Vpath = jute_utils:write_ustring(R#'CreateRequest'.path),
  Vdata = jute_utils:write_buffer(R#'CreateRequest'.data),
  Vacl = jute_utils:write_vector(R#'CreateRequest'.acl, fun(B)-> org_apache_zookeeper_data:read_ACL(B) end),
  Vflags = jute_utils:write_int(R#'CreateRequest'.flags),
  <<Vpath/binary,
    Vdata/binary,
    Vacl/binary,
    Vflags/binary>>.

write_DeleteRequest(R) when is_record(R, 'DeleteRequest') ->
  Vpath = jute_utils:write_ustring(R#'DeleteRequest'.path),
  Vversion = jute_utils:write_int(R#'DeleteRequest'.version),
  <<Vpath/binary,
    Vversion/binary>>.

write_GetChildrenRequest(R) when is_record(R, 'GetChildrenRequest') ->
  Vpath = jute_utils:write_ustring(R#'GetChildrenRequest'.path),
  Vwatch = jute_utils:write_boolean(R#'GetChildrenRequest'.watch),
  <<Vpath/binary,
    Vwatch/binary>>.

write_GetChildren2Request(R) when is_record(R, 'GetChildren2Request') ->
  Vpath = jute_utils:write_ustring(R#'GetChildren2Request'.path),
  Vwatch = jute_utils:write_boolean(R#'GetChildren2Request'.watch),
  <<Vpath/binary,
    Vwatch/binary>>.

write_CheckVersionRequest(R) when is_record(R, 'CheckVersionRequest') ->
  Vpath = jute_utils:write_ustring(R#'CheckVersionRequest'.path),
  Vversion = jute_utils:write_int(R#'CheckVersionRequest'.version),
  <<Vpath/binary,
    Vversion/binary>>.

write_GetMaxChildrenRequest(R) when is_record(R, 'GetMaxChildrenRequest') ->
  Vpath = jute_utils:write_ustring(R#'GetMaxChildrenRequest'.path),
  <<Vpath/binary>>.

write_GetMaxChildrenResponse(R) when is_record(R, 'GetMaxChildrenResponse') ->
  Vmax = jute_utils:write_int(R#'GetMaxChildrenResponse'.max),
  <<Vmax/binary>>.

write_SetMaxChildrenRequest(R) when is_record(R, 'SetMaxChildrenRequest') ->
  Vpath = jute_utils:write_ustring(R#'SetMaxChildrenRequest'.path),
  Vmax = jute_utils:write_int(R#'SetMaxChildrenRequest'.max),
  <<Vpath/binary,
    Vmax/binary>>.

write_SyncRequest(R) when is_record(R, 'SyncRequest') ->
  Vpath = jute_utils:write_ustring(R#'SyncRequest'.path),
  <<Vpath/binary>>.

write_SyncResponse(R) when is_record(R, 'SyncResponse') ->
  Vpath = jute_utils:write_ustring(R#'SyncResponse'.path),
  <<Vpath/binary>>.

write_GetACLRequest(R) when is_record(R, 'GetACLRequest') ->
  Vpath = jute_utils:write_ustring(R#'GetACLRequest'.path),
  <<Vpath/binary>>.

write_SetACLRequest(R) when is_record(R, 'SetACLRequest') ->
  Vpath = jute_utils:write_ustring(R#'SetACLRequest'.path),
  Vacl = jute_utils:write_vector(R#'SetACLRequest'.acl, fun(B)-> org_apache_zookeeper_data:read_ACL(B) end),
  Vversion = jute_utils:write_int(R#'SetACLRequest'.version),
  <<Vpath/binary,
    Vacl/binary,
    Vversion/binary>>.

write_SetACLResponse(R) when is_record(R, 'SetACLResponse') ->
  Vstat = org_apache_zookeeper_data:write_Stat(R#'SetACLResponse'.stat),
  <<Vstat/binary>>.

write_WatcherEvent(R) when is_record(R, 'WatcherEvent') ->
  Vtype = jute_utils:write_int(R#'WatcherEvent'.type),
  Vstate = jute_utils:write_int(R#'WatcherEvent'.state),
  Vpath = jute_utils:write_ustring(R#'WatcherEvent'.path),
  <<Vtype/binary,
    Vstate/binary,
    Vpath/binary>>.

write_ErrorResponse(R) when is_record(R, 'ErrorResponse') ->
  Verr = jute_utils:write_int(R#'ErrorResponse'.err),
  <<Verr/binary>>.

write_CreateResponse(R) when is_record(R, 'CreateResponse') ->
  Vpath = jute_utils:write_ustring(R#'CreateResponse'.path),
  <<Vpath/binary>>.

write_ExistsRequest(R) when is_record(R, 'ExistsRequest') ->
  Vpath = jute_utils:write_ustring(R#'ExistsRequest'.path),
  Vwatch = jute_utils:write_boolean(R#'ExistsRequest'.watch),
  <<Vpath/binary,
    Vwatch/binary>>.

write_ExistsResponse(R) when is_record(R, 'ExistsResponse') ->
  Vstat = org_apache_zookeeper_data:write_Stat(R#'ExistsResponse'.stat),
  <<Vstat/binary>>.

write_GetDataResponse(R) when is_record(R, 'GetDataResponse') ->
  Vdata = jute_utils:write_buffer(R#'GetDataResponse'.data),
  Vstat = org_apache_zookeeper_data:write_Stat(R#'GetDataResponse'.stat),
  <<Vdata/binary,
    Vstat/binary>>.

write_GetChildrenResponse(R) when is_record(R, 'GetChildrenResponse') ->
  Vchildren = jute_utils:write_vector(R#'GetChildrenResponse'.children, fun(B)-> jute_utils:read_ustring(B) end),
  <<Vchildren/binary>>.

write_GetChildren2Response(R) when is_record(R, 'GetChildren2Response') ->
  Vchildren = jute_utils:write_vector(R#'GetChildren2Response'.children, fun(B)-> jute_utils:read_ustring(B) end),
  Vstat = org_apache_zookeeper_data:write_Stat(R#'GetChildren2Response'.stat),
  <<Vchildren/binary,
    Vstat/binary>>.

write_GetACLResponse(R) when is_record(R, 'GetACLResponse') ->
  Vacl = jute_utils:write_vector(R#'GetACLResponse'.acl, fun(B)-> org_apache_zookeeper_data:read_ACL(B) end),
  Vstat = org_apache_zookeeper_data:write_Stat(R#'GetACLResponse'.stat),
  <<Vacl/binary,
    Vstat/binary>>.

