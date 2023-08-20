"Message
Here are all the message constructor helpers for the various
LSP and JSON-RPC responses that may need to be sent to the client.

I have them all here because I have a feeling I am conflating
missing fields with null fields, and I want to have one location
to look to fix this in the future."

(local utils (require :fennel-ls.utils))
(local json (require :json.json))

(λ nullify [?value]
   (case ?value
     nil json.null
     v v))

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
   :RequestFailed        -32803 ;; when the server has no excuse for failure
   :ServerCancelled      -32802
   :ContentModified      -32801 ;; I don't think this one is useful unless we do async things
   :RequestCancelled     -32800}) ;; I don't think I'm going to even support cancelling things, that sounds like a pain

(local severity
  {:ERROR 1
   :WARN 2
   :INFO 3
   :HINT 4})

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
   :result (nullify ?result)})

(λ ast->range [self file ?ast]
  (case (values (utils.get-ast-info ?ast :bytestart)
                (utils.get-ast-info ?ast :byteend))
    (bytestart byteend)
    {:start (utils.byte->position file.text bytestart self.position-encoding)
     :end   (utils.byte->position file.text (+ byteend 1) self.position-encoding)}))

(λ multisym->range [self file ast n]
  (let [spl (utils.multi-sym-split ast)]
    (case (values (utils.get-ast-info ast :bytestart)
                  (utils.get-ast-info ast :byteend))
      (bytestart byteend)
      (let [bytesubstart (faccumulate [b bytestart
                                       i 1 (- n 1)]
                           (+ b (length (. spl i)) 1))
            bytesubend (faccumulate [b byteend
                                     i (+ n 1) (length spl)]
                         (- b (length (. spl i)) 1))]
        {:start (utils.byte->position file.text bytesubstart self.position-encoding)
         :end   (utils.byte->position file.text (+ bytesubend 1) self.position-encoding)}))))

(λ range-and-uri [self {: uri &as file} ?ast]
  "if possible, returns the location of a symbol"
  (case (ast->range self file ?ast)
    range {: range : uri}))

(λ diagnostics [file]
  (create-notification
    "textDocument/publishDiagnostics"
    {:uri file.uri
     :diagnostics file.diagnostics}))

{: create-notification
 : create-request
 : create-response
 : create-error
 : ast->range
 : multisym->range
 : range-and-uri
 : diagnostics
 : severity}
