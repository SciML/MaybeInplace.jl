using MaybeInplace
using Test
using Aqua
using JET

@testset "MaybeInplace.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(MaybeInplace; ambiguities = false,)
    end
    @testset "Code linting (JET.jl)" begin
        JET.test_package(MaybeInplace; target_defined_modules = true)
    end
    # Write your tests here.
end
