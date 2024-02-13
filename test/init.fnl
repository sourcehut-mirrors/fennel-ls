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

(require :test.capabilities-test)
(require :test.completion-test)
(require :test.diagnostic-test)
(require :test.goto-definition-test)
(require :test.hover-test)
(require :test.json-rpc-test)
(require :test.misc-test)
(require :test.references-test)
(require :test.rename-test)
(require :test.settings-test)
(require :test.string-processing-test)

(let [{: passes : errors} (require :test.lust)]
  (print (.. passes " passes. " errors " errors."))
  (if (not= errors 0)
    (os.exit errors)))
