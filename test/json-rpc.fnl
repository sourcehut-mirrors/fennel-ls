(local faith (require :faith))
(local stringio (require :pl.stringio))
(local json-rpc (require :fennel-ls.json-rpc))

(fn test-read []
  (let [out (stringio.open "Content-Length: 29\r\n\r\n{\"my json content\":\"is cool\"}")]
    (faith.= {"my json content" "is cool"} (json-rpc.read out)))

  (let [out (stringio.open "Content-Length: 29\r\n\r\n{\"my json content\":\"is cool\"}Content-Length: 29\r\n\r\n{\"my json content\":\"is neat\"}")]
    (faith.= {"my json content" "is cool"} (json-rpc.read out))
    (faith.= {"my json content" "is neat"} (json-rpc.read out))
    (faith.= nil (json-rpc.read out)))

  (let [out (stringio.open "Content-Length: 9\r\n\r\n{{{{{}}}}")]
    (faith.= :string (type (json-rpc.read out)) "json-rpc returns a table on successful read, and a string on unsuccessful read. It's jank and should probably be replaced with an ok, err system")))

(fn test-write []
  (let [in (stringio.create)]
    (json-rpc.write in {"my json content" "is cool"})
    (faith.= "Content-Length: 29\r\n\r\n{\"my json content\":\"is cool\"}"
                 (in:value))))

{: test-read
 : test-write}
