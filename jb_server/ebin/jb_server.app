{application,jb_server,
             [{vsn,"0.1.0"},
              {description,"ZooKeeper Server Erlang clone. In this release it acts only as a dummy (no-memory) follower."},
              {registered,[]},
              {applications,[stdlib,kernel]},
              {modules,[datastructs_x,datastructs_y,jb_client_fsm,
                        jb_client_parser,jb_fle_conn,jb_fle_out_conn_sup,
                        jb_in_conn_sup,jb_server_app,jb_server_fsm,
                        jb_server_sup,jb_server_test,jb_store_mnesia,
                        jb_txn_conn,jb_txn_conn_test,jb_txn_out_conn_sup,
                        jute_code_gen,jute_utils,org_apache_zookeeper_data,
                        org_apache_zookeeper_proto,
                        org_apache_zookeeper_server_persistence,
                        org_apache_zookeeper_server_quorum,
                        org_apache_zookeeper_txn]},
              {mod,{jb_server_app,{1,
                                   [{1,{{127,0,0,1},2888,3888}},
                                    {2,{{127,0,0,1},2889,3889}},
                                    {3,{{127,0,0,1},2890,3890}}],
                                   2000,2,2}}},
              {env,[]}]}.