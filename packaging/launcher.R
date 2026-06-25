# GenoSuite launcher — started (hidden) by GenoSuite.vbs.
# Points R at the bundled package library, runs the Shiny app, and opens it in a
# chrome-less application window (Edge/Chrome --app mode) so it feels like a
# native desktop app rather than a browser tab. Falls back to the default
# browser if neither is found.
args <- commandArgs(trailingOnly = TRUE)
base <- if (length(args) >= 1) args[1] else getwd()

lib <- file.path(base, "R", "library")
if (dir.exists(lib)) .libPaths(lib)

library(shiny)

open_app_window <- function(url) {
  pf   <- Sys.getenv("ProgramFiles")
  pf86 <- Sys.getenv("ProgramFiles(x86)")
  candidates <- c(
    file.path(pf86, "Microsoft", "Edge", "Application", "msedge.exe"),
    file.path(pf,   "Microsoft", "Edge", "Application", "msedge.exe"),
    file.path(pf,   "Google", "Chrome", "Application", "chrome.exe"),
    file.path(pf86, "Google", "Chrome", "Application", "chrome.exe")
  )
  browser <- candidates[file.exists(candidates)]
  if (length(browser) == 0) { utils::browseURL(url); return(invisible()) }
  try(system2(browser[1],
              args = c(sprintf("--app=%s", url), "--window-size=1280,860"),
              wait = FALSE), silent = TRUE)
}

appdir <- file.path(base, "app")
runApp(appdir, launch.browser = open_app_window, host = "127.0.0.1")
