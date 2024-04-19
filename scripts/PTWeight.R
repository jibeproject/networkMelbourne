# Load necessary libraries
library(tidyverse)
library(sf)
library(dplyr)

# Base paths for data
data_path <- "./data"
gtfs_base_path <- file.path(data_path, "gtfs")
output_path <- "./output"

# Function to read GTFS data
read_gtfs_data <- function(gtfs_id, file_name) {
  read_csv(file.path(gtfs_base_path, as.character(gtfs_id), "google_transit", file_name))
}

# Function to calculate and join services
calculate_services <- function(stops, stop_times, trips, services, exceptions, attribute) {
  trip_services <- trips %>% 
    filter(service_id %in% services$service_id & !(service_id %in% exceptions$service_id))
  stop_trips <- stop_times %>% 
    filter(trip_id %in% trip_services$trip_id)
  sum_services <- stop_trips %>% 
    group_by(stop_id) %>% 
    summarise(services = n()) %>%
    left_join(stops, by = "stop_id") %>%
    st_as_sf(coords = c('stop_lon', 'stop_lat'), crs = 4326) %>% 
    st_transform(28355) %>% 
    mutate(Attribute = attribute) %>% 
    dplyr::select(Attribute, weight = services, geometry)
  return(sum_services)
}

# Read spatial and GTFS data
poi <- st_read(file.path(data_path, "poi.gpkg"))
baseline_destinations <- read_sf(file.path(data_path, "newData", "baseline_destinations.sqlite"))

# Process each transportation mode
modes <- c("Train" = 2, "Tram" = 3, "Bus" = 4)
pt_points <- map_df(names(modes), function(mode) {
  stops <- read_gtfs_data(modes[[mode]], "stops.txt")
  stop_times <- read_gtfs_data(modes[[mode]], "stop_times.txt")
  calendar <- read_gtfs_data(modes[[mode]], "calendar.txt")
  exceptions <- read_gtfs_data(modes[[mode]], "calendar_dates.txt")
  trips <- read_gtfs_data(modes[[mode]], "trips.txt")
  services <- calendar %>% filter(start_date <= 20240228 & end_date >= 20240228 & wednesday == 1)
  exception_date <- exceptions %>% filter(date == 20240228)
  calculate_services(stops, stop_times, trips, services, exception_date, tolower(mode))
})

# Combine and filter POI data
poi_pt <- poi %>% filter(Attribute %in% c("bus", "tram", "train")) %>% 
  rename_with(tolower)
new_pt <- baseline_destinations %>% mutate(attribute = dest_type) %>% 
  filter(attribute %in% c("bus", "tram", "train")) %>%
  dplyr::select(- dest_type, - weight) %>%  
  rename(geom = GEOMETRY)
pt_data <- rbind(poi_pt, new_pt) %>%  
  distinct()

# Join GTFS stops frequency to POIs 
pt_weight <- st_join(pt_data, pt_points)

# Write the output
st_write(pt_weight, file.path(output_path, "PT_weight.gpkg"))
