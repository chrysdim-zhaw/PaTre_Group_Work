library("readr")
library("sf")
library(tidyr)
library(dplyr)

#1. 

wildschwein_BE <- read_delim("data/wildschwein_BE_2056.csv", ",")

wildschwein_BE <- st_as_sf(wildschwein_BE, coords = c("E", "N"), crs = 2056)


difftime_secs <- function(later, now){
  as.numeric(difftime(later, now, units = "secs"))
}


wildschwein_BE <- wildschwein_BE |> 
  group_by(TierID) |> 
  mutate(
    timelag = difftime_secs(lead(DatetimeUTC), DatetimeUTC)
  )

#2. Questions
  #1. How many individuals were tracked?
  #2. For how long were the individual tracked? Are there gaps?
  #3. Were all individuals tracked concurrently or sequentially?
  #4. What is the temporal sampling interval between the locations?

#2.1. 
length(unique(wildschwein_BE$TierID))

#2.2. 

anfang <- wildschwein_BE |> 
  group_by(TierID) |> 
  summarise(
    anfang = min(DatetimeUTC)
  )

start_tier1 <- anfang$anfang[1]
start_tier2 <- anfang$anfang[2]
start_tier3 <- anfang$anfang[3]

ende <- wildschwein_BE |> 
  group_by(TierID) |> 
  summarise(
    ende = max(DatetimeUTC)
  )
ende_tier1 <- ende$ende[1]
ende_tier2 <- ende$ende[2]
ende_tier3 <- ende$ende[3]


timefiff_tier1 <- difftime(ende_tier1, start_tier1)
timefiff_tier2 <- difftime(ende_tier2, start_tier2)
timefiff_tier3 <- difftime(ende_tier3, start_tier3)

wildschwein_BE |>                                            
  group_by(TierID) |>                                   
  mutate(
    timelag = difftime_secs(lead(DatetimeUTC), DatetimeUTC)
  )

wildschwein_BE[is.na(wildschwein_BE$timelag), ]

#2.3. 

start_tier1
start_tier2
start_tier3

#Tier 2 und 3 starteten am gleichen Tag. Tier 1 davor

ende_tier1
ende_tier2
ende_tier3

#Tier 1 und 3 endeten am gleichen tag, tier 2 davor. 

#2.4.

#Tiername Sabi Timelag während des Tages 3h während der Nacht 15 Minuten
#Tiername Rosa Timelag meistens 15 Min Takt. 
#Tiername Ruth Timelag während des Tages 3h und während der Nacht jede Stunde. 


#3. 

later <- lag(wildschwein_BE$geometry)
now <- wildschwein_BE$geometry

st_distance(later, now, by_element = TRUE)  # by_element must be set to TRUE

distance_by_element <- function(later, now){
  as.numeric(
    st_distance(later, now, by_element = TRUE)
  )
}

wildschwein_BE <- wildschwein_BE |> 
  mutate(
    steplength = distance_by_element(lead(geometry), geometry)
  )



wildschwein_BE <- wildschwein_BE |> 
  mutate(
    speed = (steplength/timelag)
  )


#5. 

wildschwein_sample <- wildschwein_BE |>
  filter(TierName == "Sabi") |> 
  head(100)


library(tmap)
tmap_mode("view")

tm_shape(wildschwein_sample) + 
  tm_dots()

wildschwein_sample_line <- wildschwein_sample |> 
  # dissolve to a MULTIPOINT:
  summarise(do_union = FALSE) |> 
  st_cast("LINESTRING")


tm_shape(wildschwein_sample_line) +
  tm_lines() +
  tm_shape(wildschwein_sample) +  
  tm_basemap("OpenStreetMap") +
  tm_dots()
