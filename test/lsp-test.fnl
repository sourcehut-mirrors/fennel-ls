(import-macros {: assert-matches : describe : it} :test.macros)
(local assert (require :luassert))

(local {: run} (require :fennel-ls))
(local fennel (require :fennel))

(describe "initialization"
  ;; TODO get rid of hardcoded paths here
  (it "responds to initialize"
    (local initialize
      {:id 1
       :jsonrpc "2.0"
       :method "initialize"
       :params
       {:capabilities {}
        :clientInfo {:name "Neovim" :version "0.7.2"}
        :initializationOptions {}
        :processId 16245
        :rootPath "/home/xerool/Documents/projects/fennel-ls"
        :rootUri "file:///home/xerool/Documents/projects/fennel-ls"
        :trace "off"
        :workspaceFolders [{:name "/home/xerool/Documents/projects/fennel-ls"
                            :uri "file:///home/xerool/Documents/projects/fennel-ls"}]}})
    (assert-matches
      (run [] initialize)
      {:id 1
       :jsonrpc "2.0"
       :result {:capabilities {}
                :serverInfo {:name "fennel-ls" : version}}})))
