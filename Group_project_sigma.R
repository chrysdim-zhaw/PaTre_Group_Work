library(jsonlite)
library(dplyr)
library(tidyr)
library(sf)
library(ggplot2)
library(tmap)

# Daten importieren und in DataFrame umwandeln
data3 <- fromJSON("data/Timeline.json", flatten = TRUE)

# Extrahiere rawSignals und bereinige Koordinaten
rawSignals <- data3$rawSignals |> 
  filter(!is.na(position.LatLng)) |>  # Fehlende GPS-Werte entfernen
  separate(position.LatLng, into = c("Latitude", "Longitude"), sep = ", ", convert = TRUE) |> 
  mutate(
    Latitude = as.numeric(str_replace_all(Latitude, "[^0-9.-]", "")),  # Gradzeichen entfernen
    Longitude = as.numeric(str_replace_all(Longitude, "[^0-9.-]", "")),
    position.timestamp = ymd_hms(position.timestamp)  # Timestamp umwandeln
  ) |> 
  filter(!is.na(Longitude) & !is.na(Latitude))  # Fehlgeschlagene Konvertierungen entfernen

# In sf-Objekt mit WGS84 (EPSG:4326) umwandeln
rawSignals_sf <- rawSignals |> 
  st_as_sf(coords = c("Longitude", "Latitude"), crs = 4326) |> 
  st_transform(crs = 2056)  # In CH1903+ LV95 (EPSG:2056) umwandeln


# Interaktive Karte mit tmap
tmap_mode("view")  
tm_shape(rawSignals_sf) + 
  tm_dots(col = "blue", alpha = 0.5, size = 0.3) +
  tm_layout(title = "GPS Tracks (CH1903+ LV95)")


