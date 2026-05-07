"JSON-RPC
This module implements the parsing and formatting code needed to read/write messages over the language server protocol.
There are only two functions exposed here:

* `read` receives and parses a message from the client.
* `write` serializes and sends a message to the client.

dkjson defaults to emitting [] when given an empty table, so we need to be
sure our object-like tables have at least one key, or we apply metatable magic
on the empty table to tell dkjson to serialize as {}."

(local {: encode : decode} (require :dkjson))
(local header-separator
       ;; Something in windows replaces \n with \r\n,
       ;; so we have to leave the \r's out
       (if (string.match package.config "^\\")
           "\n\n"
           "\r\n\r\n"))

(λ read-header [in ?header]
  "Reads the header of a JSON-RPC message"
  (let [header (or ?header {})
        line (assert (in:read) "EOF")]
    (case (line:match "^(.-)\r?$") ;; strip trailing \r
      "" header ;; base case. empty line marks end of header
      line (let [(k v) (line:match "^(.-): (.-)$")]
             (if (not (and k v))
                 (error (.. "fennel-ls encountered a malformed json-rpc header: \"" line "\"")))
             (tset header k v)
             (read-header in header)))))

(λ read-n [in len ?buffer]
  "read a string of exactly `len` characters from the `in` stream.
If there aren't enough bytes, return nil"
  (local buffer (or ?buffer []))
  (if (<= len 0)
    (table.concat buffer)
    (case (in:read len)
      content
      (do (table.insert buffer content)
          (read-n in (- len (length content)) buffer)))))

(λ read-content [in header]
  "Reads the content of a JSON-RPC message given the header"
  (let [n (assert (tonumber header.Content-Length) "fennel-ls: I expected a Content-Length header")]
    (read-n in n)))

(λ read [in]
  "Reads and parses a JSON-RPC message from the input stream
Returns a table with the message if it succeeded, or a string with the parse error if it fails."
  (let [(?result _?err-pos ?err)
        (-?>> (read-header in)
          (read-content in)
          decode)]
    (or ?result ?err)))

(var stdin-ready? nil)

(λ try-read [in]
  "If a message is available, get it, otherwise return nil without blocking"
  (set stdin-ready?
       (or stdin-ready?
         ;; lua-posix
         (case (pcall require :posix)
           (true posix) #(= 1 (posix.rpoll 0 0)))
         ;; unix + bash (slow)
         (if (and (package.config:find "^/")
                  (case (os.execute "bash --version > /dev/null") (where (or 0 true)) true))
           #(case (os.execute "bash -c 'read -t 0'") (where (or 0 true)) true))
         ;; give up
         #false))
  (when (stdin-ready?)
    (read in)))

(λ write [out msg]
  "Serializes and writes a JSON-RPC message to the given output stream"
  (let [content (encode msg)
        msg-stringified (.. "Content-Length: " (length content) header-separator content)]
    (out:write msg-stringified)
    (when out.flush
      (out:flush))))

{: read
 : try-read
 : write}
