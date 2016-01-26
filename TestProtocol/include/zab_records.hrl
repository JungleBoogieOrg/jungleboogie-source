% This is the Zxid of the Zab protocol of Zookeeper
% It consists of a timestamp of when it was created and
% a counter that is incremented for each created Zxid
% I don't see the use of the counter

-record(zxid, {epoch, counter}).

% This record contains the data of a pending transaction
% as it is exchanged between Leaders and Workers
% It consist of the dat itself and the Zxid

-record(prepared, {data, zxid}).
