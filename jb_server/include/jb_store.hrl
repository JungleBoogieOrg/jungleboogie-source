-record(datanodeR, {path, data, acl, admindata}).
-record(admindataR, {czxid, mzxid, ctime, mtime, version, aversion, ephemeralOwner, pzxid}).
% ephemeralOwner is only used in an ephemeral table
-record(treeR, {path, children, cversion}).
% cversion not implemented until we know how it works :-S
-record(watcherR, {watch}).
