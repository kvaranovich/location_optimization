function optimization_step(mx::MapData, initial_positions::Vector{Int},
    metric, space_search_function::Function = find_possible_movements_radius,
    ruin_random = 0.0; kwargs...)

    if metric in ["distance", "eucledian"]
        y = nodes_within_driving_distance
    elseif metric == "time"
        y = nodes_within_driving_time
    else
        error("Only metric = \"distance\" or metric = \"time\" is allowed")
    end

    possible_moves = space_search_function(mx, initial_positions, y; kwargs...)
    idx = sample([true, false], Weights([1-ruin_random, ruin_random]), length(possible_moves))
    possible_moves = possible_moves[idx]

    estimates_after_move = []
    for move in possible_moves
        NODES = copy(initial_positions)
        filter!(x -> x!=move[1], NODES)
        append!(NODES, move[2])
        EST = estimate_amb_layout_goodness(NODES, mx)
        append!(estimates_after_move, EST)
    end

    best_time_i = argmin(estimates_after_move)
    best_time = minimum(estimates_after_move)

    improved_positions = copy(initial_positions)
    filter!(x -> x!=possible_moves[best_time_i][1], improved_positions)
    append!(improved_positions, possible_moves[best_time_i][2])

    return improved_positions, best_time
end
