datatype 'a t0 = ECR of 'a * int | PTR of 'a t
withtype 'a t = 'a t0 ref

val v : string t = ref(PTR(ref(ECR("hi",8))))
