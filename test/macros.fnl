(fn it! [title ...]       `((. (require :busted) :it) ,title (fn [] ,...)))
(fn describe! [title ...] `((. (require :busted) :describe) ,title (fn [] ,...)))

{: it! : describe!}
