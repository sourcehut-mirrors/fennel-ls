(fn byte->unit16 [str ?byte]
  "convert from byte offset to unit16 offset. Does not work if string contains a new line"
  (let [byte (or ?byte (length str))
        substr (str:sub 1 byte)]
    (accumulate
      [total (accumulate
               [total byte
                _ (substr:gmatch "[\192-\223]")]
               (- total 1))
       _ (substr:gmatch "[\224-\247]")]
      (- total 2))))

(fn unit16->byte [str unit16]
  "convert from unit16 offset to byte offset. Does not work if string contains a new line"
  ;; TODO replace with faccumulate and :sub, because it is 70 times faster than gmatch
  (accumulate
    [(total ul) (values 0 unit16)
     utf8-character (str:gmatch "[\000-\127\192-\255][\128-\191]*")
     &until (<= ul 0)]
    (let [len (length utf8-character)]
      (values
       (+ total len)
       (- ul (case len
              1 1
              2 1
              3 1
              4 2
              _ (error "invalid utf8")))))))

(print (byte->unit16 "aλb𐐀" 1) 1)
(print (byte->unit16 "aλb𐐀" 3) 2)
(print (byte->unit16 "aλb𐐀" 4) 3)
(print (byte->unit16 "aλb𐐀") 5)

(print (unit16->byte "aλb𐐀" 1) 1)
(print (unit16->byte "aλb𐐀" 2) 3)
(print (unit16->byte "aλb𐐀" 3) 4)
(print (unit16->byte "aλb𐐀" 5) 8)

