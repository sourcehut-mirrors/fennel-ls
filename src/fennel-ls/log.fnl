"Log
In the Language Server Protocol, io.stdout is used to send messages to the client.
Because of this, I need another way to do print-debugging."

(local fennel (require :fennel))
(local disable-logs false)
(if disable-logs
  {:log #nil}
  (let [logdocument (io.open "/tmp/fennel.log" "w")]
    (assert logdocument)
    (fn log [...]
      (let [args []]
        (for [i 1 (select :# ...)]
          (table.insert args
            (let [item (select i ...)]
              (match (values item (type item))
                (str :string) str
                ?any (fennel.view ?any)))))
        (logdocument:write (table.concat args) "\n")))
    {: log}))
