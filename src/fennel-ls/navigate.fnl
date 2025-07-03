(local docs (require :fennel-ls.docs))
(local analyzer (require :fennel-ls.analyzer))
(local fennel (require :fennel))

(λ iter-fields [server definition]
  "TODO name this thing"
  (coroutine.wrap
    #(if (= (type definition.definition) :string)
         (each [key value (pairs (-> (docs.get-global server :string) (. :fields)))]
           (when (or (= (type key) :string) (= (type key) :number))
             (coroutine.yield key value true)))
         (do
           (when (fennel.table? definition.definition)
             (each [key value (pairs definition.definition)]
               (when (or (= (type key) :string) (= (type key) :number))
                 (let [value (analyzer.search server definition.file value [] {})]
                   (if value
                       (coroutine.yield key value)
                      definition.fields)))))
           (when definition.fields
             (each [key value (pairs definition.fields)]
               (when (or (= (type key) :string) (= (type key) :number))
                 (coroutine.yield key value))))))))

(λ get-field [server definition key]
  (let [fields (or definition.fields
                   (when (type definition.definition) :string
                     (. docs.get-global server :string)))]
    (or (?. fields key)
        (when (fennel.table? definition.definition)
          (analyzer.search server definition.file definition.definition {} {:stack [key]})))))

(λ getmetadata [server_ definition]
  "gets or generates a metadata table"
  (or definition.metadata
      (let [metadata (if (fennel.list? definition.definition)
                       (case definition.definition
                         ;; we can only extract metadata for functions
                         (where (or [fn* ?name arglist ?docstring body_]
                                    ([fn* ?name arglist] ?docstring)
                                    ([fn* arglist ?docstring body_] ?name)
                                    ([fn* arglist] ?name ?docstring))
                                (or (fennel.sym? fn* :fn) (fennel.sym? fn* :λ) (fennel.sym? fn* :lambda))
                                (or (= ?name nil) (fennel.sym? ?name))
                                (fennel.sequence? arglist)
                                (or (= ?docstring nil) (= :string (type ?docstring))))
                         {:fls/itemKind "Function"
                          :fls/fntype (tostring fn*)
                          :fnl/arglist arglist
                          :fnl/docstring ?docstring}))]
        (set definition.metadata metadata)
        metadata)))

{: get-field
 : iter-fields
 : getmetadata}
