"JSON-RPC
This module implements the parsing and formatting code needed to read/write messages over the language server protocol.
There are only two functions exposed here:

* `read` receives and parses a message from the client.
* `write` serializes and sends a message to the client.

It's probably not compliant yet, because serialization of [] and {} is the same,
and there are also some places where a field has to be present, but filled with null.

Luckily, I'm testing with Neovim, so I can pretend these problems don't exist for now."

;; TODO find json library that doesn't conflate missing fields with null
(local {: encode : decode} (require :json.json))

(λ read-header [in ?header]
  "Reads the header of a JSON-RPC message"
  (let [header (or ?header {})]
    (match (in:read)
      "\r" header ;; hit an empty line, I'm done reading
      nil nil ;; hit end of stream, return nil
      ;; reading an actual line
      header-line
      (let [sep (string.find header-line ": ")
            k (string.sub header-line 1 (- sep 1))
            v (string.sub header-line (+ sep 2) -2)] ;; trim off the \r
        (tset header k v)
        (read-header in header)))))

(λ read-n [in len ?buffer]
  "read a string of exactly `len` characters from the `in` stream.
If there aren't enough bytes, return nil"
  (local buffer (or ?buffer []))
  (if (<= len 0)
    (table.concat buffer)
    (match (in:read len)
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
  (let [(_success? result)
        (-?>> (read-header in)
          (read-content in)
          (pcall decode))]
    result))


(λ write [out msg]
  "Serializes and writes a JSON-RPC message to the given output stream"
  (let [content (encode msg)
        msg-stringified (.. "Content-Length: " (length content) "\r\n\r\n" content)]
    (out:write msg-stringified)
    (when out.flush
      (out:flush))))

{: read
 : write}
