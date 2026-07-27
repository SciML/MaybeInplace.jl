using MaybeInplace, Test

# `axpy!` has no method for a scalar `x`, so this has to reach the broadcast fallback.
# It previously threw a `MethodError`: the guard selecting the fallback ran `typeof` on
# names that are already bound to types inside the `@generated` body, so it never fired.
@testset "axpy! falls back when there is no matching axpy! method" begin
    y = [1.0, 2.0]
    @bb axpy!(2.0, 3.0, y)
    @test y == [7.0, 8.0]
end
