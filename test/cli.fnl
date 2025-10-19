(local faith (require :faith))

;; alas, no io.popen2
(macro with-temp-form [[filename form
                        out cmd] & body]
  `(let [,filename (os.tmpname)]
    (doto (assert (io.open ,filename :w))
      (: :write ,(view form))
      (: :close))
    (let [pipe# (io.popen (.. ,cmd " " ,filename))
          ,out (pipe#:read :*a)]
      ,body
      (os.remove ,filename))
    nil))

(fn test-lint []
  (with-temp-form [f (local x 1)
                   out "./fennel-ls --lint"]
    (faith.= (.. f ":1:7: warning: unused definition: x\n") out)))

(fn test-fix []
  (with-temp-form [f (local x 1)
                   out "./fennel-ls --fix --yes"]
    (faith.= "(local _x 1)" (with-open [file (assert (io.open f))]
                              (file:read :*a)) out))
  (with-temp-form [f [(let [(a b) (values 1 (+ 2))] (+ a b))
                      [(do (print "done doing all the fun things we did!"))]]
                   out "./fennel-ls --fix --yes"]
    (faith.= "[(let [(a b) (values 1 2)] (+ a b))
 [(print \"done doing all the fun things we did!\")]]"
             (with-open [file (assert (io.open f))]
               (file:read :*a)) out)))

{: test-lint
 : test-fix}
