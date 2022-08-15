"Util
A collection of utility functions. Many of these convert data between a
Language-Server-Protocol representation and a Lua representation.
These functions are all pure functions, which makes me happy."

(λ startswith [str pre]
  (let [len (length pre)]
    (= (str:sub 1 len) pre)))

(λ uri->path [uri]
  (local prefix "file://")
  (assert (startswith uri prefix))
  (string.sub uri (+ (length prefix) 1)))

(λ path->uri [path]
  (.. "file://" path))

(λ next-line [str ?from]
  "Find the start of the next line from a given byte offset, or from the start of the string."
  (let [from (or ?from 1)]
    (match (str:find "[\r\n]" from)
      i (+ i (length (str:match "\r?\n?" i)))
      nil nil)))

(λ pos->byte [str line col]
  "convert a 0-indexed line and column into a 1-indexed byte. Doesn't yet handle UTF8 UTF16 magic from the protocol"
  (var sofar 1)
  (for [i 1 line :until (not sofar)]
    (set sofar (next-line str sofar)))
  (if sofar
    (+ sofar col)
    nil))

(λ byte->pos [str byte]
  "convert a 1-indexed byte into a 0-indexed line and column. Doesn't yet handle UTF8 UTF16 magic from the protocol"
  (local up-to (str:sub 1 (- byte 1)))
  (var lines 0)
  (var pos 1)
  (var prev nil)
  (while (do (set prev pos)
             (set pos (next-line up-to pos))
             pos)
    (set lines (+ 1 lines)))
  (values lines (+ (length up-to) (- prev) 1)))

(λ replace [text start-line start-col end-line end-col replacement]
  "Replaces a range of text with a replacement, using the protocol's definition of range. Doesn't yet handle UTF8 UTF16 magic from the protocol"
  (let [start (pos->byte text start-line start-col)
        end   (pos->byte text end-line   end-col)]
    (..
      (text:sub 1 (- start 1))
      replacement
      (text:sub end))))

(λ apply-changes [initial-text contentChanges]
  "Takes a list of Language-Server-Protocol `contentChanges` and applies them to a piece of text. Doesn't yet handle UTF8 UTF16 magic from the protocol"
  (accumulate
    [contents initial-text
     _ change (ipairs contentChanges)]
    (match change
      ;; Handle a change
      {:range {: start : end} : text}
      (replace contents
        start.line
        start.character
        end.line
        end.character
        text)
      ;; A replacment of the entire body
      {: text}
      text)))

(λ get-ast-info [?ast info]
  ;; find a given key of info from an AST object
  (or (?. (getmetatable ?ast) info)
      (. ?ast info)))

(fn multi-sym-split [sym ?offset]
  (local sym (tostring sym))
  (local offset (or ?offset (length sym)))
  (local next-separator (or (sym:find ".[%.:]" offset)
                            (length sym)))
  (local sym (sym:sub 1 next-separator))
  (icollect [word (: (.. sym ".") :gmatch "(.-)[%.:]")]
    word))

(λ type= [val typ]
  (= (type val) typ))

{: uri->path
 : path->uri
 : pos->byte
 : byte->pos
 : apply-changes
 : multi-sym-split
 : get-ast-info
 : type=}
