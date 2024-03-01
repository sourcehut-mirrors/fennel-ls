(local {:metadata METADATA
        :scopes {:global {:specials SPECIALS
                          :macros MACROS}}}
  (require :fennel.compiler))

(local specials-metadata
  (collect [name value (pairs SPECIALS)]
    name {:binding name :metadata (. METADATA value)}))

(local macros-metadata
  (collect [name value (pairs MACROS)]
    name {:binding name :metadata (. METADATA value)}))

(local lua54-metadata (require :fennel-ls.docs.lua54))

(fn get-global-metadata [global-name]
  (or (. specials-metadata global-name)
      (. macros-metadata global-name)
      (. lua54-metadata global-name)))

{: get-global-metadata}
