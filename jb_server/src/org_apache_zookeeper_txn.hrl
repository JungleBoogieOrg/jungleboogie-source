-record('TxnHeader',
        {clientId,
         cxid,
         zxid,
         time,
         type}).
-record('CreateTxnV0',
        {path,
         data,
         acl,
         ephemeral}).
-record('CreateTxn',
        {path,
         data,
         acl,
         ephemeral,
         parentCVersion}).
-record('DeleteTxn',
        {path}).
-record('SetDataTxn',
        {path,
         data,
         version}).
-record('CheckVersionTxn',
        {path,
         version}).
-record('SetACLTxn',
        {path,
         acl,
         version}).
-record('SetMaxChildrenTxn',
        {path,
         max}).
-record('CreateSessionTxn',
        {timeOut}).
-record('ErrorTxn',
        {err}).
-record('Txn',
        {type,
         data}).
-record('MultiTxn',
        {txns}).