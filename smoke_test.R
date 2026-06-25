suppressMessages({
  library(shiny); library(bslib); library(DT); library(ggplot2); library(GSbench)
})
cat("packages: DT", requireNamespace("DT", quietly = TRUE),
    "ape", requireNamespace("ape", quietly = TRUE),
    "vegan", requireNamespace("vegan", quietly = TRUE),
    "glmnet", requireNamespace("glmnet", quietly = TRUE),
    "ranger", requireNamespace("ranger", quietly = TRUE),
    "xgboost", requireNamespace("xgboost", quietly = TRUE), "\n")

invisible(parse("app/app.R")); cat("PARSE OK\n")
source("app/app.R", local = TRUE); cat("SOURCE OK; ui class:", class(ui)[1], "\n")

df <- simulate_demo(); cat("demo dims:", dim(df), " cols:", paste(head(names(df), 4), collapse = ","), "...\n")
X  <- numeric_matrix(df, "ID", "Population", "Trait"); cat("marker matrix:", dim(X), "\n")
y  <- df$Trait

# core (phase 1)
for (mt in names(DIST_CHOICES)) {
  d <- compute_distance(X, DIST_CHOICES[[mt]]); stopifnot(length(d) == choose(nrow(X), 2))
}
cat("distances OK; nj tips:", length(ape::nj(compute_distance(X, "euclidean"))$tip.label), "\n")

# diversity
dv <- diversity_stats(X); cat("diversity rows:", nrow(dv), " mean He:", round(mean(dv$He), 3), "\n")
fs <- fst_nei(X, df$Population); cat("Fst rows:", nrow(fs), " overall Fst:", round(mean(fs$Fst, na.rm = TRUE), 3), "\n")

# gwas
gw <- gwas_scan(y, X, n_pc = 2)
cat("gwas rows:", nrow(gw), " top -log10p:", round(max(gw$logp, na.rm = TRUE), 2), "\n")

# prediction (all models)
cv <- gs_cv(y, X, models = available_models(), k = 5, seed = 1)
cat("CV models:\n"); print(round_df(as.data.frame(summary(cv))))
gb <- gblup(y, geno = X)
cat("GBLUP h2:", round(gb$h2, 3), " gebv length:", length(gb$gebv), "\n")

# kinship / GRM
G <- GSbench::Gmatrix(X, min_maf = 0.05)
cat("GRM dims:", dim(G), " mean diag:", round(mean(diag(G)), 3), "\n")

# linkage disequilibrium
Xs <- X[, apply(X, 2, stats::sd) > 0, drop = FALSE]
r2 <- cor(Xs)^2
cat("LD r2 dims:", dim(r2), " mean off-diag r2:", round(mean(r2[upper.tri(r2)]), 3), "\n")

# excel support
cat("readxl available:", requireNamespace("readxl", quietly = TRUE), "\n")

cat("ALL SMOKE TESTS PASSED\n")
