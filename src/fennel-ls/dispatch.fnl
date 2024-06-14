"Dispatch
This module is responsible for deciding which code to call in response
to a given LSP request from the client.

In general, this involves:
* determining the type of the message
* calling the appropriate handler in the :fennel-ls.handlers module.
"

(local handlers (require :fennel-ls.handlers))
(local message (require :fennel-ls.message))

(λ handle-request [server send id method ?params]
  ;; Call the appropriate request handler.
  ;; The return value of the request is sent back to the server.
  (case (. handlers.requests method)
    callback
    (case (callback server send ?params)
      (nil err) (send (message.create-error :InternalError err id))
      ?response (send (message.create-response id ?response)))
    nil
    (send
      (message.create-error
        :MethodNotFound
        (.. "\"" method "\" is not in the request-handlers table")
        id))))

(λ handle-response [_server _send _id _result]
  ;; I don't care about responses yet
  nil)

(λ handle-bad-response [_server _send _id err]
  ;; Handle a message indicating an error. Right now, it just crashes the server.
  (error (.. "Client sent fennel-ls an error: " err.code)))

(λ handle-notification [server send method ?params]
  ;; Call the appropriate notification handler.
  (case (. handlers.notifications method)
    callback (callback server send ?params)))
    ;; Silent error for unknown notifications

(λ handle [server send msg]
  "Figures out what to do with a message.
This can involve updating the state of the server, and/or sending messages to the
server.

Takes:
* `server`, which is the state of the server,
* `send`, which is a callback for sending responses, and
* `msg`, which is the message to receive."
  (case (values msg (type msg))
    {:jsonrpc "2.0" : id : method :params ?params}
    (handle-request server send id method ?params)
    {:jsonrpc "2.0" : method :params ?params}
    (handle-notification server send method ?params)
    {:jsonrpc "2.0" : id : result}
    (handle-response server send id result)
    {:jsonrpc "2.0" : id :error err}
    (handle-bad-response server send id err)
    (str :string)
    (send (message.create-error :ParseError str))
    _
    (send (message.create-error :BadMessage nil msg.id))))

(λ handle* [server msg]
  "handles a message, and returns all the responses in a table"
  (let [out []]
    (handle server (partial table.insert out) msg)
    out))

{: handle
 : handle*}
