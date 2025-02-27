(local fennel (require :fennel))
(local {:metadata METADATA
        :scopes {:global {:specials SPECIALS
                          :macros MACROS}}}
  (require :fennel.compiler))

(local docset-ext ".lua")
(local data-dir (.. (or (os.getenv "XDG_DATA_HOME")
                      (.. (or (os.getenv "HOME") "") "/.local/share/"))
                  "/fennel-ls/docsets/"))

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

(local libraries {:tic80 (require :fennel-ls.docs.generated.tic80)})

;; alias
(set libraries.tic-80 libraries.tic80)

(λ load-library [name]
  (let [path (.. data-dir name docset-ext)]
    (case (io.open path :r)
      nil (error (string.format "Could not find docset at %s" path))
      f (let [docs (fennel.load-code (f:read :a) {})]
          (f:close)
          (docs)))))

(λ get-library [name]
   (when (not (. libraries name))
     (let [docs (load-library name)]
       (tset libraries name docs)))
   (. libraries name))

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
