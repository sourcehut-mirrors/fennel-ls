(local fennel (require :fennel))
(local fls (require :fls))
(local {: run} (require :fennel-ls))
(local {: make-error-message} (require :fls.error))

(λ main-loop [in out state]
  (while
    (let [msg (fls.io.read in)]
        (fls.log.log msg)
        (-?>> msg
          (run state)
          (fls.io.write out))
      msg)))

(λ main []
  (main-loop
    (io.input)
    (io.output)
    (fls.state.new-state)))

(main)
