# libraries and functions -------------------------------------------------

library(sf)
library(dplyr)
library(igraph)

buildDirectedLinks <- function(links,transport_mode=NULL) {
  # if you don't supply a transport mode, then no filtering occurs
  #transport_mode="walk"
  linksFiltered <- links
  if(!is.null(transport_mode)) {
    linksFiltered <- links%>%filter(grepl(transport_mode,modes))
  }
  
  linksDirected<-bind_rows(
    linksFiltered%>%dplyr::select(from=from_id,to=to_id,weight,length),
    linksFiltered%>%filter(is_oneway==0)%>%dplyr::select(from=to_id,to=from_id,weight,length)
  ) %>%
    mutate(link_id=row_number()) %>%
    dplyr::select(from,to,link_id,weight,length)
  
  nodesDirected<-data.frame(
    id=sort(unique(c(linksDirected$from,linksDirected$to)))
  )
  
  return(list(nodesDirected,linksDirected))
}

calculateShortestPaths <- function(network,tripsDF) {
  # network=walkDirected;tripsDF=sampledTrips
  
  # build the graph, making sure the verticies are included
  g <- graph_from_data_frame(d=network[[2]], vertices=network[[1]], directed=TRUE)
  
  outputDF<-NULL
  
  echo(paste0('Starting to process ',nrow(tripsDF),' trips\n'))
  
  for (i in 1:nrow(tripsDF)) {
    from_node=tripsDF[i,1]%>%as.character()
    to_node=tripsDF[i,2]%>%as.character()
    # find the index numbers of each link in the shortest path
    pathIds <- shortest_paths(g, from=from_node, to=to_node, mode="out",
                              output="epath")$epath[[1]]%>%as.integer()
    # use these index numbers to pull out the traversed edges
    pathDF<-network[[2]][pathIds,]
    # find the total length and time
    outputDFcurrent<-data.frame(from_id=from_node,
                                to_id=to_node,
                                length=sum(pathDF$length,na.rm=T),
                                time=sum(pathDF$weight,na.rm=T))
    outputDF <- bind_rows(outputDF,outputDFcurrent)
    echo(paste0('Processed trip ',i,' of ',nrow(tripsDF),' trips\n'))
  }
  return(outputDF)
}



# read in network ---------------------------------------------------------
networkLocation <- "generatedNetworks/MATSimMelbNetwork.sqlite"

nodes <- st_read(networkLocation,layer="nodes",quiet=T)

# We run into trouble if the geometry column is 'geom' instead of 'GEOMETRY'
if('GEOMETRY'%in%colnames(nodes)) nodes <- nodes%>%rename(geom=GEOMETRY)

links <- st_read(networkLocation,layer="links",quiet=T) %>%
  st_drop_geometry() %>%
  dplyr::select(from_id,to_id,is_oneway,length,freespeed,modes)%>%
  mutate(weight=length/freespeed) # weight is travel time

# nodes that are reachable using any mode
routableLinks <- links %>%
  filter(grepl("walk",modes) & grepl("bike",modes) & grepl("car",modes)) %>%
  dplyr::select(from_id,to_id)
routableNodeIds <- unique(c(routableLinks$from_id,routableLinks$to_id))
# routableNodes <- nodes%>%filter(id%in%routableNodeIds)



# select origins and destinations -----------------------------------------
sampleSize=100
set.seed(123)
# we select the from and to nodes here with relace set to false so we never
# double up
sampledNodes<-sample(routableNodeIds,sampleSize*2,replace=FALSE)
sampledTrips<-data.frame(from=sampledNodes[seq(1,sampleSize)],
                         to=sampledNodes[seq(sampleSize+1,sampleSize*2)])



# build graphs ------------------------------------------------------------
walkDirected <- buildDirectedLinks(links,"walk")
bikeDirected <- buildDirectedLinks(links,"bike")
carDirected <- buildDirectedLinks(links,"car")


walkPaths<-calculateShortestPaths(walkDirected,sampledTrips)%>%mutate(mode="walk")
bikePaths<-calculateShortestPaths(bikeDirected,sampledTrips)%>%mutate(mode="bike")
carPaths<-calculateShortestPaths(carDirected,sampledTrips)%>%mutate(mode="car")

# note: the time is based on the freespeed, this means that pedestrians can walk
# at 100km/h if on a highway!




# snap trip nodes to another network --------------------------------------
networkLocation2 <- "generatedNetworks/MATSimMelbNetwork.sqlite"

nodes2 <- st_read(networkLocation2,layer="nodes",quiet=T)

# We run into trouble if the geometry column is 'geom' instead of 'GEOMETRY'
if('GEOMETRY'%in%colnames(nodes2)) nodes2 <- nodes2%>%rename(geom=GEOMETRY)

links <- st_read(networkLocation2,layer="links",quiet=T) %>%
  st_drop_geometry() %>%
  dplyr::select(from_id,to_id,is_oneway,length,freespeed,modes)%>%
  mutate(weight=length/freespeed) # weight is travel time

# the coordinates of the sampled nodes.
sampledNodesGeom <- nodes%>%filter(id%in%sampledNodes)

# find the closest node in the new network
nearestNodeId <- st_nearest_feature(sampledNodesGeom,nodes2)

# subsetting nodes2 and rearranging to match sampledNodesGeom
nearestNode <- nodes2[nearestNodeId,]

nodesMapping <- data.frame(original_id=sampledNodes,
                           new_id=nearestNode$id)
# Use these new ids to rerun calculateShortestPaths 

walkDirected2 <- buildDirectedLinks(links2,"walk")
bikeDirected2 <- buildDirectedLinks(links2,"bike")
carDirected2 <- buildDirectedLinks(links2,"car")

walkPaths<-calculateShortestPaths(walkDirected2,sampledTrips2)%>%mutate(mode="walk")
bikePaths<-calculateShortestPaths(bikeDirected2,sampledTrips2)%>%mutate(mode="bike")
carPaths<-calculateShortestPaths(carDirected2,sampledTrips2)%>%mutate(mode="car")
