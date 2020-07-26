module Synthesizer

using Jaynes
using IRTools
using IRTools: @dynamo, IR, recurse!
using MacroTools
using MacroTools: rmlines, unblock

# ------------ Fundamentals ------------ #

function _lang(name, expr::Expr)
    @capture(expr, ex_ = begin body__ end)
    trans = Any[]
    probs = Float64[]
    for subexpr in body
        @capture(subexpr, prob_ => sbod_)
        push!(probs, prob)
        nbod = MacroTools.postwalk(sbod) do k
            if k == ex
                Expr(:call, name)
            else
                k
            end
        end
        push!(trans, nbod)
    end
    trans = map(enumerate(trans)) do (i, t)
        i == length(trans) && return Expr(:return, t)
        t = MacroTools.postwalk(t) do sub
            if @capture(sub, $name(args__))
                quote rand($i, $name) end
            else
                sub
            end
        end
        quote if selection == $i
                return $t
            end
        end
    end
    
    return MacroTools.postwalk(unblock ∘ rmlines, quote
                                   function $name()
                                       selection = rand(:sel, Categorical($probs))
                                       $(trans...)
                                   end
                               end)
end

function _lang(name, arg, expr::Expr)
    @capture(expr, ex_ = begin body__ end)
    trans = Any[]
    probs = Float64[]
    for subexpr in body
        @capture(subexpr, prob_ => sbod_)
        push!(probs, prob)
        nbod = MacroTools.postwalk(sbod) do k
            if k == ex
                Expr(:call, name)
            else
                k
            end
        end
        push!(trans, nbod)
    end
    trans = map(enumerate(trans)) do (i, t)
        i == length(trans) && return Expr(:return, t)
        t = MacroTools.postwalk(t) do sub
            if @capture(sub, $name(args__))
                quote rand($i, $name) end
            else
                sub
            end
        end
        quote if selection == $i
                return $t
            end
        end
    end
    
    return MacroTools.postwalk(unblock ∘ rmlines, quote
                                   function $name($arg)
                                       selection = rand(:sel, Categorical($probs))
                                       $(trans...)
                                   end
                               end)
end

macro lang(name, expr)
    fn = _lang(name, expr)
    fn
end

macro lang(name, args, expr)
    fn = _lang(name, args, expr)
    fn
end

# ------------ Example usage 1 ------------ #

# Declare a probabilistic DSL.
@lang (arithmetic) expr = begin
    0.2 => expr * expr
    0.3 => expr + expr
    0.4 => 2.0
    0.1 => 1.0
end

ret, cl = simulate(arithmetic)

# Insert a hole into a function.
hole(lang::Function) = rand(gensym(), lang)
hole(addr::Jaynes.Address, lang::Function) = rand(addr, lang)
hole(addr::Jaynes.Address, lang::Function, args...) = rand(addr, lang, args...)

function foo(x::Float64)
    y = x * hole(1, arithmetic)
    q = hole(2, arithmetic)
    return y * q
end

function synthesize(samples::Int, fn::Function, args::Tuple, d::Distribution; reject = -Inf)
    score = Float64[]
    calls = Jaynes.CallSite[]
    for i in 1 : samples
        ret, cl = simulate(fn, args...)
        if logpdf(d, ret) > reject
            push!(score, logpdf(d, ret))
            push!(calls, cl)
        end
    end
    return Jaynes.Particles(calls, score, 0.0)
end

# Score a bunch of samples from the grammar.
#ps = synthesize(100, foo, (5.0, ), Normal(5.0, 1.0); reject = -Inf)
#map(1:length(ps)) do i
#    display(ps.calls[i].trace)
#    println(ps.lws[i])
#end

# ------------ Example usage 2 ------------ #

# A small array operation language.
swap!(x::Array) = begin
    if length(x) != 1
        x[1], x[end] = x[end], x[1]
    end
    return x
end

swap_tail!(x::Array) = begin
    if length(x) != 1
        x[end - 1], x[end] = x[end], x[end - 1]
    end
    return x
end

swap_head!(x::Array) = begin
    if length(x) != 1
        x[1], x[2] = x[2], x[1]
    end
    return x
end

reorder(x::Array) = begin
    new = typeof(x)()
    if length(x) != 1
        len = length(x)
        if len % 2 == 0
            fst = x[1 : Int(floor(len / 2))]
            snd = x[Int(ceil(len / 2)) + 1 : end]
            append!(snd, fst)
        else
            fst = x[1 : Int(floor(len / 2))]
            snd = x[Int(ceil(len / 2)) : end]
            append!(snd, fst)
        end
    end
    return snd
end

@lang (array_operation) _1 expr = begin
    0.25 => swap!(_1)
    0.25 => reorder(_1)
    0.25 => swap_head!(_1)
    0.25 => swap_tail!(_1)
end

# Some Boolean holes.
@lang (boolean) expr = begin
    0.7 => true
    0.3 => false
end

function check(x::Array{Float64})
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

function foo(x::Array{Float64})
    i = 0
    while !check(x)
        x = hole(:hole_2 => i, array_operation, x)
        i += 1
    end
    return x
end

function synthesize(iters, fn::Function, pairs::Array{T}) where T <: Tuple
    found = false
    while !found && iters != 0
        for (x, y) in pairs
            ret, cl = propose(fn, x)
            if ret == y 
                return ret, cl
            end
            iters -= 1
            continue
        end
    end
    return nothing, nothing
end

ret, cl = synthesize(1000, foo, [([1.0, 5.0, 2.0, 3.0], [1.0, 2.0, 3.0, 5.0])])
ret != nothing && cl != nothing && begin
    display(cl.trace)
    println(ret)
end

end # module
