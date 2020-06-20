using Pkg

dependencies = [
    "ArgParse",
    "DataFrames",
	"CSV",
	"Plots",
	"OpenStreetMapX",
	"OpenStreetMapXPlot",
	"GLM",
	"GLPK",
	"JuMP",
	"RCall",
	"StatsBase"
]

Pkg.add(dependencies)