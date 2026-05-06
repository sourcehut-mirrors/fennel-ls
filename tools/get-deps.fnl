(local {: sh} (require :tools.util))

(fn git-clone [location url ?tag]
  (if ?tag
    (sh :git :clone :-c :advice.detachedHead=false :--depth=1 :--branch ?tag url location)
    (sh :git :clone :-c :advice.detachedHead=false :--depth=1 url location)))

;; Vendored Dependency Versions
(local fennel-version "1.6.1")
(local faith-version "0.2.0")
(local penlight-version "1.15.0")
(local dkjson-version "2.9")
;; dkjson is hosted over http (unencrypted), so I check to make sure the file's not been tampered
(local dkjson-md5sum "0b4de99c76502f3dff3578e05c7dc38a  build/dkjson.lua")
(local dkjson-sha1sum "40a6b9f0d54095cc6e5420e4d0b3a1d5fa7f78ee  build/dkjson.lua")


(fn get-fennel []
  "downloads and builds fennel"
  (sh :mkdir :-p "build/")
  (when (not (io.open "build/fennel/fennel"))
    (git-clone "build/fennel"
               "https://git.sr.ht/~technomancy/fennel"
               fennel-version)
    (sh :make :-C "build/fennel")))

(fn get-faith []
  "downloads faith"
  (when (not (io.open "build/faith/faith.fnl"))
    (git-clone "build/faith" "https://git.sr.ht/~technomancy/faith" faith-version)))

;; we clone all of penlight, but only stringio.lua will be installed
(fn get-penlight-stringio []
  "downloads penlight"
  (when (not (io.open "build/penlight/lua/pl/stringio.lua"))
    (git-clone "build/penlight" "https://github.com/lunarmodules/Penlight" penlight-version)))

;; get dkjson
(fn get-dkjson []
  "downloads and verifies dkjson"
  (when (not (io.open "build/dkjson.lua"))
    (sh :curl (.. "http://dkolf.de/dkjson-lua/dkjson-" dkjson-version ".lua") [:>] "build/dkjson.lua")
    (assert (sh :echo dkjson-md5sum [:|] :md5sum "--check" "--status"))
    (assert (sh :echo dkjson-sha1sum [:|] :sha1sum "--check" "--status"))))

(fn prepare-deps []
  ;; "preparing" dependencies just means copying to the "deps" folder
  (sh :mkdir :-p "deps/")
  (sh :cp "build/fennel/fennel" ".")
  (sh :cp "build/fennel/fennel.lua" "deps/")
  (sh :cp "build/faith/faith.fnl" "deps/")
  (sh :mkdir :-p "deps/pl")
  (sh :cp "build/penlight/lua/pl/stringio.lua" "deps/pl/")
  (sh :cp "build/penlight/LICENSE.md" "deps/pl/")
  (sh :cp "build/dkjson.lua" "deps/"))

(when (not ...)
  (get-fennel)
  (get-faith)
  (get-penlight-stringio)
  (get-dkjson)
  (prepare-deps))

{: get-fennel
 : get-faith
 : get-penlight-stringio
 : get-dkjson
 : prepare-deps
 :versions {:fennel fennel-version
            :faith faith-version
            :penlight penlight-version
            :dkjson dkjson-version}}
