library(tidyverse)
library(ggmap)
library(gganimate)

register_google(key = Sys.getenv("GMAP_API_KEY"))

# getting the transition data
transition_df <- read_csv("Ryerson/transitions_df_dropout_2.csv")
transition_df <- transition_df %>%
  group_by(STATE) %>%
  summarise(N_AMBULANCES = n()) %>%
  left_join(transition_df)

# getting the map
map_north_bay <- read_rds("Ryerson/map_north_bay.RDS")
map_winnipeg <- read_rds("Ryerson/map_winnipeg.RDS")
#map_north_bay <- get_map(location = "North Bay, Ontario",
#                      maptype = "roadmap", scale = 2, zoom = 12)
#write_rds(map_north_bay, path = "Ryerson/map_north_bay.RDS")
#map_winnipeg <- get_map(location = "Winnipeg",
#                      maptype = "roadmap", scale = 2, zoom = 10)
#write_rds(map_winnipeg, path = "Ryerson/map_winnipeg.RDS")

p <- ggmap(map_north_bay,
           base_layer = ggplot(aes(x = LONG, y = LAT, color = factor(N_AMBULANCES)), data = transition_df)) +
  geom_point(size = 3)

anim <- p + 
  transition_states(STATE,
                    transition_length = 1,
                    state_length = 1) +
  ggtitle('Now showing {closest_state}')

animate(anim, fps = 5, nframes = 2*max(transition_df$STATE))



#########################
ggmap(map_north_bay,
      base_layer = ggplot(aes(x = LONG, y = LAT, color = as.factor(N_AMBULANCES)),
                          data = transition_df %>%
                            filter(STATE == 1))) +
  geom_point(size = 3)
