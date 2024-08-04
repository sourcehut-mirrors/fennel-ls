(local fennel (require :deps.fennel))
(local {:clone git-clone} (require :tools.util.git))

(fn download-love-api-tooling! []
  "Clones the LÖVE-API git repository that contains tooling to scrape and
   convert the LÖVE Wiki into a Lua table."
  (when (not (io.open :build/love-api))
    (git-clone :build/love-api "https://github.com/love2d-community/love-api")))

; EXAMPLE SHAPE
;
; {:love {:binding :love
;         :fields {:callbacks {:binding :love.callbacks
;                              :fields {:mousepressed {:binding :mousepressed
;                                                      :metadata {:fnl/arglist [""]
;                                                                 :fnl/docstring "..."}}}}}}}

(fn convert [_contents]
  (download-love-api-tooling!)
  (fennel.view {:love "I did it\\!"}))

{: convert}
