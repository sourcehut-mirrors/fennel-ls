(fn sh [...]
  "run a shell command."
  (let [command (table.concat
                  (icollect [_ arg (ipairs [...])]
                      (if
                        ;; table skips escaping
                        (= (type arg) :table)
                        (. arg 1)
                        ;; simple string skips escaping
                        (arg:find "^[a-zA-Z0-9/_%.-]+$")
                        arg
                        ;; full escaping
                        (.. "'"
                            (string.gsub arg "'" "\\'")
                            "'")))
                  " ")]
    (print (.. "running command: " command))
    (assert (os.execute command))))

{: sh}
