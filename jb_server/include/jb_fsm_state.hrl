-record(state, {
        myvote, 
        election_epoch, 
        election_start_time,
        server_list, 
        fle_server_list, 
        timer, 
        leader_vote, 
        votes_in_election,
        votes_out_of_election,
        is_participant,
        followers_list, 
        leader_conn,
        tick_time,
        initial_limit,
        sync_limit,
        outstanding_proposals,
        mydata
    }).
