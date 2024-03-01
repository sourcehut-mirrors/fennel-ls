(local fennel (require :fennel))
(set debug.traceback fennel.traceback)
(local old-debug-getinfo debug.getinfo)
(fn debug.getinfo [x]
  (let [{: sourcemap} (require :fennel.compiler)
        info (old-debug-getinfo (+ 1 x))]
    (when info
      (set info.currentline (or (?. sourcemap info.source info.currentline 2) info.currentline))
      (set info.linedefined (or (?. sourcemap info.source info.linedefined 2) info.linedefined)))
    info))

(local faith (require :faith))

(faith.run
  [:test.json-rpc
   :test.string-processing
   :test.capabilities
   :test.settings
   :test.goto-definition
   :test.hover
   :test.completion
   :test.references
   :test.diagnostic
   :test.rename
   :test.misc])
