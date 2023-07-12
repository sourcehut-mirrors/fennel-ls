;; fennel-ls: macro-file
"This document does not include tests. Instead it includes macros that are used for tests."

(fn it [desc ...]
  "lust's `it` function"
  (let [body [...]]
    (table.insert body `nil)
    `((. (require :test.lust) :it)
      ,desc (fn [] ,desc ,(unpack body)))))

(fn describe [desc ...]
  "lust's `describe` function"
  (let [body [...]]
    (table.insert body `nil)
    `((. (require :test.lust) :describe)
      ,desc (fn [] ,desc ,(unpack body)))))

(fn before-each [...]
  "lust's `before_each` function"
  (let [body [...]]
    (table.insert body `nil)
    `((. (require :test.lust) :before_each)
      (fn [] ,(unpack body)))))


(fn is-matching [item pattern ?msg]
  "check if item matches a pattern according to fennel's `match` builtin"
  `(match ,item
    ,pattern nil
    ?otherwise#
    (is false
      (.. "Pattern did not match:\n"
          (let [fennel# (require :fennel)]
            (fennel#.view ?otherwise#))
          "\ndid not match pattern:\n"
          ,(view pattern)
          ,(and ?msg `(.. "\n" ,?msg))))))

(fn is-casing [item pattern ?msg]
  "check if item matches a pattern according to fennel's `match` builtin"
  `(case ,item
    ,pattern nil
    ?otherwise#
    (error
      (.. "Pattern did not match:\n"
          (let [fennel# (require :fennel)]
            (fennel#.view ?otherwise#))
          "\ndid not match pattern:\n"
          ,(view pattern)
          ,(and ?msg `(.. "\n" ,?msg))))))


{: it
 : describe
 : is-matching
 : is-casing
 : before-each}
