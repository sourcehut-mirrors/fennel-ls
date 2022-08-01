"This document does not include tests. Instead it includes macros that are used for tests."

(fn it [desc ...]
  "busted's `it` function"
  `((. (require :busted) :it)
    ,desc (fn [] ,desc ,...)))

(fn describe [desc ...]
  "busted's `describe` function"
  `((. (require :busted) :describe)
    ,desc (fn [] ,desc ,...)))

(fn before-each [...]
  "busted's `describe` function"
  `((. (require :busted) :before_each)
    (fn [] ,...)))


(fn assert-matches [item pattern]
  "check if item matches a pattern according to fennel's `match` builtin"
  `(match ,item
    ,pattern nil
    ?otherwise#
    (error
      (.. "Pattern did not match:\n"
          (let [fennel# (require :fennel)]
            (fennel#.view ?otherwise#))
          "\ndid not match pattern:\n"
          ,(view pattern)))))

{: it
 : describe
 : assert-matches
 : before-each}
