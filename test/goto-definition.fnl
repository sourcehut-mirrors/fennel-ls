(local faith (require :faith))
(local {: create-client} (require :test.utils))
(local {: null} (require :dkjson))
(local {: view} (require :fennel))

(fn check [file-contents]
  (let [{: client : uri : cursor :locations [location]} (create-client file-contents)
        [message] (client:definition uri cursor)]
    (if location
      (faith.= location message.result
        (.. "Didn't go to location: \n" (view file-contents)))
      (faith.= null message.result
        (.. "Wasn't supposed to find a definition\n" (view file-contents))))))

;; "|" is the cursor
;; "==" is the definition that should be found
(fn test-local []
  (check "(fn ==x== []) x|")

  (check "(local ==x== 10)
          (print x|))")

  (check "(fn context [==x==]
            (print x|))")

  (check "(fn ==context== []
            (print context|))")

  (check "(let [x 100]
            (let [==x== 200]
              (print x|)))")

  (check "(for [==x== 1 10]
            (print x|))")

  (check "(fn context [x]
            (each [_ ==v== (ipairs x)]
              (print v|)))")

  (check "(fn context [{: ==x==}]
            (print |x))")

  (check "(fn context [[==x==]]
            (print |x))")

  ;; match unification
  (check "(let [==a== 10]
            (match [10 1]
              [a 1] a|))")

  ;; case shadows
  (check "(let [a 10]
            (case [[] 1]
              [==a== 1] a|))")

  ;; first segment of a multisym
  (check "(let [a 10
                b 20
                ==foo== {: a : b}]
            (print fo|o.a))")

  ;; starting on a binding
  (check "(let [==x== 10
                y| x]
            (print y)")

  ;; doesn't leak fn arguments
  (check "(local ==x== 10)
          (fn [x] x)
          x|")

  (check "(fn [x] x)
          x|")

  ;; the "definition" of the name of the function is the
  ;; whole outer function thing.
  (check "==(fn foo| [] nil)==")
  nil)

(fn test-fields []
  (check "(fn ==target== [] nil)
          (local obstacle {: target})
          (obstacle.tar|get)")

  (check "(fn ==target== [] nil)
          (local {: obstacle} {:obstacle {: target}})
          (obstacle.tar|get)")

  (check "(fn ==target== [] nil)
          (local [obstacle] [{: target}])
          (obstacle.tar|get)")

  (check "(fn ==target== [] nil)
          (local (obstacle) {: target})
          (obstacle.tar|get)")

  (check "(fn ==target== [] nil)
          (local (_ obstacle) (values 1 {: target}))
          (obstacle.tar|get)")

  (check "(fn ==target== [] nil)
          (local obstacle (values {: target}))
          (obstacle.tar|get)")

  (check "(fn ==target== [] nil)
          (local obstacle {: target})
          (local {:target fo|o} obstacle)
          (foo)")

  (check "(fn ==target== [] nil)
          (local obstacle {:box {: target}})
          (local box obstacle.box)
          (box.targe|t)")

  (check "(fn ==target== [] nil)
          (local obstacle {:box {: target}})
          (local {: box} obstacle)
          (box.targe|t)")

  (check "(fn ==target== [] nil)
          (local [obstacle-1] [[{: target}]])
          (local [[obstacle-2]] [obstacle-1])
          (obstacle-2.tar|get)")

  ;; goes through do, let, and values
  (check "(fn ==target== [] nil)
          (local (_ obsta|cle) (do (let [x 1] (values x target))))
          (obstacle)")

  (check "(local [==x== y] (values [1 2] [3 4]))
          (local (a b) (values {:x y : y} {: x : y}))
          (print b.x| a)")

  (check "(local a {:b {:c =={:d #\"hi\"}==}})
          (a.b.|c.d)")

  (check "(local a {:b {:c =={:d #\"hi\"}==}})
          (a.b.c|.d)")

  ;; finds fn declarations
  (check "(local M {})
          (fn ==M.my-function== [] nil)
          (M.my-function|)")
  nil)

(fn test-thru-require []
  (check
    {:foo.fnl "(fn ==target== []
                 nil)
               {: target}"
     :main.fnl "(local foo (require :foo))
                (foo.targe|t)"})

  (check
    {:foo.fnl "(fn ==target== []
                 nil)
               {: target}"
     :main.fnl "(local {: ta|rget} (require :foo))
                (target)"})
  (check
    {:foo.fnl "(local M [])
               (fn ==M.target== []
                 nil)
               M"
     :main.fnl "(local foo (require :foo))
                (foo.ta|rget)"})


  (check
    {:foo.fnl "(fn target []
                 nil)
               =={: target}=="
     :main.fnl "(local {: target} (require| :foo))
                (target)"})

  (check
    {:foo.fnl "(fn target []
                 nil)
               =={: target}=="
     :main.fnl "(local {: target} (includ|e :foo))
                (target)"})

  ;; TODO fix goto-definition on the module name string itself
  ; (check
  ;   {:foo.fnl "(fn target []
  ;                nil)
  ;              =={: target}=="
  ;    :main.fnl "(local {: target} (require :f|oo))
  ;               (target)"}))

  nil)

; (fn test-macro []
;   (check "(macro ==my-macro== [] `nil)
;           (my-mac|ro)")
;   (check {:m.fnl ";; fennel-ls: macro-file
;                   (fn ==my-macro== [] `nil)
;                   {: my-macro}"
;           :main.fnl "(import-macros m :m)
;                      (m.my-macro|)"}))

(fn test-no-crash []
  (check "(macro cool [a b] `(let [,b 10] ,a))\n(cool |x ==x==)")
  (check "(macro cool [a b] `(let [,b 10] ,a))\n(cool x x|)")
  (check "|#$...")
  nil)

; ;; (it "can go to a destructured function argument")
; ;; (it "can go through more than one file")
; ;; (it "will give up instead of freezing on recursive requires")
; ;; (it "will give up instead of freezing on recursive tables constructed with (set)")
; ;; (it "finds the definition of in-file macros")
; ;; (it "can follow import-macros (destructuring)")
; ;; (it "can follow import-macros (namespaced)")
; ;; (it "can go to the definition in a lua file")
; ;; (it "finds (set a.b) definitions")
; ;; (it "finds (tset a :b) definitions")
; ;; (it "finds (setmetatable a {:__index {:b def}) definitions")
; ;; (it "finds definitions into a function (fn foo [] (local x 10) {: x}) (let [result (foo)] (print result.x)) finds result.x")
; ;; (it "finds definitions through a function (fn foo [{: y}] {:x y}) (let [result (foo {:y {}})] (print result.x)) finds result.x")
; ;; (it "finds through setmetatable with an :__index function")

{: test-local
 : test-fields
 : test-thru-require
 : test-no-crash}
