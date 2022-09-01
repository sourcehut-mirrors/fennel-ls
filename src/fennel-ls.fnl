(local dispatch (require :fennel-ls.dispatch))
(local json-rpc (require :fennel-ls.json-rpc))

(local log (io.open "/home/xerool/Documents/projects/fennel-ls/log.txt" "w"))
(local {: view} (require :fennel))

(λ main-loop [in out]
  (local send (partial json-rpc.write out))
  (local state [])
  (while true
    (let [msg (json-rpc.read in)]
      (log:write (view msg) "\n")
      (log:flush)
      (dispatch.handle state send msg))))

(λ main []
  (main-loop
    (io.input)
    (io.output)))

(main)
