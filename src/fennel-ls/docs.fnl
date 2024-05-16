(local fennel (require :fennel))
(local {:metadata METADATA
        :scopes {:global {:specials SPECIALS
                          :macros MACROS}}}
  (require :fennel.compiler))

(local specials
  (collect [name value (pairs SPECIALS)]
    name {:binding name :metadata (. METADATA value)}))

(local macros*
  (collect [name value (pairs MACROS)]
    name {:binding name :metadata (. METADATA value)}))

(local versions
  {:lua51 (require :fennel-ls.docs.lua51)
   :lua52 (require :fennel-ls.docs.lua52)
   :lua53 (require :fennel-ls.docs.lua53)
   :lua54 (require :fennel-ls.docs.lua54)})

(fn compute-global-docs [self]
  (local sets [])
  (when (not (. versions self.configuration.version))
    (error (.. "fennel-ls doesn't know about lua version " self.configuration.version "\n"
               "The allowed versions are:"
               (fennel.view (icollect [key (pairs versions)]
                              key)))))
  (table.insert sets (. versions self.configuration.version)))

(fn get-global [self global-name]
  (when (not (. versions self.configuration.version))
    (error (.. "fennel-ls doesn't know about lua version " self.configuration.version "\n"
               "The allowed versions are:"
               (fennel.view (icollect [key (pairs versions)]
                              key)))))
  (. versions self.configuration.version global-name))

(fn get-builtin [_self builtin-name]
  (or (. specials builtin-name)
      (. macros* builtin-name)))

;; TODO get-module-metadata

{: get-global
 : get-builtin}
