;; this file isn't used in any tests yet

(let [foo true]
  (an-unknown-mystery-global)) ;; the global should be an error, but ideally the compiler should keep going

(do do) ;; this should be a compiler error, I don't mind if the compiler can't go past this one
