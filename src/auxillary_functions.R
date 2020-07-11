make_circles <- function(df, radius, n_points = 100){
    mean_lat <- mean(df$lat)
    
    radius_lon <- radius / 111 / cos(mean_lat/57.3) 
    radius_lat <- radius / 111
    circles_df <- data.frame(node = rep(df$node, each = n_points))
    angle <- seq(0, 2*pi, length.out = n_points)

    circles_df$lon <- unlist(lapply(df$lon, function(x) x + radius_lon * cos(angle)))
    circles_df$lat <- unlist(lapply(df$lat, function(x) x + radius_lat * sin(angle)))
    return(circles_df)
}

generate_scenarios_iterative <- function() {
  require(dplyr)
  
  metric_1 <- "time"
  metric_2 <- "distance"
  
  p <- c(4, 9, 16, 25)
  
  r_1 <- c(100.0, 125.0, 150.0, 175.0, 200.0, 250.0, 300.0)
  r_2 <- c(1000.0, 1500.0, 2000.0, 2500.0, 3000.0, 3500.0, 4000.0)
  
  ruin_random <- c(0.0, 0.1, 0.25, 0.5, 0.75, 0.95)
  strategy <- c("centered", "random")
  seed <- 1:30
  
  scenarios_1 <- expand.grid(metric_1, p, r_1, ruin_random, strategy, seed)
  scenarios_2 <- expand.grid(metric_2, p, r_2, ruin_random, strategy, seed)
  scenarios <- rbind(scenarios_1, scenarios_2)
  
  colnames(scenarios) <- c("metric", "p", "r", "ruin_random", "strategy","seed")
  
  scenarios_commands <- scenarios %>% 
    transmute(
      command = paste0(
        "julia iterative_model.jl --city winnipeg --metric ", metric,
        " --p ", p,
        " --r ", r,
        " --R 2500.0 5000.0 7500.0 10000.0 --q 1 2 3 ",
        " --ruin_random ", ruin_random,
        " --initialization_strategy ", strategy,
        " --seed ", seed
      )
    )
  
  write.table(scenarios_commands, "scenarios_iterative.txt",
            row.names = FALSE, col.names = FALSE, quote = TRUE)
}

generate_scenarios_p_mp <- function() {
  require(dplyr)
  
  metric_1 <- "time"
  metric_2 <- c("distance", "eucledian")
  r_1 <- 600.0
  r_2 <- 5000.0
  
  p <- c(4, 9, 16, 25)
  m <- c(500, 1000, 2000, 3000, 4000, 5000)
  n <- c(1000, 2000, 3000, 4000, 5000, 6000)
  
  seed <- 1:30
  
  scenarios_1 <- expand.grid(metric_1, p, r_1, ruin_random, strategy, seed)
  scenarios_2 <- expand.grid(metric_2, p, r_2, ruin_random, strategy, seed)
  scenarios <- rbind(scenarios_1, scenarios_2)
  
  colnames(scenarios) <- c("metric", "p", "r", "ruin_random", "strategy","seed")
  
  scenarios_commands <- scenarios %>% 
    transmute(
      command = paste0(
        "julia p_mp_model_jump.jl --city winnipeg --metric ", metric,
        " --p ", p,
        " --m ", m,
        " --n ", n,
        " --q 1 --r 5000.0",
        " --seed ", seed
      )
    )
  
  write.table(scenarios_commands, "src/scenarios_p-mp.txt",
            row.names = FALSE, col.names = FALSE, quote = TRUE)
}
