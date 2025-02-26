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

(local lua-versions
       {:lua5.1 (require :fennel-ls.docs.generated.lua51)
        :lua5.2 (require :fennel-ls.docs.generated.lua52)
        :lua5.3 (require :fennel-ls.docs.generated.lua53)
        :lua5.4 (require :fennel-ls.docs.generated.lua54)})

;; aliases
(set lua-versions.lua51 (. lua-versions "lua5.1"))
(set lua-versions.lua52 (. lua-versions "lua5.2"))
(set lua-versions.lua53 (. lua-versions "lua5.3"))
(set lua-versions.lua54 (. lua-versions "lua5.4"))

(fn get-lua-version [version]
  (when (not (. lua-versions version))
    (error (.. "fennel-ls doesn't know about lua version " version "\n"
               "The allowed versions are: "
               (fennel.view (doto (icollect [key (pairs lua-versions)] key)
                              table.sort)))))
  (. lua-versions version))

;; work around a mistake in Lua's own manual
(set lua-versions.lua51.package.fields.config
     lua-versions.lua52.package.fields.config)

(set lua-versions.intersection
     (collect [k v (pairs lua-versions.lua51)]
       (if (. lua-versions.lua54 k) (values k v))))

(local libraries
  {:tic-80 (require :fennel-ls.docs.generated.tic80)})

;; can't just pcall require because we want to trigger require-as-include
(case (pcall #(require :fennel-ls.docs.generated.love2d))
  (true love2d) (set libraries.love2d love2d))

(fn get-library [library]
  (when (not (. libraries library))
    (error (.. "fennel-ls doesn't know about library " library "\n"
               "The builtin libraries are: "
               (fennel.view (doto (icollect [key (pairs libraries)] key) table.sort)))))
  (. libraries library))

(fn get-all-globals [server]
  (let [result []]
    (each [library enabled? (pairs server.configuration.libraries)]
      (when enabled?
        (icollect [name (pairs (get-library library)) &into result]
          name)))
    (icollect [name (pairs (get-lua-version server.configuration.lua-version)) &into result]
      name)))

(fn get-library-global [server global-name]
  (accumulate [g nil library-name enabled? (pairs server.configuration.libraries)
               &until g]
    (and enabled? (. (get-library library-name) global-name))))

(fn get-global [server global-name]
  (or (get-library-global server global-name)
      (. (get-lua-version server.configuration.lua-version) global-name)))

(fn get-builtin [_server builtin-name]
  (or (. specials builtin-name)
      (. macros* builtin-name)))

;; TODO get-module-metadata

{: get-global
 : get-builtin
 : get-all-globals}
