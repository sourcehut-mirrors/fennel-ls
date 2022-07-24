(local fennel-ls (require :fennel-ls))
(local stringio (require :pl.stringio))
(local {: view} (require :fennel))
(local busted (require :busted))

((require :busted.runner))

(macro describe! [title ...]
  `(busted.describe ,title (fn [] ,...)))

(macro it! [title ...]
  `(busted.it ,title (fn [] ,...)))

(describe! "fennel-ls"

  (it! "parses incoming messages"
    (let [out (stringio.open "Content-Length: 29\r\n\r\n{\"my json content\":\"is cool\"}")]
      (assert.same {"my json content" "is cool"}
                   (fennel-ls.recieve-message out))))

  (it! "serializes outgoing messages"
    (let [in (stringio.create)]
      (fennel-ls.send-message in {"my json content" "is cool"})
      (assert.same "Content-Length: 29\r\n\r\n{\"my json content\":\"is cool\"}"
                   (in:value))))
  (it! "responds to initialize"
    (local initialize-message
      {:id 1
       :jsonrpc "2.0"
       :method "initialize"
       :params
         {:capabilities {:callHierarchy {:dynamicRegistration false}
                         :textDocument {:codeAction {:codeActionLiteralSupport
                                                      {:codeActionKind
                                                             {:valueSet
                                                                   ["" "Empty" "QuickFix" "Refactor"
                                                                    "RefactorExtract" "RefactorInline"
                                                                    "RefactorRewrite" "Source"
                                                                    "SourceOrganizeImports" "quickfix"
                                                                    "refactor" "refactor.extract"
                                                                    "refactor.inline" "refactor.rewrite"
                                                                    "source" "source.organizeImports"]}}
                                                     :dataSupport true
                                                     :dynamicRegistration false
                                                     :resolveSupport {:properties ["edit"]}}
                                        :completion {:completionItem {:commitCharactersSupport true
                                                                      :deprecatedSupport true
                                                                      :documentationFormat ["markdown" "plaintext"]
                                                                      :insertReplaceSupport true
                                                                      :labelDetailsSupport true
                                                                      :preselectSupport true
                                                                      :resolveSupport {:properties ["documentation" "detail" "additionalTextEdits"]}
                                                                      :snippetSupport true
                                                                      :tagSupport {:valueSet [1]}}
                                                     :completionItemKind {:valueSet [1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25]}
                                                     :contextSupport false
                                                     :dynamicRegistration false}
                                        :declaration {:linkSupport true}
                                        :definition {:linkSupport true}
                                        :documentHighlight {:dynamicRegistration false}
                                        :documentSymbol {:dynamicRegistration false
                                                         :hierarchicalDocumentSymbolSupport true
                                                         :symbolKind {:valueSet [1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26]}}
                                        :hover {:contentFormat ["markdown" "plaintext"]
                                                :dynamicRegistration false}
                                        :implementation {:linkSupport true}
                                        :publishDiagnostics {:relatedInformation true
                                                             :tagSupport {:valueSet [1 2]}}
                                        :references {:dynamicRegistration false}
                                        :rename {:dynamicRegistration false
                                                 :prepareSupport true}
                                        :signatureHelp {:dynamicRegistration false
                                                        :signatureInformation {:activeParameterSupport true
                                                                               :documentationFormat ["markdown" "plaintext"]
                                                                               :parameterInformation {:labelOffsetSupport true}}}
                                        :synchronization {:didSave true
                                                          :dynamicRegistration false
                                                          :willSave false
                                                          :willSaveWaitUntil false}
                                        :typeDefinition {:linkSupport true}}
                         :window {:showDocument {:support false}
                                  :showMessage {:messageActionItem {:additionalPropertiesSupport false}}
                                  :workDoneProgress true}
                         :workspace {:applyEdit true
                                     :configuration true
                                     :symbol {:dynamicRegistration false
                                              :hierarchicalWorkspaceSymbolSupport true
                                              :symbolKind {:valueSet [1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26]}}
                                     :workspaceEdit {:resourceOperations ["rename" "create" "delete"]}
                                     :workspaceFolders true}}
          :clientInfo {:name "Neovim" :version "0.7.2"}
          :initializationOptions {}
          :processId 16245
          :rootPath "/home/xerool/Documents/projects/fennel-ls"
          :rootUri "file:///home/xerool/Documents/projects/fennel-ls"
          :trace "off"
          :workspaceFolders [{:name "/home/xerool/Documents/projects/fennel-ls"
                              :uri "file:///home/xerool/Documents/projects/fennel-ls"}]}})
    (local result (fennel-ls.handle initialize-message))))
