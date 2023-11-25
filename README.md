# MaybeInplace

[![Join the chat at https://julialang.zulipchat.com #sciml-bridged](https://img.shields.io/static/v1?label=Zulip&message=chat&color=9558b2&labelColor=389826)](https://julialang.zulipchat.com/#narrow/stream/279055-sciml-bridged)

[![CI](https://github.com/avik-pal/MaybeInplace.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/avik-pal/MaybeInplace.jl/actions/workflows/CI.yml)
[![codecov](https://codecov.io/gh/avik-pal/MaybeInplace.jl/branch/main/graph/badge.svg?)](https://codecov.io/gh/avik-pal/MaybeInplace.jl)
[![Package Downloads](https://shields.io/endpoint?url=https://pkgs.genieframework.com/api/v1/badge/MaybeInplace)](https://pkgs.genieframework.com?packages=MaybeInplace)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

[![ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor%27s%20Guide-blueviolet)](https://github.com/SciML/ColPrac)
[![SciML Code Style](https://img.shields.io/static/v1?label=code%20style&message=SciML&color=9558b2&labelColor=389826)](https://github.com/SciML/SciMLStyle)

MaybeInplace.jl does a simple thing: If you write a code for mutable arrays, that won't work for immutable arrays. This package provides a macro `@bb` or `@bangbang` that will automatically convert the code to make it work for immutable arrays as well.

## Installation

<p>
MaybeInplace is a &nbsp;
    <a href="https://julialang.org">
        <img src="https://raw.githubusercontent.com/JuliaLang/julia-logo-graphics/master/images/julia.ico" width="16em">
        Julia Language
    </a>
    &nbsp; package. To install Expronicon,
    please <a href="https://docs.julialang.org/en/v1/manual/getting-started/">open
    Julia's interactive session (known as REPL)</a> and press <kbd>]</kbd> key in the REPL to use the package mode, then type the following command
</p>

```julia
pkg> add MaybeInplace
```

## How This Works?

The code is simple enough to be self-explanatory. The basic idea is as follows, if you have the following code:

```julia
@bb @. x = y + z
```

This macro will convert it to:

```julia
if setindex_trait(x) === CanSetindex()
    @. x = y + z
else
    x = @. y + z
end
```
