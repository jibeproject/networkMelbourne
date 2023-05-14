rm(list = ls())
library(dplyr)
library(sf)
library(raster)
library(purrr)
library(stringr)
library(tidyverse)


# Reading inputs
nodesmel = st_read("./data/nodes.gpkg")
edgesmel = st_read("./data/Geopackage.gpkg")
nodesmel = networkFinal[[1]]
edgesmel = networkFinal[[2]]
edgesmel <- edgesmel %>% st_cast("LINESTRING")


# Adjusting nodes

# addElevation2Nodes <- function(nodes, rasterFile, multiplier=10){
#   elevation <- raster(rasterFile) 
#   nodes$z <- round(raster::extract(elevation ,as(nodes, "Spatial"),method='bilinear'))/multiplier
#   return(nodes)
# }
# 
# st_crs(nodesmel) <- 28355
# nodes_crs <- nodesmel %>% st_as_sf() %>%  st_transform(crs =  28355)
# 
# nodes_elev <- addElevation2Nodes(nodes = nodes_crs, rasterFile = "./data/DEMx10EPSG28355.tif" )
# 
# nodes <- nodes_elev %>% 
#   rename(nodeid=id) %>%
#   mutate(nodeid = format(nodeid, scientific = FALSE),
#          cyc_cros = "null", 
#          ped_cros = "null",
#          x = unlist(map(geom,1)),
#          y = unlist(map(geom,2)),
#          z = ifelse(is.na(z), round(mean(z, na.rm = T), digits = 1), z)) %>% 
#   mutate(nodeid = trimws(x= nodeid, which = c("both")), 
#          nodeid = as.integer(as.character(nodeid))) %>% 
#   distinct() %>% 
#   arrange(nodeid)

nodes <- nodes_elev %>% 
  rename(nodeid=id) %>%
  mutate(nodeid = format(nodeid, scientific = FALSE),
         cyc_cros = "null", 
         ped_cros = "null") %>% 
  mutate(nodeid = trimws(x= nodeid, which = c("both")), 
         nodeid = as.integer(as.character(nodeid))) %>% 
  distinct() %>% 
  arrange(nodeid)

st_write(nodes, "./output/nodes.gpkg", layer = "adjusted", delete_layer = T)


# Adjusting links
freespeed_categories <- edgesmel %>% 
  st_drop_geometry() %>% 
  group_by(highway, freespeed) %>% 
  summarise(n = n())

### selecting and cleaning edges
edges_sel <- edgesmel %>% 
  dplyr::select(edgeID = edgeid,
                from_id,
                to_id,
                length,
                freespeed,
                capacity,
                permlanes,
                is_oneway,
                modes,
                indp_sc = Individual_count,
                aadt_hgv_im = ad_aadt, 
                avg_wdt_mp =averagew_2,
                cyclwy_f = cycleway.l,
                cyclwy_b = cycleway.r,
                ngp_scr = Negative_count,
                Junction,
                ndvimean,
                osm_id,
                quietness,
                Shannon_Index,
                SpeedLimit,
                surface, 
                highway, 
                spedKPH = maxspeed,
                VGVI_Mean) %>% 
  mutate(osm_id = as.integer(as.character(edgesmel$osm_id)),
         spedKPH = as.double(as.character(spedKPH))) %>% 
  mutate(freespeed = case_when(is.na(freespeed) & str_detect(highway, "primary") | 
                                 freespeed == 0 & str_detect(highway, "primary") ~ 16.66667, 
                               is.na(freespeed) & str_detect(highway, "secondary") | 
                                 freespeed == 0 & str_detect(highway, "secondary") ~ 16.66667,
                               is.na(freespeed) & str_detect(highway, "tertiary") | 
                                 freespeed == 0 & str_detect(highway, "tertiary") ~ 13.88889,
                               is.na(freespeed) & str_detect(highway, "residential") | 
                                 freespeed == 0 & str_detect(highway, "residential") ~ 13.88889,
                               is.na(freespeed) & str_detect(highway, "motorway") | 
                                 freespeed == 0 & str_detect(highway, "motorway") ~ 27.77778,
                               is.na(freespeed) & highway == "service" | 
                                 freespeed == 0 & highway == "service"~ 13.888889,
                               is.na(freespeed) & highway %in% c("trunk") | 
                                 freespeed == 0 & highway %in% c("trunk") ~ 22.222222,   
                               is.na(freespeed) & highway %in% c("path", "footway", "steps", "pedestrian") | 
                                 freespeed == 0 & highway %in% c("path", "footway", "steps", "pedestrian") ~ 1.4,   # average walking speed
                               is.na(freespeed) & highway %in% c("cycleway") | 
                                 freespeed == 0 & highway %in% c("cycleway") ~ 5,   # average cycling speed
                               is.na(freespeed) | freespeed == 0 ~  mean(freespeed, na.rm= T),
                               T ~ freespeed)) %>% 
  mutate(permlanes = ifelse(is.na(permlanes) | permlanes == 0, round(mean(permlanes, na.rm= T), digits = 0), permlanes),
         capacity = ifelse(is.na(capacity), round(mean(capacity, na.rm= T), digits = 0), capacity),
         SpeedLimit = ifelse(is.na(SpeedLimit) | SpeedLimit==0, 
                             round(freespeed * 2.237, digits = 0), round((SpeedLimit * 0.6214), digits = 0)), # converting m/s to mph and converting kph to mph
         spedKPH = ifelse(is.na(spedKPH), round(mean(spedKPH, na.rm=T), digits = 0), spedKPH)) %>% 
  mutate(indp_sc = ifelse(is.na(indp_sc), 0, indp_sc), 
         aadt_hgv_im = ifelse(is.na(aadt_hgv_im), NaN, aadt_hgv_im),
         allowsCar = ifelse(str_detect(modes, "car"), T, F),
         dismount = ifelse(str_detect(modes, "bike"), F, T),
         motorway = ifelse(str_detect(highway, "motorway"), T, F), 
         crim_cnt = 0,
         cyclesm = "null",
         edgeID = format(edgeID, scientific = FALSE),
         from_id = format(from_id, scientific = FALSE),
         to_id = format(to_id, scientific = FALSE),
         Junction = ifelse(is.na(Junction), "null", Junction), 
         ngp_scr = ifelse(is.na(ngp_scr), 0, ngp_scr),
         ndvimean = ifelse(is.na(ndvimean), 0, ndvimean),
         quietness = ifelse(is.na(quietness), 10, quietness),
         Shannon_Index = ifelse(is.na(Shannon_Index), 0, Shannon_Index),
         strtlgh = 0,
         surface = ifelse(is.na(surface), "null", surface),
         VGVI_Mean = ifelse(is.na(VGVI_Mean), (0.0293269 + 1.0927493 * ndvimean), VGVI_Mean)) %>%    # from Corin's code
  mutate(edgeID = trimws(x= edgeID, which = c("both")), 
         from_id = trimws(x= from_id, which = c("both")), 
         to_id = trimws(x= to_id, which = c("both"))) %>% 
  mutate(edgeID = as.integer(as.character(edgeID)),
         from_id = as.integer(as.character(from_id)),
         to_id = as.integer(as.character(to_id)),
         freespeed = as.double(as.character(freespeed)),
         permlanes = as.integer(as.character(permlanes)),
         SpeedLimit= as.integer(as.character(SpeedLimit))) %>% 
  distinct()

edges_sel <- edges_sel[-c(471911, 471914),]


### creating one way network with rtn and out links
edges_1way <- edges_sel %>% 
  filter(is_oneway == 1) %>% 
  mutate(id = paste0(as.character(edgeID), "out"),
         from = from_id,
         to = to_id,
         cycleway =  cyclwy_f,
         fwd = T)

edges_2ways_out <- edges_sel %>% 
  filter(is_oneway == 0) %>% 
  mutate(id = paste0(as.character(edgeID), "out"),
         from = from_id,
         to = to_id,
         is_oneway = 1,
         aadt_hgv_im= ifelse(allowsCar, aadt_hgv_im/2, 0),
         cycleway =  cyclwy_f,
         fwd = T)

edges_2ways_rtn <- edges_sel %>% 
  filter(is_oneway == 0) %>% 
  mutate(id = paste0(as.character(edgeID), "rtn"),
         from = to_id,
         to = from_id,
         is_oneway = 1,
         aadt_hgv_im= ifelse(allowsCar, aadt_hgv_im/2, 0),
         cycleway =  cyclwy_b,
         fwd = F)

edges_total <- rbind(edges_1way, edges_2ways_out, edges_2ways_rtn) %>% 
  mutate(cycleway = ifelse(is.na(cycleway), "No", cycleway)) %>% 
  dplyr::select(-from_id, -to_id) %>% 
  distinct() %>% 
  arrange(edgeID)

### getting junctions (intersection) and crossing attributes
edges_total_nogeom <- edges_total %>% 
  st_drop_geometry() 

nodes_jnc<- edges_total_nogeom %>%
  group_by(to) %>%
  summarise(n= n()) %>% 
  filter(n > 2)

lookup_cross <- edges_total_nogeom %>% 
  filter(to %in% nodes_jnc$to) %>% 
  group_by(to) %>% 
  mutate(crossVehicles = T,
         crossLanes = sum(permlanes),
         crossAadt = sum(aadt_hgv_im),
         crossSpeedLimit = max(SpeedLimit),
         cross85PercSpeed = max(spedKPH)) %>% 
  dplyr::select(to, crossVehicles, crossLanes, crossAadt, crossSpeedLimit, cross85PercSpeed) %>% 
  ungroup() %>% 
  distinct()

### final edge
edges <- edges_total %>% left_join(lookup_cross, by= "to") %>% 
  mutate(crossVehicles = ifelse(is.na(crossVehicles), F, crossVehicles),
         crossLanes = ifelse(is.na(crossLanes), NaN,  crossLanes),
         crossAadt = ifelse(is.na(crossAadt), NaN, crossAadt),
         crossSpeedLimit = ifelse(is.na(crossSpeedLimit), NaN, crossSpeedLimit),
         cross85PercSpeed = ifelse(is.na(cross85PercSpeed), NaN, cross85PercSpeed)) %>% 
  distinct()


st_write(edges, "./output/edges.gpkg", layer = "adjusted", delete_layer = T)


# Network file
networkFinal <- list(nodes, edges)


