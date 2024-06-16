(local faith (require :faith))

(faith.run
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
   :test.check])
