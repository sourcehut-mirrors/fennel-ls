(local {: sh} (require :tools.util.sh))

(fn git-clone [location url tag]
  (if tag
    (sh :git :clone :-c :advice.detachedHead=false :--depth=1 :--branch tag url location)
    (sh :git :clone :-c :advice.detachedHead=false :--depth=1 url location)))

(local fennel-version "1.5.1")
(local faith-version "0.2.0")
(local penlight-version "1.14.0")
(local dkjson-version "2.7")
;; dkjson is hosted over http (unencrypted), so I check to make sure the file's not been tampered
(local dkjson-md5sum "94320e64e95f9bb5b06d9955e5391a78  build/dkjson.lua")
(local dkjson-sha1sum "6926b65aa74ae8278b6c5923c0c5568af4f1fef1  build/dkjson.lua")


;; get fennel
(sh :mkdir :-p "build/")
(when (not (io.open "build/fennel/fennel"))
  (git-clone "build/fennel"
             "https://git.sr.ht/~technomancy/fennel"
             fennel-version)
  (sh :make :-C "build/fennel"))

;; get faith
(when (not (io.open "build/faith/faith.fnl"))
  (git-clone "build/faith" "https://git.sr.ht/~technomancy/faith" faith-version))

;; get penlight.stringio
(when (not (io.open "build/penlight/lua/pl/stringio.lua"))
  (git-clone "build/penlight" "https://github.com/lunarmodules/Penlight" penlight-version))

;; get dkjson
(when (not (io.open "build/dkjson.lua"))
  (sh :curl (.. "http://dkolf.de/dkjson-lua/dkjson-" dkjson-version ".lua") [:>] "build/dkjson.lua")
  (assert (sh :echo dkjson-md5sum [:|] :md5sum "--check" "--status"))
  (assert (sh :echo dkjson-sha1sum [:|] :sha1sum "--check" "--status")))

;; copy to the "deps" folder
(sh :mkdir :-p "deps/")
(sh :cp "build/fennel/fennel" ".")
(sh :cp "build/fennel/fennel.lua" "deps/")
(sh :cp "build/faith/faith.fnl" "deps/")
(sh :mkdir :-p "deps/pl")
(sh :cp "build/penlight/lua/pl/stringio.lua" "deps/pl/")
(sh :cp "build/penlight/LICENSE.md" "deps/pl/")
(sh :cp "build/dkjson.lua" "deps/")
