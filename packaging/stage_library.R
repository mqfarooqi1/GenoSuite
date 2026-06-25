# Copy the app's package dependencies (recursive) into the bundled R library.
# Base/recommended packages already ship inside the copied R installation.
# Usage:  Rscript stage_library.R <dist_dir>
args   <- commandArgs(trailingOnly = TRUE)
dist   <- args[1]
target <- file.path(dist, "R", "library")

direct <- c("shiny", "bslib", "DT", "ggplot2", "ape", "vegan",
            "GSbench", "glmnet", "ranger", "xgboost", "rrBLUP")

ip   <- installed.packages()
deps <- tools::package_dependencies(direct, db = ip,
                                    which = c("Depends", "Imports", "LinkingTo"),
                                    recursive = TRUE)
need <- unique(c(direct, unlist(deps, use.names = FALSE)))

have    <- list.dirs(target, recursive = FALSE, full.names = FALSE)
missing <- setdiff(need, have)

copied <- character(0); notfound <- character(0)
for (p in missing) {
  loc <- tryCatch(find.package(p), error = function(e) NA_character_)
  if (!is.na(loc) && dir.exists(loc)) {
    file.copy(loc, target, recursive = TRUE)
    copied <- c(copied, p)
  } else {
    notfound <- c(notfound, p)
  }
}

cat("Bundled library:", length(list.dirs(target, recursive = FALSE)), "packages\n")
cat("Copied", length(copied), "dependency packages\n")
if (length(notfound)) cat("NOT FOUND (check):", paste(notfound, collapse = ", "), "\n")
