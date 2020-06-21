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
      help = "a metric to choose from, either \"distance\", \"time\" or \"eucledian\". distance and time are calculated on graph"
      arg_type = String
      required = true
    "--p"
      help = "number of ambulances, e.g. [4, 9, 16]"
      arg_type = Int
      required = true
    "--m"
      help = "number of candidate locations, e.g. [50, 100, 200, 400]"
      arg_type = Int
      required = true
    "--n"
      help = "number of demand points, e.g. [500, 1000, 1500, 2000]"
      arg_type = Int
      required = true
    "--q"
      help = "minimum number of coverage, e.g. [1, 2, 3]"
      arg_type = Int
      required = true
    "--r"
      help = """radius of coverage in meters, e.g. [3000.00, 4500.00, 6000.00];
      meters are gonna be converted to seconds if the specified metric is time;
      In p-mp model this argument is only used to calculate C1-C5 metrics"""
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
#args = Dict("city" => "winnipeg", "metric" => "distance",
#            "m" => 20, "n" => 200, "p" => 9, "q" => 1)

# ========================================
# Input parameters and data
# ========================================
println("===== Input parameters and data =====")
const m = args["m"] #number of candidate locations (max: 400 - 6.5 hours)
const n = args["n"] #numer of demand locations (max: 2000)
const h = n #weights for demand locations, assumed to be 1 for all demand points
const p = args["p"] #number of facilities
const q = args["q"] #minimum number of coverage required
const r = args["r"] #minimum number of coverage required
const city = args["city"]
const map_path = "../osm_maps/" * city * ".osm"
const metric = args["metric"]
const seed = args["seed"]
Random.seed!(seed)

mx = get_map_data(map_path, use_cache=false, road_levels=Set(1:5));
const reachable_nodes, node_data = find_connected_nodes(mx, metric)

# ========================================
#Output folder
# ========================================
println("===== Creating Output Folder =====")
output_path = "../output/p-mp/" *
              string(Dates.format(Dates.now(), "yyyymmdd_HHMM_")) *
              city * "_" * metric * "_" * "p" * string(p) *
              "_m" * string(m) * "_n" * string(n) * "_q" * string(q)
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

# 1. Sample M candidate locations and N demand locations
println("===== Model: 1. Sample M candidate locations and N demand locations =====")
Random.seed!(0)
const M = sample(reachable_nodes, m, replace=false)
const N = sample(reachable_nodes, n, replace=false)
const H = repeat([1], h)

# 2. Calculate distance matrix
println("===== Model: 2. Calculating distance matrix =====")
if metric in ["distance", "time"]
  const D_ij = build_distance_matrix_graph(M, N, node_data)
elseif metric == "eucledian"
  const D_ij = build_distance_matrix_eucleadian(M, N, mx)
else
  error("Wrong metric used. Metric can only be: distance, time or eucledian")
end

println("===== Model: 3. Saving distance matrix to csv =====")
D_ij_df = DataFrame(D_ij)
CSV.write(output_path * "/distance_matrix.csv", D_ij_df)

# 3. Define a JuMP Model
println("===== Model: 4. Defining a JuMP Model =====")
model = Model(GLPK.Optimizer)

@variable(model, y[1:m], Bin) # 1 if facility is sited at location "i"
@variable(model, z[1:m, 1:n], Bin) # 1 demand j is assigned to a facility at location "i"

@objective(model, Min, sum(H[j]*D_ij[i,j]*z[i,j] for i in 1:m, j in 1:n))

@constraint(model, sum(y[i] for i in 1:m) == p)
@constraint(model, eq3[j = 1:n], sum(z[i, j] for i in 1:m) == q)
@constraint(model, con[i = 1:m, j = 1:n], z[i,j] <= y[i])
#@constraint(model)

println("===== Model: 5. Optimizing JuMP Model =====")
t = @elapsed JuMP.optimize!(model)

JuMP.value.(y)
JuMP.value.(z)
final_nodes = M[convert(Array{Bool}, JuMP.value.(y))]
obj = estimate_amb_layout_goodness(final_nodes, mx)

println("===== Calculating C1-C5 metrics =====")
C1, C2, C3, C4, C5 = c1_c5_metrics(mx, final_nodes, metric, r, q)

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
  print(f, "===== JuMP Information =====" * "\n")
  print(f, "Objective value: " * string(objective_value(model)))
end

#Converting nodes to Longitude, Latitude for visualization
println("===== Converting nodes to Longitude, Latitude for visualization =====")
LLA_M = [LLA(mx.nodes[x], center(mx.bounds)) for x in M]
LLA_M = [(x.lat, x.lon) for x in LLA_M]
LLA_N = [LLA(mx.nodes[x], center(mx.bounds)) for x in N]
LLA_N = [(x.lat, x.lon) for x in LLA_N]

#Saving results to DataFrames and then to CSV
println("===== Writing Output information: 2. candidates, demand_points, demand_assignment =====")
candidates = DataFrame(node = string.(M), #cast to string to avoid type convertsion between julia and R
                       lat = [x[1] for x in LLA_M],
                       lon = [x[2] for x in LLA_M],
                       is_occupied = convert(Array{Int}, JuMP.value.(y)))
demand_points = DataFrame(node = string.(N), #cast to string to avoid type convertsion between julia and R
                          lat = [x[1] for x in LLA_N],
                          lon = [x[2] for x in LLA_N])
demand_assignment = DataFrame(convert(Array{Int}, JuMP.value.(z)))
vals = [Symbol(x) for x in "N" .* string.(1:n)]
rename!(demand_assignment, vals)
demand_assignment = hcat("M" .* string.(1:m), demand_assignment)

CSV.write(output_path * "/candidates.csv", candidates)
CSV.write(output_path * "/demand_points.csv", demand_points)
CSV.write(output_path * "/demand_assignment.csv", demand_assignment)

results_df = DataFrame(datetime = Dates.now(), model_type = "p-mp", metric = metric,
                       p = p, m = m, n = n, q = q, R = r, r = missing, obj = obj,
                       obj2 = objective_value(model), proc_time = t,
                       ruin_random = missing,
                       C1 = C1, C2 = C2, C3 = C3, C4 = C4, C5 = C5)
CSV.write(output_path * "/../../output_all_models.csv", results_df, append=true)

# Visualization of results in R's ggmap
println("===== Writing Output information: 3. Plotting results on a map =====")
@rput candidates demand_points demand_assignment

R"""
library(ggplot2)
suppressPackageStartupMessages(library(ggmap))
suppressPackageStartupMessages(library(dplyr))

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
candidates <- candidates %>% arrange(is_occupied)
plt <- ggmap(map_city) +
  geom_point(aes(x=lon, y=lat),
             data=demand_points, color="black", size=1, alpha = 0.5) +
  geom_point(aes(x=lon, y=lat,
                 fill=factor(is_occupied, labels = c("No", "Yes")),
                 size=factor(is_occupied, labels = c("No", "Yes")) ),
             data=candidates, shape = 23, alpha = 0.75) +
  scale_fill_manual(values = c("No" = "red", "Yes" = "green")) +
  scale_size_manual(values = c("No" = 1.5, "Yes" = 3)) +
  xlab("Longitude") + ylab("Latitude") +
  ggtitle("Demand Points",
          subtitle = paste0("City: ", stringr::str_to_title($city), "\n",
                            "p = ", as.character($p), " ambulances, ",
                            "m = ", as.character($m), " candidate locations, ",
                            "n = ", as.character($n), " demand points, ",
                            "q = ", as.character($q), "\n",
                            "Objective value = ", as.character(round($obj, 4)), " seconds\n",
                            "Optimization time = ", as.character(round($t/60, 4)), " minutes")) +
  labs(fill = "Is Candidate Location Occupied",
       size = "Is Candidate Location Occupied")

suppressMessages(
  ggsave(filename = "positions.png", path = $output_path,  plot = plt)
)
"""
println("=============== Finished processing ===============")
