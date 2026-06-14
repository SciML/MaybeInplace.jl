using MaybeInplace, Test
include("shared/basictests_setup.jl")

@testset "similar" begin
    x = [1.0, 1.0]
    z = get_similar(x)

    @test_nowarn z[1]

    x = BigFloat[1.0, 1.0]
    z = get_similar(x)

    @test_nowarn z[1]  # Without correct similar this would throw UndefRefError
end
