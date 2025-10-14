(local faith (require :faith))
(local fennel (require :fennel))
(local {: create-client} (require :test.utils))

(local analyzer (require :fennel-ls.analyzer))
(local utils (require :fennel-ls.utils))
(local {: sort-text} (require :fennel-ls.formatter))


(fn test-multi-sym-split []
  (faith.= ["foo"] (utils.multi-sym-split "foo" 2))
  (faith.= ["foo"] (utils.multi-sym-split "foo:bar" 3))
  (faith.= ["foo" "bar"] (utils.multi-sym-split "foo:bar" 4))
  (faith.= ["is" "equal"] (utils.multi-sym-split "is.equal" 5))
  (faith.= ["a" "b" "c" "d" "e" "f"] (utils.multi-sym-split "a.b.c.d.e.f"))
  (faith.= ["obj" "bar"] (utils.multi-sym-split (fennel.sym "obj.bar")))
  (faith.= ["a."] (utils.multi-sym-split (fennel.sym "a.")))
  (faith.= [".."] (utils.multi-sym-split (fennel.sym "..")))
  (faith.= ["?."] (utils.multi-sym-split (fennel.sym "?.")))
  (faith.= ["b:"] (utils.multi-sym-split (fennel.sym "b:")))
  (faith.= ["b" "a."] (utils.multi-sym-split (fennel.sym "b:a.")))
  nil)

(fn test-find-symbol []
  (let [{: server : uri} (create-client "(match [1 2 4] [1 2 sym-one] sym-one)")
        file (. server.files uri)
        [symbol parents] [(analyzer.find-symbol server file 23)]]
    (faith.= symbol (fennel.sym :sym-one))
    (faith.=
      "[[1 2 sym-one] (match [1 2 4] [1 2 sym-one] sym-one) [(match [1 2 4] [1 2 sym-one] sym-one)]]"
      (fennel.view parents {:one-line? true})
      "bad parents"))

  (let [{: server : uri} (create-client "(match [1 2 4] [1 2 sym-one] sym-one)")
        file (. server.files uri)
        [symbol parents] [(analyzer.find-symbol server file 18)]]
    (faith.= symbol nil)
    (faith.=
      "[[1 2 sym-one] (match [1 2 4] [1 2 sym-one] sym-one) [(match [1 2 4] [1 2 sym-one] sym-one)]]"
      (fennel.view parents {:one-line? true})
      "bad parents"))

  (let [{: server : uri} (create-client "(local a. 1) (print a.)")
        file (. server.files uri)
        [symbol _parents] [(analyzer.find-symbol server file 21)]]
    (faith.= symbol (fennel.sym "a.")))
  nil)

(fn test-failure []
  (create-client "(macro foo {} nil)
                  (λ test {} nil)
                  (λ {} nil")
  (create-client "(fn foo []\n  #\n  (print :test))")
  (create-client "(let [map {}] (set (. map (tostring :a)) :b))")
  nil)

(fn test-path-join []
  ;; Basic path joining
  (faith.= "path/file" (utils.path-join "path/" "file"))
  (faith.= "path/file" (utils.path-join "path" "file"))
  (faith.= "path/file" (utils.path-join "path" "./file"))

  ; Empty path - return suffix as-is
  (faith.= "file" (utils.path-join "" "file"))
  (faith.= "main.fnl" (utils.path-join "" "main.fnl"))
  (faith.= "path/" (utils.path-join "path" ""))

  ; Absolute suffix should override base path
  (faith.= "/usr/share/awesome/lib" (utils.path-join "/home/myusername/.config/awesome/" "/usr/share/awesome/lib"))

  ; Leading ./ in suffix should be stripped
  (faith.= "/home/myusername/my-project/main.fnl" (utils.path-join "/home/myusername/my-project" "./main.fnl"))

  ; Nested relative paths
  (faith.= "a/b/c/d" (utils.path-join "a/b" "c/d"))
  nil)


(fn test-sort-text []
  (fn assert< [a ak b bk]
    (faith.= true (< (sort-text a ak) (sort-text b bk))
             (.. "expected (< (sort-text " (fennel.view a) " " ak ") "
                             "(sort-text " (fennel.view b) " " bk "))")))
  (fn assert= [a ak b bk]
    (faith.= true (= (sort-text a ak) (sort-text b bk))
             (.. "expected (= (sort-text " (fennel.view a) " " ak ") "
                             "(sort-text " (fennel.view b) " " bk "))")))

  ;; these are brittle so remove them when sort text requirements change
  (assert< "aaabbb" 2 "a.b" 2)
  (assert< "a.bb" 2 "aa.b" 2)
  (assert< "x.y.zzz" 2 "x.yy.z" 2)
  (assert< "short.a" 2 "short.bb" 2)
  (assert< "aaa.a" 2 "bbbb.a" 2)
  (assert< "aa" 2 "a" 3)
  (assert< "a.aa" 2 "a.a" 3)
  (assert< "a.a" 3 "aa.a" 2)
  (assert< "a" 20 "a" 1)
  (assert< "" 2 "a" 2)
  (assert= "a.b:c" 1 "a.b.c" 1)

  ;; Operators should be the same, regardless of if .'s are in them in non separator spots
  (assert= "?." 1 ".." 1)
  (assert= "." 1 "+" 1)

  ;; absolutely please stop recommending string methods as more important than the strings themselves
  (faith.< (sort-text "_VERSION" 2) (sort-text "_VERSION:gsub" 100))
  nil)

{: test-multi-sym-split
 : test-find-symbol
 : test-failure
 : test-path-join
 : test-sort-text}
