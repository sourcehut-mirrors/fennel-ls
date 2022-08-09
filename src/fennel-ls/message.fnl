"Message
Here are all the message constructor helpers for the various
LSP and JSON-RPC responses that may need to be sent to the client.

I have them all here because I have a feeling I am conflating
missing fields with null fields, and I want to have one location
to look to fix this in the future."

(local utils (require :fennel-ls.utils))
(local state (require :fennel-ls.state))

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
   :RequestFailed        -32802 ;; when the server has no excuse for failure
   :ServerCancelled      -32802
   :ContentModified      -32801 ;; I don't think this one is useful unless we do async things
   :RequestCancelled     -32800}) ;; I don't think I'm going to even support cancelling things, that sounds like a pain

(λ create-error [code message ?id ?data]
  {:jsonrpc "2.0"
   :id ?id
   :error {:code (or (. error-codes code) code)
           :data ?data
           : message}})

(λ create-request [id method ?params]
  {:jsonrpc "2.0"
   : id
   : method
   :params ?params})

(λ create-notification [method ?params]
  {:jsonrpc "2.0"
   : method
   :params ?params})

(λ create-response [id ?result]
  {:jsonrpc "2.0"
   : id
   :result ?result})

(λ range-and-uri [?ast file]
  "if possible, returns the location of a symbol"
  (match
    (values
      (utils.get-ast-info ?ast :bytestart)
      (utils.get-ast-info ?ast :byteend))
    (i j)
    (let [(start-line start-col) (utils.byte->pos file.text i)
          (end-line   end-col)   (utils.byte->pos file.text (+ j 1))]
     {:range {:start {:line start-line :character start-col}
              :end   {:line end-line   :character end-col}}
      :uri file.uri})))

{: create-notification
 : create-request
 : create-response
 : create-error
 : range-and-uri}
