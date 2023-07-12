"Diagnostics

Goes through a file and mutates the `file.diagnostics` field, filling it with diagnostics."

(local language (require :fennel-ls.language))
(local message (require :fennel-ls.message))
(local utils (require :fennel-ls.utils))

(λ unused-definition [self file]
  "local variable that is defined but not used"
  (icollect [symbol definition (pairs file.definitions) &into file.diagnostics]
    (if (and (= 0 (length definition.referenced-by))
             (not= "_" (: (tostring symbol) :sub 1 1)))
      {:range (message.ast->range self file symbol)
       :message (.. "unused definition: " (tostring symbol))
       :severity message.severity.WARN
       :code 301
       :codeDescription "warning error"})))

(λ unknown-module-field [self file]
  "any multisym whose definition can't be found through a (require) call"
  (icollect [symbol (pairs file.references) &into file.diagnostics]
    (if (. (utils.multi-sym-split symbol) 2)
      (let [opts {}
            item (language.search self file symbol [] opts)]
        (if (and (not item) opts.searched-through-require)
          {:range (message.ast->range self file symbol)
           :message (.. "unknown field " (tostring symbol))
           :severity message.severity.WARN
           :code 302
           :codeDescription "field checking I guess"})))))

(λ check [self file]
  "fill up the file.diagnostics table with linting things"
  (if self.configuration.checks.unused-definition
    (unused-definition self file))
  (if self.configuration.checks.unknown-module-field
    (unknown-module-field self file)))

{: check}
