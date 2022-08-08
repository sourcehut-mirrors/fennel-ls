(local core (require :fennel-ls.core))
(local json-rpc (require :fennel-ls.json-rpc))

(λ main-loop [in out]
  (local send (partial json-rpc.write out))
  (local state [])
  (while true
    (let [msg (json-rpc.read in)]
      (core.handle state send msg))))

(λ main []
  (main-loop
    (io.input)
    (io.output)))

(main)
