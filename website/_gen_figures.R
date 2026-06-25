# Generate example figures for the website from the demo dataset.
# Run from the repository root:  Rscript website/_gen_figures.R
suppressMessages({library(ggplot2); library(GSbench)})
source("app/app.R", local = TRUE)

img <- "website/images"
dir.create(img, showWarnings = FALSE, recursive = TRUE)

df <- simulate_demo()
X  <- numeric_matrix(df, "ID", "Population", "Trait"); rownames(X) <- df$ID
g  <- factor(df$Population); y <- df$Trait

# 1. PCA
pr <- prcomp(X); ve <- pr$sdev^2 / sum(pr$sdev^2)
ggsave(file.path(img, "pca.png"),
  ggplot(data.frame(PC1 = pr$x[, 1], PC2 = pr$x[, 2], Population = g),
         aes(PC1, PC2, colour = Population)) +
    geom_point(size = 3, alpha = .85) +
    scale_colour_viridis_d(option = "D", end = .85) +
    labs(x = sprintf("PC1 (%.1f%%)", 100 * ve[1]),
         y = sprintf("PC2 (%.1f%%)", 100 * ve[2])) +
    theme_minimal(base_size = 13),
  width = 6, height = 4.2, dpi = 130)

# 2. NJ tree
d <- compute_distance(X, "euclidean"); nj <- ape::nj(d)
pal <- grDevices::hcl.colors(nlevels(g), "Dark 3")
tipcol <- pal[as.integer(g)][match(nj$tip.label, rownames(as.matrix(d)))]
png(file.path(img, "tree.png"), width = 800, height = 560, res = 110)
ape::plot.phylo(nj, type = "unrooted", cex = .7, tip.color = tipcol,
                lab4ut = "axial", no.margin = TRUE)
dev.off()

# 3. Manhattan
gw <- gwas_scan(y, X, n_pc = 2); thr <- -log10(0.05 / nrow(gw)); gw$sig <- gw$logp >= thr
ggsave(file.path(img, "manhattan.png"),
  ggplot(gw, aes(index, logp, colour = sig)) + geom_point(size = 2) +
    geom_hline(yintercept = thr, linetype = 2, colour = "#b5651d") +
    scale_colour_manual(values = c("FALSE" = "#9bb8a6", "TRUE" = "#1f7a3d"), guide = "none") +
    labs(x = "marker index", y = expression(-log[10](p))) +
    theme_minimal(base_size = 13),
  width = 6, height = 4, dpi = 130)

# 4. Diversity
dv <- diversity_stats(X)
long <- rbind(data.frame(stat = "MAF", value = dv$MAF),
              data.frame(stat = "He",  value = dv$He),
              data.frame(stat = "PIC", value = dv$PIC))
ggsave(file.path(img, "diversity.png"),
  ggplot(long, aes(value, fill = stat)) +
    geom_histogram(bins = 20, alpha = .8, colour = "white") +
    facet_wrap(~stat, scales = "free") +
    scale_fill_viridis_d(option = "D", end = .8, guide = "none") +
    theme_minimal(base_size = 12) + labs(x = NULL, y = "markers"),
  width = 7.5, height = 3, dpi = 130)

# 5. Prediction accuracy
cv <- gs_cv(y, X, models = available_models(), k = 5, seed = 1)
s  <- as.data.frame(summary(cv))
ggsave(file.path(img, "prediction.png"),
  ggplot(s, aes(reorder(model, mean), mean)) +
    geom_col(fill = "#1f7a3d") +
    geom_errorbar(aes(ymin = mean - sd, ymax = mean + sd), width = .2) +
    coord_flip() + labs(x = NULL, y = "CV predictive ability") +
    theme_minimal(base_size = 13),
  width = 6, height = 3.6, dpi = 130)

cat("FIGURES GENERATED\n")
