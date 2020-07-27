using Documenter
using Synthesizer

makedocs(sitename = "Synthesizer.jl",
         pages = ["Introduction" => "index.md"],
         format = Documenter.HTML(prettyurls = true,
                                  assets = ["assets/favicon.ico"])
        )

deploydocs(repo = "github.com/femtomc/Synthesizer.jl.git")
