"Message
Here are all the message constructor helpers for the various
LSP and JSON-RPC responses that may need to be sent to the client.

This module is responsible for any tables that need to correlate 1:1 with the
LSP json objects."

(local fennel (require :fennel))
(local utils (require :fennel-ls.utils))
(local json (require :dkjson))

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

(local severity->string
  ;; Transforming the `severity` table into
  ;; `{severity-code printable-string ...}`
  (collect [k v (pairs severity)]
    v (case k
        :WARN :warning
        _ (string.lower k))))

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

(λ ast->range [server file ?ast]
  (case (fennel.ast-source ?ast)
    {: bytestart : byteend} {:start (utils.byte->position file.text bytestart
                                                          server.position-encoding)
                             :end   (utils.byte->position file.text (+ byteend 1)
                                                          server.position-encoding)}))

(λ code-action-title [diag]
  (let [titles {:match-should-case "Replace match with case"
                :unused-definition "Prefix with _ to silence warning"
                :op-with-no-arguments "Replace with the corresponding literal"
                :no-decreasing-comparison "Reverse comparison"
                :unnecessary-tset "Replace with set"
                :unnecessary-do-values "Remove unnecessary do or values"
                :redundant-do "Remove redundant do"
                :bad-unpack "Replace with table.concat call"}]
    (or (. titles diag.code)
        (.. "Action title missing - " diag.code))))

(λ diagnostic->code-action [_server file diagnostic ?kind]
  (let [{: uri} file]
    {:title (code-action-title diagnostic)
     :kind ?kind
     :edit {:changes {uri (diagnostic.quickfix)}}}))

(λ symbol->signature-help [_server _file _call signature active-parameter]
  (let [params-count (length signature.parameters)
        {:label last} (. signature.parameters params-count)]
    {:signatures [signature]
        :activeSignature 0 ; we only ever have one signature
        :activeParameter (if (and (>= active-parameter params-count)
                                  (= last "..."))
                             (- params-count 1)
                             (>= active-parameter 0)
                             active-parameter)}))

(λ multisym->range [server file ast n]
  (let [spl (utils.multi-sym-split ast)
        n (if (< n 0) (+ n 1 (length spl)) n)]
    (case (values (utils.get-ast-info ast :bytestart)
                  (utils.get-ast-info ast :byteend))
      (bytestart byteend)
      (let [bytesubstart (faccumulate [b bytestart
                                       i 1 (- n 1)]
                           (+ b (length (. spl i)) 1))
            bytesubend (faccumulate [b byteend
                                     i (+ n 1) (length spl)]
                         (- b (length (. spl i)) 1))]
        {:start (utils.byte->position file.text bytesubstart server.position-encoding)
         :end   (utils.byte->position file.text (+ bytesubend 1) server.position-encoding)}))))

(λ range-and-uri [server {: uri &as file} ?ast]
  "if possible, returns the location of a symbol"
  (case (ast->range server file ?ast)
    range {: range : uri}))

(λ diagnostics [file]
  (create-notification
    "textDocument/publishDiagnostics"
    {:uri file.uri
     :diagnostics file.diagnostics}))

(λ show-message [message msg-type]
  (create-notification
    "window/showMessage"
    {:type (. severity msg-type)
     : message}))

{: create-notification
 : create-request
 : create-response
 : create-error
 : ast->range
 : diagnostic->code-action
 : symbol->signature-help
 : multisym->range
 : range-and-uri
 : diagnostics
 : severity
 : severity->string
 : show-message}
