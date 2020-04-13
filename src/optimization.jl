function estimate_amb_layout_goodness(ambulance_loc:: Vector{Int}, mx::MapData)
    ranges_nodes, ranges_times = OpenStreetMapX.nodes_within_driving_time(mx, ambulance_loc,100000.0)
    mean(ranges_times)
end

function location_optimization(mx::MapData, initial_positions::Vector{Int}, N_ITER = 100)
    LAST_NODES = copy(initial_positions)
    NODES = []
    TIMES = []

    for i in 1:N_ITER
        println(i)
        CURR_NODES, CURR_TIME = optimization_step_neighbours(mx, LAST_NODES)

        if i > 1
            if CURR_TIME >= TIMES[end]
                println("Found local minimum. Stopping.")
                break
            end
        end

        append!(NODES, [CURR_NODES])
        append!(TIMES, CURR_TIME)
        LAST_NODES = CURR_NODES
        #println(CURR_TIME)
    end

    return NODES, TIMES
end

function location_optimization_radius(mx::MapData, initial_positions::Vector{Int},
    N_ITER = 100, metric = "time", ruin_random = 0.0, r = 150.0)

    LAST_NODES = copy(initial_positions)
    NODES = []
    TIMES = []

    for i in 1:N_ITER
        println(i)
        CURR_NODES, CURR_TIME = optimization_step(mx, LAST_NODES, metric, find_possible_movements_radius, ruin_random; r = r)

        if i > 1
            if CURR_TIME >= TIMES[end]
                println("Found local minimum. Stopping.")
                break
            end
        end

        append!(NODES, [CURR_NODES])
        append!(TIMES, CURR_TIME)
        LAST_NODES = CURR_NODES
        #println(CURR_TIME)
    end

    return NODES, TIMES
end

function location_optimization_donut(mx::MapData, initial_positions::Vector{Int}, N_ITER = 100, r1::Float64 = 50.0, r2::Float64 = 150.0, r3::Float64=200.0)
    LAST_NODES = copy(initial_positions)
    NODES = []
    TIMES = []

    for i in 1:N_ITER
        println(i)
        CURR_NODES, CURR_TIME = optimization_step_donut(mx, LAST_NODES, r1, r2, r3)

        if i > 1
            if CURR_TIME >= TIMES[end]
                println("Found local minimum. Stopping.")
                break
            end
        end

        append!(NODES, [CURR_NODES])
        append!(TIMES, CURR_TIME)
        LAST_NODES = CURR_NODES
        #println(CURR_TIME)
    end

    return NODES, TIMES
end

function location_optimization_route_neighbour_nodes(mx::MapData, initial_positions::Vector{Int}, dropped_node, N_ITER = 100, thin_out_ratio = 0.2)
    routes = [fastest_route(mx, initial_positions[i], dropped_node)[1] for i in 1:length(initial_positions)]
    thinned_routes = [thin_out_route(routes[i], thin_out_ratio) for i in 1:length(routes)]

    LAST_NODES = copy(initial_positions)
    NODES = []
    TIMES = []

    for i in 1:N_ITER
        println(i)
        CURR_NODES, CURR_TIME = optimization_step_route_neighbor_nodes(mx, LAST_NODES, thinned_routes)

        if i > 1
            if CURR_TIME >= TIMES[end]
                println("Found local minimum. Stopping.")
                break
            end
        end

        append!(NODES, [CURR_NODES])
        append!(TIMES, CURR_TIME)
        LAST_NODES = CURR_NODES
    end

    return NODES, TIMES
end

function location_optimization_route_all_nodes(mx::MapData, initial_positions::Vector{Int}, dropped_node::Int, thin_out_ratio = 1.0)
    LAST_NODES = copy(initial_positions)
    NODES = []
    TIMES = []

    for i in 1:length(initial_positions)
        println(i)
        CURR_NODES, CURR_TIME = optimization_step_route_all_nodes(mx, LAST_NODES, dropped_node, thin_out_ratio)

        if i > 1
            if CURR_TIME >= TIMES[end]
                println("Found local minimum. Stopping.")
                break
            end
        end

        append!(NODES, [CURR_NODES])
        append!(TIMES, CURR_TIME)
        LAST_NODES = CURR_NODES
        println(CURR_TIME)
    end

    return NODES, TIMES
end

function location_optimization_dropout(mx::MapData, initial_positions::Vector{Int}, n_iter)
    #Location optimization
    N_AMBULANCES = length(initial_positions)
    AMBULANCES = copy(initial_positions)
    DROPPED_AMBULANCES = []
    SYSTEM_STATES = []
    SYSTEM_TIMES = []

    for amb in 1:N_AMBULANCES
        println("The number of ambulances left: ", length(AMBULANCES))
        OPTIMAL_LOCATION = location_optimization(mx, AMBULANCES, n_iter)
        append!(SYSTEM_STATES, OPTIMAL_LOCATION[1])
        append!(SYSTEM_TIMES, OPTIMAL_LOCATION[2])

        DISPATCHED_AMB = rand(OPTIMAL_LOCATION[1][end], 1)[1]
        println("=====================Dropping ", DISPATCHED_AMB)
        append!(DROPPED_AMBULANCES, DISPATCHED_AMB)
        AMBULANCES = OPTIMAL_LOCATION[1][end]
        filter!(x -> x!=DISPATCHED_AMB, AMBULANCES)
    end

    return SYSTEM_STATES, SYSTEM_TIMES, DROPPED_AMBULANCES
end

function location_optimization_2step_dropout(mx::MapData, initial_positions::Vector{Int}, n_iter)
    #placeholders
    N_AMBULANCES = length(initial_positions)
    AMBULANCES = copy(initial_positions)
    DROPPED_AMBULANCES = []
    SYSTEM_STATES = []
    SYSTEM_TIMES = []

    #initial time - reference point
    INITIAL_TIME = estimate_amb_layout_goodness(ORIGIN_NODES, mx)
    println("Initial time: ", INITIAL_TIME)

    #initial optimization
    OPTIMAL_LOCATION = location_optimization(mx, ORIGIN_NODES, 100)
    append!(SYSTEM_STATES, OPTIMAL_LOCATION[1])
    append!(SYSTEM_TIMES, OPTIMAL_LOCATION[2])
    AMBULANCES = OPTIMAL_LOCATION[1][end]

    #loop: drop an ambulance, optimize based on routes to dispathced ambulance,
    #optimize by greedy search, repeat
    for amb in 1:N_AMBULANCES
        println("The number of ambulances left: ", length(AMBULANCES))
        OPTIMAL_LOCATION = location_optimization(mx, AMBULANCES, n_iter)
        append!(SYSTEM_STATES, OPTIMAL_LOCATION[1])
        append!(SYSTEM_TIMES, OPTIMAL_LOCATION[2])

        DISPATCHED_AMB = rand(OPTIMAL_LOCATION[1][end], 1)[1]
        println("=====================Dropping ", DISPATCHED_AMB)
        append!(DROPPED_AMBULANCES, DISPATCHED_AMB)
        AMBULANCES = OPTIMAL_LOCATION[1][end]
        filter!(x -> x!=DISPATCHED_AMB, AMBULANCES)
    end

    return SYSTEM_STATES, SYSTEM_TIMES, DROPPED_AMBULANCES
end

function location_optimization_empty_spot_cover(mx::MapData, initial_positions::Vector{Int}, n_iter, thin_out_ratio)
    """
    Function optimizing locations of EMS vehicles with cover-empty-spot heuristic.
    When one EMS vehicle is dropped (is going to an emergency call), others move
    towards location, where EMS vehicle dispathced from.
    ...
    # Arguments
    - `mx::MapData`: map data from OpenStreetMapX library
    - `initial_positions::Vector{Int}`: initial positions of EMS vehicles.
    A vector of nodes from OSM.
    - `n_iter`: number of optimization iterations when finding optimal location
    within neighbour nodes. Default - 150.
    - `thin_out_ratio`: makes routes consisting of nodes sparser. Speeds-up
    computation skipping nodes on a route.
    ...
    """
    # Defining placeholders
    N_AMBULANCES = length(initial_positions)
    AMBULANCES = copy(initial_positions)
    DROPPED_AMBULANCES = []
    SYSTEM_STATES = []
    SYSTEM_TIMES = []

    # First step - optimizing initial positions before dropping ambulances
    OPTIMAL_LOCATION = location_optimization(mx, AMBULANCES, n_iter)
    append!(SYSTEM_STATES, OPTIMAL_LOCATION[1])
    append!(SYSTEM_TIMES, OPTIMAL_LOCATION[2])
    AMBULANCES = OPTIMAL_LOCATION[1][end]

    # Second step - cover-empty-spot optimization and move-to-neighbour-node
    # optimization
    for amb in 1:N_AMBULANCES
        # Drop an ambulance
        println("The number of ambulances left: ", length(AMBULANCES))
        DISPATCHED_AMB = rand(AMBULANCES, 1)[1]
        println("=====================Dropping ", DISPATCHED_AMB)
        append!(DROPPED_AMBULANCES, DISPATCHED_AMB)
        filter!(x -> x!=DISPATCHED_AMB, AMBULANCES)

        # Cover-empty-spot optimization
        OPTIMAL_LOCATION = location_optimization(mx, AMBULANCES, n_iter)
        append!(SYSTEM_STATES, OPTIMAL_LOCATION[1])
        append!(SYSTEM_TIMES, OPTIMAL_LOCATION[2])


    end

    return SYSTEM_STATES, SYSTEM_TIMES, DROPPED_AMBULANCES
end
