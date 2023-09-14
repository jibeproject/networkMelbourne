#!/usr/bin/env Rscript

# load libraries and functions --------------------------------------------
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(tidyr))
suppressPackageStartupMessages(library(sf))
options(dplyr.summarise.inform = FALSE) # make dplyr stop blabbing about summarise





# Reading inputs
nodesmel = st_read("data/melbourneClipped_nodes.sqlite")
edgesmel = st_read("data/melbourneClipped_edges.sqlite")
# shouldn't be any multi-linestrings, but better to be certain
<<<<<<< HEAD
edgesmel <- edgesmel %>%
  st_cast("LINESTRING") %>%
  mutate(osm_id_full=osm_id)
edgesmel$osm_id <- gsub("_.*", "", edgesmel$osm_id)
=======
edgesmel <- edgesmel %>% st_cast("LINESTRING")
>>>>>>> 0d75494290f990df2eeffe98b3276ce3711da648



# Nodes adjustment --------------------------------------------------------

# CODE FOR ADDING ELEVATION TO NODES. It should already be present
# library(raster)
# # Adjusting nodes
# addElevation2Nodes <- function(nodes, rasterFile, multiplier=10){
#   elevation <- raster(rasterFile) 
#   nodes$z <- round(raster::extract(elevation ,as(nodes, "Spatial"),method='bilinear'))/multiplier
#   return(nodes)
# }
# 
# st_crs(nodesmel) <- 28355
# nodes_crs <- nodesmel %>% st_as_sf() %>%  st_transform(crs =  28355)
# 
# nodesmel <- addElevation2Nodes(nodes = nodes_crs, rasterFile = "./data/DEMx10EPSG28355.tif" )

nodes <- nodesmel %>%
  mutate(cyc_cros = case_when(
    type %in% c("signalised_intersection","signalised_roundabout")                   ~ "Signal",
    is_crossing==1 & !type %in% c("signalised_intersection","signalised_roundabout") ~ "Toucan"
  )) %>%
  mutate(ped_cros = cyc_cros) %>%
  mutate(z=ifelse(is.na(z),0,z)) %>% # a few of the points land outside of the study area so setting their height to 0
  mutate(id=as.integer(id)) %>%
  mutate(z=as.integer(z)) %>%
  select(nodeID=id,z_coor=z,ped_cros,cyc_cros)
  
st_write(nodes, "./output/nodesMelbourne.gpkg", delete_dsn = T)



# Edges adjustment --------------------------------------------------------

# determine the number of pedestrian and cycling crossings
crossing_count <- edgesmel %>%
  st_drop_geometry() %>%
  dplyr::select(edgeID=id,from=from_id,to=to_id) %>%
  pivot_longer(cols=c(from,to)) %>%
  dplyr::select(edgeID,nodeID=value) %>%
  inner_join(nodes%>%st_drop_geometry()%>%dplyr::select(nodeID,ped_cros,cyc_cros), by="nodeID") %>%
  mutate(ped_cros=ifelse(is.na(ped_cros),0,1)) %>%
  mutate(cyc_cros=ifelse(is.na(cyc_cros),0,1)) %>%
  group_by(edgeID) %>%
  summarise(crs_cnt=sum(ped_cros,na.rm=T),bik_cnt=sum(cyc_cros,na.rm=T)) %>%
  ungroup()
  
# roadtype table
roadtyp <- read.csv("data/roadtyp.csv")

# attributes calculated in processNetwork.R
edge_attributes <- readRDS("data/POIs_joined.rds")

edges <- edgesmel %>%
<<<<<<< HEAD
  # st_drop_geometry() %>%
=======
  st_drop_geometry() %>%
>>>>>>> 0d75494290f990df2eeffe98b3276ce3711da648
  left_join(edge_attributes, by="id") %>%
  rename(edgeID=id,
         from=from_id,
         to=to_id) %>%
  mutate(junctn = "no") %>%
  left_join(roadtyp, by=c("highway","cycleway","is_cycle")) %>%
  mutate(onwysmm = case_when(
    is_car==0 & is_walk==1 & is_cycle==0  ~ "Not Applicable",
    is_oneway==1 & is_cycle==0            ~ "One Way",
    is_oneway==0                          ~ "Two Way",
    is_oneway==1 & is_cycle==1            ~ "One Way - Two Way Cycling"
  )) %>%
  mutate(elevatn = "ground") %>%
  mutate(maxspeed = round(freespeed * 2.23694)) %>%
  mutate(surface = ifelse(surface=="concrete:lanes","concrete",surface)) %>%
  mutate(surface = ifelse(is.na(surface),"asphalt",surface)) %>%
  mutate(segrgtd = ifelse(cycleway%in%c("separated_lane","bikepath"),"yes","no")) %>%
  mutate(sidewlk = case_when(
    is_car==0               ~ "Not Applicable",
    is_car==1 & (is_walk==1 | is_cycle==1) ~ "both",
    is_car==1 & is_walk==0 & is_cycle==0   ~ "no"
  )) %>%
  mutate(cyclwy_f = case_when(
    is_car==0 | is_cycle==0  ~ "no",
    is_car==1 & is_cycle==1 & cycleway%in%c("separated_lane","bikepath") ~ "track",
    is_car==1 & is_cycle==1 & cycleway=="simple_lane" ~ "lane",
    is_car==1 & is_cycle==1 & !cycleway%in%c("separated_lane","bikepath","simple_lane") ~ "no"
  )) %>%
  mutate(lns_psv_f = 0) %>%
  mutate(lns_no_f = permlanes) %>% 
  mutate(lns_no_b = ifelse(is_oneway==0,lns_no_f,0)) %>% 
  mutate(lns_psv_b = 0) %>%
  mutate(cyclwy_b = cyclwy_f) %>%
  mutate(cyc_wd_f = ifelse(cyclwy_f%in%c("track","lane"),1.25,NA)) %>%
  mutate(cyc_wd_b = cyc_wd_f) %>%
  rename(quitnss=quietness) %>%
  mutate(avg_wdt_md = round(permlanes * (1.976000 + 0.102142*freespeed),3)) %>%
  mutate(avg_wdt_mp=avg_wdt_md) %>%
  mutate(avg_wdt=avg_wdt_md) %>%
  mutate(slope=ifelse(is.na(fwd_slope_pct),0,fwd_slope_pct)) %>% # setting edges with no slope to 0
  mutate(bffrdst=avg_wdt_md/2+20) %>%
  mutate(spedKPH=freespeed*3.6) %>%
  left_join(crossing_count, by="edgeID") %>%
  mutate(cros_rt=crs_cnt/length) %>%
  mutate(bike_rt=bik_cnt/length) %>%
  mutate(RtSrf_m=ifelse(is_walk==1 | is_cycle==1,"all-weather",NA)) %>%
  mutate(cyclesm=ifelse(roadtyp%in%c("Cycleway","Segregated Cycleway")                                      , "offroad"   , NA     )) %>%
  mutate(cyclesm=ifelse(cyclwy_f%in%c("lane","share_busway")                                                , "integrated", cyclesm)) %>%
  mutate(cyclesm=ifelse(highway=="cycleway"                                                                 , "protected" , cyclesm)) %>%
  mutate(cyclesm=ifelse(cyclwy_f=="track"                                                                   , "offroad"   , cyclesm)) %>%
  mutate(cyclesm=ifelse(highway%in%c("track","path") & roadtyp%in%c("Shared Path","Segregated Shared Path") , "integrated", cyclesm)) %>%
  mutate(cyclesm=ifelse(highway%in%c("path","footway") & roadtyp=="Segregated Shared Path"                  , "protected" , cyclesm)) %>%
  mutate(cyclesm=ifelse(roadtyp=="Segregated Cycleway"                                                      , "offroad"   , cyclesm)) %>%
  mutate(cyclesm=ifelse(highway=="cycleway" & roadtyp%in%c("Cycleway","Segregated Cycleway")                , "painted"   , cyclesm)) %>%
  rename(indp_sc=positpoi_score) %>%
  rename(ngp_scr=negpoi_score) %>%
  dplyr::relocate(edgeID,from,to,osm_id,highway,junctn,roadtyp,onwysmm,elevatn,
                  length,maxspeed,surface,segrgtd,sidewlk,cyclwy_f,lns_psv_f,
                  lns_no_f,lns_no_b,lns_psv_b,cyclwy_b,cyc_wd_f,cyc_wd_b,
                  quitnss,avg_wdt_md,avg_wdt_mp,avg_wdt,slope,bffrdst,spedKPH,
                  crs_cnt,cros_rt,bik_cnt,bike_rt,RtSrf_m,cyclesm,highstr,
<<<<<<< HEAD
                  indp_sc,ngp_scr,shannon,simpson) %>%
  mutate(across(c(edgeID,from,to,osm_id,maxspeed,quitnss)))

=======
                  indp_sc,ngp_scr,shannon,simpson)
>>>>>>> 0d75494290f990df2eeffe98b3276ce3711da648

st_write(edges, "./output/edgesMelbourne.gpkg", delete_dsn = T)

# simplify the lines so they go straight between their from and to nodes
edges_direct <- edges %>%
  st_drop_geometry() %>%
  mutate(geom=paste0("LINESTRING(",fromx," ",fromy,",",tox," ",toy,")")) %>%
  st_as_sf(wkt = "geom", crs = 28355)
st_write(edges_direct, "./output/edgesMelbourneDirect.gpkg", delete_dsn = T)





