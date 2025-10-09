(require :fennel)
(local dispatch (require :fennel-ls.dispatch))
(local json-rpc (require :fennel-ls.json-rpc))
(local lint (require :fennel-ls.lint))
(local utils (require :fennel-ls.utils))
(local files (require :fennel-ls.files))
(local {: severity->string &as message} (require :fennel-ls.message))

(fn print-diagnostic [filename {:message msg : range : severity}]
  (print (: "%s:%s:%s: %s: %s" :format
            filename
            ;; LSP line numbers are zero-indexed, but Emacs and Vim both use
            ;; 1-indexing for this.
            (if (= range message.unknown-range) "?" (+ range.start.line 1))
            (if (= range message.unknown-range) "?" range.start.character)
            (or (. severity->string severity) "?")
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

(λ lint-files [filenames]
  "non-interactive mode that gets executed from CLI with --lint.
   runs lints on each file, then formats and prints them"
  (let [server (doto {} initialize)]
    (var should-err? false)
    (each [_ filename (ipairs filenames)]
      (let [uri (case filename
                  "-" :stdin
                  _ (.. "file://" filename))
            file (files.get-by-uri server uri)]
        (lint.add-lint-diagnostics server file)
        (each [_ diagnostic (ipairs file.diagnostics)]
          (set should-err? true)
          (print-diagnostic filename diagnostic))))
    (when should-err?
      (os.exit 1))))

(λ apply-changes [server filename changes]
  (let [contents (with-open [f (io.open filename)] (f:read :*a))
        new (utils.apply-edits contents changes server.position-encoding)]
    (with-open [f (io.open filename :w)]
      (f:write new))))

(λ confirm [msg]
  (io.write msg)
  (case (io.read) (where (or "" "y" "Y" "yes")) true))

(λ fix-files [filenames --yes]
  (let [server (doto {} initialize)]
    (each [_ filename (ipairs filenames)]
      (let [uri (case filename
                  "-" :stdin
                  _ (.. "file://" filename))
            file (files.get-by-uri server uri)]
        (lint.add-lint-diagnostics server file)
        (case [(next file.diagnostics)]
          [_ {: fix &as diagnostic}]
          (let [{: title : changes} (fix)
                query (: "Apply fix? [Y/n] %s " :format title)]
            (print-diagnostic filename diagnostic)
            (when (or --yes (confirm query))
              (apply-changes server filename changes)
              (fix-files [filename] --yes))))))))

(λ main-loop [in out]
  (local send (partial json-rpc.write out))
  (local server {})
  (while true
    (let [msg (json-rpc.read in)]
      (dispatch.handle server send [msg]))))

(local {: version} (require :fennel-ls.utils))
(local help "Usage: fennel-ls [FLAG] [FILES]

Run fennel-ls, the Fennel language server and linter.

  --lint FILES     : Run the linter on the provided files
                     a single dash (-) can be used to read from stdin
  --fix [-y] FILES : Run suggested fixes from linters on files
  --server         : Start the language server (stdio mode only)
                     optional, this is the default with no arguments

  --help           : Display this text
  --version        : Show version")

(λ main []
  (case arg
    (where (or ["-h"] ["--help"])) (print help)
    (where (or ["-v"] ["--version"])) (print version)
    ;; (where (or ["-l" & filenames] ["--lint" & filenames])) (lint filenames) ;; compile error in fennel <= 1.5.4
    (where [--lint & filenames] (or (= --lint "--lint") (= --lint "-l"))) (lint-files filenames)
    (where (or ["--server"] [nil])) (main-loop (io.input)
                                               (io.output))
    ["--fix" "-y" & filenames] (fix-files filenames true)
    ["--fix" "--yes" & filenames] (fix-files filenames true)
    ["--fix" & filenames] (fix-files filenames false)
    _args (do (io.stderr:write help)
              (io.stderr:write "\n")
              (os.exit 1))))

(main)
