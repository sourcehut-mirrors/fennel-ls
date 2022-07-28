(local error-codes
  {;; JSON-RPC errors
   :ParseError     -32700
   :InvalidRequest -32600
   :MethodNotFound -32601
   :InvalidParams  -32602
   :InternalError  -32603
   ;; LSP errors
   :ServerNotInitialized -32002
   :UnknownErrorCode     -32001
   :RequestFailed        -32802 ;; when the server has no excuse
   :ServerCancelled      -32802
   :ContentModified      -32801 ;; I don't think this one is useful
   :RequestCancelled     -32800}) ;; I don't think I'm going to even support cancelling things, that sounds like a pain

(λ make-error-message [code message ?id ?data]
  {:jsonrpc "2.0"
   :id ?id
   :error {:code (or (. error-codes code) code)
           :data ?data
           : message}})

{: error-codes : make-error-message}
