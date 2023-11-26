(local dispatch (require :fennel-ls.dispatch))
(local json-rpc (require :fennel-ls.json-rpc))
(local state (require :fennel-ls.state))
(local diagnostics (require :fennel-ls.diagnostics))

(λ check [filename]
  (let [server (doto {}
                 (dispatch.handle* {:id 1
                                    :jsonrpc "2.0"
                                    :method "initialize"
                                    :params {:capabilities {}
                                             :clientInfo {:name "fennel-ls"}
                                             :rootUri "file://"}}))
        file (state.get-by-uri server (.. "file://" filename))]
    (diagnostics.check server file)
    (each [_ {: message :range {: start}} (ipairs file.diagnostics)]
      (print (: "%s:%s:%s %s" :format filename
                ;; LSP line numbers are zero-indexed, but Emacs and Vim both use
                ;; 1-indexing for this.
                (+ (or start.line 0) 1) (or start.character "?") message)))))

(λ main-loop [in out]
  (local send (partial json-rpc.write out))
  (local state [])
  (while true
    (let [msg (json-rpc.read in)]
      (dispatch.handle state send msg))))

(λ main []
  (case arg
    ["--check" & filenames] (each [_ filename (ipairs filenames)]
                              (check filename))
    (where (or ["--server"] [nil])) (main-loop (io.input)
                                               (io.output))
    _args (do (io.stderr:write "USAGE: fennel-ls [--check file] [--server]\n")
              (os.exit 1))))

(main)
