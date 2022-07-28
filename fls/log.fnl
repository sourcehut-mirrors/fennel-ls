(local fennel (require :fennel))
(local disable-logs false)
(if disable-logs
  {:log #nil}
  (let [logfile (io.open "/tmp/fennel.log" "w")]
    (assert logfile)
    (fn log [...]
      (let [args []]
        (for [i 1 (select :# ...)]
          (table.insert args
            (let [item (select i ...)]
              (match (values item (type item))
                (str :string) str
                ?any (fennel.view ?any)))))
        (logfile:write (table.concat args) "\n")))
    {: log}))
