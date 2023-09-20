library(sf)
library(dplyr)
library(igraph)

# Because we need to generate the network for all of Victoria, it is necessary
# to clip the network to the study region. We do so by finding all edges with an
# endpoint within the study region, and then finding the largest connected
# component in order to remove any disconnected components arising from the clip

# finds the largest connected component
largestConnectedComponent <- function(n_df,l_df){
  l_df_no_geom <- l_df %>%
    st_drop_geometry() %>%
    dplyr::select(from=from_id,to=to_id)
  # remove the disconnected bits
  
  # Making the graph for the intersections
  g <- graph_from_data_frame(l_df_no_geom, directed = FALSE) 

  # Getting components
  comp <- components(g)
  nodes_in_largest_component <- data.frame(node_id=as.integer(names(comp$membership)),
                                           cluster_id=comp$membership, row.names=NULL) %>%
    filter(cluster_id==which.max(comp$csize)) %>%
    pull(node_id) %>%
    base::unique()
  
  n_df_filtered <- n_df %>%
    filter(id%in%nodes_in_largest_component) 
  
  l_df_filtered <- l_df %>%
    filter(from_id%in%nodes_in_largest_component & to_id%in%nodes_in_largest_component)
  
  return(list(n_df_filtered,l_df_filtered))
}


study_region <- st_read("data/region_buffer.sqlite")
nodes <- st_read("network/output/networkJIBE/network.sqlite", layer="nodes")
edges <- st_read("network/output/networkJIBE/network.sqlite", layer="links")

# nodes within the study region
nodes_clipped <- nodes %>%
  filter(lengths(st_intersects(., study_region, prepared = TRUE)) > 0)
node_ids <- nodes_clipped$id

# roads that trucks can use
truck_roads <- c("motorway", "motorway_link", "trunk", "trunk_link",
                 "primary", "primary_link", "secondary", "secondary_link",
                 "tertiary", "tertiary_link")

# edges that allow trucks
edges_trucks <- edges %>%
  mutate(is_truck = ifelse(highway%in%truck_roads,1,0) & is_car == 1) %>%
  dplyr::relocate(is_truck,.after=is_car) %>%
  mutate(modes=ifelse(is_truck==1,paste0(modes,",truck"),modes))

# edges that allow trucks or have at least one endpoint within the study region
edges_filtered <- edges_trucks %>%
  filter(is_truck==1 | from_id %in% node_ids | to_id %in% node_ids)



# endpoint nodes of these edges
nodes_filtered <- nodes %>%
  filter(id %in% c(edges_filtered$from_id, edges_filtered$to_id))

# filter nodes and edges to largest connected component
largest_component <- largestConnectedComponent(nodes_filtered,edges_filtered)

# export to file
nodes_final <- largest_component[[1]]
edges_final <- largest_component[[2]]
st_write(nodes_final, "data/melbourneClipped_nodes.sqlite", delete_dsn=T)
st_write(edges_final, "data/melbourneClipped_edges.sqlite", delete_dsn=T)
