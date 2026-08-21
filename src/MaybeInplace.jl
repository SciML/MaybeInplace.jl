module MaybeInplace

using LinearAlgebra: LinearAlgebra, axpy!, mul!
using MacroTools: MacroTools, @capture
using ArrayInterface: can_setindex, restructure

## Main Function
function __bangbang__(M, iip::Symbol, expr)
    new_expr = nothing
    if @capture(expr, f_(a_, args__))
        new_expr = quote
            if $(iip)
                $(expr)
            else
                $(a) = $(f)($(a), $(args...))
            end
        end
    end
    if new_expr !== nothing
        return esc(new_expr)
    end
    error("`$(iip) $(expr)` cannot be handled. Check the documentation for allowed \
           expressions.")
end

function __bangbang__(M, expr; depth::Int = 1)
    new_expr = nothing
    if @capture(expr, a_ = copy(b_))
        new_expr = :($(a) = $(__copy)($(setindex_trait)($(b)), $(b)))
    elseif @capture(expr, a_ = zero(b_))
        new_expr = :($(a) = $(__zero)($(setindex_trait)($(b)), $(b)))
    elseif @capture(expr, a_ = similar(b_))
        new_expr = :($(a) = $(__similar)($(setindex_trait)($(b)), $(b)))
    elseif @capture(expr, axpy!(α_, x_, y_))
        new_expr = __handle_axpy(M, α, x, y, depth)
    elseif @capture(expr, f_(a_, args__))
        g = get(OP_MAPPING, f, nothing)
        if g !== nothing
            new_expr = :($(a) = $(g)($(setindex_trait)($(a)), $(a), $(args...)))
        end
    elseif @capture(expr, a_ = f_Symbol(b_, args__))
        g = get(OP_MAPPING, f, nothing)
        if g !== nothing
            new_expr = :($(a) = $(g)($(setindex_trait)($(a)), $(a), $(b), $(args...)))
        elseif f == :×
            new_expr = __handle_custom_operator(Val{:times}(), M, expr, depth)
        end
    elseif @capture(expr, @. a_ = f_)
        new_expr = __handle_dot_macro(M, a, f, depth)
    elseif @capture(expr, a_ += ×(b_, c_))
        new_expr = __handle_custom_operator(Val{:plustimes}(), M, expr, depth)
    elseif expr.head == :macrocall
        new_expr = __bangbang__(
            M, Base.macroexpand(M, expr; recursive = true);
            depth = depth + 1
        )
    else
        new_expr = __handle_dot_op_equals_operators(M, expr, depth)
    end
    # If we have updated the expression return it, else throw an error
    if new_expr !== nothing
        depth == 1 && return esc(new_expr)
        return new_expr
    end
    error("`$(expr)` cannot be handled. Check the documentation for allowed expressions.")
end

## Custom Operators
function __handle_custom_operator(op::Union{Val{:times}, Val{:plustimes}}, M, expr, depth)
    @capture(expr, a_ = ×(b_, c_)) || @capture(expr, a_ += ×(b_, c_)) ||
        error("Expected `a = b × c` got `$(expr)`")
    @capture(expr, a_ = ×(vec(b_), vec(c_))) && return nothing
    a_sym = gensym("a")
    if @capture(expr, a_ = ×(vec(b_), c_))
        return quote
            if $(setindex_trait)($(a)) === $(CanSetindex())
                $(a_sym) = $(a)
                $(__mul!)($(a_sym), $(_vec)($b), $(c))
                $(a) = $(_restructure)($(a), $(a_sym))
            else
                $(a) = $(_restructure)($a, $(_vec)($b) * $(c))
            end
        end
    elseif @capture(expr, a_ += ×(vec(b_), c_))
        return quote
            if $(setindex_trait)($(a)) === $(CanSetindex())
                $(a_sym) = $(a)
                $(__mul!)($(a_sym), $(_vec)($b), $(c), true, true)
                $(a) = $(_restructure)($(a), $(a_sym))
            else
                $(a) = $(a) .+ $(_restructure)($a, $(_vec)($b) * $(c))
            end
        end
    elseif @capture(expr, a_ = ×(b_, vec(c_)))
        return quote
            if $(setindex_trait)($(a)) === $(CanSetindex())
                $(a_sym) = $(_vec)($a)
                $(__mul!)($(a_sym), $(b), $(_vec)($c))
                $(a) = $(_restructure)($(a), $(a_sym))
            else
                $(a) = $(_restructure)($a, $(b) * $(_vec)($c))
            end
        end
    elseif @capture(expr, a_ += ×(b_, vec(c_)))
        return quote
            if $(setindex_trait)($(a)) === $(CanSetindex())
                $(a_sym) = $(_vec)($a)
                $(__mul!)($(a_sym), $(b), $(_vec)($c), true, true)
                $(a) = $(_restructure)($(a), $(a_sym))
            else
                $(a) = $(a) .+ $(_restructure)($a, $(b) * $(_vec)($c))
            end
        end
    elseif @capture(expr, a_ = ×(b_, c_))
        return quote
            if $(setindex_trait)($(a)) === $(CanSetindex())
                $(__mul!)($(a), $(b), $(c))
            else
                $(a) = $(_restructure)($a, $(b) * ($c))
            end
        end
    elseif @capture(expr, a_ += ×(b_, c_))
        return quote
            if $(setindex_trait)($(a)) === $(CanSetindex())
                $(__mul!)($(a), $(b), $(c), true, true)
            else
                $(a) = $(a) .+ $(_restructure)($a, $(b) * ($c))
            end
        end
    end
    return nothing
end

function __handle_dot_op_equals_operators(M, expr, depth)
    op = nothing
    al, bl = nothing, nothing
    if @capture(expr, a_ .= b_)
        return quote
            if $(setindex_trait)($(a)) === $(CanSetindex())
                $(a) .= $(b)
            else
                $(a) = $(b)
            end
        end
    end
    @capture(expr, a_ .+= b_) && (op = :.+; al = a; bl = b)
    @capture(expr, a_ .-= b_) && (op = :.-; al = a; bl = b)
    @capture(expr, a_ .*= b_) && (op = :.*; al = a; bl = b)
    @capture(expr, a_ ./= b_) && (op = :./; al = a; bl = b)
    if op !== nothing
        return quote
            if $(setindex_trait)($(al)) === $(CanSetindex())
                $(al) .= $(op)($(al), $(bl))
            else
                $(al) = $(op)($(al), $(bl))
            end
        end
    end
    return nothing
end

function __handle_dot_macro(M, a, f, depth)
    return quote
        if $(setindex_trait)($(a)) === $(CanSetindex())
            @. $(a) = $(f)
        else
            $(a) = @. $(f)
        end
    end
end

function __handle_axpy(M, α, x, y, depth)
    return quote
        if $(setindex_trait)($(y)) === $(CanSetindex())
            $(__safe_axpy!)($(α), $(x), $(y))
        else
            $(y) = @. $(α) * $(x) + $(y)
        end
    end
end

## Traits
abstract type AbstractMaybeSetindex end
struct CannotSetindex <: AbstractMaybeSetindex end
struct CanSetindex <: AbstractMaybeSetindex end

"""
    setindex_trait(A)

Returns `CanSetindex()` if `A` can be setindex-ed else returns `CannotSetindex()`. This is
used by `@bangbang` to determine if an array can be setindex-ed or not.
"""
@inline setindex_trait(::Number) = CannotSetindex()
@inline setindex_trait(::Array) = CanSetindex()
@inline setindex_trait(A::SubArray) = setindex_trait(parent(A))
# LinearAlgebra wrapper types: delegate to parent
@inline setindex_trait(A::LinearAlgebra.Symmetric) = setindex_trait(parent(A))
@inline setindex_trait(A::LinearAlgebra.Hermitian) = setindex_trait(parent(A))
@inline setindex_trait(A::LinearAlgebra.AbstractTriangular) = setindex_trait(parent(A))
@inline setindex_trait(A::LinearAlgebra.Diagonal) = setindex_trait(parent(A))
# In recent versions of Julia, this function has a type stable return type even without
# overloading for custom array types
@inline setindex_trait(A) = ifelse(can_setindex(A), CanSetindex(), CannotSetindex())

## Operations
@inline __copyto!!(::CannotSetindex, x, y) = y
@inline __copyto!!(::CanSetindex, x, y) = (copyto!(x, y); x)

@inline __broadcast!!(::CannotSetindex, op, x, args...) = broadcast(op, args...)
@inline __broadcast!!(::CanSetindex, op, x, args...) = (broadcast!(op, x, args...); x)

@inline __sub!!(S, x, args...) = __broadcast!!(S, -, x, x, args...)
@inline __add!!(S, x, args...) = __broadcast!!(S, +, x, x, args...)
@inline __mul!!(S, x, args...) = __broadcast!!(S, *, x, x, args...)
@inline __div!!(S, x, args...) = __broadcast!!(S, /, x, x, args...)

@inline __copy(::CannotSetindex, x) = x
@inline __copy(::CanSetindex, x) = copy(x)

@inline __zero(::CannotSetindex, x) = x
@inline __zero(::CanSetindex, x) = zero(x)

@inline __similar(::CannotSetindex, x) = x
@inline __similar(::CanSetindex, x) = similar(x)
@inline function __similar(::CanSetindex, x::AbstractArray{<:BigFloat})
    y = similar(x)
    fill!(y, zero(eltype(y)))
    return y
end

const OP_MAPPING = Dict{Symbol, Function}(
    :copyto! => __copyto!!, :.-= => __sub!!,
    :.+= => __add!!, :.*= => __mul!!, :./= => __div!!, :copy => __copy
)

@inline @generated function __safe_axpy!(α, x, y)
    # In a `@generated` body the arguments are the argument *types*, so the method lookup
    # uses them directly; `typeof` would ask whether `axpy!` accepts three `DataType`s,
    # which is never true, leaving the fallback unreachable.
    hasmethod(axpy!, Tuple{α, x, y}) || return :(@. y += α * x)
    return :(axpy!(α, x, y))
end

"""
    __mul!(C, A, B)
    __mul!(C, A, B, α, β)

Mutating multiplication hook used by `@bangbang`/`@bb` when rewriting the custom
matrix multiplication operator `×`.

`__mul!(C, A, B)` writes `A * B` into `C`. `__mul!(C, A, B, α, β)` writes the
scaled update `α * A * B + β * C` into `C`, matching the semantics of
`LinearAlgebra.mul!`.

## Arguments

  - `C`: mutable output storage that receives the multiplication result.
  - `A`: left multiplication input.
  - `B`: right multiplication input.
  - `α`: multiplier applied to `A * B` in the five-argument form.
  - `β`: multiplier applied to the previous contents of `C` in the five-argument form.

## Interface

`__mul!` is a developer extension point, not a general user-facing multiplication API.
Extend `MaybeInplace.__mul!` only when a destination type needs a specialized
storage-preserving implementation for `@bb y = A × B` or `@bb y += A × B`.

Implementations must mutate and return `C`. The three-argument form must overwrite `C`
with `A * B`; the five-argument form must overwrite `C` with `α * A * B + β * C`, using
the value of `C` that existed on entry. Methods must preserve the destination's shape and
storage invariants, or return a result that `MaybeInplace` can restructure to that shape.
Do not call this hook directly from ordinary application code; use the `@bangbang` macro.

## Examples

```julia
using MaybeInplace

C = zeros(2)
A = [1.0 2.0; 3.0 4.0]
B = [1.0, 1.0]

MaybeInplace.__mul!(C, A, B)
C == [3.0, 7.0]
```
"""
__mul!(C, A, B) = mul!(C, A, B)
__mul!(C, A, B, α, β) = mul!(C, A, B, α, β)

## Macros
"""
    @bangbang expr
    @bangbang iip expr

Rewrite a supported mutating expression so that it updates mutable destinations and
rebinds immutable destinations to an equivalent out-of-place result.

# Arguments

  - `expr`: one supported operation: `copyto!(y, x)`, `axpy!(a, x, y)`, `y .= x`,
    `y .+= x`, `y .-= x`, `y .*= x`, `y ./= x`, `y = copy(x)`, `y = zero(x)`,
    `y = similar(x)`, `@. y = f`, `y = A × B`, or `y += A × B`.
  - `iip`: an identifier bound to a `Bool`. When it is `true`, the supplied function call
    is evaluated as written; when it is `false`, its first argument is rebound to the
    corresponding out-of-place result. This form applies only to ordinary function calls.

The macro uses the destination's setindex trait to select its branch. For immutable
destinations, it preserves the value semantics of the listed operations, not the exact
mutating-call contract. Unsupported syntax raises an error during macro expansion.

# Examples

```julia
using MaybeInplace

function add_one(y)
    @bangbang y .+= 1
    return y
end

add_one([1, 2])
```
"""
macro bangbang(expr)
    return __bangbang__(__module__, expr)
end

macro bangbang(iip::Symbol, expr)
    return __bangbang__(__module__, iip, expr)
end

"""
    @bb expr
    @bb iip expr

Alias for [`@bangbang`](@ref). Use `@bb` when a compact spelling makes a sequence of
generic in-place/out-of-place operations easier to read.

# Arguments

  - `expr`: a supported `@bangbang` expression.
  - `iip`: an identifier bound to a `Bool` for the conditional function-call form.

# Examples

```julia
using MaybeInplace

function copy_value(y, x)
    @bb copyto!(y, x)
    return y
end

copy_value([0.0, 0.0], [1.0, 2.0])
```
"""
macro bb(expr)
    return __bangbang__(__module__, expr)
end

macro bb(iip::Symbol, expr)
    return __bangbang__(__module__, iip, expr)
end

"""
    @❗ expr
    @❗ iip expr

Alias for [`@bangbang`](@ref), named with an exclamation mark to emphasize code that can
mutate its destination. Type the macro name with `\\:exclamation:<tab>` in the Julia REPL.

# Arguments

  - `expr`: a supported `@bangbang` expression.
  - `iip`: an identifier bound to a `Bool` for the conditional function-call form.

# Examples

```julia
using MaybeInplace

function scale_value(y)
    @❗ y .*= 2
    return y
end

scale_value([1, 2])
```
"""
macro ❗(expr)
    return __bangbang__(__module__, expr)
end

macro ❗(iip::Symbol, expr)
    return __bangbang__(__module__, iip, expr)
end

@inline _vec(v) = v
@inline _vec(v::Number) = v
@inline _vec(v::AbstractArray) = vec(v)

@inline _restructure(y::Number, x::Number) = x
@inline _restructure(y, x) = restructure(y, x)

## Exports
export @bb, @bangbang, @❗

@static if VERSION >= v"1.11"
    eval(Expr(:public, :__mul!))
end

using PrecompileTools: @compile_workload, @setup_workload

@setup_workload begin
    @compile_workload begin
        x = [1.0, 2.0]
        y = similar(x)
        @bb copyto!(y, x)
        @bb y .+= x
        @bb y .*= 2
        setindex_trait(y)
        setindex_trait(1.0)
    end
end

end
