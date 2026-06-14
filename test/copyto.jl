using MaybeInplace, StaticArrays, Test
include("basictests_setup.jl")

@testset "copyto!" begin
    x = [1.0, 1.0]
    y = [0.0, 0.0]
    @test copyto!!(y, x) == [1.0, 1.0]
    @test y == [1.0, 1.0]

    x = @SVector[1.0, 1.0]
    y = @SVector[0.0, 0.0]
    @test copyto!!(y, x) == @SVector[1.0, 1.0]
    @test y == @SVector[0.0, 0.0]

    x = @SMatrix[1.0 1.0; 1.0 1.0]
    y = @SMatrix[0.0 0.0; 0.0 0.0]
    @test copyto!!(y, x) == @SMatrix[1.0 1.0; 1.0 1.0]
    @test y == @SMatrix[0.0 0.0; 0.0 0.0]
end
