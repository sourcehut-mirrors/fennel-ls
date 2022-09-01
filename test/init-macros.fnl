"This document does not include tests. Instead it includes macros that are used for tests."

(fn it [desc ...]
  "busted's `it` function"
  (let [body [...]]
    (table.insert body `nil)
    `((. (require :busted) :it)
      ,desc (fn [] ,desc ,(unpack body)))))

(fn describe [desc ...]
  "busted's `describe` function"
  (let [body [...]]
    (table.insert body `nil)
    `((. (require :busted) :describe)
      ,desc (fn [] ,desc ,(unpack body)))))

(fn before-each [...]
  "busted's `describe` function"
  (let [body [...]]
    (table.insert body `nil)
    `((. (require :busted) :before_each)
      (fn [] ,(unpack body)))))


(fn is-matching [item pattern ?msg]
  "check if item matches a pattern according to fennel's `match` builtin"
  `(match ,item
    ,pattern nil
    ?otherwise#
    (error
      (.. "Pattern did not match:\n"
          (let [fennel# (require :fennel)]
            (fennel#.view ?otherwise#))
          "\ndid not match pattern:\n"
          ,(view pattern)
          (and ,?msg (.. "\n" ,?msg))))))

{: it
 : describe
 : is-matching
 : before-each}
