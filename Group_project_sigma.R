library(jsonlite)
library(dplyr)
library(tidyr)
library(sf)
library(ggplot2)
library(tmap)
library(stringr)
library(lubridate)



# Daten importieren und in DataFrame umwandeln
data3 <- fromJSON("data/Timeline.json", flatten = TRUE)

#Infos über daten erhalen
class(data3$semanticSegments)
class(data3$rawSignals)
class(data3$userLocationProfile)
str(data3$userLocationProfile)

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


# Konvertiere endTime in POSIXct mit korrektem Format
data3$semanticSegments$endTime <- ymd_hms(data3$semanticSegments$endTime, tz = "UTC")
data3$semanticSegments$startTime <- ymd_hms(data3$semanticSegments$startTime, tz = "UTC")

summary(data3$semanticSegments$startTime)
summary(data3$semanticSegments$endTime)


data3$semanticSegments

# Überblick über die Zeitstempel in den rawSignals
summary(as.POSIXct(rawSignals$position.timestamp, format = "%Y-%m-%dT%H:%M:%OS%z"))


data3$rawSignals


# Konvertiere Spalten von rawSignals in POSIXct mit korrektem Format

data3$rawSignals$activityRecord.timestamp <- ymd_hms(data3$rawSignals$activityRecord.timestamp, tz = "UTC")
data3$rawSignals$wifiScan.deliveryTime <- ymd_hms(data3$rawSignals$wifiScan.deliveryTime, tz = "UTC")
data3$rawSignals$position.timestamp <- ymd_hms(data3$rawSignals$position.timestamp, tz = "UTC")

data3$userLocationProfile

# Spaltennamen von semanticSignals anzeigen
colnames(data3$semanticSegments)

# Spaltennamen von rawSignals anzeigen
colnames(data3$rawSignals)
str(data3$rawSignals$activityRecord.probableActivities)


# Spaltennamen von userLocationProfile anzeigen
colnames(data3$userLocationProfile$frequentPlaces)
colnames(data3$userLocationProfile$persona$chainAffinities)
colnames(data3$userLocationProfile$persona$travelModeAffinities)
colnames(data3$userLocationProfile$persona$placeAffinity)



head(data3$rawSignals$position.LatLng)
head(data3$rawSignals$position.timestamp)

# 1. NA-Werte entfernen & Spalten bereinigen
data3$rawSignals <- data3$rawSignals %>%
  filter(!is.na(position.LatLng) & !is.na(position.timestamp)) %>%  # Entferne NA-Werte
  mutate(
    position.timestamp = ymd_hms(position.timestamp, tz = "UTC"),  # Konvertiere Zeitstempel
    Latitude = as.numeric(str_remove(str_extract(position.LatLng, "^[^,]+"), "°")),  # Extrahiere Latitude
    Longitude = as.numeric(str_remove(str_extract(position.LatLng, "[^,]+$"), "°"))  # Extrahiere Longitude
  )

# Prüfe die ersten Zeilen
head(data3$rawSignals[, c("position.timestamp", "Latitude", "Longitude")])


# Erstelle sf-Objekt mit Koordinaten (EPSG 4326 = WGS84)
raw_sf <- data3$rawSignals %>%
  st_as_sf(coords = c("Longitude", "Latitude"), crs = 4326, remove = FALSE) %>%
  arrange(position.timestamp)  # Sortiere nach Zeit

# Funktion zur Distanzberechnung zwischen aufeinanderfolgenden Punkten
distance_by_element <- function(later, now) {
  as.numeric(st_distance(later, now, by_element = TRUE))
}

# Berechne Distanz zwischen aufeinanderfolgenden GPS-Punkten
raw_sf <- raw_sf %>%
  mutate(
    nMinus1 = distance_by_element(lag(geometry, 1), geometry),  # Distanz zur vorherigen Position
    nPlus1  = distance_by_element(geometry, lead(geometry, 1))  # Distanz zur nächsten Position
  )

# Ausgabe der ersten Zeilen mit Distanzen
head(raw_sf[, c("position.timestamp", "nMinus1", "nPlus1")])

# Mittelwert der Schrittweiten berechnen
raw_sf <- raw_sf %>%
  rowwise() %>%
  mutate(stepMean = mean(c(nMinus1, nPlus1), na.rm = TRUE)) %>%
  ungroup()

# Definiere Stillstand als Werte unterhalb des Durchschnitts
raw_sf <- raw_sf %>%
  mutate(static = stepMean < mean(stepMean, na.rm = TRUE))

# Zeige die Anzahl der Stillstands- und Bewegungsmomente
table(raw_sf$static)


ggplot(raw_sf, aes(Longitude, Latitude, color = static)) +
  geom_point(size = 2) +
  geom_path() +
  coord_fixed() +
  labs(title = "Bewegungsmuster", color = "Stillstand") +
  theme_minimal()


library(zoo)

raw_sf <- raw_sf %>%
  mutate(
    stepMean5min = rollmean(stepMean, k = 5, fill = NA, align = "center"),
    stepMean10min = rollmean(stepMean, k = 10, fill = NA, align = "center")
  )


ggplot(raw_sf, aes(Longitude, Latitude, color = static)) +
  geom_point(size = 2) +
  geom_path() +
  coord_fixed() +
  labs(title = "Bewegungsmuster", color = "Stillstand") +
  theme_minimal()
