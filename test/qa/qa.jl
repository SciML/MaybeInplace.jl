using Aqua, JET, MaybeInplace, SciMLTesting, Test
using ExplicitImports
# Load SparseArrays so MaybeInplaceSparseArraysExt is active: the ExplicitImports
# checks recurse into loaded extensions, so the extension's accesses are covered too.
using SparseArrays

# `can_setindex`/`restructure` are core ArrayInterface API that MaybeInplace is built
# on, but ArrayInterface exports nothing and declares no public names, so there is no
# public alias to switch to — ignore them for the explicit-imports-are-public check.
qualified_public_ignore = if VERSION >= v"1.11"
    ()
else
    # On Julia < 1.11 there is no `public` keyword, so ExplicitImports treats only
    # exported names as public. Two names are exported/public on >=1.11 but not on
    # 1.10, with no public alias available on 1.10:
    #   * `LinearAlgebra.AbstractTriangular` (public since 1.11);
    #   * MaybeInplace's own `__mul!` overload point (declared `public` only on >=1.11),
    #     accessed by MaybeInplaceSparseArraysExt.
    (:AbstractTriangular, :__mul!)
end

ei_kwargs = (;
    all_explicit_imports_are_public = (; ignore = (:can_setindex, :restructure)),
    all_qualified_accesses_are_public = (; ignore = qualified_public_ignore),
)

run_qa(
    MaybeInplace;
    Aqua = Aqua,
    JET = JET,
    jet = true,
    jet_kwargs = (; target_defined_modules = true),
    aqua_kwargs = (; ambiguities = false),
    ExplicitImports = ExplicitImports,
    explicit_imports = true,
    ei_kwargs = ei_kwargs,
)
