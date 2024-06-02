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

(fn get-lua-version [version]
  (when (not (. versions version))
    (error (.. "fennel-ls doesn't know about lua version " version "\n"
               "The allowed versions are: "
               (fennel.view (doto (icollect [key (pairs versions)] key) table.sort)))))
  (. versions version))

(local libraries
  {:tic80 (require :fennel-ls.docs.tic80)})

(fn get-native-library [library]
  (when (not (. libraries library))
    (error (.. "fennel-ls doesn't know about native library " library "\n"
               "The builtin libraries are: "
               (fennel.view (doto (icollect [key (pairs libraries)] key) table.sort)))))
  (. libraries library))

(fn get-all-globals [server]
  (let [result []]
    (each [_ library (ipairs server.configuration.native-libraries)]
      (icollect [name (pairs (get-native-library library)) &into result]
        name))
    (icollect [name (pairs (get-lua-version server.configuration.version)) &into result]
      name)))

(fn get-global [server global-name]
  (or
    (accumulate [result nil
                 _ library (ipairs server.configuration.native-libraries)
                 &until result]
      (. (get-native-library library)
         global-name))
    (. (get-lua-version server.configuration.version)
       global-name)))

(fn get-builtin [_server builtin-name]
  (or (. specials builtin-name)
      (. macros* builtin-name)))

;; TODO get-module-metadata

{: get-global
 : get-builtin
 : get-all-globals}
