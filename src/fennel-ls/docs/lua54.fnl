(local {: sym} (require :fennel))
{
 :_G {}
 :_VERSION {}
 :arg {}
 :assert {}
 :collectgarbage {}
 :coroutine {}
 :debug {}
 :dofile {}
 :error {}
 :getmetatable {}
 :io {}
 :ipairs {}
 :load {}
 :loadfile {}
 :math {}
 :next {}
 :os {}
 :package {}
 :pairs {:metadata {:fnl/arglist [:t]
                    :fnl/docstring "If t has a metamethod __pairs, calls it with t as argument and returns the first three results from the call.

Otherwise, returns three values: the next function, the table t, and nil, so that the construction
```fnl
(each [k v (pairs t)] <body>)
```
will iterate over all key–value pairs of table t.

See function next for the caveats of modifying the table during its traversal."}}
 :pcall {}
 :print {}
 :rawequal {}
 :rawget {}
 :rawlen {}
 :rawset {}
 :require {}
 :select {}
 :setmetatable {}
 :string {}
 :table {}
 :tonumber {}
 :tostring {}
 :type {}
 :utf8 {}
 :warn {}
 :xpcall {}}
