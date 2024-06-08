(local {: sh} (require :tools.util.sh))

(sh :rm :-f
    ;; delete vendored "fennel"
    "src/fennel.lua"
    ;; delete vendored "fennel" (build dependency)
    "fennel"
    ;; delete vendored "faith" (build dependency)
    "test/faith/faith.fnl"
    ;; delete vendored "penlight" (build dependency)
    "test/pl/stringio.lua")

;; write a dummy file to forward to the installation of penlight on LUA_PATH
(doto (io.open "test/pl/stringio.lua")
  (: :write "(require :pl.stringio)")
  (: :close))
