(local fennel (require :fennel))
(local fls (require :fls))
(local {: run} (require :fennel-ls))

(λ main-loop [in out state]
  (while
    (let [msg (fls.protocol.read in)]
        (fls.log.log msg)
        (-?>> msg
          (run state)
          (fls.protocol.write out))
      msg)))

(λ main []
  (main-loop
    (io.input)
    (io.output)
    (fls.state.new-state)))

(main)
