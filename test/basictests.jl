using SafeTestsets

@safetestset "copyto!" begin
    include("copyto.jl")
end

@safetestset "(_/+/-/*/div)=" begin
    include("eqop.jl")
end

@safetestset "dot" begin
    include("dot.jl")
end

@safetestset "matmul" begin
    include("matmul.jl")
end

@safetestset "similar" begin
    include("similar.jl")
end

@safetestset "setindex_trait with LinearAlgebra wrappers" begin
    include("setindex_trait.jl")
end
