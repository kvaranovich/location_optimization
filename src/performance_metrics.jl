using Statistics
using DataFrames
using Dates
using OpenStreetMapX
using CSV
using Random
using OpenStreetMapXPlot
using JuMP
using GLPK
using RCall
using StatsBase
using GLM
import Plots

include("auxillary_functions.jl")
include("movement_search_space.jl")
include("optimization_step.jl")
include("optimization.jl")
include("distance_matrix.jl")

map_path = "winnipeg_map.osm"
mx = get_map_data(map_path, use_cache=false, road_levels=Set(1:5));

"""
    C1_mean_dist_to_primary(mx::MapData, positions::Vector{Int})

C1 metric - Compute the mean distance to primary location from each demand point.

# Arguments
- `mx::MapData`: MapData object from OpenStreetMapX library
- `positions::Vector{Int}`: List of nodes inidicating positions of ambulances
"""
function C1_mean_dist_to_primary(mx::MapData, positions::Vector{Int})
    all_nodes = mx.v |> keys |> collect
    df = DataFrame(node = Int64[],
                   primary_amb = Int64[],
                   backup_amb = Int64[],
                   dist_to_primary = Float64[],
                   dist_to_backup = Float64[])

    for node in all_nodes
        println(nrow(df))
        dist = []
        ambulances = []

        for position in positions
            route = fastest_route(mx, node, position)
            append!(dist, route[3])
            append!(ambulances, position)
        end

        i = sortperm(dist)
        push!(df, [node ambulances[i[1]] ambulances[i[2]] dist[i[1]] dist[i[2]]])
    end

    return df
end

positions = [129014143,
  128686681,
  370073744,
  469531931,
   82772408,
  323530106,
  735138811,
 1715694314,
 1878845103]

df = C1_mean_dist_to_primary(mx, positions)
