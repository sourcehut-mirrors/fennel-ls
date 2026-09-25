;; this file is used by test/lint.fnl as a test plugin
(fn lint-bad-sym [_server _file symbol _definition]
  (when (string.find (tostring symbol) "[^c]ei")
    {:ast symbol
     :message "I before E except after C"}))

{:lints {:bad-sym {:impl lint-bad-sym
                   :what-it-does "checks a certain spelling rule"
                   :type :definition
                   :why-care? "good speling is important"
                   :example "perceive good spelling"
                   :since "0.2.5-dev"}}}
