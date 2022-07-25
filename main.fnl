(local fennel (require :fennel))
(local {: read-message : write-message} (require :lsp-io))
(local {: handle} (require :fennel-ls))

(λ main-loop [in out]
  (let [msg (read-message in)]
    (when msg
      (let [response (handle msg)]
        (when response
          (write-message out response))
        (main-loop in out)))))

(λ main []
  (main-loop (io.input) (io.output)))

(main)
