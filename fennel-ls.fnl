(local {: encode : decode} (require :json.json))
(local {: split} (require :pl.stringx))

(local capabilities {:positionEncoding nil ; "utf-8"
                     :textDocumentSync nil
                     :notepookDocumentSync nil
                     :completionProvider nil
                     :hoverProvider nil
                     :signatureHelpProvider nil
                     :declarationProvider nil
                     :definitionProvider nil
                     :typeDefinitionProvider nil
                     :implementationProvider nil
                     :referencesProvider nil
                     :documentHighlightProvider nil
                     :documentSymbolProvider nil
                     :codeActionProvider nil
                     :codeLensProvider nil
                     :documentLinkProvider nil
                     :colorProvider nil
                     :documentFormattingProvider nil
                     :documentRangeFormattingProvider nil
                     :documentOnTypeFormattingProvider nil
                     :renameProvider nil
                     :foldingRangeProvider nil
                     :executeCommandProvider nil
                     :selectionRangeProvider nil
                     :linkedEditingRangeProvider nil
                     :callHierarchyProvider nil
                     :semanticTokensProvider nil
                     :monikerProvider nil
                     :typeHierarchyProvider nil
                     :inlineValueProvider nil
                     :inlayHintProvider nil
                     :diagnosticProvider nil
                     :workspaceSymbolProvider nil
                     :workspace nil})

(local handlers {})

(λ handlers.initialize [params]
    {:capabilities capabilities
     :serverInfo {:name "fennel-ls" :version "0.0.0"}})

(λ receive-message [in]
  (local header {})
  (while
    (match (in:read)
      "\r" false
       header-line
       (let [[k v] (split header-line ": " 2)]
         (tset header k v)
         true)
       _ nil))
  (let [len (tonumber header.Content-Length)
        buffer []]
    (var sofar 0)
    (while (< sofar len)
      (let [r (in:read (- len sofar))]
        (set sofar (+ sofar (length r)))
        (table.insert buffer r)))
    (decode (table.concat buffer))))

(λ send-message [out msg]
  (let [content (encode msg)
        msg-stringified (.. "Content-Length: " (length content) "\r\n\r\n" content)]
    (out:write msg-stringified)))

(λ handle [{: jsonrpc : method : params : id &as msg}]
  (assert (= jsonrpc "2.0"))
  ;; Right now, if the callback crashes, the whole server does.
  ;; It would be nice to turn this into an error message
  (match (. handlers method)
    callback
    (let [result (callback params)]
      {: id
       : method
       :params result
       :jsonrpc "2.0"})
    _ {: id
       : method
       :error (.. "unknown method " msg.method)}))

{: receive-message
 : send-message
 : handle}
