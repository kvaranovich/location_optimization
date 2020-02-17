# Input data
map_path = "winnipeg_map.osm"
mx = get_map_data(map_path, use_cache=false, road_levels=Set(1:5));

# Start flow
GRID_DIM = make_grid(mx, 4);
N_AMB = GRID_DIM[1]*GRID_DIM[2];
LOC = find_centers(mx, GRID_DIM);
ORIGIN_NODES = [point_to_nodes(LOC[i], mx) for i in 1:length(LOC)];
plot_ambulances(ORIGIN_NODES, mx, "Initial placement")

# radius (km) to radius (seconds)
GRID_DIM = make_grid(mx, 1);
N_AMB = GRID_DIM[1]*GRID_DIM[2];
LOC = find_centers(mx, GRID_DIM);
ORIGIN_NODES = [point_to_nodes(LOC[i], mx) for i in 1:length(LOC)];

nd_km = nodes_within_driving_distance(mx, ORIGIN_NODES, 99999999.99) |> DataFrame
nd_sec = nodes_within_driving_time(mx, ORIGIN_NODES, 99999999.99) |> DataFrame
nd = join(nd_km, nd_sec, on = :x1, makeunique=true)
nd = nd[:, [2,3]]

lm_fit = lm(@formula(x2_1 ~ x2), nd)
predict(lm_fit, DataFrame(x2 = [3000.0, 4500.0, 6000.0]))


@rput nd
R"""
library(ggplot2)

ggplot(data = nd, aes(x = x2, y = x2_1)) +
    geom_point() +
    xlab("km") + ylab("seconds") + ggtitle("Distance to Time comparison") +
    theme_bw()
"""

R"""
lm_fit <- lm(x2_1 ~ x2, data=nd)
summary(lm_fit)
preds <- predict(lm_fit, data.frame(x2 = c(3000.0, 4500.0, 6000.0)))
"""

nd_radius = [nodes_within_driving_distance(mx, [ORIGIN_NODES[x]], 23000.0)[1] for x in 1:length(ORIGIN_NODES)]
nd_radius |> Iterators.flatten |> collect |> unique
###############################
#Initial optimization
###############################

#Test cases
#1 - Initial optimization - only neighbour
#2 - Initial optimization - only radius
#3 - Initial optimization - neighbour + radius
#4 - Initial optimization - donut search

#0 - Initial placement - 431.2752 seconds

#1
@time TEST1 = location_optimization(mx, ORIGIN_NODES, 100)
plot_ambulances(TEST1[1][end], mx, "Initial optimization - neighbours only")
#Result - 325.5705 seconds, time - 7.458965 seconds

#2
@time TEST2 = location_optimization_radius(mx, ORIGIN_NODES, 100, 175.0)
plot_ambulances(TEST2[1][end], mx, "Initial optimization - radius only")
#Result - 281.814 seconds, time - 106.301356 seconds, radius - 100.0 seconds
#Result - 280.496 seconds, time - 163.063127 seconds, radius - 125.0 seconds
#Result - 280.496 seconds, time - 257.386614 seconds, radius - 150.0 seconds
#Result - 258.191 seconds, time - 303.858132 seconds, radius - 175.0 seconds
#Result - 258.191 seconds, time - 426.458918 seconds, radius - 200.0 seconds
#Result - 258.191 seconds, time - 722.540153 seconds, radius - 300.0 seconds

#3
@time TEST3 = location_optimization_radius(mx, TEST1[1][end], 100, 125.0)
plot_ambulances(TEST3[1][end], mx, "Initial optimization - neighbours + radius (125.0)")
#Result - 258.191 seconds, time - 202.592965 seconds, radius - 125.0 seconds

#4
@time TEST4 = location_optimization_donut(mx, ORIGIN_NODES, 100, 30.0, 150.0, 175.0)
plot_ambulances(TEST4[1][end], mx, "Initial optimization - donut: 30, 150, 175")
#Result - 258.2459 seconds, time - 127.663536 seconds, 30, 150, 175

###############################
#Redeployment
###############################
#Test cases
#1 - radius only
#2 - route + radius

#0 time after redeployment - 365.1857
DISPATCHED_AMB = rand(TEST1[1][end], 1)[1]
ORIGIN_NODES_AFTER_DISPATCH = copy(TEST1[1][end])
filter!(x -> x!=DISPATCHED_AMB, ORIGIN_NODES_AFTER_DISPATCH)
plot_ambulances(ORIGIN_NODES_AFTER_DISPATCH, mx, "After dispath of one ambulance")

#1
@time OPT_RELOC = location_optimization_radius(mx, ORIGIN_NODES_AFTER_DISPATCH, 100, 175.0)
plot_ambulances(OPT_RELOC[1][end], mx, "Relocation, radius - 175.0")
#Result - 285.608 seconds, time - 223.611522 seconds, radius - 175.0 seconds
#Result - 285.608 seconds, time - 277.429524 seconds, radius - 200.0 seconds

#2
#2.1 global optimization based on route
@time OPT_RELOC_2METHOD = location_optimization_route_all_nodes(mx, ORIGIN_NODES_AFTER_DISPATCH, DISPATCHED_AMB)
plot_ambulances(OPT_RELOC_2METHOD[1][end], mx, "Relocation, route")
#Result - 287.3465, time - 18.888687 seconds

#2.2 local radius optimization
@time OPT_RELOC_LOCAL = location_optimization_radius(mx, OPT_RELOC_2METHOD[1][end], 100, 75.0)
plot_ambulances(OPT_RELOC_LOCAL[1][end], mx, "Relocation, radius after route")
#Result - 286.5227, time - 28.208427 seconds, radius - 75.0
#Result - 285.6080, time - 53.640073 seconds, radius - 100.0

###############################
#Redeployment - 2 iteration
###############################

#0
DISPATCHED_AMB_2 = rand(OPT_RELOC_LOCAL[1][end], 1)[1]
ORIGIN_NODES_AFTER_DISPATCH_2 = copy(OPT_RELOC_LOCAL[1][end])
filter!(x -> x!=DISPATCHED_AMB_2, ORIGIN_NODES_AFTER_DISPATCH_2)
plot_ambulances(ORIGIN_NODES_AFTER_DISPATCH_2, mx, "After dispath of two ambulances")
#Result - 358.0525

#1
@time OPT_RELOC_2 = location_optimization_radius(mx, ORIGIN_NODES_AFTER_DISPATCH_2, 100, 350.0)
plot_ambulances(OPT_RELOC_2[1][end], mx, "Relocation - two dispatched, radius - 350.0")
#Result - 331.9428, time - 237.806581 seconds, radius - 175.0
#Result - 331.9428, time - 392.043192 seconds, radius - 250.0
#Result - 331.9428, time - 571.228522 seconds, radius - 350.0

#2
#2.1 global optimization based on route
@time OPT_RELOC_2METHOD_2 = location_optimization_route_all_nodes(mx, ORIGIN_NODES_AFTER_DISPATCH_2, DISPATCHED_AMB_2)
plot_ambulances(OPT_RELOC_2METHOD_2[1][end], mx, "Relocation - two dispatched, route")
#Result - 346.4748, time - 7.686281 seconds

#2.2 local radius optimization
@time OPT_RELOC_LOCAL_2 = location_optimization_radius(mx, OPT_RELOC_2METHOD_2[1][end], 100, 100.0)
plot_ambulances(OPT_RELOC_LOCAL_2[1][end], mx, "Relocation - two dispatched, radius after route, 100.0")
#Result - 332.5435, time - 57.005541 seconds, radius - 100.0
