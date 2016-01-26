-module(org_apache_zookeeper_txn).
-include("org_apache_zookeeper_txn.hrl").

-export([read_TxnHeader/1, write_TxnHeader/1,
         read_CreateTxnV0/1, write_CreateTxnV0/1,
         read_CreateTxn/1, write_CreateTxn/1,
         read_DeleteTxn/1, write_DeleteTxn/1,
         read_SetDataTxn/1, write_SetDataTxn/1,
         read_CheckVersionTxn/1, write_CheckVersionTxn/1,
         read_SetACLTxn/1, write_SetACLTxn/1,
         read_SetMaxChildrenTxn/1, write_SetMaxChildrenTxn/1,
         read_CreateSessionTxn/1, write_CreateSessionTxn/1,
         read_ErrorTxn/1, write_ErrorTxn/1,
         read_Txn/1, write_Txn/1,
         read_MultiTxn/1, write_MultiTxn/1]).

read_TxnHeader(<<Binary0/binary>>) ->
  {VclientId, Binary1} = jute_utils:read_long(Binary0),
  {Vcxid, Binary2} = jute_utils:read_int(Binary1),
  {Vzxid, Binary3} = jute_utils:read_long(Binary2),
  {Vtime, Binary4} = jute_utils:read_long(Binary3),
  {Vtype, Binary5} = jute_utils:read_int(Binary4),
  {#'TxnHeader'{
  clientId = VclientId,
  cxid = Vcxid,
  zxid = Vzxid,
  time = Vtime,
  type = Vtype}, Binary5}.

read_CreateTxnV0(<<Binary0/binary>>) ->
  {Vpath, Binary1} = jute_utils:read_ustring(Binary0),
  {Vdata, Binary2} = jute_utils:read_buffer(Binary1),
  {Vacl, Binary3} = jute_utils:read_vector(Binary2, fun(B)-> org_apache_zookeeper_data:read_ACL(B) end),
  {Vephemeral, Binary4} = jute_utils:read_boolean(Binary3),
  {#'CreateTxnV0'{
  path = Vpath,
  data = Vdata,
  acl = Vacl,
  ephemeral = Vephemeral}, Binary4}.

read_CreateTxn(<<Binary0/binary>>) ->
  {Vpath, Binary1} = jute_utils:read_ustring(Binary0),
  {Vdata, Binary2} = jute_utils:read_buffer(Binary1),
  {Vacl, Binary3} = jute_utils:read_vector(Binary2, fun(B)-> org_apache_zookeeper_data:read_ACL(B) end),
  {Vephemeral, Binary4} = jute_utils:read_boolean(Binary3),
  {VparentCVersion, Binary5} = jute_utils:read_int(Binary4),
  {#'CreateTxn'{
  path = Vpath,
  data = Vdata,
  acl = Vacl,
  ephemeral = Vephemeral,
  parentCVersion = VparentCVersion}, Binary5}.

read_DeleteTxn(<<Binary0/binary>>) ->
  {Vpath, Binary1} = jute_utils:read_ustring(Binary0),
  {#'DeleteTxn'{
  path = Vpath}, Binary1}.

read_SetDataTxn(<<Binary0/binary>>) ->
  {Vpath, Binary1} = jute_utils:read_ustring(Binary0),
  {Vdata, Binary2} = jute_utils:read_buffer(Binary1),
  {Vversion, Binary3} = jute_utils:read_int(Binary2),
  {#'SetDataTxn'{
  path = Vpath,
  data = Vdata,
  version = Vversion}, Binary3}.

read_CheckVersionTxn(<<Binary0/binary>>) ->
  {Vpath, Binary1} = jute_utils:read_ustring(Binary0),
  {Vversion, Binary2} = jute_utils:read_int(Binary1),
  {#'CheckVersionTxn'{
  path = Vpath,
  version = Vversion}, Binary2}.

read_SetACLTxn(<<Binary0/binary>>) ->
  {Vpath, Binary1} = jute_utils:read_ustring(Binary0),
  {Vacl, Binary2} = jute_utils:read_vector(Binary1, fun(B)-> org_apache_zookeeper_data:read_ACL(B) end),
  {Vversion, Binary3} = jute_utils:read_int(Binary2),
  {#'SetACLTxn'{
  path = Vpath,
  acl = Vacl,
  version = Vversion}, Binary3}.

read_SetMaxChildrenTxn(<<Binary0/binary>>) ->
  {Vpath, Binary1} = jute_utils:read_ustring(Binary0),
  {Vmax, Binary2} = jute_utils:read_int(Binary1),
  {#'SetMaxChildrenTxn'{
  path = Vpath,
  max = Vmax}, Binary2}.

read_CreateSessionTxn(<<Binary0/binary>>) ->
  {VtimeOut, Binary1} = jute_utils:read_int(Binary0),
  {#'CreateSessionTxn'{
  timeOut = VtimeOut}, Binary1}.

read_ErrorTxn(<<Binary0/binary>>) ->
  {Verr, Binary1} = jute_utils:read_int(Binary0),
  {#'ErrorTxn'{
  err = Verr}, Binary1}.

read_Txn(<<Binary0/binary>>) ->
  {Vtype, Binary1} = jute_utils:read_int(Binary0),
  {Vdata, Binary2} = jute_utils:read_buffer(Binary1),
  {#'Txn'{
  type = Vtype,
  data = Vdata}, Binary2}.

read_MultiTxn(<<Binary0/binary>>) ->
  {Vtxns, Binary1} = jute_utils:read_vector(Binary0, fun(B)-> org_apache_zookeeper_txn:read_Txn(B) end),
  {#'MultiTxn'{
  txns = Vtxns}, Binary1}.



write_TxnHeader(R) when is_record(R, 'TxnHeader') ->
  VclientId = jute_utils:write_long(R#'TxnHeader'.clientId),
  Vcxid = jute_utils:write_int(R#'TxnHeader'.cxid),
  Vzxid = jute_utils:write_long(R#'TxnHeader'.zxid),
  Vtime = jute_utils:write_long(R#'TxnHeader'.time),
  Vtype = jute_utils:write_int(R#'TxnHeader'.type),
  <<VclientId/binary,
    Vcxid/binary,
    Vzxid/binary,
    Vtime/binary,
    Vtype/binary>>.

write_CreateTxnV0(R) when is_record(R, 'CreateTxnV0') ->
  Vpath = jute_utils:write_ustring(R#'CreateTxnV0'.path),
  Vdata = jute_utils:write_buffer(R#'CreateTxnV0'.data),
  Vacl = jute_utils:write_vector(R#'CreateTxnV0'.acl, fun(B)-> org_apache_zookeeper_data:read_ACL(B) end),
  Vephemeral = jute_utils:write_boolean(R#'CreateTxnV0'.ephemeral),
  <<Vpath/binary,
    Vdata/binary,
    Vacl/binary,
    Vephemeral/binary>>.

write_CreateTxn(R) when is_record(R, 'CreateTxn') ->
  Vpath = jute_utils:write_ustring(R#'CreateTxn'.path),
  Vdata = jute_utils:write_buffer(R#'CreateTxn'.data),
  Vacl = jute_utils:write_vector(R#'CreateTxn'.acl, fun(B)-> org_apache_zookeeper_data:read_ACL(B) end),
  Vephemeral = jute_utils:write_boolean(R#'CreateTxn'.ephemeral),
  VparentCVersion = jute_utils:write_int(R#'CreateTxn'.parentCVersion),
  <<Vpath/binary,
    Vdata/binary,
    Vacl/binary,
    Vephemeral/binary,
    VparentCVersion/binary>>.

write_DeleteTxn(R) when is_record(R, 'DeleteTxn') ->
  Vpath = jute_utils:write_ustring(R#'DeleteTxn'.path),
  <<Vpath/binary>>.

write_SetDataTxn(R) when is_record(R, 'SetDataTxn') ->
  Vpath = jute_utils:write_ustring(R#'SetDataTxn'.path),
  Vdata = jute_utils:write_buffer(R#'SetDataTxn'.data),
  Vversion = jute_utils:write_int(R#'SetDataTxn'.version),
  <<Vpath/binary,
    Vdata/binary,
    Vversion/binary>>.

write_CheckVersionTxn(R) when is_record(R, 'CheckVersionTxn') ->
  Vpath = jute_utils:write_ustring(R#'CheckVersionTxn'.path),
  Vversion = jute_utils:write_int(R#'CheckVersionTxn'.version),
  <<Vpath/binary,
    Vversion/binary>>.

write_SetACLTxn(R) when is_record(R, 'SetACLTxn') ->
  Vpath = jute_utils:write_ustring(R#'SetACLTxn'.path),
  Vacl = jute_utils:write_vector(R#'SetACLTxn'.acl, fun(B)-> org_apache_zookeeper_data:read_ACL(B) end),
  Vversion = jute_utils:write_int(R#'SetACLTxn'.version),
  <<Vpath/binary,
    Vacl/binary,
    Vversion/binary>>.

write_SetMaxChildrenTxn(R) when is_record(R, 'SetMaxChildrenTxn') ->
  Vpath = jute_utils:write_ustring(R#'SetMaxChildrenTxn'.path),
  Vmax = jute_utils:write_int(R#'SetMaxChildrenTxn'.max),
  <<Vpath/binary,
    Vmax/binary>>.

write_CreateSessionTxn(R) when is_record(R, 'CreateSessionTxn') ->
  VtimeOut = jute_utils:write_int(R#'CreateSessionTxn'.timeOut),
  <<VtimeOut/binary>>.

write_ErrorTxn(R) when is_record(R, 'ErrorTxn') ->
  Verr = jute_utils:write_int(R#'ErrorTxn'.err),
  <<Verr/binary>>.

write_Txn(R) when is_record(R, 'Txn') ->
  Vtype = jute_utils:write_int(R#'Txn'.type),
  Vdata = jute_utils:write_buffer(R#'Txn'.data),
  <<Vtype/binary,
    Vdata/binary>>.

write_MultiTxn(R) when is_record(R, 'MultiTxn') ->
  Vtxns = jute_utils:write_vector(R#'MultiTxn'.txns, fun(B)-> org_apache_zookeeper_txn:read_Txn(B) end),
  <<Vtxns/binary>>.

