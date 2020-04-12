function find_neighbour_nodes(mx::MapData, node::Int)
    edges_with_nodes = [n for n in mx.e if node in n]
    flattened_nodes = collect(Iterators.flatten(edges_with_nodes))
    nodes = unique(flattened_nodes[flattened_nodes.!=node])
    return nodes
end

function find_possible_movements_neighbours(mx::MapData, positions::Vector{Int})
    ORIGIN_DESTINATION = []
    for AMB in positions
        adj_nodes = collect(Iterators.product(AMB, find_neighbour_nodes(mx, AMB)))
        append!(ORIGIN_DESTINATION, adj_nodes)
    end
    return ORIGIN_DESTINATION
end

function find_possible_movements_radius(mx::MapData, positions::Vector{Int}, y, r::Float64 = 150.0)
    ORIGIN_DESTINATION = []

    for (index, value) in enumerate(positions)
        nodes, times = y(mx, [value], r)
        origin_destination = collect(Iterators.product(value, nodes, index))
        append!(ORIGIN_DESTINATION, origin_destination)
    end

    return ORIGIN_DESTINATION
end

function find_possible_movements_donut_search(mx::MapData, positions::Vector{Int}, r1, r2, r3)
    ORIGIN_DESTINATION = []

    for amb in positions
        nodes_r1, times_r1 = nodes_within_driving_time(mx, [amb], r1)
        nodes_r2, times_r2 = nodes_within_driving_time(mx, [amb], r2)
        nodes_r3, times_r3 = nodes_within_driving_time(mx, [amb], r3)
        nodes = vcat(nodes_r1, setdiff(nodes_r3, nodes_r2))
        origin_destination = collect(Iterators.product(amb, nodes))
        append!(ORIGIN_DESTINATION, origin_destination)
    end

    return ORIGIN_DESTINATION
end

function find_possible_movements_route_all_nodes(mx::MapData, positions::Vector{Int}, dropped_node::Int, thin_out_ratio = 1.0)
    ORIGIN_DESTINATION = []

    for amb in positions
        nodes, dist, time = fastest_route(mx, amb, dropped_node)
        println((nodes[1], nodes[end]))
        nodes = thin_out_route(nodes, thin_out_ratio)
        origin_destination = collect(Iterators.product(amb, nodes[2:end]))
        append!(ORIGIN_DESTINATION, origin_destination)
    end

    return ORIGIN_DESTINATION
end

function find_possible_movements_route_neighbor_nodes(positions::Vector{Int}, routes)
    ORIGIN_DESTINATION = []

    for position in 1:length(positions)
        if isempty(routes[position])
            continue
        end

        index = findfirst(x->x==positions[position], routes[position])

        if index == 1
            origin_destination = (routes[position][1], routes[position][2])
            push!(ORIGIN_DESTINATION, origin_destination)
        elseif index == length(routes[position])
            origin_destination = (routes[position][end], routes[position][end-1])
            push!(ORIGIN_DESTINATION, origin_destination)
        else
            origin_destination = (routes[position][index], routes[position][index+1])
            push!(ORIGIN_DESTINATION, origin_destination)
            origin_destination = (routes[position][index], routes[position][index-1])
            push!(ORIGIN_DESTINATION, origin_destination)
        end
    end

    return ORIGIN_DESTINATION
end
