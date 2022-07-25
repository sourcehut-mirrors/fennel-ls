(local {: encode : decode} (require :json.json))
(local {: split} (require :pl.stringx))

(λ read-header [in ?header]
  (let [header (or ?header {})]
    (match (in:read)
      ;; base cases
      "\r" header
      nil nil
      ;; reading an actual line
      header-line
      (let [[k v] (split header-line ": " 2)]
        (tset header k (string.sub v 1 -2))
        (read-header in header)))))

(λ read-content [in header]
  (let [len (tonumber header.Content-Length)
        buffer []]
    ;; TODO make this code as tolerable as possible
    (var sofar 0)
    (var currently-read-bytes nil)
    (while
      (and (< sofar len)
           (do (set currently-read-bytes (in:read (- len sofar)))
               currently-read-bytes))
      (set sofar (+ sofar (length currently-read-bytes)))
      (table.insert buffer currently-read-bytes))
    (decode (table.concat buffer))))


(λ read-message [in]
  (match (read-header in)
    header (read-content in header)
    nil nil))

(λ write-message [out msg]
  (let [content (encode msg)
        msg-stringified (.. "Content-Length: " (length content) "\r\n\r\n" content)]
    (out:write msg-stringified)
    (when out.flush
      (out:flush))))

{: read-message
 : write-message}
