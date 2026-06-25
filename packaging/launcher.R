# GenoSuite launcher — started (hidden) by GenoSuite.vbs.
# Points R at the bundled package library, then runs the Shiny app and opens
# the user's default browser.
args <- commandArgs(trailingOnly = TRUE)
base <- if (length(args) >= 1) args[1] else getwd()

lib <- file.path(base, "R", "library")
if (dir.exists(lib)) .libPaths(lib)

library(shiny)
appdir <- file.path(base, "app")
runApp(appdir, launch.browser = TRUE, host = "127.0.0.1")
