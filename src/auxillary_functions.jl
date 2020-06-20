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

function make_grid(mx::MapData, k::Int64)
    W = haversine(mx.bounds.max_x, mx.bounds.min_y, mx.bounds.max_x, mx.bounds.max_y)
    H = haversine(mx.bounds.min_x, mx.bounds.min_y, mx.bounds.max_x, mx.bounds.min_y)
    s = sqrt(W*H/k)
    a = W/s
    b = H/s
    A = Integer(round(a))
    B = Integer(round(b))
    println("Width: ", A)
    println("Height: ", B)
    return A, B
end

function find_centers(mx::MapData, grid_dim)
    x_ticks = collect(range(mx.bounds.min_x, mx.bounds.max_x, length = grid_dim[1]*2+1))
    y_ticks = collect(range(mx.bounds.min_y, mx.bounds.max_y, length = grid_dim[2]*2+1))
    loc = vec([LLA(y, x) for x=x_ticks[2:2:length(x_ticks)], y=y_ticks[2:2:length(y_ticks)]])
    return loc
end

function generate_ambulances_random(mx::MapData, p::Int)
    initial_nodes = sample(collect(keys(mx.v)), p, replace=false)
    return initial_nodes
end

function generate_ambulances_centers(mx::MapData, p::Int)
    grid_dim = make_grid(mx, p)
    n_amb = grid_dim[1]*grid_dim[2]
    loc = find_centers(mx, grid_dim)
    initial_nodes = [point_to_nodes(loc[i], mx) for i in 1:length(loc)]
    return initial_nodes
end

function plot_points(mx::MapData, LOC)
    flm = pyimport("folium")
    matplotlib_cm = pyimport("matplotlib.cm")
    matplotlib_colors = pyimport("matplotlib.colors")

    cmap = matplotlib_cm.get_cmap("prism")

    m = flm.Map()
    for i in 1:N_AMB
        loc = LOC[i]
        info = "Ambulance $i\n<BR>"*
                "Loc: $(round.((loc.lat, loc.lon),digits=4))\n<br>";
        flm.Rectangle(
            [(loc.lat-0.0004, loc.lon-0.0004),(loc.lat+0.0004, loc.lon+0.0004)],
            popup=info,
            tooltip=info,
            color="black"
        ).add_to(m)
    end

    MAP_BOUNDS = [(mx.bounds.min_y,mx.bounds.min_x),(mx.bounds.max_y,mx.bounds.max_x)]
    flm.Rectangle(MAP_BOUNDS, color="black",weight=1).add_to(m)
    m.fit_bounds(MAP_BOUNDS)
    m
end

function thin_out_route(nodes::Vector{Int}, pct::Float64 = 1.0)
    if (pct < 0.0) | (pct > 1.0)
        error("pct must be between 0.0 an 1.0")
    elseif pct == 1.0
        return nodes
    elseif (length(nodes)-1)*pct < 2
        println("Shourt route - thinning out is not needed. Returnning full route")
        return nodes
    else
        N_NODES_TO_RETURN = (length(nodes)-1)*pct |> floor |> Int
        NODES_INDICES = range(1, length(nodes), length = N_NODES_TO_RETURN) |>
        collect .|> floor |> unique .|> Int
        return nodes[NODES_INDICES]
    end
end

function floor_route(nodes::Vector{Int}, pct::Float64 = 0.5)
    if length(nodes) < 3
        println("The route is short and has <= 3 nodes. Keeping the original route")
        return nodes
    else
        N_NODES_TO_RETURN = length(nodes)*pct |> floor |> Int
        NODES_INDICES = range(1, stop=N_NODES_TO_RETURN)
        return nodes[NODES_INDICES]
    end
end

function plot_ambulances(nodes::Vector{Int}, mx, title = "Ambulances location")
    Plots.gr()
    p = OpenStreetMapXPlot.plotmap(mx,width=1000,height=800);
    Plots.title!(title * "\n" * string(round(estimate_amb_layout_goodness(nodes, mx), digits=4)) * " seconds")
    plot_nodes!(p,mx,nodes,start_numbering_from=nothing,fontsize=13,color="black");
    p
end

function find_roadway_id(node::Int, mx::MapData)
    roadway_ids = [road.id for road in mx.roadways if node in road.nodes]
    return roadway_ids
end

function find_roadway_description(roadway_id::Int, mx::MapData)
    roadway_description = [road.tags["name"] for road in mx.roadways if roadway_id in road.id]
    return roadway_description[1]
end

function find_roadway_nodes(roadway_id::Int, mx::MapData)
    nodes = [road.nodes for road in mx.roadways if roadway_id in road.id]
    return nodes[1]
end

function find_roadway_id(nodes::Vector{Int}, mx::MapData)
    all_roadway_ids = []

    for node in nodes
        roadway_ids = [road.id for road in mx.roadways if node in road.nodes]
        append!(all_roadway_ids, roadway_ids)
    end
    return all_roadway_ids
end

function radius_m_to_sec(mx::MapData, r::Float64)
    println("===== Converting meters to seconds =====")
    grid_dim = make_grid(mx, 1);
    n_amb = grid_dim[1]*grid_dim[2];
    loc = find_centers(mx, grid_dim);
    origin_nodes = [point_to_nodes(loc[i], mx) for i in 1:length(loc)];
    nd_km = nodes_within_driving_distance(mx, origin_nodes, 99999999.99) |> DataFrame
    nd_sec = nodes_within_driving_time(mx, origin_nodes, 99999999.99) |> DataFrame
    nd = join(nd_km, nd_sec, on = :x1, makeunique=true)

    lm_fit = lm(@formula(x2_1 ~ x2), nd)
    pred = predict(lm_fit, DataFrame(x2 = [r]))
    return pred[1]
end
