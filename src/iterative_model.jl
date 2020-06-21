# ========================================
# Commmand Line Interface definition
# ========================================
println("===== Commmand Line Interface definition =====")
using ArgParse

function parse_commandline()
  s = ArgParseSettings()

  @add_arg_table! s begin
    "--city"
      help = "name of .osm file in osm_maps folder, representing a city (without .osm extension)"
      arg_type = String
      required = true
    "--metric"
      help = "a metric to choose from, either \"distance\" or \"time\"."
      arg_type = String
      required = true
    "--p"
      help = "number of ambulances, e.g. [4, 9, 16]"
      arg_type = Int
      required = true
    "--r"
      help = """radius of reachable nodes around each ambulance to consider at
      each optimization step. The higher the radius, the longer is optimization
      time. Examples: [100.00, 150.00, 175.00] for time and [1000.00, 2000.00, 3000.00]"""
      arg_type = Float64
      required = true
    "--R"
      help = """radius of required coverage / threshold in meters, e.g.
      [3000.00, 4500.00, 6000.00] or seconds, e.g. [300.0, 600.0, 900.0];"""
      arg_type = Float64
      required = true
    "--q"
      help = """minimum number of coverage, e.g. [1, 2, 3]. Used only to calculate
      C1:C5 metrics. Doesn't influence final allocation."""
      arg_type = Int
      required = true
    "--ruin_random"
      help = """% of potential moves to randomly destroy at each iteration. In
      general, leads to better computing time at a cost of worse results. It
      is not recommended to set it higher than 0.5. Setting parameter to 0.0
      means that no potential moves are destroyed, i.e. all moves are considered"""
      arg_type = Float64
      required = true
	"--seed"
	  help = "random seed for reproducing results"
	  arg_type = Int
	  required = true
  end

  return parse_args(s)
end

args = parse_commandline()

# ========================================
# Libraries
# ========================================
println("===== Reading Libraries =====")
using Statistics
using DataFrames
using Dates
using OpenStreetMapX
using CSV
using Random
using OpenStreetMapXPlot
using JuMP
using GLPK
using GLM
using RCall
using StatsBase
import Plots

include("auxillary_functions.jl")
include("movement_search_space.jl")
include("optimization_step.jl")
include("optimization.jl")
include("distance_matrix.jl")
include("performance_metrics.jl")

# Examples input parameters for interactive testing
# args = Dict("city" => "winnipeg", "metric" => "distance", "p" => 9, "r" => 150.00)

# ========================================
# Input parameters and data
# ========================================
println("===== Input parameters and data =====")
const p = args["p"] #number of facilities
const r = args["r"] #radius of local search
const R = args["R"] #required threshold / coverage for an ambulance
const q = args["q"] #required number of coverage for each demand point
const city = args["city"]
const map_path = "../osm_maps/" * city * ".osm"
const metric = args["metric"]
const ruin_random = args["ruin_random"]
const seed = args["seed"]
Random.seed!(seed)

mx = get_map_data(map_path, use_cache=false, road_levels=Set(1:5));

# ========================================
#Output folder
# ========================================
println("===== Creating Output Folder =====")
output_path = "../output/iterative/" *
              string(Dates.format(Dates.now(), "yyyymmdd_HHMM_")) * city *
              "_" * metric * "_p" * string(p) * "_r" * string(Int(r)) *
			  "_ruin" * string(ruin_random)
mkdir(output_path)

# ========================================
#Write input parameters to a text file
# ========================================
println("===== Writing input parameters to a text file =====")
input_parameters = join([(k * " = " * string(v)) for (k, v) in args], "\n")
open(output_path * "/input_parameters.txt", "w") do f
  write(f, input_parameters)
end

# ========================================
# Model
# ========================================
println("===== Model optimization =====")

initial_nodes = generate_ambulances_centers(mx, p)
t = @elapsed opt_loc = location_optimization_radius(mx, initial_nodes, 100,
                                                    metric, ruin_random, r)

final_nodes = opt_loc[1][end]
obj = opt_loc[2][end]

println("===== Calculating C1-C5 metrics =====")
C1, C2, C3, C4, C5 = c1_c5_metrics(mx, final_nodes, metric, R, q)

#Writing output information
println("===== Writing Output information: 1. Results =====")
open(output_path * "/results.txt", "w") do f
  print(f, "===== Results =====" * "\n")
  print(f, "Processing time: " * string(t) * "\n")
  print(f, "Objective value: " * string(obj) * "\n")
  print(f, "C1: " * string(C1) * "\n")
  print(f, "C2: " * string(C2) * "\n")
  print(f, "C3: " * string(C3) * "\n")
  print(f, "C4: " * string(C4) * "\n")
  print(f, "C5: " * string(C5) * "\n")
end

#Converting nodes to Longitude, Latitude for visualization
println("===== Converting nodes to Longitude, Latitude for visualization =====")
all_nodes = mx.v |> keys |> collect
LLA_all = [LLA(mx.nodes[x], center(mx.bounds)) for x in all_nodes]
LLA_all = [(x.lat, x.lon) for x in LLA_all]
LLA_final = [LLA(mx.nodes[x], center(mx.bounds)) for x in final_nodes]
LLA_final = [(x.lat, x.lon) for x in LLA_final]

#Saving results to DataFrames and then to CSV
println("===== Writing Output information: 2. final_nodes, demand_points =====")
final_nodes = DataFrame(node = string.(final_nodes), #cast to string to avoid type convertsion between julia and R
                       lat = [x[1] for x in LLA_final],
                       lon = [x[2] for x in LLA_final])
demand_points = DataFrame(node = string.(all_nodes), #cast to string to avoid type convertsion between julia and R
                          lat = [x[1] for x in LLA_all],
                          lon = [x[2] for x in LLA_all])

CSV.write(output_path * "/final_nodes.csv", final_nodes)
CSV.write(output_path * "/demand_points.csv", demand_points)

# Transitions data frame - for animation of optimization process
states = collect(Iterators.flatten(opt_loc[1]))
states_lat_long = [LLA(mx.nodes[states[i]], mx.bounds) for i in 1:length(states)]
state_no = [collect(Iterators.flatten(fill.(i, length(opt_loc[1][i])))) for i in 1:length(opt_loc[1])]
state_no = collect(Iterators.flatten(state_no))
times = opt_loc[2]

transitions_df = DataFrame(
  lat = [states_lat_long[i].lat for i in 1:length(states_lat_long)],
  lon = [states_lat_long[i].lon for i in 1:length(states_lat_long)],
  state = state_no
)

CSV.write(output_path * "/transitions_df.csv", transitions_df)

results_df = DataFrame(datetime = Dates.now(), model_type = "iterative", metric = metric,
                       p = p, m = length(mx.v), n = length(mx.v), q = q, R = R, r = r,
                       obj = obj, obj2 = 0.0, proc_time = t, ruin_random = ruin_random,
                       C1 = C1, C2 = C2, C3 = C3, C4 = C4, C5 = C5)
CSV.write(output_path * "/../../output_all_models.csv", results_df, append=true)

# Visualization of results in R's ggmap
println("===== Writing Output information: 3. Plotting results on a map =====")
@rput final_nodes demand_points transitions_df times

R"""
library(ggplot2)
suppressPackageStartupMessages(library(ggmap))
library(gganimate)

if (!file.exists((paste0("../ggmaps/", $city, ".RDS")))) {
  KEY <- readr::read_file('../GOOGLE_API_KEY.txt');
  register_google(key = KEY);
  map_city <- get_googlemap(center = c(lon = mean(demand_points$lon),
                                       lat = mean(demand_points$lat)))
  saveRDS(map_city, file = paste0("../ggmaps/", $city, ".RDS"))
} else {
  map_city <- readRDS(file = paste0("../ggmaps/", $city, ".RDS"))
}
"""

R"""
plt <- ggmap(map_city) +
  geom_point(aes(x=lon, y=lat),
             data=demand_points, color="black", size=1, alpha = 0.5) +
  geom_point(aes(x=lon, y=lat), data=final_nodes,
             shape = 23, alpha = 0.75, size=3, fill="green") +
  xlab("Longitude") + ylab("Latitude") +
  ggtitle("Demand Points",
          subtitle = paste0("City: ", stringr::str_to_title($city), "\n",
                            "p = ", as.character($p), " ambulances, ",
                            "ruin_random = ", as.character($ruin_random), "\n",
                            "Objective value = ", as.character(round($obj, 4)), " seconds\n",
                            "Optimization time = ", as.character(round($t/60, 4)), " minutes"))

ggsave(filename = "positions.png", path = $output_path,  plot = plt)
"""

# Output - animation of optimization
println("===== Writing Output information: 4. Optimization animation =====")

R"""
p <- ggmap(map_city,
           base_layer = ggplot(aes(x = lon, y = lat), data = transitions_df)) +
  geom_point(size = 3)

anim <- p +
  transition_states(state,
                    transition_length = 1,
                    state_length = 1) +
  ggtitle('Now showing {closest_state}', subtitle = '{times[as.integer(closest_state)]}')

a <- animate(anim, fps = 5, nframes = 2*max(transitions_df$state))

suppressMessages(
	anim_save(filename = "optimization.gif", animation = a, path = $output_path)
)
"""

println("=============== Finished processing ===============")
