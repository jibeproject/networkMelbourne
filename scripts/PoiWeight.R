library(dplyr)
library(readr)
library(tidyverse)
library(sf)
library(DBI)
library(RPostgres)
library(RSQLite)
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(sf))
suppressPackageStartupMessages(library(RPostgreSQL))
suppressPackageStartupMessages(library(dbscan))

# Setup the building footprint database (uses bash) -----------------------------------------------

# Uncomment and run in the terminal

# createdb -U postgres buildingFootprint
# psql -U postgres -d buildingFootprint -c 'CREATE EXTENSION IF NOT EXISTS postgis'


# First Step: Calculate each job category density in SA2 level---------------------------------------------------

# Read Inputs 
orgPoi<- st_read("./data/poi.gpkg")                                                #read pois data
baseline_destinations <- read_sf("./data/newData/baseline_destinations.sqlite")    #read new destinations added to the baseline
sa2_employment <- read.csv("./data/sa2_employment_2016.csv")                      #employment data
sa2_boundary <- st_read("./data/sa2Boundry/SA2_2016_AUST.shp")                    #SA2 boundary data
building_footprint<- st_read("./output/building_footprint.gpkg")                  #Building footprint data
gm_bound <- read_sf("./data/region_buffer.sqlite")

# Create the SQM^2 for area
sa2_boundary <- sa2_boundary %>% 
  mutate(SA2 = as.integer(SA2_MAIN16), AREASQM16 = AREASQKM16 * 1000000) %>% 
  dplyr::select(SA2, AREASQM16, geometry)

# Join the boundary of each area to employment data
employment_area <- left_join(x = sa2_employment, y = sa2_boundary, by = "SA2")

# Calculate the density of each job category fo each SA2 area
employment_area[, 2:(ncol(employment_area) - 2)] <- employment_area[, 2:(ncol(employment_area) - 2)] / employment_area$AREASQM16

## Building footprint import -----------------------------------------------------------------------------------------

# Getting the area of buildings
building_footprint$area <- st_area(building_footprint)
building_footprint <- building_footprint %>%  
  mutate(id = row_number(), area = as.double(area))

# Connect to database
conn = dbConnect(PostgreSQL(), dbname="buildingFootprint", user="postgres", password="", host="localhost")

# Adding the building to the database, and generating a spatial index to speed up query
st_write(building_footprint, conn, layer="building")
dbSendQuery(conn, statement="CREATE INDEX building_gix ON building USING GIST (geom);")

## poi import-----------------------------------------------------------------------------------------------

#get the the new destinations
new_destinations <- baseline_destinations %>% 
  filter(dest_type %in% 
           c("convenience_store", "gp", "maternal_child_health", 
             "dentist", "kindergarten", "primary")) %>% 
  mutate(id = row_number(), attribute = dest_type) %>% 
  rename("geom" = "GEOMETRY") %>%  
  select(-dest_type, -weight)

# get the positive POIs
poi_positive <- orgPoi %>%
  filter(Type == "Positive", 
         !Indicator %in% c("Public transport", "Public open space"))%>% 
  mutate(id = row_number()) %>% 
  rename_with(tolower)

# create total poi data 
poi <- rbind(poi_positive, new_destinations)

# Assign a job category to each poi
poi_job <- poi %>%
  mutate(id = row_number()) %>%
  mutate(JobCategory = case_when(attribute %in% c("pipeline facility", "power facility") ~
                                   "Electricity..Gas..Water.and.Waste.Services",
                                 attribute %in% c( "green_grocers", "supermarket", "book_store",
                                                   "clothing", "florist", "jewelry_store", "shopping_mall",
                                                   "convenience_store") ~
                                   "Retail.Trade",
                                 attribute %in% c( "bar", "cafe", "restaurant") ~
                                   "Accommodation.and.Food.Services",
                                 attribute %in% c("storage facility") ~
                                   "Transport..Postal.and.Warehousing",
                                 attribute %in% c( "accounting", "bank") ~
                                   "Financial.and.Insurance.Services",
                                 attribute %in% c("post_office", "tourist information centre") ~
                                   "Administrative.and.Support.Services",
                                 attribute %in% c( "child care", "primary school", "primary/secondary school",
                                                   "secondary school", 
                                                   "kindergarten","primary") ~
                                   "Education.and.Training",
                                 attribute %in% c( "pharmacy", "maternal/child health centre", "hospital", "aged care",
                                                   "community health centre", "day procedure centre", "general hospital",
                                                   "general hospital (emergency)", 
                                                   "gp", "maternal_child_health", "dentist") ~
                                   "Health.Care.and.Social.Assistance",
                                 attribute %in% c( "boathouse", "boating club", "club house", "gym", "spa", "swimming pool",
                                                   "amphitheatre", "aquarium", "art gallery", "entertainment centre",
                                                   "historic site", "museum", "tourist attraction", "tourist_attraction") ~
                                   "Arts.and.Recreation.Services",
                                 attribute %in% c(  "beauty_salon", "hair_care", "church", "monastry", "mondir (hindu)",
                                                    "mosque", "synagogue", "hall", "community centre", "neighbourhood house", "library") ~
                                   "Other.Services"
                                 )
         )

# Add to database and generate spatial index
st_write(poi, conn, layer="poi")
dbSendQuery(conn,statement="CREATE INDEX poi_gix ON poi USING GIST (geom);")

# Snap pois to nearest building (within 10m)
dbSendQuery(conn,statement="
   DROP TABLE IF EXISTS poi_snapped_building;
   CREATE TABLE poi_snapped_building AS
   SELECT DISTINCT ON (n.id) n.id, e.id AS closest_building_id
   FROM poi AS n
   JOIN building AS e ON ST_DWithin(n.geom, e.geom, 10)
   ORDER BY n.id, ST_Distance(n.geom, e.geom)
;")

# Get ids of closest building with a poi
poi_snapped_building <- dbGetQuery(conn,"SELECT * FROM poi_snapped_building;")

# SA2 area import ------------------------------------------------------------------------------------------------------------

# The sa2 area
sa2_area<- sa2_boundary %>%
  dplyr::select(id = SA2, geom = geometry) %>%
  st_as_sf() %>%
  st_transform(28355)

# Adding the sa2 to the database, and generating a spatial index to speed up query
st_write(sa2_area, conn, layer="sa2")
dbSendQuery(conn,statement="CREATE INDEX sa2_gix ON sa2 USING GIST (geom);")

# Snap pois to nearest SA2 (within 10m)
dbSendQuery(conn,statement="
   DROP TABLE IF EXISTS poi_snapped_sa2;
   CREATE TABLE poi_snapped_sa2 AS
   SELECT DISTINCT ON (n.id) n.id, e.id AS closest_sa2_id
   FROM poi AS n
   JOIN sa2 AS e ON ST_DWithin(n.geom, e.geom, 10)
   ORDER BY n.id, ST_Distance(n.geom, e.geom)
;")

# Get ids of closest sa2 with a positive poi
pois_snapped_sa2 <- dbGetQuery(conn,"SELECT * FROM poi_snapped_sa2;")

# Weight assignment to POIs ------------------------------------------------------------------------------------------------------------------

employment_area_long <-employment_area %>% gather(key = 'JobCategory', value = 'density', -SA2)
employment_area_long$density <- as.numeric(format(employment_area_long$density, scientific = FALSE))

building_id <- building_footprint %>% 
  dplyr::select(area, id) %>% 
  st_drop_geometry()

poi_building_sa2 <- poi_job %>%
   left_join(pois_snapped_sa2 , by= "id") %>%
   left_join(poi_snapped_building, by= "id") %>%
   left_join(employment_area_long, by= c("closest_sa2_id"= "SA2", "JobCategory" = "JobCategory")) %>%
   left_join(building_id, by= c("closest_building_id" = "id"))

# calculate average building area for each attribute in each SA2 and in total
average_area_SA2_poi <- poi_building_sa2 %>% 
  filter(!is.na(area)) %>% 
  group_by(attribute, closest_sa2_id) %>%
  summarise(mean_area_SA2 = mean(area)) %>%  
  st_drop_geometry()

average_area_poi <- average_area_SA2_poi %>% 
  group_by(attribute) %>%
  summarise(mean_area = mean(mean_area_SA2))

# add average building area to data to assign to the points that have NA as the building area
poi_building_sa2 <-  poi_building_sa2 %>% 
  left_join(average_area_SA2_poi , by= c("attribute", "closest_sa2_id")) %>% 
  left_join(average_area_poi, by= "attribute")

# calculate weight for each point 
poi_building_sa2 <- poi_building_sa2 %>% 
  mutate(weight = case_when(!is.na(area) ~ density*area, 
                            (is.na(area) & !is.na(mean_area_SA2)) ~ density*mean_area_SA2,
                            T ~ density*mean_area))

poi_building_sa2$weight <- as.numeric(format(poi_building_sa2$weight, scientific = FALSE))
poi_building_sa2 <- st_intersection(poi_building_sa2, gm_bound)     #constrain to Greater Melbourne region

poi_weight <- poi_building_sa2 %>%
  select(attribute, indicator, type, code, weight, geom)

# Write the output
poi_weight <- st_write(poi_weight, "./output/poi_weight.gpkg")


