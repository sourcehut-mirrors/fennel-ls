(local faith (require :faith))

;; TODO refactor fennel-ls.check to avoid running end-to-end
;; (but keep/write at least some end-to-end tests)
(fn test-check []
  (let [input-file-name (os.tmpname)]
    (doto (io.open input-file-name :w)
      (: :write "(local x 1)")
      (: :close))
    (let [output-file (io.popen (.. "./fennel-ls --lint "
                                    input-file-name)
                                :r)]
      (faith.= (.. input-file-name ":1:7: unused definition: x\n")
               (output-file:read :*a))
      (os.remove input-file-name))
    nil))

{: test-check}
