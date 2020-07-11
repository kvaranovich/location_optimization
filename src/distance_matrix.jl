function haversine(lon1, lat1, lon2, lat2)
    # convert decimal degrees to radians
    lon1, lat1, lon2, lat2 = map(deg2rad, [lon1, lat1, lon2, lat2])

    # haversine formula
    dlon = lon2 - lon1
    dlat = lat2 - lat1
    a = sin(dlat/2)^2 + cos(lat1) * cos(lat2) * sin(dlon/2)^2
    c = 2 * asin(sqrt(a))
    r = 6371 # Earth Radius km (3956 miles)
    return c * r
end

function build_distance_matrix_eucleadian(nodes1, nodes2, mx)
    m = length(nodes1)
    n = length(nodes2)
    LLA_reference = center(mx.bounds)
    D_ij = Array{Float64}(undef, m, n)

    LLA_M = [LLA(mx.nodes[nodes1[x][1]], LLA_reference) for x in 1:m]
    LLA_M = [(x.lat, x.lon) for x in LLA_M]
    LLA_N = [LLA(mx.nodes[nodes2[x][1]], LLA_reference) for x in 1:n]
    LLA_N = [(x.lat, x.lon) for x in LLA_N]

    for i in 1:m
        for j in 1:n
            D_ij[i, j] = haversine(LLA_M[i][2], LLA_M[i][1], LLA_N[j][2], LLA_N[j][1])
        end
    end

    return D_ij
end

function create_distance_trees(mx::MapData, metric)
    all_nodes = collect(keys(mx.v))
    node_data = Dict()

    if metric in ["distance", "eucledian"]
        y = nodes_within_driving_distance
    elseif metric == "time"
        y = nodes_within_driving_time
    else
        error("Only metric = \"distance\" or metric = \"time\" is allowed")
    end

    for node in all_nodes
        nd_data = y(mx, [node], 999999.99)
        push!(node_data, node => nd_data)
    end

    return node_data
end

function build_distance_matrix_graph(nodes1, nodes2, node_data)
    m = length(nodes1)
    n = length(nodes2)
    D_ij = Array{Float64}(undef, m, n)

    for i in 1:m
        for j in 1:n
            node1 = nodes1[i]
            node2_idx = findfirst(x -> x == nodes2[j], node_data[node1][1])
            D_ij[i,j] = node_data[node1][2][node2_idx]
        end
    end

    return D_ij
end

function build_distance_matrix_routing(nodes1, nodes2, mx)
    m = length(nodes1)
    n = length(nodes2)
    #D_ij_graph_distance = Array{Float64}(undef, m, n) #graph - distance matrix between candidate location "i" and demand point "j"
    D_ij_graph_time = Array{Float64}(undef, m, n) #graph - time matrix between candidate location "i" and demand point "j"

    t = 0 #timer
    c = 1 #c
    for i in 1:m
        for j in 1:n
            t1 = Dates.now()

            if c % 100 == 0
                println(string(100 - c/(m*n)*100) * " % pct left")
                println(string(t) * " seconds passed")
            end

            #D_ij_graph_distance[i, j] = shortest_route(mx, M[i][1], N[j][1])[2]
            D_ij_graph_time[i, j] = fastest_route(mx, M[i][1], N[j][1])[3]
            t2 = Dates.now()
            t = t + ((t2-t1).value/1000)
            c = c + 1
        end
    end

    return D_ij_graph_time
end
