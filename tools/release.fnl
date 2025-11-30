"Script to publish a new release of fennel-ls"

(local {: try-sh : sh} (require :tools.util))
(local {: versions} (require :tools.get-deps))

(fn prompt [message ?opt]
  (case (type ?opt)
    (where (or "nil" "boolean"))
    (do (io.write message (if (not= ?opt false)
                           " (Y/n): "
                           " (y/N): "))
       (case (string.lower (io.read))
         "y" true
         "" (not= ?opt false)
         _ false))
    "string"
    (do (io.write message " (" ?opt "): ")
        (case (io.read)
          "" ?opt
          choice choice))))

(fn get-next-version [current-version]
  (let [(major-minor patch) (current-version:match "(%d+%.%d+%.)(%d+)")]
    (.. major-minor (+ (tonumber patch) 1) "-dev")))

(fn main []
  (when (not (try-sh "git" "diff-index" "--quiet" "HEAD"))
    (io.stderr:write "There are uncommitted changes in your repo\n"
                     "\n"
                     "Please commit them, or discard.\n")
    (os.exit 1))

  (when (not (try-sh "make" "test"))
    (io.stderr:write "The current commit does not pass the tests\n"
                     "\n"
                     "Fix the tests first.\n")
    (os.exit 1))
  (when (not (prompt (.. "You are making a release using the following versions:\n"
                         (table.concat (doto (icollect [n v (pairs versions)] (.. n " " v)) table.sort) "\n")
                         "\nAre these dependencies at their most recent versions?")))
    (io.stderr:write "You can update the version numbers in `./tools/get-deps.fnl`.")
    (os.exit 1))
  (when (not (try-sh "make" "check-deps"))
    (io.stderr:write "Dependencies aren't reproducible\n"
                     "\n"
                     "Run `make deps` to update the dependencies.\n")
    (os.exit 1))
  (when (not (try-sh "make" "check-docs"))
    (io.stderr:write "Documentation isn't reproducible\n"
                     "\n"
                     "Run `make docs` to update the documentation files.\n")
    (os.exit 1))
  (let [utils-fnl (-> (io.open "src/fennel-ls/utils.fnl")
                      (: :read "*a"))
        lint-fnl (-> (io.open "src/fennel-ls/lint.fnl")
                     (: :read "*a"))
        changelog-md (-> (io.open "changelog.md")
                         (: :read "*a"))]
    (case (-?> utils-fnl
              (: :match "%(local version \"([%d.]-)%-dev\"%)")

              (#(prompt "What's the new version number for fennel-ls? [hint: this is where you can bump the major or minor]"
                        $)))
      nil
      (do (io.stderr:write "Could not find the version number in utils.fnl.\n")
          (os.exit 1))
      version
      (do
        (when (not (version:match "^%d+%.%d+%.%d+$"))
          (io.stderr:write "The version number should be of the form \"x.y.z\" where x and y and z are numbers")
          (os.exit 1))
        (doto (io.open "src/fennel-ls/utils.fnl" :w)
           (: :write (pick-values 1 (utils-fnl:gsub "%(local version \"([%d.]-)%-dev\"%)"
                                                    (.. "(local version \"" version "\")"))))
           (: :flush)
           (: :close))
        (doto (io.open "src/fennel-ls/lint.fnl" :w)
           (: :write (pick-values 1 (lint-fnl:gsub ":since \"([%d.]-)%-dev\""
                                                    (.. ":since \"" version "\""))))
           (: :flush)
           (: :close))
        (let [(new tail) (changelog-md:match "^# Changelog\n(.-)\n+(## %d+%.%d+%.%d+ / %d%d%d%d%-%d%d%-%d%d\n.*)$")
              new (new:match "%s*(.*)%s*")
              new (new:gsub "^## [^\n]+\n" "")]
          (when (and (= "" new)
                     (not (prompt "There are no changes in changelog.md are sure you want an empty release?")))
            (os.exit 1))
          (let [new (.. "## " version " / " (-> (io.popen "date +%Y-%m-%d") (: :read))
                        "\n\n"
                        new)]
            (doto (io.open "changelog.md" :w)
               (: :write (.. "# Changelog\n\n" new "\n\n" tail))
               (: :flush)
               (: :close))
            (sh "git" "add" ".")
            (sh "git" "commit" "--message" (.. "Release " version))
            (when (not (try-sh "make" "test"))
              (io.stderr:write "The release candidate commit does not pass the tests\n"
                               "\n"
                               "Something has gone wrong and I don't know how to recover.\n")
              (os.exit 1))
            ;; convert "## foo" to "= foo =" in the tag's message
            (sh "git" "tag"
                "--sign" version
                "--message" (pick-values 1 (new:gsub "%f[^\n\0](#+) (.-)%f[\n\0]"
                                                     #(let [decoration (: "=" :rep (- (length $1) 1))]
                                                        (.. decoration " " $2 " " decoration)))))

            (let [dev-version (get-next-version version)]
              (doto (io.open "src/fennel-ls/utils.fnl" :w)
                 (: :write (pick-values 1 (utils-fnl:gsub "%(local version \"([%d.]-)%-dev\"%)"
                                                          (.. "(local version \"" dev-version "\")"))))
                 (: :flush)
                 (: :close))
              (sh "git" "add" ".")
              (sh "git" "commit" "--message" (.. "change version to " dev-version)))))))))

(main)
