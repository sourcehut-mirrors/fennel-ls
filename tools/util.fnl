(fn try-sh [...]
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
                            (-> arg
                                (string.gsub "'" "'\\''")
                                (string.gsub "\n" "'\\n'"))
                            "'")))
                  " ")]
    (io.stderr:write "running command: " command "\n")
    (os.execute command)))

(fn sh [...]
  "run a shell command."
    (case (try-sh ...)
      ;; lua 5.1 success is reported as 0
      ;; lua 5.2+ success is reported as true
      (where (or true 0)) true
      _ (error "command did not succeed")))

(fn clone [location url ?tag]
  "Clones a git repository, given a location, url, and optional tag."
  (assert location "Expected file location to clone git repository into.")
  (assert url "Expected git repository url to clone.")
  (if ?tag
      (sh :git :clone :-c :advice.detachedHead=false :--depth=1 :--branch ?tag
          url location)
      (sh :git :clone :-c :advice.detachedHead=false :--depth=1 url location)))

(fn curl-cached [url]
  (let [filename (.. "build/" (url:gsub "[/:]" "_"))]
    (or (io.open filename)
        (do (sh "curl" url [">"] filename)
            (io.open filename)))))

{: sh : try-sh : clone : curl-cached}
