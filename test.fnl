(local fennel (require :fennel))
(local fls (require :fls))
(local stringio (require :pl.stringio))
(local stringx (require :pl.stringx))
(local {: run} (require :fennel-ls))

(local busted (require :busted))
((require :busted.runner))

(macro it! [title ...]       `(busted.it ,title (fn [] ,...)))
(macro describe! [title ...] `(busted.describe ,title (fn [] ,...)))

(describe! "fennel-ls"

  (describe! "fls.io"
    (it! "parses incoming messages"
      (let [out (stringio.open "Content-Length: 29\r\n\r\n{\"my json content\":\"is cool\"}")]
        (assert.same {"my json content" "is cool"}
                     (fls.io.read out))))

    (it! "serializes outgoing messages"
      (let [in (stringio.create)]
        (fls.io.write in {"my json content" "is cool"})
        (assert.same "Content-Length: 29\r\n\r\n{\"my json content\":\"is cool\"}"
                     (in:value))))

    (it! "can read multiple incoming messages"
      (let [out (stringio.open "Content-Length: 29\r\n\r\n{\"my json content\":\"is cool\"}Content-Length: 29\r\n\r\n{\"my json content\":\"is cool\"}")]
        (assert.same {"my json content" "is cool"}
                     (fls.io.read out))
        (assert.same {"my json content" "is cool"}
                     (fls.io.read out))
        (assert.same nil
                     (fls.io.read out))))

    (it! "can report the ParseError code"
      (let [out (stringio.open "Content-Length: 9\r\n\r\n{{{{{}}}}")]
        (assert
          (match (run [] (fls.io.read out))
            {:error {:code -32700} :jsonrpc "2.0"}
            true
            otherwise (values false (fennel.view otherwise)))))))

    ;; FIXME all of the other RPC codes

  (describe! "initialization"
    ;; TODO get rid of hardcoded paths here
    (it! "responds to initialize"
      (local initialize
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
        (match (run [] initialize)
          {:id 1
           :jsonrpc "2.0"
           :result {:capabilities {}
                    :serverInfo {:name "fennel-ls" : version}}}
          true
          otherwise (values false (fennel.view otherwise))))))

  (describe! "file syncing"
    (it! "can open files from disk"
      (local state (fls.state.new-state))
      (assert state)
      (local uri
        (-> (io.popen "pwd")
          (: :read :*a)
          (stringx.strip)
          (->> (.. "file://"))
          (.. "/test.fnl")))

      (fls.state.add-file state uri)
      (assert (. state :files uri))
      (assert.equal (. state :files uri :lines 1)
                    "(local fennel (require :fennel))"))))

