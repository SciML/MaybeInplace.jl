using MaybeInplace, StaticArrays, Test
using MaybeInplace: LinearAlgebra

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
