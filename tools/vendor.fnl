(local {: sh} (require :tools.util.sh))

(fn git-clone [location url tag]
  (if tag
    (sh :git :clone :-c :advice.detachedHead=false :--depth=1 :--branch tag url location)
    (sh :git :clone :-c :advice.detachedHead=false :--depth=1 url location)))

(local fennel-version "1.4.2")
(local faith-version "0.1.2")
(local penlight-version "1.14.0")

;; get && build fennel
(sh :mkdir :-p "build")
(when (not (io.open "build/fennel/fennel"))
  (git-clone "build/fennel"
             "https://git.sr.ht/~technomancy/fennel"
             fennel-version)
  (sh :make :-C "build/fennel"))
sh :cp "build/fennel/fennel" "."
(sh :cp "build/fennel/fennel.lua" "src")

;; get faith
(when (not (io.open "build/fennel/faith.fnl"))
  (git-clone "build/faith" "https://git.sr.ht/~technomancy/faith" faith-version))
(sh :cp "build/faith/faith.fnl" "test/faith/faith.fnl")

;; get penlight.stringio
(when (not (io.open "build/pl/stringio.lua"))
  (git-clone "build/penlight" "https://github.com/lunarmodules/Penlight" penlight-version))
(sh :cp "build/penlight/lua/pl/stringio.lua" "test/pl/stringio.lua")
