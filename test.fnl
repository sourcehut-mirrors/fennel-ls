(local {: handle} (require :fennel-ls))
(local {: read-message : write-message} (require :lsp-io))
(local stringio (require :pl.stringio))
(local {: view} (require :fennel))
(local busted (require :busted))

((require :busted.runner))

(macro it! [title ...]       `(busted.it ,title (fn [] ,...)))
(macro describe! [title ...] `(busted.describe ,title (fn [] ,...)))

(describe! "fennel-ls"

  (it! "parses incoming messages"
    (let [out (stringio.open "Content-Length: 29\r\n\r\n{\"my json content\":\"is cool\"}")]
      (assert.same {"my json content" "is cool"}
                   (read-message out))))

  (it! "serializes outgoing messages"
    (let [in (stringio.create)]
      (write-message in {"my json content" "is cool"})
      (assert.same "Content-Length: 29\r\n\r\n{\"my json content\":\"is cool\"}"
                   (in:value))))

  (it! "can read multiple messages"
    (let [out (stringio.open "Content-Length: 29\r\n\r\n{\"my json content\":\"is cool\"}Content-Length: 29\r\n\r\n{\"my json content\":\"is cool\"}")]
      (assert.same {"my json content" "is cool"}
                   (read-message out))
      (assert.same {"my json content" "is cool"}
                   (read-message out))
      (assert.same nil
                   (read-message out))))

  (it! "responds to initialize"
    (local initialize-message
      {:id 1
       :jsonrpc "2.0"
       :method "initialize"
       :params
         {:capabilities {}
          :clientInfo {:name "Neovim" :version "0.7.2"}
          :initializationOptions {}
          :processId 16245
          :rootPath "/home/xerool/Documents/projects/fennel-ls"
          :rootUri "file:///home/xerool/Documents/projects/fennel-ls"
          :trace "off"
          :workspaceFolders [{:name "/home/xerool/Documents/projects/fennel-ls"
                              :uri "file:///home/xerool/Documents/projects/fennel-ls"}]}})
    (assert
      (match (handle initialize-message)
        {:id 1
         :jsonrpc "2.0"
         :result {:capabilities {}
                  :serverInfo {:name "fennel-ls" : version}}}
        true
        otherwise (values false (view otherwise))))))

