"work in progress script to generate /src/fennel-ls/docs/lua54.fnl automatically"

(local version "5.4")
(local filename (.. "lua" version ".html"))
(var file (io.open filename :r))
(when (not file)
  ;; I think the repos also have the html file (or the ability to generate it, depending on lua version)
  ;; but for simplicity I'm just grabbing the html straight from the website
  (os.execute (.. "curl https://www.lua.org/manual/" version "/manual.html > lua" version ".html"))
  (set file (io.open filename :r)))

(local html (file:read :a))

;; The section about the standard library
(local begin-index (assert (html:find "<h2>.%.1 &ndash; <a name=\".%.1\">Basic Functions.-\n")))
(local end-index (assert (html:find "<h1>. &ndash; <a name=\".\".-\n" begin-index)))
(local stdlib (html:sub begin-index (- end-index 1)))


;; Each section split by <h3>
;; TODO figure out <h2>
(local sections [])
(fn loop [prev]
  (let [header (stdlib:find "<hr><h3>.-\n" (+ prev 1))
        section (stdlib:sub prev (if header (- header 1)))]
    (table.insert sections section)
    (when header (loop header))))
(loop (stdlib:find "<hr><h3>.-\n"))

;; I should probably split more of this file into functions like this
(fn process-html-thing [html-describing-the-thing]
  (let [(header description) (html-describing-the-thing:match "^(.-)\n+(.-)\n*$")
        optional-args []
        signature (header:match "<code>(.-)</code>")
        ;; Replace `[]`'d args with ?-prefixes
        ;; Three times is enough, as `table.concat` and `load` and `loadfile`
        ;; and `utf8.codepoint` and `utf8.len` have 3 sets of []'s.
        ;; Lua 5.2 manual has a typo, so the last pass makes the `]` optional.
        signature (signature:gsub "%[,? ?([^%[%] ]+)([^%[%]]-)%](%]-%))"
                                  #(do (table.insert optional-args $1) (.. :? $1 $2 $3)))
        signature (signature:gsub "%[,? ?([^%[%] ]+)([^%[%]]-)%](%]-%))"
                                  #(do (table.insert optional-args $1) (.. :? $1 $2 $3)))
        signature (signature:gsub "%[,? ?([^%[%] ]+)([^%[%]]-)%]?(%]-)%)"
                                  #(do (table.insert optional-args $1) (.. :? $1 $2 $3)))
        ;; For some reason, they use an html middot, but we want to use periods.
        signature (signature:gsub "&middot;&middot;&middot;" "...")]
    nil
    ;; Debug prints for now. I'm not sure how to process the description.
    (if (not (signature:match "%("))
      ;; (print "c" signature)
      nil
      (and (signature:match "[%[]")
           (not (signature:match "debug"))
           (not (signature:match "table.insert")))
      (do
        (print "========================" signature))
      (print "?" signature))))


(each [_ section (ipairs sections)]
  (process-html-thing section))
