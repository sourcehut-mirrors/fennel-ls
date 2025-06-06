(local faith (require :faith))
(local fennel (require :fennel))
(local {: create-client} (require :test.utils))

(local analyzer (require :fennel-ls.analyzer))
(local utils    (require :fennel-ls.utils))


(fn test-multi-sym-split []
  (faith.= ["foo"] (utils.multi-sym-split "foo" 2))
  (faith.= ["foo"] (utils.multi-sym-split "foo:bar" 3))
  (faith.= ["foo" "bar"] (utils.multi-sym-split "foo:bar" 4))
  (faith.= ["is" "equal"] (utils.multi-sym-split "is.equal" 5))
  (faith.= ["a" "b" "c" "d" "e" "f"] (utils.multi-sym-split "a.b.c.d.e.f"))
  (faith.= ["obj" "bar"] (utils.multi-sym-split (fennel.sym "obj.bar")))
  nil)

(fn test-find-symbol []
  (let [{: server : uri} (create-client "(match [1 2 4] [1 2 sym-one] sym-one)")
        file (. server.files uri)
        (symbol parents) (analyzer.find-symbol file.ast 23)]
    (faith.= symbol (fennel.sym :sym-one))
    (faith.=
      "[[1 2 sym-one] (match [1 2 4] [1 2 sym-one] sym-one) [(match [1 2 4] [1 2 sym-one] sym-one)]]"
      (fennel.view parents {:one-line? true})
      "bad parents"))

  (let [{: server : uri} (create-client "(match [1 2 4] [1 2 sym-one] sym-one)")
        file (. server.files uri)
        (symbol parents) (analyzer.find-symbol file.ast 18)]
    (faith.= symbol nil)
    (faith.=
      "[[1 2 sym-one] (match [1 2 4] [1 2 sym-one] sym-one) [(match [1 2 4] [1 2 sym-one] sym-one)]]"
      (fennel.view parents {:one-line? true})
      "bad parents"))
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

{: test-multi-sym-split
 : test-find-symbol
 : test-failure
 : test-path-join}
