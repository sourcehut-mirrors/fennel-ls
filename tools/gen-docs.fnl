"Script to generate /src/fennel-ls/docs/lua54.fnl and friends automatically"

(fn sh [...]
  "run a shell command."
  (let [command (table.concat
                  (icollect [_ arg (ipairs [...])]
                      (if
                        ;; table skips escaping
                        (= (type arg) :table)
                        (. arg 1)
                        ;; simple string skips escaping
                        (arg:find "^[a-zA-Z0-9/_-]+$")
                        arg
                        ;; full escaping
                        (.. "'"
                            (string.gsub arg "'" "\\'")
                            "'")))
                  " ")]
    (print (.. "tools/gen-docs: " command))
    (os.execute command)))

(fn mkdir-p [dirname]
  (sh "mkdir" "-p" dirname))

(fn open-file-cached [filename url]
  (var file (io.open filename :r))
  (when (not file)
    ;; I think the repos also have the html file (or the ability to generate it, depending on lua version)
    ;; but for simplicity I'm just grabbing the html straight from the website
    (sh "curl" url [">"] filename)
    (set file (io.open filename :r)))
  file)


(fn main []
  (mkdir-p "build")
  (let [lua-manual-parser (require :tools.gen-docs.lua-manual)]
    (each [_ version (ipairs [:5.1 :5.2 :5.3 :5.4])]
      (let [html-filename (.. "build/lua" version ".html")
            url (.. "https://www.lua.org/manual/" version "/manual.html")
            infile (open-file-cached html-filename url)
            contents (infile:read "*a")
            _ (infile:close)
            docfile (lua-manual-parser.html-to-docfile contents version)
            outfilename (.. "src/fennel-ls/docs/lua" (version:gsub "%." "") ".fnl")]
        (print (.. "tools/gen-docs: writing " outfilename))
        (doto (io.open outfilename "w")
              (: :write docfile)
              (: :close))))))

(main)
