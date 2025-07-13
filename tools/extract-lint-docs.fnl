"Script to generate docs/lints.md from the embedded documentation in lint.fnl"

(local lint (require :fennel-ls.lint))

(fn strip-indentation [text]
  "Remove common leading whitespace from multiline strings"
  (let [lines (icollect [line (text:gmatch "[^\n]*")]
                line)
        ;; Find minimum indentation from lines 2+ (ignoring empty lines)
        min-indent (accumulate [min-spaces math.huge i line (ipairs lines)]
                     (if (or (= i 1) (line:find "^%s*$"))
                         min-spaces  ; skip first line and empty lines
                         (math.min min-spaces (- (line:find "[^%s]") 1))))]
    ;; Only strip if we found indentation
    (if (and (not= min-indent math.huge) (< 0 min-indent))
        (table.concat
          (icollect [i line (ipairs lines)]
            (if (or (= i 1) (line:find "^%s*$"))
                line
                (line:sub (+ min-indent 1))))
          "\n")
        text)))

(fn main []
  "Convert lint info to markdown format"
  (each [_ lint-info (ipairs lint.list)]
    (print (.. "# " lint-info.name
               (if lint-info.disabled " (off by default)" "")))
    (when lint-info.what-it-does
      (print "## What it does")
      (print (strip-indentation lint-info.what-it-does))
      (print ""))
    (when lint-info.why-care?
      (print "## Why is this bad?")
      (print (strip-indentation lint-info.why-care?))
      (print ""))
    (when lint-info.example
      (print "## Example")
      (print (strip-indentation lint-info.example))
      (print))
    (when lint-info.limitations
      (print "## Known limitations")
      (print (strip-indentation lint-info.limitations))
      (print))))

(main)