(local {: view} (require :fennel))
(local lint (require :fennel-ls.lint))
(local utils (require :fennel-ls.utils))
(local config (require :fennel-ls.config))
(local files (require :fennel-ls.files))
(local faith (require :faith))

(fn test-lints-are-documented []
  (each [_ lint (ipairs lint.list)]
    (let [name lint.name]
      (when (not= (type lint.what-it-does) "string") (error (.. name " needs a description of what it does in :what-it-does")))
      (when (not= (type lint.why-care?) "string") (error (.. name " needs a description of why the linted pattern is bad in :why-care?")))
      (when (not= (type lint.example) "string") (error (.. name " needs an example of broken and fixed code in :example")))
      (when (not= (type lint.since) "string") (error (.. name " needs version: :since " (view utils.version))))))
  nil)

(fn test-release-version-number-is-right []
  (let [commit-message (-> (io.popen "git show -s --format='%s'")
                           (: :read "*a")
                           (: :match "[^\n]*"))
        version (commit-message:match "^Release (.*)")
        version-from-utils utils.version
        version-from-changelog (-> (io.open "changelog.md")
                                   (: :read "*a")
                                   (: :match "## ([%d.-]*) /.*"))]
    (if (= "" commit-message) nil
      version
      (do ;; Release checks
        (faith.= version version-from-utils "update `utils.version`")
        (faith.= version version-from-changelog "update `changelog.md`"))
      ;; Non-release checks
      (faith.match "%-dev" version-from-utils "Commit message doesn't say \"Release\", so this should be a dev version")))
  nil)

(fn test-self-lint []
  (let [server {}]
    (config.initialize server {:capabilities {:general {:positionEncodings [:utf-8]}}
                               :clientInfo {:name "fennel-ls"}
                               :rootUri "file://."})
    (let [filenames (-> (io.popen "find src -name \"*.fnl\" ! -path \"*/generated/*\" && find test -name \"*.fnl\"" :r)
                        (: :read "*a")
                        (: :gmatch "[^\n]+"))]
      (each [filename filenames]
        (let [uri (.. "file://" filename)
              file (files.get-by-uri server uri)]
          (lint.add-lint-diagnostics server file)
          (each [_ diagnostic (ipairs file.diagnostics)]
            (faith.= nil diagnostic))))))
  nil)

;; other ideas:
;; selflint
;; docs on top of each file
;; makefile covers
{: test-lints-are-documented
 : test-release-version-number-is-right
 : test-self-lint}
