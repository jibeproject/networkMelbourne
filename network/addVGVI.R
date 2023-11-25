#SET UP
rm(list = ls())

library(terra)
library(sfheaders)
library(sf)
install.packages("remotes")
if (!require("remotes")) install.packages("remotes")
library(remotes)
install.packages("glue")
if (!require("qgisprocess")) install.packages("qgisprocess")
library(qgisprocess)

remotes::install_git("https://github.com/STBrinkmann/GVI")
install.packages("GVI", dependencies = TRUE)
library(GVI)


######################################
#PART 1: get VGVI
######################################

setwd("")

#read network
osm <- st_read(file.path("~/edgesMelbourneDirect.gpkg"))

#Input greenness and DEM data
DSM <- rast("~/VGVI_input/dsm_10_RE.tif")

DEM <- rast("~/VGVI_input/clipped_dem_re.tif")

Green <- rast("~/VGVI_input/Green.tif")
crs(Green) <- "epsg:28355" #change coordinate ref system

#Take point sample on master map at certain distance and start/end offset
pointsonedge <- st_line_sample(osm, density = 1/20, n = 1, type = "regular", sample = NULL) #each 20m, at least 1 point
pointson <- st_sf(as.data.frame(osm), pointsonedge)
pointson <- st_cast(pointson, "POINT")
pointson <- st_as_sf(pointson)

pVGVI <- vgvi_from_sf(observer = pointson,
                      dsm_rast = DSM, dtm_rast = DEM, greenspace_rast = Green,
                      max_distance = 300, observer_height = 1.7,
                      m = 0.5, b = 8, mode = "logit", cores = 3, progress = T)

rm(DEM, DSM, Green, pointsonedge, pointson)

pVGVIbuffer <- st_buffer(pVGVI, dist = 0.5)

rm(pVGVI)

######################################
#PART 2: attach to OSM
######################################

joinVGVIlines <- qgis_run_algorithm(
  "qgis:joinbylocationsummary",
  DISCARD_NONMATCHING = F,
  INPUT = osm,
  JOIN = pVGVIbuffer,
  SUMMARIES = "mean", # 10 is for majority, 7 for median
  JOIN_FIELDS = 'VGVI' #the column to join the attribute
)

joinVGVIlines_sf <- sf::read_sf(qgis_output(joinVGVIlines, "OUTPUT"))

joinVGVIlines_sf_osm <- joinVGVIlines_sf %>% st_drop_geometry() %>% dplyr::select(edgeID, VGVI_mean)

osm <- merge(osm, joinVGVIlines_sf_osm, by = 'edgeID')

st_write(osm, file.path(paste("edge_data/edgesMelbourneDirect_vgvi.gpkg")), driver="GPKG")
