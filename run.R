source("main.R")
source("ui.R")
source("server.R")

rstudioapi::jobRunScript("server.R")

shiny::shinyApp(ui = ui, server = server)