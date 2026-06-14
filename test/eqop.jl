using MaybeInplace, StaticArrays, Test
include("basictests_setup.jl")

@testset "(_/+/-/*/div)=" begin
    y = [0.0, 0.0]
    x1 = [1.0, 1.0]
    x2 = [1.0, 1.0]
    x3 = [1.0, 1.0]
    x4 = [1.0, 1.0]
    x5 = [1.0, 1.0]
    @test eqop!!(y, x1, x2, x3, x4, x5) == [1.0, 1.0]
    @test y == [1.0, 1.0]

    y = @SVector[0.0, 0.0]
    x1 = @SVector[1.0, 1.0]
    x2 = @SVector[1.0, 1.0]
    x3 = @SVector[1.0, 1.0]
    x4 = @SVector[1.0, 1.0]
    x5 = @SVector[1.0, 1.0]
    @test eqop!!(y, x1, x2, x3, x4, x5) == @SVector[1.0, 1.0]
    @test y == @SVector[0.0, 0.0]
end
