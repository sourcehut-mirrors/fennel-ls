(local {: sh} (require :tools.util.sh))

(sh :rm :-rf
    ;; delete vendored "fennel" (build dependency)
    "fennel"
    ;; delete deps folder
    "deps/")
