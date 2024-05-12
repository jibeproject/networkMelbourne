library(dplyr)
library(readr)
library(tidyverse)
library(sf)

# Define functions -------------------------------------------------------------
# Function to read interventions locations for all layers
read_intervention_data <- function(file_path, layer_name) {
  read_sf(file_path, layer = layer_name)
}

# Function to calculate average weight for each type
calculate_weight_average <- function(data, attribute_column, weight_column, attribute_value) {
  
  # filter the data with trimmed and case-insensitive comparison
  filtered_data <- data %>%
    filter(tolower(trimws(get(attribute_column))) %in% tolower(attribute_value))
  
    # calculate and return the mean of the weight column
    return(mean(filtered_data[[weight_column]], na.rm = TRUE))
}

# Read data --------------------------------------------------------------------
#Baseline data
baseline_weights <- read_sf("output/baseline_weight_totall.gpkg") %>% 
  mutate(attribute = if_else(attribute == "post_office", "post", attribute))

#Intervention data
intervention_types <- c("supermarket", "convenience_store", "restaurant_cafe", 
                        "pharmacy", "post", "gp", "maternal_child_health", 
                        "dentist", "childcare", "kindergarten", "primary", 
                        "community_centre_library", "park", "bus")

intervention_locations <- setNames(vector("list", length(intervention_types)), intervention_types)

for (type in intervention_types) {
  intervention_locations[[type]] <- read_intervention_data("./data/newData/intervention locations.sqlite", type)
}

# Calculate average weight for each type ---------------------------------------
baseline_attributes <- c("supermarket", "convenience_store", "post", 
                         "child care", "kindergarten", "primary", "pharmacy", 
                         "gp", "maternal_child_health", "dentist", "park", "bus")

baseline_weight_averages <- list()

# Loop through baseline_attributes to calculate and store weight averages
for (attr in baseline_attributes) {
  baseline_weight_averages[[attr]] <- calculate_weight_average(
    data = baseline_weights,
    attribute_column = "attribute",
    weight_column = "weight",
    attribute_value = attr
  )
} 

# Calculate the combined average for "cafe" and "restaurant"
cafe_restaurant_average <- calculate_weight_average(
  data = baseline_weights,
  attribute_column = "attribute",
  weight_column = "weight",
  attribute_value = c("cafe", "restaurant")
)

# Calculate the combined average for "community centre" and "library"
community_centre_library_average <- calculate_weight_average(
  data = baseline_weights,
  attribute_column = "attribute",
  weight_column = "weight",
  attribute_value = c("community centre","library")
)

# Add the combined average 
baseline_weight_averages[["restaurant_cafe"]] <- cafe_restaurant_average
baseline_weight_averages[["community_centre_library"]] <- community_centre_library_average 


# Assign the average weight to the intervention locations ----------------------
baseline_average <- data.frame(
  attribute = names(baseline_weight_averages),
  weight_avg = unlist(baseline_weight_averages)
)

# Loop through the list and convert each tibble to a data frame and add the 'weight' column
interventions_added_weight <- lapply(names(intervention_locations), function(name) {
  
  # convert tibble to data frame if not already
  intervention <- as.data.frame(intervention_locations[[name]])
  
  # retrieve the average weight for the current attribute
  weight_average <- baseline_average %>% 
    filter(attribute == name) %>% 
    pull(weight_avg)
  
  # check if weight_average has length greater than 0 (it exists)
  if (length(weight_average) > 0) {
    # add the 'weight' column to the data frame with the found weight
    intervention$weight <-  weight_average
  } else {
    # Add the 'weight' column with NA or some default value if no weight was found
    intervention$weight <- NA 
  }
  
  # Return the updated data frame
  intervention
})

# naming the list of data frames for easier access
names(interventions_added_weight) <- names(intervention_locations)


# write output --------------------------------------------------------------
gpkg_path <- "./output/intervention_weight.gpkg"

lapply(names(interventions_added_weight), function(df_name) {
  st_write(interventions_added_weight[[df_name]], gpkg_path, layer = df_name, append = TRUE, delete_layer = TRUE)
})


