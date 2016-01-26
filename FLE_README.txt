Zookeeper Fast Leader Election

- This is a description of the Fast Leader Election (FLE) in ZooKeeper (ZK).
- ZK works with two different finite state machines (FSM)s managing independent TCP/IP connections.
- One of the state machines handles leader election, and it is described here. The other manages data operations.
- The leader election has the goal of finding consensum within quorum of peers for choosing leader.
- The rest of the peers in the quorum will be followers of that leader.
- It is possible also to participate as an observer. Observers do not take part in elections, but receive all messages.
- Before a consensum is reached, peers are in "looking" state.
- After a consensum is reached peers move to either "leading", "following" or "observing", and the election is over.
- Peers that are not looking, just reply to any (FLE) notification with a notification to the sending peer with the vote of the current leader.

- Peers that are within the election process (looking state), do the Following:
  - Keep an epoch value for the current election.
  - This value is one when the ZK process is started. 
  - It is updated when another peer reports a higher value or when a new election process is started.
  - Messages from Observers, invalid messages and messages from older election processes are ignored.
  - A vote includes the leader identifier, the last valid transaction identifier and the proposed epoch.
  - When entering the election process, each peer broadcasts its own vote as proposed leader.
  - If a new connection is established, votes are exchanged in that connection.
  - After that, each peer broadcasts its own vote every time that it is updated.
  - The vote of each peer is updated if a higher vote is received.
  - Votes are compared based on election epoch, zxid and peer sid, in higher to lower significance order.
  - If a quorum is reached for any peer to be a leader in the list of received votes of a peer, that peer leaves the election.
  - If the votes that have a quorum are for this peer, it changes state to leading otherwise it changes state to following.
  - Votes from peers out of the election (in other states than looking) are counted together with the election votes if they have the same election epoch.
  - If votes from peers out of the election reach a quorum (counted independently), then the leader in that quorum is followed.

%% Handling of the epoch is fuzzy, needs to be checked.
