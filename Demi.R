now <- as.POSIXct("2024-04-26 10:20:00")
later <- as.POSIXct("2024-04-26 11:35:00")

later

time_diference <- difftime(later, now, unit = "mins")
