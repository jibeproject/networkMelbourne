# nodes_current <-combinedUndirectedAndDirected2[[1]]
# edges_current <-combinedUndirectedAndDirected2[[2]]
makeEdgesDirect <- function(nodes_current,edges_current){
  
  # nodes_coords <- nodes_current %>%
  #   st_drop_geometry() %>%
  #   cbind(st_coordinates(nodes_current))
  
  # simplify the lines so they go straight between their from and to nodes
  edges_current <- edges_current %>%
    filter(!is.na(from_id)) %>%
    st_drop_geometry() %>%
    left_join(st_drop_geometry(nodes_current),by=c("from_id"="id")) %>%
    rename(fromX=X,fromY=Y) %>%
    left_join(st_drop_geometry(nodes_current),by=c("to_id"="id")) %>%
    rename(toX=X,toY=Y) %>%
    mutate(geom=paste0("LINESTRING(",fromX," ",fromY,",",toX," ",toY,")")) %>%
    st_as_sf(wkt = "geom", crs = 28355)
  return(list(nodes_current,edges_current))
}


# nodes_current <-combinedUndirectedAndDirected2[[1]]
# edges_current <-combinedUndirectedAndDirected2[[2]]
makeEdgesUnDirect <- function(nodes_current,edges_current){
  
  # nodes_coords <- nodes_current %>%
  #   st_drop_geometry() %>%
  #   cbind(st_coordinates(nodes_current))
  
  # simplify the lines so they go straight between their from and to nodes
  edges_current <- edges_current %>%
    filter(!is.na(from_id)) %>%
    left_join(st_drop_geometry(nodes_current),by=c("from_id"="id")) %>%
    rename(fromX=X,fromY=Y) %>%
    left_join(st_drop_geometry(nodes_current),by=c("to_id"="id")) %>%
    rename(toX=X,toY=Y)
  return(list(nodes_current,edges_current))
}


makeEdgesDirect2 <- function(nodes_current,edges_current){
  
  # nodes_coords <- nodes_current %>%
  #   st_drop_geometry() %>%
  #   cbind(st_coordinates(nodes_current))
  
  # simplify the lines so they go straight between their from and to nodes
  edges_current <- edges_current %>%
    st_drop_geometry() %>%
    mutate(geom=paste0("LINESTRING(",fromX," ",fromY,",",toX," ",toY,")")) %>%
    st_as_sf(wkt = "geom", crs = 28355)
  return(list(nodes_current,edges_current))
}