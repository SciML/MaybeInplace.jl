module MaybeInplaceSparseArraysExt

using MaybeInplace: MaybeInplace
using SparseArrays: AbstractSparseArray

# Sparse Arrays `mul!` has really bad performance
# This works around it, and also potentially allows dispatching for other array types
MaybeInplace.__mul!(C::AbstractSparseArray, A, B) = (C .= A * B)
MaybeInplace.__mul!(C::AbstractSparseArray, A, B, α, β) = (C .= α * A * B .+ β * C)

end
