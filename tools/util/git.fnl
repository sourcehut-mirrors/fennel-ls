(local {: sh} (require :tools.util.sh))

(fn clone [location url ?tag]
  "Clones a git repository, given a location, url, and optional tag."
  (assert location "Expected file location to clone git repository into.")
  (assert url "Expected git repository url to clone.")
  (if ?tag
      (sh :git :clone :-c :advice.detachedHead=false :--depth=1 :--branch ?tag
          url location)
      (sh :git :clone :-c :advice.detachedHead=false :--depth=1 url location)))

{: clone}
