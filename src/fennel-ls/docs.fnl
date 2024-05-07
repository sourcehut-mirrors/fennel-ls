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

(local lua54 (require :fennel-ls.docs.lua54))

(fn get-global [_self global-name]
  (or (. specials global-name)
      (. macros* global-name)
      (. lua54 global-name)))

;; TODO get-module-metadata

{: get-global}
