# Libraries
using Statistics
using DataFrames
using OpenStreetMapX
using CSV
using JLD
using Random
using OpenStreetMapXPlot
import Plots
Random.seed!(0)

include("auxillary_functions.jl")
include("movement_search_space.jl")
include("optimization_step.jl")
include("optimization.jl")

# Input data
map_path = "winnipeg_map.osm"
mx = get_map_data(map_path, use_cache=false, road_levels=Set(1:5));

# Start flow
GRID_DIM = make_grid(mx, 9);
N_AMB = GRID_DIM[1]*GRID_DIM[2];
LOC = find_centers(mx, GRID_DIM);
ORIGIN_NODES = [point_to_nodes(LOC[i], mx) for i in 1:length(LOC)];
plot_ambulances(ORIGIN_NODES, mx, "Initial placement")

# Initial location optimization
@time OPTIMAL_LOCATION = location_optimization(mx, ORIGIN_NODES, 100)
plot_ambulances(OPTIMAL_LOCATION[1][end], mx, "Initial optimization - neighbour nodes only")
#save("optimal_location_north_bay_4amb.jld", "OPTIMAL_LOCATION", OPTIMAL_LOCATION)

# Dispatching one ambulance
DISPATCHED_AMB = rand(OPTIMAL_LOCATION[1][end], 1)[1]
ORIGIN_NODES_AFTER_DISPATCH = copy(OPTIMAL_LOCATION[1][end])
filter!(x -> x!=DISPATCHED_AMB, ORIGIN_NODES_AFTER_DISPATCH)
plot_ambulances(ORIGIN_NODES_AFTER_DISPATCH, mx, "After dispath of one ambulance")

# Relocation
OPTIMAL_LOCATION_AFTER_DISPATCH = location_optimization(mx, ORIGIN_NODES_AFTER_DISPATCH, 500)
plot_ambulances(OPTIMAL_LOCATION_AFTER_DISPATCH[1][end], mx, "Relocation #1: neighbour nodes only")

OPTIMAL_LOCATION_GLOBAL = location_optimization_route_all_nodes(mx, ORIGIN_NODES_AFTER_DISPATCH, DISPATCHED_AMB)
plot_ambulances(OPTIMAL_LOCATION_GLOBAL[1][end], mx, "Relocation #2: global - all nodes on route")

OPTIMAL_LOCATION_LOCAL = location_optimization_radius(mx, OPTIMAL_LOCATION_GLOBAL[1][end], 100, 175.0)
plot_ambulances(OPTIMAL_LOCATION_LOCAL[1][end], mx, "Relocation #3: local after global")
# Dropout optimization
Random.seed!(0)
states,  times, ambulances = location_optimization_dropout(mx, ORIGIN_NODES, 500)
#Saving data for animation
FLAT_OPTIMAL_LOCATION = collect(Iterators.flatten(states))
FLAT_OPTIMAL_LOCATION_LAT_LONG = [LLA(mx.nodes[FLAT_OPTIMAL_LOCATION[i]], mx.bounds) for i in 1:length(FLAT_OPTIMAL_LOCATION)]
STATE_NO = [collect(Iterators.flatten(fill.(i, length(states[i])))) for i in 1:length(states)]
STATE_NO = collect(Iterators.flatten(STATE_NO))
transitions_df = DataFrame(
LAT = [FLAT_OPTIMAL_LOCATION_LAT_LONG[i].lat for i in 1:length(FLAT_OPTIMAL_LOCATION_LAT_LONG)],
LONG = [FLAT_OPTIMAL_LOCATION_LAT_LONG[i].lon for i in 1:length(FLAT_OPTIMAL_LOCATION_LAT_LONG)],
STATE = STATE_NO
)
CSV.write("transitions_df_dropout_2.csv", transitions_df)
