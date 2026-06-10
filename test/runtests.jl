using Pkg
using SafeTestsets, Test

const GROUP = get(ENV, "GROUP", "All")

if GROUP == "QA"
    Pkg.activate(joinpath(@__DIR__, "qa"))
    Pkg.develop(PackageSpec(; path = joinpath(@__DIR__, "..")))
    Pkg.instantiate()
    include("qa.jl")
else
    @testset "MaybeInplace.jl" begin
        if GROUP == "All" || GROUP == "Core"
            @safetestset "Core" begin
                include("basictests.jl")
            end
        end
    end
end
