(import-macros {: it! : describe!} :test.macros)
(local assert (require :luassert))

(local fennel (require :fennel))
(local stringio (require :pl.stringio))
(local fls (require :fls))
(local {: run} (require :fennel-ls))

(describe! "fls.protocol"
  (it! "parses incoming messages"
    (let [out (stringio.open "Content-Length: 29\r\n\r\n{\"my json content\":\"is cool\"}")]
      (assert.same {"my json content" "is cool"}
                   (fls.protocol.read out))))

  (it! "serializes outgoing messages"
    (let [in (stringio.create)]
      (fls.protocol.write in {"my json content" "is cool"})
      (assert.same "Content-Length: 29\r\n\r\n{\"my json content\":\"is cool\"}"
                   (in:value))))

  (it! "can read multiple incoming messages"
    (let [out (stringio.open "Content-Length: 29\r\n\r\n{\"my json content\":\"is cool\"}Content-Length: 29\r\n\r\n{\"my json content\":\"is cool\"}")]
      (assert.same {"my json content" "is cool"}
                   (fls.protocol.read out))
      (assert.same {"my json content" "is cool"}
                   (fls.protocol.read out))
      (assert.same nil
                   (fls.protocol.read out))))

  (it! "can report the ParseError code"
    (let [out (stringio.open "Content-Length: 9\r\n\r\n{{{{{}}}}")]
      (assert
        (match (run [] (fls.protocol.read out))
          {:error {:code -32700} :jsonrpc "2.0"}
          true
          otherwise (values false (fennel.view otherwise)))))))
