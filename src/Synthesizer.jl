module Synthesizer

using Reexport
@reexport using Jaynes
using IRTools
using IRTools: @dynamo, IR, recurse!
using MacroTools
using MacroTools: rmlines, unblock
using Mjolnir

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
    esc(fn)
end

macro lang(name, args, expr)
    fn = _lang(name, args, expr)
    esc(fn)
end

# Insert a hole into a function.
hole(lang::Function) = rand(gensym(), lang)
hole(lang::Function, args...) = rand(gensym(), lang, args...)
hole(addr::Jaynes.Address, lang::Function) = rand(addr, lang)
hole(addr::Jaynes.Address, lang::Function, args...) = rand(addr, lang, args...)

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

function synthesize(fn::Function, pairs::Array{T}; iters = 1000) where T <: Tuple
    found = false
    while !found && iters != 0
        for (x, y) in pairs
            ret, cl = propose(fn, x)
            if ret == y 
                return ret, cl
            end
            continue
        end
        iters -= 1
    end
    return nothing, nothing
end

export @lang, synthesize, hole

end # module
