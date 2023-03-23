;; this package is here to translate into lust's weird dsl
(local {: view} (require :fennel))
(local {: expect} (require :test.lust))
;; lust uses weird terminology, but equal is by __eq, same is by recursively having the same contents
(setmetatable {:equal  #((. (expect $1) :to :be) $2)
               :same  #((. (expect $1) :to :equal) $2)
               :nil #((. (expect $1) :to_not :exist))
               :not {:nil #((. (expect $1) :to :exist))}
               :truthy #((. (expect $1) :to :be :truthy))}
              {:__call #((. (expect $2) :to :be :truthy))})
