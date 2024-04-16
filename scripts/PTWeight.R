rm(list = ls())
library(dplyr)
library(readr)
library(tidyverse)
library(sf)

# Read Inputs: 
Poi<- st_read("./data/poi.gpkg")      
baseline_destinations <- read_sf("./Steve's Data/baseline_destinations.sqlite")  

Train_stops <- read_csv("./data/gtfs/2/google_transit/stops.txt")
Train_stop_times <- read_csv("./data/gtfs/2/google_transit/stop_times.txt")
Train_calender <- read_csv("./data/gtfs/2/google_transit/calendar.txt")
Train_exception <- read_csv("./data/gtfs/2/google_transit/calendar_dates.txt")   # All exceptions are exception type 2 
Train_trips <- read_csv("./data/gtfs/2/google_transit/trips.txt")
Tram_stops <- read_csv("./data/gtfs/3/google_transit/stops.txt")
Tram_stop_times <- read_csv("./data/gtfs/3/google_transit/stop_times.txt")
Tram_calender <- read_csv("./data/gtfs/3/google_transit/calendar.txt")
Tram_exception <- read_csv("./data/gtfs/3/google_transit/calendar_dates.txt")    # All exceptions are exception type 2 
Tram_trips <- read_csv("./data/gtfs/3/google_transit/trips.txt")
Bus_stops <- read_csv("./data/gtfs/4/google_transit/stops.txt")
Bus_stop_times <-read_csv("./data/gtfs/4/google_transit/stop_times.txt")
Bus_calender <- read_csv("./data/gtfs/4/google_transit/calendar.txt")
Bus_exception <- read_csv("./data/gtfs/4/google_transit/calendar_dates.txt")     # All exceptions are exception type 2
Bus_trips <- read_csv("./data/gtfs/4/google_transit/trips.txt")

# Filter GTFS ------------------------------------------------------------------ 
# filter services 
Train_services <- Train_calender %>% filter(start_date <= 20240228 & end_date >= 20240228 & wednesday == 1)
Tram_services <- Tram_calender %>% filter(start_date <= 20240228 & end_date >= 20240228 & wednesday == 1)
Bus_services <- Bus_calender %>% filter (start_date <= 20240228 & end_date >= 20240228 & wednesday == 1)

Train_exception_date <- Train_exception %>% filter(date == 20240228)
Tram_exception_date <- Tram_exception %>% filter(date == 20240228)
Bus_exception_date <- Bus_exception %>% filter(date == 20240228)


# filter trips based on the services 
Train_trip_services <- Train_trips %>% 
  filter(service_id %in%Train_services$service_id)              # No exception on the specific chosen date 
Tram_trip_services <- Tram_trips %>% 
  filter(service_id %in% Tram_services$service_id)              # No exception on the specific chosen date
Bus_trip_services <- Bus_trips %>% 
  filter((service_id %in% Bus_services$service_id) & !(service_id %in% Bus_exception_date$service_id))             

# filter stops based on filtered trips 
Train_stop_trips <- Train_stop_times %>%  
  filter(trip_id %in% Train_trip_services$trip_id)

Tram_stop_trips <- Tram_stop_times %>%  
  filter(trip_id %in% Tram_trip_services$trip_id)

Bus_stop_trips <- Bus_stop_times %>%  
  filter(trip_id %in% Bus_trip_services$trip_id)

# Filter POIs to PT ------------------------------------------------------------
# filter destination points on PT data 
Poi_PT <- Poi %>% filter(Attribute %in% c("bus", "tram","train")) %>% 
  dplyr::select(Attribute, geom)
bd_PT <- baseline_destinations %>% filter(dest_type %in% c("bus", "tram","train")) %>% 
  dplyr::select(Attribute = dest_type, geom = GEOMETRY)

PT <- rbind(Poi_PT, bd_PT) %>% 
  distinct()

Train <- PT %>%  filter(Attribute == "train")
Tram <- PT %>%  filter(Attribute == "tram")
Bus <- PT %>%  filter(Attribute == "bus")

# Calculation ------------------------------------------------------------------
# calculate the number of services passing each stop for each pt mode in GTFS 
Train_sum_services <- Train_stop_trips %>% 
  group_by(stop_id) %>% 
  summarise(services=n())
Train_sum_services <- Train_sum_services %>% 
  left_join(Train_stops, by = "stop_id")
Train_sum_services <- st_as_sf(Train_sum_services, coords = c('stop_lon', 'stop_lat'), crs = 4326) %>% 
  st_transform(28355)

Tram_sum_services <- Tram_stop_trips %>% 
  group_by(stop_id) %>% 
  summarise(services=n())
Tram_sum_services <- Tram_sum_services %>% 
  left_join(Tram_stops, by = "stop_id")
Tram_sum_services <- st_as_sf(Tram_sum_services, coords = c('stop_lon', 'stop_lat'), crs = 4326) %>% 
  st_transform(28355)

Bus_sum_services <- Bus_stop_trips %>% 
  group_by(stop_id) %>% 
  summarise(services=n())
Bus_sum_services <- Bus_sum_services %>% 
  left_join(Bus_stops, by = "stop_id")
Bus_sum_services <- st_as_sf(Bus_sum_services, coords = c('stop_lon', 'stop_lat'), crs = 4326) %>% 
  st_transform(28355)

# joint the GTFS stops frequency to POIs for each PT mode ----------------------
Train_points <- st_join(Train_sum_services, Train) %>% mutate(Attribute = "train") %>% 
  dplyr::select(Attribute, weight = services, geometry)
Tram_points <- st_join(Tram_sum_services, Tram) %>% mutate(Attribute = "tram") %>% 
  dplyr::select(Attribute, weight = services, geometry)
Bus_points <- st_join(Bus_sum_services, Bus) %>% mutate(Attribute = "bus")%>%
  dplyr::select(Attribute, weight = services, geometry)

PT_points <- rbind(Train_points, Tram_points, Bus_points)

# Write the output
PT_weight <- st_write(PT_points, "./output/PT_weight.gpkg")




