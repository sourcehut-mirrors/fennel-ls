;; this package is here to translate into lust's weird dsl
(local {: view} (require :fennel))
(local {: expect} (require :test.lust))
;; lust uses weird terminology, but equal is by __eq, same is by recursively having the same contents
(setmetatable {:equal  #(do ((. (expect $1) :to :be) $2) true)
               :same  #(do ((. (expect $1) :to :equal) $2) true)
               :nil #(do ((. (expect $1) :to_not :exist)) true)
               :not {:nil #(do ((. (expect $1) :to :exist)) true)}
               :truthy #(do ((. (expect $1) :to :be :truthy)) true)}
              {:__call #(do ((. (expect $2) :to :be :truthy)) true)})
