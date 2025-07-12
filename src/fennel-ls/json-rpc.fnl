"JSON-RPC
This module implements the parsing and formatting code needed to read/write messages over the language server protocol.
There are only two functions exposed here:

* `read` receives and parses a message from the client.
* `write` serializes and sends a message to the client.

It's probably not compliant yet, because serialization of [] and {} is the same.
Luckily, I'm testing with Neovim, so I can pretend these problems don't exist for now."

(local {: encode : decode} (require :dkjson))
(local http-separator
       (if (string.match package.config "^\\")
           "\n\n"
           "\r\n\r\n"))

(λ read-header [in ?header]
  "Reads the header of a JSON-RPC message"
  (let [header (or ?header {})]
    (case (in:read)
      nil nil ;; I've hit end of stream, return nil instead of a header
      line (case (line:match "^(.-)\r?$") ;; strip trailing \r
             "" header ;; base case. empty line marks end of header
             line (let [(k v) (line:match "^(.-): (.-)$")]
                    (if (not (and k v))
                      (error (.. "fennel-ls encountered a malformed json-rpc header: \"" line "\"")))
                    (tset header k v)
                    (read-header in header))))))

(λ read-n [in len ?buffer]
  "read a string of exactly `len` characters from the `in` stream.
If there aren't enough bytes, return nil"
  (local buffer (or ?buffer []))
  (if (<= len 0)
    (table.concat buffer)
    (case (in:read len)
      content
      (read-n in
              (- len (length content))
              (doto buffer (table.insert content))))))

(λ read-content [in header]
  "Reads the content of a JSON-RPC message given the header"
  (read-n in (tonumber header.Content-Length)))

(λ read [in]
  "Reads and parses a JSON-RPC message from the input stream
Returns a table with the message if it succeeded, or a string with the parse error if it fails."
  (let [(?result _?err-pos ?err)
        (-?>> (read-header in)
          (read-content in)
          decode)]
    (or ?result ?err)))

(λ write [out msg]
  "Serializes and writes a JSON-RPC message to the given output stream"
  (let [content (encode msg)
        msg-stringified (.. "Content-Length: " (length content) http-separator content)]
    (out:write msg-stringified)
    (when out.flush
      (out:flush))))

{: read
 : write}
