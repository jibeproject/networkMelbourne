# function to add level of traffic stress to network, based on cycleway category,
# highway class, traffic (ADT) and speed, and related impedance

# this function is based on a 4-category LTS level that is derived (with some
# simplification) from a Victorian DTP publication, Victorian Department of Transport 2020, 
# Cycling Level of Traffic Stress Methodology, Melbourne.

# traffic volumes (eg ADT 10000) are for two-way traffic, so are halved
# (eg 10000 / 2) in order to apply to the one-way links in edges.for.LTS



# functions for adding LTS ----
# -------------------------------------#
# function to convert edges to all one way, and join traffic volumes
makeOnewayTraffic <- function(input.edges, edges.traffic) {
  
  # remove public transport and take fields required for LTS 
  edges.for.LTS <- input.edges %>%
    filter(!highway %in% c("train", "tram", "bus")) %>%
    dplyr::select(edgeID, from, to, is_oneway, cycleway, highway, freespeed, length)
  
  # select only two-way edges, and reverse their details
  edges.twoway.reversed <- edges.for.LTS %>%
    filter(is_oneway == FALSE) %>%
    # store original from/to details
    mutate(orig_from = from,
           orig_to = to) %>%
    # swap from/to
    mutate(from = orig_to,
           to = orig_from) %>%
    # remove the original details
    dplyr::select(-orig_from, -orig_to)
  
  # add 'out' or 'rtn' to the edgeIDs
  edges.for.LTS <- edges.for.LTS %>%
    mutate(linkID = paste0(edgeID, "out"))
  edges.twoway.reversed <- edges.twoway.reversed %>%
    mutate(linkID = paste0(edgeID, "rtn"))
  
  # combine with two-way reversed edges, and add traffic
  edges.for.LTS <- rbind(edges.for.LTS,
                         edges.twoway.reversed) %>%
    left_join(edges.traffic %>%
                st_drop_geometry() %>%
                dplyr::select(linkID, aadt, aadtFwd, aadtFwd_car, aadtFwd_truck),
              by = "linkID")
  
  return(edges.for.LTS)
}

# function to calculate LTS and related impedances
calculateLTS <- function(edges.for.LTS, input.nodes) {
  
  # assign LTS to edges 
  # '1' to '4' are categories of increasing stress, as per table below]
  
  # road groups
  local <- c("residential", "road", "unclassified", "living_street", "service")
  tertiary <- c("tertiary", "tertiary_link")
  secondary <- c("secondary", "secondary_link")
  primary <- c("primary", "primary_link")
  
  edges.with.LTS <- edges.for.LTS %>%
    
    # make speed field (rounded, to avoid floating point issues)
    mutate(speed = round(freespeed * 3.6)) %>%
    # complete any NA traffic as 0
    mutate(ADT = ifelse(is.na(aadtFwd), 0, aadtFwd)) %>%
    
    # add LTS 
    mutate(LTS = case_when(
      
      # LTS 1 - off-road paths
      cycleway %in% c("bikepath", "shared_path")                   ~ 1,
      highway %in% c("cycleway", "track", "pedestrian", 
                     "footway", "path", "corridor", "steps")       ~ 1,
      
      # LTS 1 - separated cycle lanes
      cycleway == "separated_lane" & speed <= 50                   ~ 1,
      
      # LTS 1 - on-road cycle lanes
      cycleway == "simple_lane" & 
        highway %in% c(local, tertiary, secondary) &
        ADT <= 10000 /2 & speed <= 30                              ~ 1,
      
      # LTS 1 - mixed traffic
      highway %in% local & ADT <= 2000 / 2 & speed <= 30           ~ 1,
      
      # LTS 2 - separated cycle lanes
      cycleway == "separated_lane" & speed <= 60                   ~ 2,
      
      # LTS 2 - on-road cycle lanes
      cycleway == "simple_lane" &
        highway %in% c(local, tertiary, secondary) &
        ADT <= 10000 / 2 & speed <= 50                             ~ 2,
      cycleway == "simple_lane" &
        (highway %in% primary | 
           (highway %in% c(local, tertiary, secondary) & 
              ADT > 10000 / 2)) & speed <= 40                      ~ 2,
      
      # LTS 2 - mixed traffic
      highway %in% local & ADT <= 750 / 2 & speed <= 50            ~ 2,
      highway %in% local & ADT <= 2000 / 2 & speed <= 40           ~ 2,
      highway %in% c(local, tertiary) & 
        ADT <= 3000 / 2 & speed <= 30                              ~ 2,
      
      # LTS 3 - on-road cycle lanes
      cycleway == "simple_lane" & speed <= 60                      ~ 3,
      
      # LTS 3 - mixed traffic
      highway %in% local & ADT <= 750 / 2 & speed <= 60            ~ 3,
      highway %in% c(local, tertiary) & 
        ADT <= 3000 / 2 & speed <= 50                              ~ 3,
      (highway %in% c(secondary, primary) |
         (highway %in% c(local, tertiary) & ADT > 3000 / 2)) &
        speed <= 40                                                ~ 3,
      
      # LTS 4 - everything not covered above
      TRUE                                                         ~ 4
    ))
  
  # #check to test how many in each category
  # LTS_table <- edges.for.LTS %>%
  #   st_drop_geometry() %>%
  #   group_by(highway, LTS) %>%
  #   summarise(n = n())
  
  # assign LTS to nodes, based on highest 
  # begin with all nodes (from and to) and the LTS level of the associated link
  node_max_lookup <- rbind(edges.with.LTS %>%
                             st_drop_geometry() %>%
                             dplyr::select(id = from, LTS),
                           edges.with.LTS %>%
                             st_drop_geometry() %>%
                             dplyr::select(id = to, LTS)) %>%
    group_by(id) %>%
    # find highest level of LTS for links connecting with the node
    summarise(max_LTS = max(LTS)) %>%
    ungroup()
  
  # Calculate impedance  for intersection, and total impedance
  
  # Impedance for intersection applies to the to-node (the intersection
  # that the link arrives at), and only if it's unsignalised
  # penalty is calculated as: 
  #     penaltya = (Buffb – Buffa) * (IFb – 1)for
  # where 
  #   a is the link for which the penalty (penaltya) is being calculated
  #   b is the highest-ranked other link at the relevant intersection
  #   Buffa and Buffb are the buffer distances for a and b, where the buffer 
  #     distance is 0, 5, 10 or 25m for a link of LTS 1, 2, 3 or 4 respectively
  #   IFb is the impedance factor for b, where the impedance factor is 1.00, 
  #     1.05, 1.10 or 1.15 for a link of LTS 1, 2, 3 or 4 respectively
  
  # LTS impedance, which is to be added to the length of the link and any other 
  # impedances (outside this function) to create the weight for the link,
  # is the length-based impedance for the link plus its intersection impedance.
  # - Length-based impedance is the link multiplied by its impedance factor
  #   minus 1 (that is, subtracting 1 so it os only the additional impedance,
  #   not the length itself:
  #     total_imped = length * (IFa - 1)
  #   where IFa is the impedance factor for a, where the impedance factor is 1.00, 
  #   1.05, 1.10 or 1.15 for a link of LTS 1, 2, 3 or 4 respectively
  # - Intersection impedance is calculated as above
  
  buff_imped_df <- data.frame(cbind(LTS = c(1, 2, 3, 4),
                                    buffer = c(0, 5, 10, 25),
                                    imped = c(1, 1.05, 1.10, 1.15)))
  
  edges.with.LTS <- edges.with.LTS %>%
    # join node intersection details for the to-node
    left_join(., input.nodes %>%
                st_drop_geometry() %>%
                dplyr::select(nodeID, ped_cros),
              by = c("to" = "nodeID")) %>%
    # join the node max LTS buffer & impedance details for the to-node 
    left_join(., node_max_lookup, by = c("to" = "id")) %>%
    left_join(., buff_imped_df, by = "LTS") %>%
    # and the buff_imped_df details for the max LTS
    left_join(., buff_imped_df, by = c("max_LTS" = "LTS"), suffix = c(".a", ".b")) %>%
    
    # calculate link imped (length * relevant factor); intersection impedance, 
    # using formula above (unsignalised only); and total
    mutate(LTS_link_imped = length * (imped.a - 1),
           LTS_isec_imped = ifelse(!is.na(ped_cros) & ped_cros == "Car signal",
                                   0,
                                   (buffer.b - buffer.a) * (imped.b - 1)),
           LTS_total_imped = LTS_link_imped + LTS_isec_imped) %>%
    # remove unwanted fields
    dplyr::select(-speed, -ped_cros, -max_LTS, -buffer.a, -buffer.b, 
                  -imped.a, -imped.b)
  
  return(edges.with.LTS)
}


# adding LTS ----
# -------------------------------------#
# packages
library(dplyr)
library(sf)
library(stringr)

# read input file
input.nodes <- st_read("./data/nodesMelbourne.gpkg")
input.edges <- st_read("./data/edgesMelbourne_VGVI.gpkg")
edges.traffic <- st_read("./data/network2way.gpkg")

# make input edges one-way, and join traffic
edges.for.LTS <- makeOnewayTraffic(input.edges, edges.traffic)

# calculate LTS
edges.with.LTS <- calculateLTS(edges.for.LTS, input.nodes)

# join LTS to input network
output.edges <- edges.traffic %>%
  left_join(edges.with.LTS %>%
              st_drop_geometry() %>%
              dplyr::select(linkID, LTS, LTS_link_imped,
                            LTS_isec_imped, LTS_total_imped),
            by = "linkID")

# write output
st_write(output.edges, "./output/network2way_LTS.gpkg", delete_layer = T) 
