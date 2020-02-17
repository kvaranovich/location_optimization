map_path = "winnipeg_map.osm";
mx = get_map_data(map_path, use_cache=false, road_levels=Set(1:5));

routes = [fastest_route(mx, ORIGIN_NODES_AFTER_DISPATCH[i], DISPATCHED_AMB)[1] for i in 1:length(ORIGIN_NODES_AFTER_DISPATCH)]

#Initial locations
estimate_amb_layout_goodness(ORIGIN_NODES, mx)
Plots.gr()
p = OpenStreetMapXPlot.plotmap(mx,width=1000,height=800);
Plots.title!("Inital locations placement \n" * string(round(estimate_amb_layout_goodness(ORIGIN_NODES, mx), digits=4)) * " seconds")
plot_nodes!(p,mx,ORIGIN_NODES,start_numbering_from=nothing,fontsize=13,color="black");
p

#Initial optimization
estimate_amb_layout_goodness(OPTIMAL_LOCATION[1][end], mx)
Plots.gr()
p = OpenStreetMapXPlot.plotmap(mx,width=1000,height=800);
Plots.title!("Initial optimization \n" * string(round(estimate_amb_layout_goodness(OPTIMAL_LOCATION[1][end], mx), digits=4)) * " seconds")
plot_nodes!(p,mx,OPTIMAL_LOCATION[1][end],start_numbering_from=nothing,fontsize=13,color="black");
p

#After dropping one node
estimate_amb_layout_goodness(ORIGIN_NODES_AFTER_DISPATCH, mx)
Plots.gr()
p = OpenStreetMapXPlot.plotmap(mx,width=1000,height=800);
Plots.title!("After dropping one ambulance \n" * string(round(estimate_amb_layout_goodness(ORIGIN_NODES_AFTER_DISPATCH, mx), digits=4)) * " seconds")
plot_nodes!(p,mx,ORIGIN_NODES_AFTER_DISPATCH,start_numbering_from=nothing,fontsize=13,color="black");
p

#Routes
Plots.gr()
p = OpenStreetMapXPlot.plotmap(mx,width=1000,height=800);
Plots.title!("Routes - After dropping one ambulance \n" * string(round(estimate_amb_layout_goodness(ORIGIN_NODES_AFTER_DISPATCH, mx), digits=4)) * " seconds")
addroute!(p,mx,routes[1];route_color="red")
addroute!(p,mx,routes[2];route_color="green")
addroute!(p,mx,routes[3];route_color="blue")
plot_nodes!(p,mx,ORIGIN_NODES_AFTER_DISPATCH,start_numbering_from=nothing,fontsize=13,color="black");
p

#Optimization - 100% full routes
OPT_LOC_100 = location_optimization_on_route(mx, ORIGIN_NODES_AFTER_DISPATCH, DISPATCHED_AMB, 100, 1.0)
OPT_LOC_100[2][end]
Plots.gr()
p = OpenStreetMapXPlot.plotmap(mx,width=1000,height=800);
addroute!(p,mx,routes[1];route_color="red")
addroute!(p,mx,routes[2];route_color="green")
addroute!(p,mx,routes[3];route_color="blue")
plot_nodes!(p,mx,OPT_LOC_100[1][end],start_numbering_from=nothing,fontsize=13,color="black");
p
#Optimization - 75% full routes
OPT_LOC_075 = location_optimization_on_route(mx, ORIGIN_NODES_AFTER_DISPATCH, DISPATCHED_AMB, 100, 0.75)
OPT_LOC_075[2][end]
Plots.gr()
p = OpenStreetMapXPlot.plotmap(mx,width=1000,height=800);
addroute!(p,mx,routes[1];route_color="red")
addroute!(p,mx,routes[2];route_color="green")
addroute!(p,mx,routes[3];route_color="blue")
plot_nodes!(p,mx,OPT_LOC_075[1][end],start_numbering_from=nothing,fontsize=13,color="black");
p
#Optimization - 50% full routes
OPT_LOC_050 = location_optimization_on_route(mx, ORIGIN_NODES_AFTER_DISPATCH, DISPATCHED_AMB, 100, 0.5)
OPT_LOC_050[2][end]
Plots.gr()
p = OpenStreetMapXPlot.plotmap(mx,width=1000,height=800);
Plots.title!("50% thinning \n" * string(round(OPT_LOC_050[2][end], digits=4)) * " seconds")
addroute!(p,mx,routes[1];route_color="red")
addroute!(p,mx,routes[2];route_color="green")
addroute!(p,mx,routes[3];route_color="blue")
plot_nodes!(p,mx,OPT_LOC_050[1][end],start_numbering_from=nothing,fontsize=13,color="black");
p
#Optimization - 25% full routes
OPT_LOC_025 = location_optimization_on_route(mx, ORIGIN_NODES_AFTER_DISPATCH, DISPATCHED_AMB, 100, 0.25)
OPT_LOC_025[2][end]
Plots.gr()
p = OpenStreetMapXPlot.plotmap(mx,width=1000,height=800);
Plots.title!("25% thinning \n" * string(round(OPT_LOC_025[2][end], digits=4)) * " seconds")
addroute!(p,mx,routes[1];route_color="red")
addroute!(p,mx,routes[2];route_color="green")
addroute!(p,mx,routes[3];route_color="blue")
plot_nodes!(p,mx,OPT_LOC_025[1][end],start_numbering_from=nothing,fontsize=13,color="black");
p

#Optimization - 10% full routes
OPT_LOC_010 = location_optimization_on_route(mx, ORIGIN_NODES_AFTER_DISPATCH, DISPATCHED_AMB, 100, 0.1)
OPT_LOC_010[2][end]
Plots.gr()
p = OpenStreetMapXPlot.plotmap(mx,width=1000,height=800);
Plots.title!("10% thinning \n" * string(round(OPT_LOC_010[2][end], digits=4)) * " seconds")
addroute!(p,mx,routes[1];route_color="red")
addroute!(p,mx,routes[2];route_color="green")
addroute!(p,mx,routes[3];route_color="blue")
plot_nodes!(p,mx,OPT_LOC_010[1][end],start_numbering_from=nothing,fontsize=13,color="black");
p

#Continue optimizing by greed search
test2 = location_optimization(mx, OPT_LOC_010[1][end])
test2[2][end]
Plots.gr()
p = OpenStreetMapXPlot.plotmap(mx,width=1000,height=800);
Plots.title!("Optimizing by greed search - after 10% thinning \n " * string(round(test2[2][end], digits=4)) * " seconds")
addroute!(p,mx,routes[1];route_color="red")
addroute!(p,mx,routes[2];route_color="green")
addroute!(p,mx,routes[3];route_color="blue")
plot_nodes!(p,mx,test2[1][end],start_numbering_from=nothing,fontsize=13,color="black");
p

#Optimization - move to any node on routes
test1 = location_optimization_cover_empty_spot(mx, ORIGIN_NODES_AFTER_DISPATCH, DISPATCHED_AMB, 1.0)
Plots.gr()
p = OpenStreetMapXPlot.plotmap(mx,width=1000,height=800);
Plots.title!("Optimization - move to any node on routes \n " * string(round(test1[2][end], digits=4)) * " seconds")
addroute!(p,mx,routes[1];route_color="red")
addroute!(p,mx,routes[2];route_color="green")
addroute!(p,mx,routes[3];route_color="blue")
plot_nodes!(p,mx,test1[1][end],start_numbering_from=nothing,fontsize=13,color="black");
p

# routes - 100
Plots.gr()
p = OpenStreetMapXPlot.plotmap(mx,width=1000,height=800);
addroute!(p,mx,routes[1];route_color="red")
addroute!(p,mx,routes[2];route_color="green")
addroute!(p,mx,routes[3];route_color="blue")
plot_nodes!(p,mx,routes[1],start_numbering_from=nothing,fontsize=13,color="black");
plot_nodes!(p,mx,routes[2],start_numbering_from=nothing,fontsize=13,color="black");
plot_nodes!(p,mx,routes[3],start_numbering_from=nothing,fontsize=13,color="black");
p

#routes - 50
Plots.gr()
p = OpenStreetMapXPlot.plotmap(mx,width=1000,height=800);
addroute!(p,mx,routes[1];route_color="red")
addroute!(p,mx,routes[2];route_color="green")
addroute!(p,mx,routes[3];route_color="blue")
plot_nodes!(p,mx,thin_out_route(routes[1], 0.5),start_numbering_from=nothing,fontsize=13,color="black");
plot_nodes!(p,mx,thin_out_route(routes[2], 0.5),start_numbering_from=nothing,fontsize=13,color="black");
plot_nodes!(p,mx,thin_out_route(routes[3], 0.5),start_numbering_from=nothing,fontsize=13,color="black");
p

#routes - 25
Plots.gr()
p = OpenStreetMapXPlot.plotmap(mx,width=1000,height=800);
addroute!(p,mx,routes[1];route_color="red")
addroute!(p,mx,routes[2];route_color="green")
addroute!(p,mx,routes[3];route_color="blue")
plot_nodes!(p,mx,thin_out_route(routes[1], 0.25),start_numbering_from=nothing,fontsize=13,color="black");
plot_nodes!(p,mx,thin_out_route(routes[2], 0.25),start_numbering_from=nothing,fontsize=13,color="black");
plot_nodes!(p,mx,thin_out_route(routes[3], 0.25),start_numbering_from=nothing,fontsize=13,color="black");
p

#routes - 10
p = OpenStreetMapXPlot.plotmap(mx,width=1000,height=800);
addroute!(p,mx,routes[1];route_color="red")
addroute!(p,mx,routes[2];route_color="green")
addroute!(p,mx,routes[3];route_color="blue")
plot_nodes!(p,mx,thin_out_route(routes[1], 0.10),start_numbering_from=nothing,fontsize=13,color="black");
Plots.gr()
plot_nodes!(p,mx,thin_out_route(routes[2], 0.10),start_numbering_from=nothing,fontsize=13,color="black");
plot_nodes!(p,mx,thin_out_route(routes[3], 0.10),start_numbering_from=nothing,fontsize=13,color="black");
p
