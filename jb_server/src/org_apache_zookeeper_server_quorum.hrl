-record('LearnerInfo',
        {serverid,
         protocolVersion}).
-record('QuorumPacket',
        {type,
         zxid,
         data,
         authinfo}).
