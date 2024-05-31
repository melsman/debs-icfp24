datatype 'a str = VAL of 'a * 'a stream | FN of unit -> 'a
withtype 'a stream = 'a str ref

val s : char stream = ref (VAL(#"a",ref(FN (fn () => #"b"))))
