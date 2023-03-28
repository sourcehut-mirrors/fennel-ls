(require :test.completion-test)
(require :test.diagnostic-test)
(require :test.goto-definition-test)
(require :test.hover-test)
(require :test.json-rpc-test)
(require :test.misc-test)
(require :test.references-test)
(require :test.settings-test)
(require :test.string-processing-test)

(let [{: passes : errors} (require :test.lust)]
  (print (.. passes " passes. " errors " errors."))
  (os.exit errors))
