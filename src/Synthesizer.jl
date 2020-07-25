module Synthesizer

using Jaynes
using IRTools

@dynamo function synthesize(a...)
    ir = IR(a...)
    ir == nothing && return
    recurse!(ir)
    return ir
end

# ------------ Example usage 1 ------------ #

# Declare a probabilistic DSL.
@lang (arithmetic) expr = begin
    0.5 => expr * expr
    0.3 => expr + expr
    0.2 => 2.0
end

# Insert a hole into a function.
function foo(x::Float64)
    y = x * hole(arithmetic())
    return y
end

# Synthesize a new IR fragment which satisfies the specification. Also provide a probabilistic trace of the synthesizer.
ir, cl = synthesize(foo, [(1.0, 2.0), (2.0, 4.0)])
println(ir)

# ------------ Example usage 2 ------------ #

# Multiple languages
@lang (arrays) expr = begin
    0.5 => [1.0, 3.0]
    0.5 => [3.0, 5.0]
end

function bar(x::Float64)
    y = x .+ hole(arrays())
    z = x * hole(arithmetic())
    return y, z
end

ir, cl = synthesize(foo, [(1.0, ([2.0, 4.0], 2.0)), (3.0, ([4.0, 6.0], 6.0))])
println(ir)

end # module
