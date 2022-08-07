(import-macros {: is-matching : describe : it} :test.macros)
(local is (require :luassert))

(local fennel (require :fennel))
(local stringio (require :test.pl.stringio))
(local json-rpc (require :fennel-ls.json-rpc))

(describe "json-rpc"
  (describe "read"
    (it "parses incoming messages"
      (let [out (stringio.open
                  "Content-Length: 29\r\n\r\n{\"my json content\":\"is cool\"}")]
        (is.same
          {"my json content" "is cool"}
          (json-rpc.read out))))

    (it "can read multiple incoming messages"
      (let [out (stringio.open
                  "Content-Length: 29\r\n\r\n{\"my json content\":\"is cool\"}Content-Length: 29\r\n\r\n{\"my json content\":\"is neat\"}")]
        (is.same
          {"my json content" "is cool"}
          (json-rpc.read out))
        (is.same
          {"my json content" "is neat"}
          (json-rpc.read out))
        (is.same
          nil
          (json-rpc.read out))))

    (it "can report compiler errors"
      (let [out (stringio.open "Content-Length: 9\r\n\r\n{{{{{}}}}")]
        (is (= (type (json-rpc.read out)) :string)))))

  (describe "write"
    (it "serializes outgoing messages"
      (let [in (stringio.create)]
        (json-rpc.write in {"my json content" "is cool"})
        (is.same "Content-Length: 29\r\n\r\n{\"my json content\":\"is cool\"}"
                     (in:value))))))
