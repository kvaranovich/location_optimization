function optimization_step_neighbours(mx::MapData, initial_positions::Vector{Int})
    possible_moves = find_possible_movements_neighbours(mx, initial_positions)
    estimates_after_move = []
    for move in possible_moves
        NODES = copy(initial_positions)
        filter!(x -> x!=move[1], NODES)
        append!(NODES, move[2])
        EST = estimate_amb_layout_goodness(NODES, mx)
        append!(estimates_after_move, EST)
    end

    ARGMIN = argmin(estimates_after_move)
    MIN = minimum(estimates_after_move)

    improved_positions = copy(initial_positions)
    filter!(x -> x!=possible_moves[ARGMIN][1], improved_positions)
    append!(improved_positions, possible_moves[ARGMIN][2])

    return improved_positions, MIN
end

function optimization_step_radius(mx::MapData, initial_positions::Vector{Int}, t::Float64 = 150.0)
    possible_moves = find_possible_movements_radius(mx, initial_positions, t)
    estimates_after_move = []
    for move in possible_moves
        NODES = copy(initial_positions)
        filter!(x -> x!=move[1], NODES)
        append!(NODES, move[2])
        EST = estimate_amb_layout_goodness(NODES, mx)
        append!(estimates_after_move, EST)
    end

    ARGMIN = argmin(estimates_after_move)
    MIN = minimum(estimates_after_move)

    improved_positions = copy(initial_positions)
    filter!(x -> x!=possible_moves[ARGMIN][1], improved_positions)
    append!(improved_positions, possible_moves[ARGMIN][2])

    return improved_positions, MIN
end

function optimization_step_donut(mx::MapData, initial_positions::Vector{Int}, r1::Float64 = 50.0, r2::Float64 = 150.0, r3::Float64=200.0)
    possible_moves = find_possible_movements_donut_search(mx, initial_positions, r1, r2, r3)
    estimates_after_move = []
    for move in possible_moves
        NODES = copy(initial_positions)
        filter!(x -> x!=move[1], NODES)
        append!(NODES, move[2])
        EST = estimate_amb_layout_goodness(NODES, mx)
        append!(estimates_after_move, EST)
    end

    ARGMIN = argmin(estimates_after_move)
    MIN = minimum(estimates_after_move)

    improved_positions = copy(initial_positions)
    filter!(x -> x!=possible_moves[ARGMIN][1], improved_positions)
    append!(improved_positions, possible_moves[ARGMIN][2])

    return improved_positions, MIN
end

function optimization_step_route_all_nodes(mx::MapData, initial_positions::Vector{Int}, dropped_node::Int, thin_out_ratio = 1.0)
    possible_moves = find_possible_movements_route_all_nodes(mx, initial_positions, dropped_node, thin_out_ratio)
    estimates_after_move = []
    for move in possible_moves
        NODES = copy(initial_positions)
        filter!(x -> x!=move[1], NODES)
        append!(NODES, move[2])
        EST = estimate_amb_layout_goodness(NODES, mx)
        append!(estimates_after_move, EST)
    end

    ARGMIN = argmin(estimates_after_move)
    MIN = minimum(estimates_after_move)

    improved_positions = copy(initial_positions)
    filter!(x -> x!=possible_moves[ARGMIN][1], improved_positions)
    append!(improved_positions, possible_moves[ARGMIN][2])

    return improved_positions, MIN
end

function optimization_step_route_neighbour_nodes(mx::MapData, initial_positions::Vector{Int}, routes)
    possible_moves = find_possible_movements_route_neighbor_nodes(initial_positions, routes)
    estimates_after_move = []
    for move in possible_moves
        NODES = copy(initial_positions)
        NODES[findfirst(x->x==move[1], NODES)] = move[2]
        EST = estimate_amb_layout_goodness(NODES, mx)
        append!(estimates_after_move, EST)
    end

    ARGMIN = argmin(estimates_after_move)
    MIN = minimum(estimates_after_move)

    improved_positions = copy(initial_positions)
    improved_positions[findfirst(x->x==possible_moves[ARGMIN][1], improved_positions)] = possible_moves[ARGMIN][2]

    return improved_positions, MIN
end
