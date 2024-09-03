(local faith (require :faith))
(local fennel (require :fennel))

(set debug.getinfo (or fennel.getinfo debug.getinfo))
(set debug.traceback (or fennel.traceback debug.traceback))

(case (os.getenv "FAITH_TEST")
  target (let [(module function) (target:match "([^ ]+) ([^ ]+)")]
           (tset package.loaded module {function (. (require module) function)})
           (faith.run [module]))
  _ (faith.run
      [:test.json-rpc
       :test.string-processing
       :test.capabilities
       :test.settings
       :test.diagnostic
       :test.goto-definition
       :test.hover
       :test.completion
       :test.references
       :test.lint
       :test.code-action
       :test.rename
       :test.misc
       :test.check]))
