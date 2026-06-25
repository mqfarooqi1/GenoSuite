suppressMessages({library(shiny); library(bslib); library(DT); library(ggplot2)})
cat("packages: DT", requireNamespace("DT", quietly = TRUE),
    "ape", requireNamespace("ape", quietly = TRUE),
    "vegan", requireNamespace("vegan", quietly = TRUE), "\n")

invisible(parse("app/app.R")); cat("PARSE OK\n")
source("app/app.R", local = TRUE); cat("SOURCE OK; ui class:", class(ui)[1], "\n")

df <- simulate_demo(); cat("demo dims:", dim(df), "\n")
X <- numeric_matrix(df, "ID", "Population"); cat("marker matrix:", dim(X), "\n")
for (mt in c("euclidean", "manhattan", "correlation", "jaccard", "gower")) {
  d <- compute_distance(X, mt); cat(sprintf("  dist %-12s size=%d ok\n", mt, length(d)))
}
d  <- compute_distance(X, "euclidean")
hc <- hclust(d, "average");      cat("hclust OK\n")
nj <- ape::nj(d);                cat("nj tips:", length(nj$tip.label), "\n")
cm <- cmdscale(d, k = 2, eig = TRUE); cat("PCoA dims:", dim(cm$points), "\n")
pr <- prcomp(X);                 cat("PCA PCs:", ncol(pr$x), "\n")
mr <- vegan::mantel(compute_distance(X, "euclidean"),
                    compute_distance(X, "manhattan"), permutations = 99)
cat("mantel r:", round(mr$statistic, 3), " p:", mr$signif, "\n")
cat("ALL SMOKE TESTS PASSED\n")
