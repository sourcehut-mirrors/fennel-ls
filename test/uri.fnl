(local faith (require :faith))
(local uri (require :fennel-ls.uri))

(local use-windows {:windows true})
(local use-unix {:windows false})

(fn test-percent-encode-case-insensitive []
  ;; Percent decoding should handle both uppercase and lowercase hex digits
  (faith.= "/home/user/file[test].fnl"
           (uri.uri->path "file:///home/user/file%5Btest%5D.fnl" use-unix))
  (faith.= "/home/user/file[test].fnl"
           (uri.uri->path "file:///home/user/file%5btest%5d.fnl" use-unix))
  nil)

(fn test-roundtrip-unix []
  ;; Path -> URI -> Path should be identity for Unix paths
  (let [paths ["/home/user/file.fnl"
               "/tmp/test with spaces.lua"
               "/path/file(test).fnl"
               "/path/file[test].fnl"
               "/path/file#hash.fnl"
               "/path/file?query.fnl"
               "/home/user/✓.fnl"
               "/home/user/中文.fnl"
               "/home/user/file-test_v1.0.fnl"
               "/"
               "/file.fnl"]]
    (each [_ path (ipairs paths)]
      (let [uri-str (uri.path->uri path use-unix)
            decoded (uri.uri->path uri-str use-unix)]
        (faith.= path decoded
                 (.. "roundtrip failed for: " path
                     " (got URI: " uri-str
                     ", decoded to: " decoded ")")))))
  nil)

(fn test-roundtrip-windows []
  ;; Path -> URI -> Path should be identity for Windows paths
  (let [paths ["C:\\Users\\user\\file.fnl"
               "D:\\projects\\test with spaces.lua"
               "C:\\path\\file(test).fnl"
               "C:\\path\\file[test].fnl"
               "C:\\Users\\user\\✓.fnl"
               "C:\\Users\\user\\中文.fnl"
               "C:\\Users\\user\\file-test_v1.0.fnl"
               "C:\\file.fnl"]]
    (each [_ path (ipairs paths)]
      (let [uri-str (uri.path->uri path use-windows)
            decoded (uri.uri->path uri-str use-windows)]
        (faith.= path decoded
                 (.. "roundtrip failed for: " path
                     " (got URI: " uri-str
                     ", decoded to: " decoded ")")))))
  nil)

(fn test-uri->path-unix []
  ;; Test decoding Unix-style file URIs
  (faith.= "/home/user/file.fnl"
           (uri.uri->path "file:///home/user/file.fnl" use-unix))
  (faith.= "/tmp/test.lua"
           (uri.uri->path "file:///tmp/test.lua" use-unix))
  (faith.= "/home/user/my file.fnl"
           (uri.uri->path "file:///home/user/my%20file.fnl" use-unix))
  (faith.= "/home/user/file(test).fnl"
           (uri.uri->path "file:///home/user/file%28test%29.fnl" use-unix))
  (faith.= "/home/user/✓.fnl"
           (uri.uri->path "file:///home/user/%E2%9C%93.fnl" use-unix))

  nil)

(fn test-uri->path-windows []
  ;; Test decoding Windows-style file URIs
  (faith.= "C:\\Users\\user\\file.fnl"
           (uri.uri->path "file:///C:/Users/user/file.fnl" use-windows))
  (faith.= "D:\\projects\\test.lua"
           (uri.uri->path "file:///D:/projects/test.lua" use-windows))
  (faith.= "C:\\Users\\my user\\my file.fnl"
           (uri.uri->path "file:///C:/Users/my%20user/my%20file.fnl" use-windows))
  (faith.= "C:\\Users\\user\\file(test).fnl"
           (uri.uri->path "file:///C:/Users/user/file%28test%29.fnl" use-windows))
  (faith.= "C:\\Users\\user\\✓.fnl"
           (uri.uri->path "file:///C:/Users/user/%E2%9C%93.fnl" use-windows))

  nil)

(fn test-non-file-uri-error []
  ;; Non-file URI should error
  (let [(ok? err) (pcall uri.uri->path "http://example.com/file.fnl")]
    (faith.= false ok?)
    (faith.= true (not= nil (err:match "encountered non%-file URI"))))

  (let [(ok? err) (pcall uri.uri->path "https://example.com/file.fnl")]
    (faith.= false ok?)
    (faith.= true (not= nil (err:match "encountered non%-file URI"))))

  nil)

{: test-percent-encode-case-insensitive
 : test-roundtrip-unix
 : test-roundtrip-windows
 : test-uri->path-unix
 : test-uri->path-windows
 : test-non-file-uri-error}
