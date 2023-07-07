(fn utf [byte]
  "returns the number of (utf8) bytes, and (utf-16) code units from the first byte of a character"
  (if
    (<= 0x00 byte 0x80)
    (values 1 1)
    (<= 0xC0 byte 0xDF)
    (values 2 1)
    (<= 0xE0 byte 0xEF)
    (values 3 1)
    (<= 0xF0 byte 0xF7)
    (values 4 2)
    (error :utf8-error)))

(fn byte->unit16 [str ?byte]
  "convert from normal units to utf16 garbage"
  (let [unit8 (or ?byte (length str))]
    (var o8 0)
    (var o16 0)
    (while (< o8 unit8)
      (let [(a8 a16) (utf (str:byte (+ 1 o8)))]
        (set o8 (+ o8 a8))
        (set o16 (+ o16 a16))))
    (if (= o8 unit8)
      o16
      (error :utf8-error))))


(fn unit16->byte [str unit16]
  "convert from utf16 garbage to normal units"
  (var o8 0)
  (var o16 0)
  (while (< o16 unit16)
    (let [(a8 a16) (utf (str:byte (+ 1 o8)))]
      (set o8 (+ o8 a8))
      (set o16 (+ o16 a16))))
  (if (= o16 unit16)
    o8
    (error :utf8-error)))


(print (byte->unit16 "aλb𐐀" 1) 1)
(print (byte->unit16 "aλb𐐀" 3) 2)
(print (byte->unit16 "aλb𐐀" 4) 3)
(print (byte->unit16 "aλb𐐀") 5)

(print (unit16->byte "aλb𐐀" 1) 1)
(print (unit16->byte "aλb𐐀" 2) 3)
(print (unit16->byte "aλb𐐀" 3) 4)
(print (unit16->byte "aλb𐐀" 5) 8)

