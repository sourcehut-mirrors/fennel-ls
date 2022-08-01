
(fn bazfn []
  (print "you called bazfn"))

(fn unused []
  (print "this function is unused"))

(fn unused2 []
  (print "this function is unused, but also exported. Tricky!"))

{: bazfn : unused2}
