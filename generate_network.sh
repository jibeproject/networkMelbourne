# 1. Cloning repositories

## make the directories
mkdir -p ~/Projects/JIBE
mkdir -p ~/Projects/matsim-melbourne

## clone the repositories
cd ~/Projects/JIBE
git clone git@github.com:jibeproject/networkMelbourne
cd ~/Projects/matsim-melbourne
git clone git@github.com:matsim-melbourne/network

## copy the files needed into the AToM network
cp "/Users/alan/Projects/JIBE/networkMelbourne/network/processOSM_JIBE.sh" \
   "/Users/alan/Projects/matsim-melbourne/network/processOSM_JIBE.sh"
cp "/Users/alan/Projects/JIBE/networkMelbourne/network/NetworkGenerator_JIBE.R" \
   "/Users/alan/Projects/matsim-melbourne/network/NetworkGenerator_JIBE.R"
cp "/Users/alan/Projects/JIBE/melbourne/dem/original/DEMx10EPSG28355.tif" \
   "/Users/alan/Projects/matsim-melbourne/network/data/DEMx10EPSG28355.tif"

# 2. Running the AToM network:

## clip OSM to victoria
ogr2ogr -f SQLite -clipsrc \
  "/Users/alan/Projects/JIBE/melbourne/regions/original/victoria.sqlite" \
  "/Users/alan/Projects/JIBE/melbourne/osm/final/victoriaOSM.sqlite" \
  "/Users/alan/Projects/JIBE/melbourne/osm/original/australia-190101.osm.pbf"

## processing the osm data into an unconfigured network (i.e., making it noded/routable)
cd "/Users/alan/Projects/matsim-melbourne/network"
"/Users/alan/Projects/matsim-melbourne/network/processOSM_JIBE.sh" \
  "/Users/alan/Projects/JIBE/melbourne/osm/final/victoriaOSM.sqlite" \
  28355 \
  "/Users/alan/Projects/JIBE/melbourne/network/intermediate/unconfigured_network/network_victoria.sqlite"

## Process unconfigured network into AToM network
Rscript "/Users/alan/Projects/matsim-melbourne/network/NetworkGenerator_JIBE.R"

## Move output network into correct directories
cp "/Users/alan/Projects/JIBE/networkMelbourne/network/output/networkJIBE/network.sqlite" \
   "/Users/alan/Projects/JIBE/melbourne/network/intermediate/atom_network/network.sqlite"

cp "/Users/alan/Projects/JIBE/networkMelbourne/network/output/networkJIBE/gtfs" \ 
   "/Users/alan/Projects/JIBE/melbourne/network/intermediate/atom_network/gtfs"


# 3. Running the JIBE network

## clip the Victoria-wide network to our study region (Greater Melbourne plus a 10km buffer). We do so by finding all edges with an endpoint within the study region, and then finding the largest connected component in order to remove any disconnected components arising from the clip. 
cd "/Users/alan/Projects/JIBE/networkMelbourne"
Rscript "/Users/alan/Projects/JIBE/networkMelbourne/clipNetwork.R"

## Run processNetwork.R to calculate quietness, positive and negative POIs, whether an edge is part of a highstreet, and Shannon diversity. Main difference from the Manchester code is the edge snapping takes place in postgres. This has sped up the process from several days to around 30 seconds.
Rscript "/Users/alan/Projects/JIBE/networkMelbourne/processNetwork.R"

## Run adjustNetwork.R to perform the final tweaking to ensure the Melbourne network's attributes are compatible with the Manchester network.
Rscript "/Users/alan/Projects/JIBE/networkMelbourne/adjustNetwork.R"