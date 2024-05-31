datatype s = A of t * t | B
     and t = S of s * s
     and u = U of t | K of s
