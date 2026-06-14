using MaybeInplace, StaticArrays, SparseArrays, Test
include("basictests_setup.jl")

@testset "matmul" begin
    y = [0.0, 0.0]
    x = [1.0 1.0; 1.0 1.0]
    z = [1.0, 1.0]
    @test matmul!!(y, x, z) == [2.0, 2.0]
    @test y == [2.0, 2.0]

    y = @SVector[0.0, 0.0]
    x = @SMatrix[1.0 1.0; 1.0 1.0]
    z = @SVector[1.0, 1.0]
    @test matmul!!(y, x, z) == @SVector[2.0, 2.0]
    @test y == @SVector[0.0, 0.0]

    x = sprand(100, 100, 0.01)
    z = sprand(100, 100, 0.01)
    y = x * z
    @test matmul!!(y, x, z) == x * z
end
