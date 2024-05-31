datatype 'a map = Empty
               | Lf of word * 'a
               | Br of word * word * 'a map * 'a map
