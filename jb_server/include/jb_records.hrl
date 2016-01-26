% This is the Zxid of the Zab protocol of Zookeeper
% It consists of a timestamp of when it was created and
% a counter that is incremented for each created Zxid

-record(vote, {epoch, zxid, sid}).
-record(notification, {vote, election_epoch, state}).
