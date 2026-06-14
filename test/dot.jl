using MaybeInplace, StaticArrays, Test
include("shared/basictests_setup.jl")

@testset "dot" begin
    y = [0.0, 0.0]
    x = [1.0, 1.0]
    z = [1.0, 1.0]
    @test dotmacro!!(y, x, z) == [1.0, 1.0]
    @test y == [1.0, 1.0]

    y = @SVector[0.0, 0.0]
    x = @SVector[1.0, 1.0]
    z = @SVector[1.0, 1.0]
    @test dotmacro!!(y, x, z) == @SVector[1.0, 1.0]
    @test y == @SVector[0.0, 0.0]
end
