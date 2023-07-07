(local dispatch (require :fennel-ls.dispatch))
(local state (require :fennel-ls.state))
(local diagnostics (require :fennel-ls.diagnostics))
(local {: view} (require :fennel))

;; set up the state of fennel-ls into the `server` table
(local server {})
(dispatch.handle* server {:id 1
                          :jsonrpc "2.0"
                          :method "initialize"
                          :params {:capabilities {}
                                   :clientInfo {:name "Neovim" :version "0.7.2"}
                                   :initializationOptions {}
                                   :rootPath "."
                                   :rootUri "file://."
                                   :trace "off"
                                   :workspaceFolders [{:name "."
                                                       :uri "file://."}]}})

;; open the file specified by (. arg 1) from the command line
(local file (state.get-by-uri server (.. "file://" (. arg 1))))
;; run diagnostics to populate file.diagnostics field
(diagnostics.check server file)
;; print the output
(each [_ v (ipairs file.diagnostics)]
  (print (view v)))
