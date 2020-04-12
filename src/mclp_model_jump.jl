# ========================================
# Commmand Line Interface definition
# ========================================
println("===== Commmand Line Interface definition =====")
using ArgParse

function parse_commandline()
  s = ArgParseSettings()

  @add_arg_table s begin
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
      help = "radius of coverage in meters, e.g. [3000.00, 4500.00, 6000.00]; meters are gonna be converted to seconds if the specified metric is time"
      arg_type = Float64
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
using RCall
using StatsBase
using GLM

import Plots

include("auxillary_functions.jl")
include("movement_search_space.jl")
include("optimization_step.jl")
include("optimization.jl")
include("distance_matrix.jl")

# Examples input parameters for interactive testing
#args = Dict("city" => "winnipeg", "metric" => "distance",
#            "m" => 20, "n" => 200, "p" => 9, "q" => 1, "r" => 3000.0)

# ========================================
# Input parameters and data
# ========================================
println("===== Input parameters and data =====")
const m = args["m"] #number of candidate locations (max: 400 - 6.5 hours)
const n = args["n"] #numer of demand locations (max: 2000)
const h = n #weights for demand locations, assumed to be 1 for all demand points
const p = args["p"] #number of facilities
const Q = args["q"] #minimum number of coverage required
const city = args["city"]
const map_path = "../osm_maps/" * city * ".osm"
const metric = args["metric"]
const r = args["r"] #radius in km e.g. [3000.00, 4500.00, 6000.00]

mx = get_map_data(map_path, use_cache=false, road_levels=Set(1:5));
if metric == "time" const r = radius_m_to_sec(mx, r) end;
const reachable_nodes, node_data = find_connected_nodes(mx, metric)

# ========================================
#Output folder
# ========================================
println("===== Creating Output Folder =====")
output_path = "../output/mclp/" *
              string(Dates.format(Dates.now(), "yyyymmdd_HHMM_")) * city *
              "_" * metric * "_" * "p" * string(p) * "_m" * string(m) *
              "_n" * string(n) * "_q" * string(Q) * "_r" * string(Int(r))
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
const M = sample(reachable_nodes, m, replace=false) #set of candidate locations
const N = sample(reachable_nodes, n, replace=false) #set of demand locations
#const H = repeat([1], h)
const H = ones(h)
#const H = collect(1:h) #the bigger facility number the more important demand

# 2. Calculate distance matrix
println("===== Model: 2. Calculating distance matrix =====")
if metric in ["distance", "time"]
  const D_ij = build_distance_matrix_graph(M, N, node_data)
elseif metric == "eucledian"
  const D_ij = build_distance_matrix_eucleadian(M, N, mx)
else
  error("Wrong metric used. Metric can only be: distance, time or eucledian")
end

const Q_ij = D_ij .<= r #facility i covers target locations j

println("===== Model: 3. Saving distance matrix to csv =====")
D_ij_df = DataFrame(D_ij)
Q_ij_df = DataFrame(Q_ij)

CSV.write(output_path * "/distance_matrix.csv", D_ij_df)
CSV.write(output_path * "/covered_or_not.csv", Q_ij_df)

# 3. Define a JuMP Model
println("===== Model: 4. Defining a JuMP Model =====")
model = Model(with_optimizer(GLPK.Optimizer))

@variable(model, y[1:m], Bin) # constraint 9; 1 if facility is sited at location "i"
@variable(model, z[1:n], Bin) # constraint 9; 1 demand j is assigned to a facility at location "i"

@objective(model, Max, sum(H[j]*z[j] for j in 1:n))

@constraint(model, sum(y[i] for i in 1:m) == p) #constraint 7

for j = 1:n
    @constraint(model, sum(Q_ij[i,j]*y[i] for i in 1:m) >= Q*z[j]) #constraint 8
end

println("===== Model: 5. Optimizing JuMP Model =====")
t = @elapsed JuMP.optimize!(model)

JuMP.value.(y)
JuMP.value.(z)
final_nodes = M[convert(Array{Bool}, JuMP.value.(y))]
obj = estimate_amb_layout_goodness(final_nodes, mx)

#Number of suppliers for each delivery loc
n_suppliers = [sum(Q_ij[i,j]*value(y[i]) for i in 1:m) for j in 1:n]

#Writing output information
println("===== Writing Output information: 1. Results =====")
open(output_path * "/results.txt", "w") do f
  print(f, "===== Results =====" * "\n")
  print(f, "Processing time: " * string(t) * "\n")
  print(f, "Objective value: " * string(obj) * "\n")
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
                          lon = [x[2] for x in LLA_N],
                          n_suppliers = convert(Array{Int}, n_suppliers))
demand_assignment = DataFrame(is_assigned = convert(Array{Int}, JuMP.value.(z)))

CSV.write(output_path * "/candidates.csv", candidates)
CSV.write(output_path * "/demand_points.csv", demand_points)
CSV.write(output_path * "/demand_assignment.csv", demand_assignment)

results_df = DataFrame(datetime = Dates.now(), model_type = "mclp", metric = metric,
                       p = p, m = m, n = n, q = Q, R = r, r = 0.0, obj = obj,
                       obj2 = objective_value(model), proc_time = t)
CSV.write(output_path * "/../../output_all_models.csv", results_df, append=true)

# Visualization of results in R's ggmap
println("===== Writing Output information: 3. Plotting results on a map =====")
@rput candidates demand_points demand_assignment

R"""
library(ggmap)

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
  geom_point(aes(x=lon, y=lat,
                 fill=factor(is_occupied, labels = c("No", "Yes")),
                 size=factor(is_occupied, labels = c("No", "Yes")) ),
             data=candidates, shape = 23, alpha = 0.75) +
  scale_fill_manual(values = c("No" = "red", "Yes" = "green")) +
  scale_size_manual(values = c("No" = 1.5, "Yes" = 3)) +
  xlab("Longitude") + ylab("Latitude") +
  ggtitle("Demand Points",
          subtitle = paste0("m = ", as.character($m), " candidate locations, ",
                            "n = ", as.character($n), " demand points\n",
                            "Objective value = ", as.character(round($obj, 4)), " seconds\n",
                            "Optimization time = ", as.character(round($t/60, 4)), " minutes")) +
  labs(fill = "Is Candidate Location Occupied",
       size = "Is Candidate Location Occupied")

ggsave(filename = "positions.png", path = $output_path,  plot = plt)
"""
println("=============== Finished processing ===============")
