{:assert-compile {:metadata {:fls/fntype "fn"
                             :fls/itemKind "Function"
                             :fnl/arglist ["condition"
                                           "msg"
                                           "ast"
                                           "?fallback-ast"]
                             :fnl/docstring "Assert a condition and raise a compile error with line numbers.
The ast arg should be unmodified so that its first element is the form called."}}
 :ast-source {:metadata {:fls/fntype "fn"
                         :fls/itemKind "Function"
                         :fnl/arglist ["ast"]
                         :fnl/docstring "Get a table for the given ast which includes file/line info, if possible."}}
 :comment {:metadata {:fls/fntype "fn"
                      :fls/itemKind "Function"
                      :fnl/arglist ["contents" "?source"]}}
 :comment? {:metadata {:fls/fntype "fn"
                       :fls/itemKind "Function"
                       :fnl/arglist ["x"]}}
 :fennel-module-name {:metadata {:fls/fntype "fn"
                                 :fls/itemKind "Function"
                                 :fnl/arglist []}}
 :gensym {:metadata {:fls/fntype "fn"
                     :fls/itemKind "Function"
                     :fnl/arglist ["base"]}}
 :get-scope {:metadata {:fls/fntype "fn"
                        :fls/itemKind "Function"
                        :fnl/arglist []}}
 :in-scope? {:metadata {:fls/fntype "fn"
                        :fls/itemKind "Function"
                        :fnl/arglist ["symbol"]}}
 :list {:metadata {:fls/fntype "fn"
                   :fls/itemKind "Function"
                   :fnl/arglist ["..."]
                   :fnl/docstring "Create a new list. Lists are a compile-time construct in Fennel; they are
represented as tables with a special marker metatable. They only come from
the parser, and they represent code which comes from reading a paren form;
they are specifically not cons cells."}}
 :list? {:metadata {:fls/fntype "fn"
                    :fls/itemKind "Function"
                    :fnl/arglist ["x"]
                    :fnl/docstring "Checks if an object is a list. Returns the object if is."}}
 :macro-loaded {:fields {}}
 :macroexpand {:metadata {:fls/fntype "fn"
                          :fls/itemKind "Function"
                          :fnl/arglist ["form"]}}
 :multi-sym? {:metadata {:fls/fntype "fn"
                         :fls/itemKind "Function"
                         :fnl/arglist ["str"]
                         :fnl/docstring "Returns a table containing the symbol's segments if passed a multi-sym.
A multi-sym refers to a table field reference like tbl.x or access.channel:deny.
Returns nil if passed something other than a multi-sym."}}
 :pack {}
 :sequence {:metadata {:fls/fntype "fn"
                       :fls/itemKind "Function"
                       :fnl/arglist ["..."]
                       :fnl/docstring "Create a new sequence. Sequences are tables that come from the parser when
it encounters a form with square brackets. They are treated as regular tables
except when certain macros need to look for binding forms, etc specifically."}}
 :sequence? {:metadata {:fls/fntype "fn"
                        :fls/itemKind "Function"
                        :fnl/arglist ["x"]
                        :fnl/docstring "Checks if an object is a sequence (created with a [] literal)"}}
 :sym {:metadata {:fls/fntype "fn"
                  :fls/itemKind "Function"
                  :fnl/arglist ["str" "?source"]
                  :fnl/docstring "Create a new symbol. Symbols are a compile-time construct in Fennel and are
not exposed outside the compiler. Second optional argument is a table describing
where the symbol came from; should be a table with filename, line, bytestart,
and byteend fields."}}
 :sym? {:metadata {:fls/fntype "fn"
                   :fls/itemKind "Function"
                   :fnl/arglist ["x" "?name"]
                   :fnl/docstring "Checks if an object is a symbol. Returns the object if it is.
When given a second string argument, will check that the sym's name matches it."}}
 :table? {:metadata {:fls/fntype "fn"
                     :fls/itemKind "Function"
                     :fnl/arglist ["x"]
                     :fnl/docstring "Checks if an object any kind of table, EXCEPT list/symbol/varg/comment."}}
 :unpack {}
 :varg? {:metadata {:fls/fntype "fn"
                    :fls/itemKind "Function"
                    :fnl/arglist ["x"]
                    :fnl/docstring "Checks if an object is the varg symbol. Returns the object if is."}}
 :version {:definition "1.5.3"}
 :view {:metadata {:fls/fntype "fn"
                   :fls/itemKind "Function"
                   :fnl/arglist ["x" "?options"]
                   :fnl/docstring "Return a string representation of x.

Can take an options table with the following keys:

* :one-line? (default: false) keep the output string as a one-liner
* :depth (number, default: 128) limit how many levels to go (default: 128)
* :detect-cycles? (default: true) don't try to traverse a looping table
* :metamethod? (default: true) use the __fennelview metamethod if found
* :empty-as-sequence? (default: false) render empty tables as []
* :line-length (number, default: 80) length of the line at which
  multi-line output for tables is forced
* :escape-newlines? (default: false) emit strings with \\n instead of newline
* :prefer-colon? (default: false) emit strings in colon notation when possible
* :utf8? (default: true) whether to use the utf8 module to compute string lengths
* :max-sparse-gap: maximum gap to fill in with nils in sparse sequential tables
* :preprocess (function) if present, called on x (and recursively on each value
  in x), and the result is used for pretty printing; takes the same arguments as
  `fennel.view`
* :infinity, :negative-infinity - how to serialize infinity and negative infinity
* :nan, :negative-nan - how to serialize NaN and negative NaN values

All options can be set to `{:once some-value}` to force their value to be
`some-value` but only for the current level.  After that, the option is reset
to its default value.  Alternatively, `{:once value :after other-value}` can
be used, with the difference that after the first use, the options will be set to
`other-value` instead of the default value.

You can set a `__fennelview` metamethod on a table to override its serialization
behavior; see the API reference for details."}}}
