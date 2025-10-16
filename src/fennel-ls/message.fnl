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

(local symbol-kind
  {:File 1 :Module 2 :Namespace 3 :Package 4 :Class 5 :Method 6 :Property 7
   :Field 8 :Constructor 9 :Enum 10 :Interface 11 :Function 12 :Variable 13
   :Constant 14 :String 15 :Number 16 :Boolean 17 :Array 18 :Object 19 :Key 20
   :Null 21 :EnumMember 22 :Struct 23 :Event 24 :Operator 25 :TypeParameter 26})

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

(local unknown-range {:start {:line 0 :character 0}
                      :end {:line 0 :character 0}})

(λ ast->range [server file ?ast]
  (case (fennel.ast-source ?ast)
    {: bytestart : byteend} {:start (utils.byte->position file.text bytestart
                                                          server.position-encoding)
                             :end   (utils.byte->position file.text (+ byteend 1)
                                                          server.position-encoding)}))

(λ diagnostic->code-action [_server {: uri} diagnostic ?kind]
  (case-try diagnostic.fix
    fix (fix)
    {: title : changes} {: title
                         :kind ?kind
                         :diagnostics [diagnostic]
                         :edit {:changes {uri changes}}}))

(λ call->signature-help [_server _file _call signature active-parameter]
  (let [params-count (length signature.parameters)]
    {:signatures [signature]
     :activeSignature 0 ; we only ever have one signature
     :activeParameter (if (<= params-count active-parameter)
                          (- params-count 1)
                          (<= 0 active-parameter)
                          active-parameter)}))

(λ multisym->range [server file ast n]
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

(λ definition->symbol-kind [definition]
  (let [def definition.definition]
    (if (fennel.list? def)
      (let [head (. def 1)]
        (if (or (fennel.sym? head :fn)
                (fennel.sym? head :lambda)
                (fennel.sym? head :λ))
          symbol-kind.Function
          symbol-kind.Variable))
      symbol-kind.Variable)))

(λ document-symbol-format [server file symbols]
  (let [symbols (icollect [_ {: symbol : definition} (ipairs symbols)]
                 (let [name (tostring symbol)
                       kind (definition->symbol-kind definition)
                       range (ast->range server file definition.binding)]
                   (when range
                     {: name
                      : kind
                      : range
                      :selectionRange range})))]
    ; the spec doesn't define an order, and not all clients sort the results
    (table.sort symbols
      (fn [a b]
        (or (< a.range.start.line b.range.start.line)
            (and (= a.range.start.line b.range.start.line)
                 (< a.range.start.character b.range.start.character)))))
    symbols))

{: create-notification
 : create-request
 : create-response
 : create-error
 : ast->range
 : diagnostic->code-action
 : call->signature-help
 : multisym->range
 : range-and-uri
 : diagnostics
 : severity
 : severity->string
 : show-message
 : unknown-range
 : document-symbol-format
 : symbol-kind}
