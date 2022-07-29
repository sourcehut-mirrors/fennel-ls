" Language Server Protocol I/O

This module implements the parsing and formatting needed to read/write messages using the language server protocol.
There are only two functions exposed here:

* `read` receives a message from the client.
* `write` sends a message to the client."

;; TODO find json library that doesn't conflate missing fields with null
(local {: encode : decode} (require :json.json))
(local {: split} (require :pl.stringx))

(λ read-header [in ?header]
  (let [header (or ?header {})]
    (match (in:read)
      "\r" header ;; hit an empty line, I'm done reading
      nil nil ;; hit end of stream, return nil
      ;; reading an actual line
      header-line
      (let [[k v] (split header-line ": " 2)]
        (tset header k (string.sub v 1 -2))
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
  (read-n in (tonumber header.Content-Length)))

(λ read [in]
  "Reads the next Language Server Protocol message from the given input stream"
  (let [(_success? result)
        (-?>>
          (read-header in)
          (read-content in)
          (pcall decode))]
    result))


(λ write [out msg]
  "Writes a Language Server Protocol message to the given output stream"
  (let [content (encode msg)
        msg-stringified (.. "Content-Length: " (length content) "\r\n\r\n" content)]
    (out:write msg-stringified)
    (when out.flush
      (out:flush))))

{: read
 : write}
