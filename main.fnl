(local
  {: handle
   : send-message
   : receive-message}
  (require "fennel-ls"))

(λ main []
  (local in (io.input))
  (local out (io.output))
  (while
    (match (receive-message in)
      msg
      (do
       (let [response (handle msg)]
         (if msg.id
           (send-message out response)))
       true)
      _ nil)))

(main)
