(require :fennel)
(local dispatch (require :fennel-ls.dispatch))
(local json-rpc (require :fennel-ls.json-rpc))
(local files (require :fennel-ls.files))
(local {: severity->string &as message} (require :fennel-ls.message))

(fn print-diagnostic [filename msg range ?severity]
  (print (: "%s:%s:%s: %s: %s" :format
            filename
            ;; LSP line numbers are zero-indexed, but Emacs and Vim both use
            ;; 1-indexing for this.
            (if (= range message.unknown-range) "?" (+ range.start.line 1))
            (if (= range message.unknown-range) "?" range.start.character)
            (or (. severity->string ?severity) "?")
            msg)))

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
      (let [uri (case filename
                  "-" :stdin
                  _ (.. "file://" filename))
            file (files.get-by-uri server uri)]
        (lint.add-lint-diagnostics server file)
        (each [_ {: message : range : severity} (ipairs file.diagnostics)]
          (set should-err? true)
          (print-diagnostic filename message range severity))))
    (when should-err?
      (os.exit 1))))

(λ main-loop [in out]
  (local send (partial json-rpc.write out))
  (local server {})
  (while true
    (let [msg (json-rpc.read in)]
      (dispatch.handle server send msg))))

(local {: version} (require :fennel-ls.utils))
(local help "Usage: fennel-ls [FLAG] [FILES]

Run fennel-ls, the Fennel language server and linter.

  --lint FILES : Run the linter on the provided files
                 a single dash (-) can be used to read from stdin
  --server     : Start the language server (stdio mode only)
                 optional, this is the default with no arguments

  --help       : Display this text
  --version    : Show version")

(λ main []
  (case arg
    (where (or ["-h"] ["--help"])) (print help)
    (where (or ["-v"] ["--version"])) (print version)
    ;; (where (or ["-l" & filenames] ["--lint" & filenames])) (lint filenames) ;; compile error in fennel <= 1.5.4
    (where [--lint & filenames] (or (= --lint "--lint") (= --lint "-l"))) (lint filenames)
    (where (or ["--server"] [nil])) (main-loop (io.input)
                                               (io.output))
    _args (do (io.stderr:write help)
              (io.stderr:write "\n")
              (os.exit 1))))

(main)
