# Load required libraries
library(dplyr)
library(readr)
library(tidyverse)
library(sf)

### Second Step: Calculating weights of outdoor POIS ---------------------------------------------------------------------------

# Read input data for park ----------------------------------------------------- 
baseline_destinations <- read_sf("./data/newData/baseline_destinations.sqlite") 
meshblock_vic <- read_sf("./data/MB/MB_2016_VIC.shp")%>%
  st_as_sf() %>%
  st_transform(28355)
meshblock_population <- read_csv("./data/2016 census mesh block counts.csv")
gm_bound <- read_sf("./data/region_buffer.sqlite")

# Read input data for PT stops -------------------------------------------------
data_path <- "./data/"
gtfs_path <- paste0(data_path, "gtfs/")
poi <- st_read(paste0(data_path, "poi.gpkg"))
baseline_destinations <- read_sf(paste0(data_path,"newData/baseline_destinations.sqlite"))

# Define a function to read GTFS data
read_gtfs <- function(gtfs_id) {
  path <- paste0(gtfs_path, gtfs_id, "/google_transit/")
  list(
    stops = read_csv(paste0(path, "stops.txt")),
    stop_times = read_csv(paste0(path, "stop_times.txt")),
    calendar = read_csv(paste0(path, "calendar.txt")),
    calendar_dates = read_csv(paste0(path, "calendar_dates.txt")), # All exceptions are exception type 2 
    trips = read_csv(paste0(path, "trips.txt"))
  )
}

# Load GTFS data for Train, Tram, and Bus
train_data <- read_gtfs(2)
tram_data <- read_gtfs(3)
bus_data <- read_gtfs(4)

# Assign weights to PT stops ---------------------------------------------------

# Function to process GTFS data
process_gtfs_data <- function(gtfs_data, date) {
  services <- gtfs_data$calendar %>%
    filter(start_date <= date & end_date >= date & wednesday == 1)
  
  exception_date <- gtfs_data$calendar_dates %>%
    filter(date == date)
  
  trip_services <- gtfs_data$trips %>%
    filter(service_id %in% services$service_id & !(service_id %in% exception_date$service_id))
  
  stop_trips <- gtfs_data$stop_times %>%
    filter(trip_id %in% trip_services$trip_id)
  
  stop_trips
}

# Process each GTFS type
train_stop_trips <- process_gtfs_data(train_data, 20240228)
tram_stop_trips <- process_gtfs_data(tram_data, 20240228)
bus_stop_trips <- process_gtfs_data(bus_data, 20240228)

# Filter and bind original POIS and baseline destinations
filtered_poi <- poi %>% filter(Attribute %in% c("bus", "tram", "train")) %>% 
  select(Attribute, geom)

filtered_destinations <- baseline_destinations %>% filter(dest_type %in% c("bus", "tram", "train")) %>%
  select(Attribute = dest_type, geom = GEOMETRY)

pt_data <- rbind(filtered_poi, filtered_destinations) %>% 
  distinct()

# Calculation of services per stop
calculate_services <- function(stop_trips, stops) {
  stop_trips %>%
    group_by(stop_id) %>%
    summarise(services = n()) %>%
    left_join(stops, by = "stop_id") %>%
    st_as_sf(coords = c('stop_lon', 'stop_lat'), crs = 4326) %>%
    st_transform(28355)
}

train_services <- calculate_services(train_stop_trips, train_data$stops)
tram_services <- calculate_services(tram_stop_trips, tram_data$stops)
bus_services <- calculate_services(bus_stop_trips, bus_data$stops)

# Join GTFS stop frequencies with POIs
join_pt_data <- function(pt_data, services) {
  st_join(services, pt_data) %>%
    mutate(Attribute = unique(pt_data$Attribute)) %>%
    select(Attribute, weight = services, geometry)
}

pt_points <- do.call(rbind, list(
  train = join_pt_data(pt_data %>% filter(Attribute == "train"), train_services),
  tram = join_pt_data(pt_data %>% filter(Attribute == "tram"), tram_services),
  bus = join_pt_data(pt_data %>% filter(Attribute == "bus"), bus_services)
))

# Assign weights to Parks ------------------------------------------------------

# Get the area of each mesh block and assign population to each mesh block
# Constrain to Greater Melbourne region 
meshblock <- st_intersection(meshblock_vic, gm_bound) %>% 
  filter(AREASQKM16 != 0) %>%  
  mutate(AREASQM16 = AREASQKM16 * 1000000) %>% 
  dplyr::select(MB_CODE16, AREASQM16, geometry)
meshblock_population <- meshblock_population %>% 
  filter(State == 2) %>%  
  dplyr::select(MB_CODE_2016, MB_CATEGORY_NAME_2016, MB_Person = Person)

meshblock_data <- left_join(meshblock, meshblock_population, by= c("MB_CODE16" = "MB_CODE_2016")) %>% 
  # Get the density of person/area for each mesh block
  mutate(MB_Density = MB_Person/AREASQM16)

# Get parks from input data
parks <- baseline_destinations %>% 
  filter(dest_type == "park")%>%
  mutate(parkid = row_number()) %>% 
  st_as_sf() %>% 
  st_transform(28355) %>% 
  dplyr::select(dest_type, parkid, GEOMETRY)

parks$park_area <- as.double(st_area(parks)) 

# Create 400m buffer around each park
parks_buffered <- st_buffer(parks, dist = 400)

# Get the intersection of surrounded mesh blocks with 400m buffer around each park 
intersection <- st_intersection(parks_buffered, meshblock_data)
intersection$InterArea <- as.double(st_area(intersection))
intersection <- intersection %>% 
  mutate(InterPerson = MB_Density * InterArea)

# Park weights 
park_weight <- intersection %>% 
  mutate(Subweight = InterPerson/park_area) 
park_weight <- park_weight %>% 
  group_by(parkid) %>%  
  summarise(weight = sum(Subweight)) %>% 
  mutate(Attribute = "park") %>% 
  dplyr::select(Attribute, weight, geometry=GEOMETRY)

# Write outputs ----------------------------------------------------------------
ParkPT_weight <- rbind(pt_points, park_weight)
st_write(ParkPT_weight, "./output/ParkPT_weight.gpkg")
