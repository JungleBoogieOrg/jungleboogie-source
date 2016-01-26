-module(org_apache_zookeeper_server_persistence).
-include("org_apache_zookeeper_server_persistence.hrl").

-export([read_FileHeader/1, write_FileHeader/1]).

read_FileHeader(<<Binary0/binary>>) ->
  {Vmagic, Binary1} = jute_utils:read_int(Binary0),
  {Vversion, Binary2} = jute_utils:read_int(Binary1),
  {Vdbid, Binary3} = jute_utils:read_long(Binary2),
  {#'FileHeader'{
  magic = Vmagic,
  version = Vversion,
  dbid = Vdbid}, Binary3}.



write_FileHeader(R) when is_record(R, 'FileHeader') ->
  Vmagic = jute_utils:write_int(R#'FileHeader'.magic),
  Vversion = jute_utils:write_int(R#'FileHeader'.version),
  Vdbid = jute_utils:write_long(R#'FileHeader'.dbid),
  <<Vmagic/binary,
    Vversion/binary,
    Vdbid/binary>>.

