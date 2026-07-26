using Documenter
using MaybeInplace

makedocs(
    modules = [MaybeInplace],
    sitename = "MaybeInplace.jl",
    checkdocs = :exports,
    format = Documenter.HTML(
        canonical = "https://docs.sciml.ai/MaybeInplace/stable/"
    ),
    pages = [
        "Home" => "index.md",
        "API" => "api.md",
    ],
)

deploydocs(
    repo = "github.com/SciML/MaybeInplace.jl.git",
    push_preview = true,
)
