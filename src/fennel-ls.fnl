(require :fennel)
(local dispatch (require :fennel-ls.dispatch))
(local json-rpc (require :fennel-ls.json-rpc))
(local files (require :fennel-ls.files))

(fn print-diagnostic [filename message ?range]
  (print (: "%s:%s:%s: %s" :format filename
            ;; LSP line numbers are zero-indexed, but Emacs and Vim both use
            ;; 1-indexing for this.
            (+ (or (?. ?range :start :line) 0) 1)
            (or (?. ?range :start :character) "?") message)))

(fn initialize [server]
  (let [params {:id 1
                :jsonrpc "2.0"
                :method "initialize"
                :params {:capabilities {:general {:positionEncodings [:utf-8]}}
                         :clientInfo {:name "fennel-ls"}
                         :rootUri "file://."}}]
    (each [_ response (ipairs (dispatch.handle* server params))]
      (case response
        {:method "window/showMessage" :params {: message}}
        (print "WARN:" message)))))

(λ lint [filenames]
  "non-interactive mode that gets executed from CLI with --lint.
   runs lints on each file, then formats and prints them"
  (let [lint (require :fennel-ls.lint)
        server (doto {} initialize)]
    (var should-err? false)
    (each [_ filename (ipairs filenames)]
      (let [file (files.get-by-uri server (.. "file://" filename))]
        (lint.add-lint-diagnostics server file)
        (each [_ {: message : range} (ipairs file.diagnostics)]
          (set should-err? true)
          (print-diagnostic filename message range))))
    (when should-err?
      (os.exit 1))))

(λ main-loop [in out]
  (local send (partial json-rpc.write out))
  (local server {})
  (while true
    (let [msg (json-rpc.read in)]
      (dispatch.handle server send msg))))

(λ main []
  (case arg
    ["--lint" & filenames] (lint filenames)
    (where (or ["--server"] [nil])) (main-loop (io.input)
                                               (io.output))
    _args (do (io.stderr:write "USAGE: fennel-ls [--lint file] [--server]\n")
              (os.exit 1))))

(main)
