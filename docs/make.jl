using Documenter

push!(LOAD_PATH,"../src/")

using PosixChannels

makedocs(
    sitename = "PosixChannels",
    format = Documenter.HTML(),
    modules = [PosixChannels]
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
#=deploydocs(
    repo = "<repository url>"
)=#
deploydocs(
    repo = "github.com/Klafyvel/PosixChannels.jl.git",
)
