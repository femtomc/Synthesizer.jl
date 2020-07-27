This is the documentation for the [Synthesizer.jl](https://github.com/femtomc/Synthesizer.jl) program synthesis system.

The goal of this package is to provide a set of interfaces for probabilistic program synthesis via sketching. The hope is to faciliate research into probabilistic program synthesis, as well as provide a pipeline to optimize synthesized programs as IR fragments, before compilation into a method body in Julia.

---

The idea behind sketching is to provide a high-level skeleton of the program (or function) you want to synthesize. This high-level skeleton contains a number of "holes" which the synthesizer should fill with an expression or function.

Let's say we wanted to synthesize a sorting program.

```julia
function sort!(x::Array{T}) where T <: Number
    while !check(x)
        x = hole(array_operation, x)
    end
    return x
end
```

Here, I've provided the high-level structure of the function (e.g. control flow) but I've also inserted a hole, and I'm telling the synthesizer what sort of hole it should be (an `array_operation` function, which acts on `x`). `array_operation` is defined by a miniature DSL.

```julia
@lang (array_operation) _1 expr = begin
    0.20 => swap!(_1)
    0.20 => reorder(_1)
    0.20 => swap_head!(_1)
    0.20 => swap_tail!(_1)
    0.20 => reverse(_1)
end
```

This DSL is _probabilistic_ - the numbers on the left-hand side correspond to probability of selection by the synthesizer. Furthermore, we've specified that holes of `array_operation` take in a single argument (here, by specifying `_1` before defining the `expr` of type `array_operation`).

In our high-level program, we've cheated a bit by providing a way for the program to determine if it's sorted the list correctly. The function `check` checks if the array satisfies the sorted condition.

```julia
function check(x::Array{T}) where T <: Number
    length(x) == 1 && return true
    i = x[1]
    for j in x[2 : end]
        if !(i < j)
            return false
        end
        i = j
    end
    return true
end
```

To summarize: in `Synthesizer.jl`, the user writes small probabilistic DSLs (specifically, _probabilistic context-free grammars_) which can then be used inside holes in other functions. The process of synthesis is expressed using a [universal trace-based probabilistic programming system](https://github.com/femtomc/Jaynes.jl).

---

The core of the engine is a multi-threaded rejection sampler.

```julia
function synthesize(sel::Array{K}, fn::Function, pair::T; iters = 50) where {K <: Jaynes.ConstrainedSelection, T <: Tuple}
    in, out = pair
    success = Jaynes.CallSite[]
    Threads.@threads for s in sel
        for i in iters
            ret, cl, w = generate(s, fn, in)
            out == ret && push!(success, cl)
        end
    end
    return success
end

function synthesize(fn::Function, pairs::Array{T}; iters = 50) where T <: Tuple
    local cls
    constraints = [selection()]
    for p in pairs
        cls = synthesize(constraints, fn, p; iters = iters)
        cls == nothing && return cls
        constraints = map(cls) do cl
            get_selection(cl)
        end
    end
    return cls
end
```

Here, `synthesize` requires that the user pass in a function with holes, as well as `pairs` of `(input, output)` tuples. `generate` generates a set of possible solutions. This version of `synthesize` will return an `Array` of successful traces (if the search succeeds). The `CallSite` representation is a trace of the original function, as well as a recording of the choices made by the PCFG.

In future versions, `Synthesizer.jl` will support the ability to compile these traces into IR and generate a new (optimized) method body for the synthesized function.
