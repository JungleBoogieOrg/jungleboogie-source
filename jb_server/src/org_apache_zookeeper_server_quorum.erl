-module(org_apache_zookeeper_server_quorum).
-include("org_apache_zookeeper_server_quorum.hrl").

-export([read_LearnerInfo/1, write_LearnerInfo/1,
         read_QuorumPacket/1, write_QuorumPacket/1]).

read_LearnerInfo(<<Binary0/binary>>) ->
  {Vserverid, Binary1} = jute_utils:read_long(Binary0),
  {VprotocolVersion, Binary2} = jute_utils:read_int(Binary1),
  {#'LearnerInfo'{
  serverid = Vserverid,
  protocolVersion = VprotocolVersion}, Binary2}.

read_QuorumPacket(<<Binary0/binary>>) ->
  {Vtype, Binary1} = jute_utils:read_int(Binary0),
  {Vzxid, Binary2} = jute_utils:read_long(Binary1),
  {Vdata, Binary3} = jute_utils:read_buffer(Binary2),
  {Vauthinfo, Binary4} = jute_utils:read_vector(Binary3, fun(B)-> org_apache_zookeeper_data:read_Id(B) end),
  {#'QuorumPacket'{
  type = Vtype,
  zxid = Vzxid,
  data = Vdata,
  authinfo = Vauthinfo}, Binary4}.



write_LearnerInfo(R) when is_record(R, 'LearnerInfo') ->
  Vserverid = jute_utils:write_long(R#'LearnerInfo'.serverid),
  VprotocolVersion = jute_utils:write_int(R#'LearnerInfo'.protocolVersion),
  <<Vserverid/binary,
    VprotocolVersion/binary>>.

write_QuorumPacket(R) when is_record(R, 'QuorumPacket') ->
  Vtype = jute_utils:write_int(R#'QuorumPacket'.type),
  Vzxid = jute_utils:write_long(R#'QuorumPacket'.zxid),
  Vdata = jute_utils:write_buffer(R#'QuorumPacket'.data),
  Vauthinfo = jute_utils:write_vector(R#'QuorumPacket'.authinfo, fun(B)-> org_apache_zookeeper_data:read_Id(B) end),
  <<Vtype/binary,
    Vzxid/binary,
    Vdata/binary,
    Vauthinfo/binary>>.

