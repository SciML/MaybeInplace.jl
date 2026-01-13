using MaybeInplace, StaticArrays, Test, SparseArrays
using MaybeInplace: LinearAlgebra

function copyto!!(y, x)
    @bb copyto!(y, x)
    return y
end

function eqop!!(y, x1, x2, x3, x4, x5)
    @bb y .= x1
    @bb y .+= x2
    @bb y .*= x3
    @bb y .-= x4
    @bb y ./= x5
    return y
end

function dotmacro!!(y, x, z)
    @bb @. y = x * z
    return y
end

function matmul!!(y, x, z)
    @bb y = x × z
    return y
end

function get_similar(x)
    @bb z = similar(x)
    return z
end

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

@testset "similar" begin
    x = [1.0, 1.0]
    z = get_similar(x)

    @test_nowarn z[1]

    x = BigFloat[1.0, 1.0]
    z = get_similar(x)

    @test_nowarn z[1]  # Without correct similar this would throw UndefRefError
end

@testset "setindex_trait with LinearAlgebra wrappers" begin
    # Test with mutable arrays (should be CanSetindex)
    A = [1.0 2.0; 2.0 3.0]
    v = [1.0, 2.0]
    @test MaybeInplace.setindex_trait(LinearAlgebra.Symmetric(A)) == MaybeInplace.CanSetindex()
    @test MaybeInplace.setindex_trait(LinearAlgebra.Hermitian(A)) == MaybeInplace.CanSetindex()
    @test MaybeInplace.setindex_trait(LinearAlgebra.UpperTriangular(A)) == MaybeInplace.CanSetindex()
    @test MaybeInplace.setindex_trait(LinearAlgebra.LowerTriangular(A)) == MaybeInplace.CanSetindex()
    @test MaybeInplace.setindex_trait(LinearAlgebra.UnitUpperTriangular(A)) == MaybeInplace.CanSetindex()
    @test MaybeInplace.setindex_trait(LinearAlgebra.UnitLowerTriangular(A)) == MaybeInplace.CanSetindex()
    @test MaybeInplace.setindex_trait(LinearAlgebra.Diagonal(v)) == MaybeInplace.CanSetindex()

    # Test with immutable arrays (should be CannotSetindex)
    SA_mat = SA[1.0 2.0; 2.0 3.0]
    SA_vec = SA[1.0, 2.0]
    @test MaybeInplace.setindex_trait(LinearAlgebra.Symmetric(SA_mat)) == MaybeInplace.CannotSetindex()
    @test MaybeInplace.setindex_trait(LinearAlgebra.Hermitian(SA_mat)) == MaybeInplace.CannotSetindex()
    @test MaybeInplace.setindex_trait(LinearAlgebra.UpperTriangular(SA_mat)) == MaybeInplace.CannotSetindex()
    @test MaybeInplace.setindex_trait(LinearAlgebra.LowerTriangular(SA_mat)) == MaybeInplace.CannotSetindex()
    @test MaybeInplace.setindex_trait(LinearAlgebra.UnitUpperTriangular(SA_mat)) == MaybeInplace.CannotSetindex()
    @test MaybeInplace.setindex_trait(LinearAlgebra.UnitLowerTriangular(SA_mat)) == MaybeInplace.CannotSetindex()
    @test MaybeInplace.setindex_trait(LinearAlgebra.Diagonal(SA_vec)) == MaybeInplace.CannotSetindex()
end
