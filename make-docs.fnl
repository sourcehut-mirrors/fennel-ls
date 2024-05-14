"Script to generate /src/fennel-ls/docs/lua54.fnl and friends automatically"

(fn open-file-cached [filename url]
  (var file (io.open filename :r))
  (when (not file)
    ;; I think the repos also have the html file (or the ability to generate it, depending on lua version)
    ;; but for simplicity I'm just grabbing the html straight from the website
    (print (.. "Downloading " url))
    (os.execute (.. "curl " url " > " filename))
    (set file (io.open filename :r)))
  file)

(fn parse-html [html]
  "splits the lua manual into the relevant sections"
  (let [begin-index (assert (html:find "<h2>.%.1 &ndash; <a name=\".%.1\">Basic Functions.-\n") "no basic functions?")
        end-index (assert (html:find "<h1>. &ndash; <a name=\".\".-\n" begin-index))
        stdlib (html:sub begin-index (- end-index 1))
        fields []
        modules []]
    (fn loop [prev]
      (let [header (stdlib:find "<hr><h3>.-\n" (+ prev 1))
            section (stdlib:sub prev (if header (- header 1)))]
        (let [index (section:find "<h2>")]
          (if index
            (do
              (table.insert fields (section:sub 1 (- index 1)))
              (table.insert modules (section:sub index)))
            (table.insert fields section)))
        (when header (loop header))))
    (loop (stdlib:find "<hr><h3>.-\n"))
    (values modules fields)))

(fn html-to-markdown [str]
  (let [str
        (-> str
          ;; delete <p> tags
          (: :gsub "</?p>" "")
          ;; <code> tags for the rest
          (: :gsub "\"<code>(.-)</code>\"" "`\"%1\"`")
          (: :gsub "\'<code>(.-)</code>\'" "`\"%1\"`")
          (: :gsub "<code>(.-)</code>" "`%1`")
          (: :gsub "<sup>x</sup>" "ˣ")
          (: :gsub "<sup>e</sup>" "ᵉ")
          (: :gsub "<sup>y</sup>" "ʸ")
          (: :gsub "<sup>51</sup>" "⁵¹")
          (: :gsub "<sup>32</sup>" "³²")
          ; ᵃᵇᶜᵈᵉᶠᵍʰⁱʲᵏˡᵐⁿᵒᵖ𐞥ʳˢᵗᵘᵛʷˣʸᶻ
          ;; bold to **
          (: :gsub "<em>([^<]+)</em>" "*%1*")
          (: :gsub "<b>([^<]+)</b>" "**%1**")
          ;; defeat all the links
          (: :gsub "<a name=\"pdf%-[^\"]+\">([^<]+)</a>" "%1")
          (: :gsub "<a href=\"#pdf%-[^\"]+\">([^<]+)</a>" "%1")
          (: :gsub "<a href=\"#lua_[^\"]+\">([^<]+)</a>" "%1")
          (: :gsub "See <a href=\"#[^\"]+\">[^<]+</a>[^%.]+%." "")
          (: :gsub "[ \n]%(see <a href=\"#[^\"]+\">[^<]+</a>%)." "")
          (: :gsub "[ \n]%(<a href=\"#[^\"]+\">[^<]+</a>%)." "")
          ;; code blocks
          (: :gsub "<pre>\n?([^<]+)\n?</pre>" "```lua\n%1\n```")
          ;; list items to indented * thingies
          (: :gsub "<li>([^<]+)</li>" #(.. "* " ($:gsub "\n" "\n  ")))
          (: :gsub "</?ul>" ""))
        ;; check to ensure that all the tags have been defeated
        tag (str:match "<[^>]+>[^>]+>")]
    (when tag (error (.. tag "\n" str)))
    (-> str
      ;; trim whitespace
      (: :match "^%s*(.-)%s*$")
      ;; html things
      (: :gsub "&nbsp;" " ")
      (: :gsub "&ndash;" "–")
      (: :gsub "&mdash;" "—")
      ;; For some reason, they use an html middot, but we want to use periods.
      (: :gsub "&middot;&middot;&middot;" "...")
      (: :gsub "&gt;" ">")
      (: :gsub "&lt;" "<")
      (: :gsub "&amp;" "<")
      (: :gsub "&pi;" "π")
      (: :gsub "\n\n+" "\n\n"))))

(fn parse-h3-section [html]
  "parse a section that starts with an h3 tag. These are individual functions/variables."
  (let [(header description) (html:match "^(.-)\n+(.-)\n*$")
        optional-args []
        signature (header:match "<code>(.-)</code>")
        ;; strip commas
        signature (signature:gsub "," " ")
        ;; Replace `[]`'d args with ?-prefixes
        ;; Three times is enough, as `table.concat` and `load` and `loadfile`
        ;; and `utf8.codepoint` and `utf8.len` have 3 sets of []'s.
        ;; Lua 5.2 manual has a typo, so the last pass makes the `]` optional.
        signature (signature:gsub "%[ -([^%[%] ]+)([^%[%]]-)%](%]-%))"
                                  #(do (table.insert optional-args $1) (.. :? $1 $2 $3)))
        signature (signature:gsub "%[ -([^%[%] ]+)([^%[%]]-)%](%]-%))"
                                  #(do (table.insert optional-args $1) (.. :? $1 $2 $3)))
        signature (signature:gsub "%[ -([^%[%] ]+)([^%[%]]-)%]?(%]-%))"
                                  #(do (table.insert optional-args $1) (.. :? $1 $2 $3)))
        ;; hide the thread argument in the debug functions
        signature (if (signature:find "debug") (signature:gsub "%[thread -%]" "") signature)
        ;; hide the ?pos argument in table.insert
        signature (if (signature:find "table%.insert") (signature:gsub "%[pos -%]" "") signature)
        ;; For some reason, they use an html middot, but we want to use periods.
        signature (signature:gsub "&middot;&middot;&middot;" "...")
        ;; fix parens
        signature (signature:gsub "^(.-) -%(" "(%1 ")
        ;; fix spaces
        signature (signature:gsub " +" " ")
        signature (signature:gsub " +%)" ")")

        ;; <code> tags for optional args
        description (accumulate [description description _ arg (ipairs optional-args)]
                      (description:gsub (.. "<code>" arg "</code>")
                                        (.. "`?" arg "`")))
        ;; trim off the string pattern and string.pack/string.unpack format docs
        description (description:gsub "\n[^\n]*<h3>.*" "")
        description (html-to-markdown description)
        name (signature:match "[^() ]+")
        key (name:match "[^.:]+$")
        ?module (and (name:find "[.:]") (name:match "^[^.:]+"))]

    (values ?module
            key
            {:binding (signature:match "[^() ]+")
             :metadata {:fnl/docstring description}})))

(fn parse-h2-section [html]
  "parse a section that starts with an h2 tag. These are the main modules."
  (let [(title description) (html:match "(.-)\n(.*)")
        module-name  (if (title:find "Coroutine")
                         "coroutine"
                         (title:find "Modules")
                         "package"
                         (title:find "String")
                         "string"
                         (title:find "UTF")
                         "utf8"
                         (title:find "Mathematical")
                         "math"
                         (title:find "Input and Output")
                         "io"
                         (title:find "Operating System")
                         "os"
                         (title:find "Debug")
                         "debug"
                         (title:find "Bitwise")
                         "bit32"
                         (title:find "Table")
                         "table")
        description (html-to-markdown description)]
    (assert module-name title)
    (values module-name
            {:binding module-name
             :fields {}
             :metadata {:fnl/docstring description}})))


(fn main []
  (each [_ version (ipairs [:5.1 :5.2 :5.3 :5.4])]
    (let [infile (open-file-cached
                   (.. "lua" version ".html")
                   (.. "https://www.lua.org/manual/" version "/manual.html"))
          (modules module-items) (parse-html (infile:read :a))
          docs
          (collect [_ module (ipairs modules)]
            (parse-h2-section module))]

      (each [_ section (ipairs module-items)]
        (let [(mod k v) (parse-h3-section section)]
          (if (not mod)
              (tset docs k v)
              (not= mod "file")
              (do
                (assert (. docs mod) (.. mod " not found"))
                (tset (. docs mod :fields) k v)))))

      (print (.. "Emitting docs for lua" version))
      (let [outfile (io.open (.. "src/fennel-ls/docs/lua" (version:gsub "%." "") ".fnl") :w)]
        (local {: view : sym : list} (require :fennel))
        (outfile:write
          (view (list (sym :local) (sym :docs) docs))
          "\n"
          "(set docs._G.fields docs)\n"
          "docs\n"))
      (print (.. "Emitted docs for lua" version)))))

(main)
