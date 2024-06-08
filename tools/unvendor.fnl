(local {: sh} (require :tools.util.sh))

(sh :rm :-f
    ;; delete vendored "fennel"
    "src/fennel.lua"
    ;; delete vendored "fennel" (build dependency)
    "fennel"
    ;; delete vendored "faith" (test dependency)
    "test/faith/faith.fnl"
    ;; delete vendored "penlight" (test dependency)
    "test/pl/stringio.lua")

    ;; I can't delete rxi/json because fennel-ls has a forked version with custom patches.
    ;; I'm working to address this. fennel-ls' forked version will not interfere with the normal version because its statically linked.

;; write a dummy file so that the tests search for penlight on LUA_PATH
(doto (io.open "test/pl/stringio.lua" :w)
  (: :write "(require :pl.stringio)")
  (: :close))
