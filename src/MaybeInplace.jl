module MaybeInplace

using LinearAlgebra, MacroTools, SparseArrays
import ArrayInterface: can_setindex, restructure
import SparseArrays: AbstractSparseArray

## Documentation
__bangbang__docs = """
    @bangbang <expr>
    @bb <expr>
    @❗ <expr> # ❗ can be typed with \\:exclamation:<tab>

The `@bangbang` macro rewrites expressions to use out-of-place operations if needed. The
following operations are supported:

  1. `copyto!(y, x)`
  2. `x .(+/-/*)= <expr>`
  3. `x ./= <expr>`
  4. `x = copy(y)`
  5. `x .= <expr>`
  6. `@. <expr>`
  7. `x = copy(y)`
  8. `axpy!(a, x, y)`
  9. `x = similar(y)`

This macro also allows some custom operators:

  1. `×` (typed with `\\times<tab>`): This is effectively a matmul operator. It is
      rewritten to use `mul!` if `y` can be setindex-ed else it is rewritten to use
      `restructure` to create a new array. If there is a `vec` on the rhs, `vec` is also
      applied to the lhs. This is useful for handling arbitrary dimensional arrays by
      flattening them.

!!! warning

    Using this on any operation not in the list will throw an error.

## Example

```julia
using MaybeInplace, StaticArrays

function my_non_generic_iip_oop(y, x)
    copyto!(y, x)
    return y
end

my_non_generic_iip_oop([0.0, 0.0], [1.0, 1.0]) # Works
my_non_generic_iip_oop(@SVector[0.0, 0.0], @SVector[1.0, 1.0]) # Fails
```

Typically this will fail if `y` cannot be setindex-ed. However, this macro will rewrite
the expression to use `copyto!` if the array supports `setindex!` (via `ArrayInterface.jl`)
else it will use `y = x`.

```julia
function my_generic_iip_oop(y, x)
    @bb copyto!(y, x)
    return y
end

my_generic_iip_oop([0.0, 0.0], [1.0, 1.0]) # Works
my_generic_iip_oop(@SVector[0.0, 0.0], @SVector[1.0, 1.0]) # Also Works
```

Importantly note that this doesn't respect the semantics of `copyto!`, rather it respects
only if the array is mutable, else it just assigns it to the variable. This is true for
all operations on the list.

!!! tip

    For extensive use of this Package, see the source code for `NonlinearSolve.jl` and
    `SimpleNonlinearSolve.jl`

!!! warning

    The generated code heavily relies on the julia compiler constant propating and
    eliminating branches. Using with tools like `Zygote.jl` might lead to slowdowns.
    In those cases, one should anyways use non-mutating code.
"""

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
    if @capture(expr, a_=copy(b_))
        new_expr = :($(a) = $(__copy)($(setindex_trait)($(b)), $(b)))
    elseif @capture(expr, a_=zero(b_))
        new_expr = :($(a) = $(__zero)($(setindex_trait)($(b)), $(b)))
    elseif @capture(expr, a_=similar(b_))
        new_expr = :($(a) = $(__similar)($(setindex_trait)($(b)), $(b)))
    elseif @capture(expr, axpy!(α_, x_, y_))
        new_expr = __handle_axpy(M, α, x, y, depth)
    elseif @capture(expr, f_(a_, args__))
        g = get(OP_MAPPING, f, nothing)
        if g !== nothing
            new_expr = :($(a) = $(g)($(setindex_trait)($(a)), $(a), $(args...)))
        end
    elseif @capture(expr, a_=f_Symbol(b_, args__))
        g = get(OP_MAPPING, f, nothing)
        if g !== nothing
            new_expr = :($(a) = $(g)($(setindex_trait)($(a)), $(a), $(b), $(args...)))
        elseif f == :×
            new_expr = __handle_custom_operator(Val{:times}(), M, expr, depth)
        end
    elseif @capture(expr, @. a_ = f_)
        new_expr = __handle_dot_macro(M, a, f, depth)
    elseif @capture(expr, a_+=×(b_, c_))
        new_expr = __handle_custom_operator(Val{:plustimes}(), M, expr, depth)
    elseif expr.head == :macrocall
        new_expr = __bangbang__(M, Base.macroexpand(M, expr; recursive = true);
            depth = depth + 1)
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
    @capture(expr, a_=×(b_, c_)) || @capture(expr, a_+=×(b_, c_)) ||
        error("Expected `a = b × c` got `$(expr)`")
    @capture(expr, a_=×(vec(b_), vec(c_))) && return nothing
    a_sym = gensym("a")
    if @capture(expr, a_=×(vec(b_), c_))
        return quote
            if $(setindex_trait)($(a)) === $(CanSetindex())
                $(a_sym) = $(a)
                $(__mul!)($(a_sym), $(_vec)($b), $(c))
                $(a) = $(_restructure)($(a), $(a_sym))
            else
                $(a) = $(_restructure)($a, $(_vec)($b) * $(c))
            end
        end
    elseif @capture(expr, a_+=×(vec(b_), c_))
        return quote
            if $(setindex_trait)($(a)) === $(CanSetindex())
                $(a_sym) = $(a)
                $(__mul!)($(a_sym), $(_vec)($b), $(c), true, true)
                $(a) = $(_restructure)($(a), $(a_sym))
            else
                $(a) = $(a) .+ $(_restructure)($a, $(_vec)($b) * $(c))
            end
        end
    elseif @capture(expr, a_=×(b_, vec(c_)))
        return quote
            if $(setindex_trait)($(a)) === $(CanSetindex())
                $(a_sym) = $(_vec)($a)
                $(__mul!)($(a_sym), $(b), $(_vec)($c))
                $(a) = $(_restructure)($(a), $(a_sym))
            else
                $(a) = $(_restructure)($a, $(b) * $(_vec)($c))
            end
        end
    elseif @capture(expr, a_+=×(b_, vec(c_)))
        return quote
            if $(setindex_trait)($(a)) === $(CanSetindex())
                $(a_sym) = $(_vec)($a)
                $(__mul!)($(a_sym), $(b), $(_vec)($c), true, true)
                $(a) = $(_restructure)($(a), $(a_sym))
            else
                $(a) = $(a) .+ $(_restructure)($a, $(b) * $(_vec)($c))
            end
        end
    elseif @capture(expr, a_=×(b_, c_))
        return quote
            if $(setindex_trait)($(a)) === $(CanSetindex())
                $(__mul!)($(a), $(b), $(c))
            else
                $(a) = $(_restructure)($a, $(b) * ($c))
            end
        end
    elseif @capture(expr, a_+=×(b_, c_))
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
    if @capture(expr, a_.=b_)
        return quote
            if $(setindex_trait)($(a)) === $(CanSetindex())
                $(a) .= $(b)
            else
                $(a) = $(b)
            end
        end
    end
    @capture(expr, a_.+=b_) && (op = :.+; al = a; bl = b)
    @capture(expr, a_.-=b_) && (op = :.-; al = a; bl = b)
    @capture(expr, a_.*=b_) && (op = :.*; al = a; bl = b)
    @capture(expr, a_./=b_) && (op = :./; al = a; bl = b)
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
# In recent versions of Julia, this function has a type stable return type even without
# overloading for sutom array types
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

const OP_MAPPING = Dict{Symbol, Function}(:copyto! => __copyto!!, :.-= => __sub!!,
    :.+= => __add!!, :.*= => __mul!!, :./= => __div!!, :copy => __copy)

@inline @generated function __safe_axpy!(α, x, y)
    hasmethod(axpy!, Tuple{typeof(α), typeof(x), typeof(y)}) || return :(axpy!(α, x, y))
    return :(@. y += α * x)
end

# Sparse Arrays `mul!` has really bad performance
# This works around it, and also potentially allows dispatching for other array types
__mul!(C, A, B) = mul!(C, A, B)
__mul!(C::AbstractSparseArray, A, B) = (C .= A * B)
__mul!(C, A, B, α, β) = mul!(C, A, B, α, β)
__mul!(C::AbstractSparseArray, A, B, α, β) = (C .= α * A * B .+ β * C)

## Macros
for m in (:bangbang, :bb, :❗)
    @eval begin
        @doc __bangbang__docs
        macro $m(expr)
            return __bangbang__(__module__, expr)
        end

        @doc __bangbang__docs
        macro $m(iip::Symbol, expr)
            return __bangbang__(__module__, iip, expr)
        end
    end
end

@inline _vec(v) = v
@inline _vec(v::Number) = v
@inline _vec(v::AbstractArray) = vec(v)

@inline _restructure(y::Number, x::Number) = x
@inline _restructure(y, x) = restructure(y, x)

## Exports
export @bb, @bangbang, @❗

end
