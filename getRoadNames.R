#!/usr/bin/env Rscript

# load libraries and functions --------------------------------------------
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(tidyr))
suppressPackageStartupMessages(library(data.table))
suppressPackageStartupMessages(library(sf))
options(dplyr.summarise.inform = FALSE) # make dplyr stop blabbing about summarise

# returnStreetname <- function(tags) {
#   # tags <- network$other_tags[1]
#   tagList <- strsplit(gsub('=>',',', gsub('"', '', tags)),',')%>%unlist()
#   streetname <- tagList[which(tagList %like% "addr:street")+1] %>%
#     first() %>%
#     unname()
#   streetname <- as.character(streetname)
#   return(streetname)
# }
# returnStreetname <- Vectorize(returnStreetname)
# 
# # Reading inputs
# network = st_read("network/data/victoriaOSM.sqlite", layer="lines") %>%
#   st_drop_geometry() %>%
#   filter(other_tags %like% "addr:street") %>%
#   mutate(streetname=returnStreetname(other_tags)) %>%
#   dplyr::select(osm_id,streetname) %>%
#   distinct()

# Reading inputs
network = st_read("network/data/victoriaOSM.sqlite", layer="lines") %>%
  st_drop_geometry() %>%
  filter(!is.na(name)) %>%
  dplyr::select(osm_id,streetname=name) %>%
  distinct()



#saving the streetnames and osm ids
saveRDS(network,"data/network_streetnames.rds")


