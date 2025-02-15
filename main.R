# Importing required libraries 
library(DBI)
library(fastmap)
library(RSQLite)
library(shiny)
library(shinydashboard)
library(ggplot2)
library(DT)
library(plotly)
library(leaflet)
library(forecast)
library(dplyr)
library(prophet)
library(bslib)
library(viridis)
library(RColorBrewer)
library(scales)

# Connection to database 
connect2DB <- dbConnect(SQLite(), dbname = "data/Supermarket_up.db")

