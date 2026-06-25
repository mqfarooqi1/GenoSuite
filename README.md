# GenoSuite

**Modern numerical-genomics analytics — a desktop application.**

GenoSuite is a point-and-click desktop tool for multivariate analysis of
genetic marker data, in the spirit of classic packages like NTSYSpc but rebuilt
for genomic-era datasets. It runs as a self-contained Windows application: the
user installs a single `Setup.exe` and launches a graphical interface — no R
installation or coding required.

## Current modules (Phase 1)

| Module | What it does |
|---|---|
| **Data** | Import CSV/marker tables or load a demo SNP dataset; pick ID and grouping columns. |
| **Distance** | Genetic distance / similarity matrices: Euclidean, Manhattan, 1 − correlation, Jaccard (presence/absence), Gower. Heatmap + CSV export. |
| **Clustering** | Dendrograms by UPGMA, Ward, complete, single linkage, and neighbour-joining (NJ). Newick export. |
| **Ordination** | Interactive PCA (markers) and PCoA (distance) with scree plots, coloured by group. |
| **Mantel test** | Matrix-correlation test between two distance metrics, with permutation significance. |

## Planned (Phase 2+)

Population structure & diversity (kinship/GRM, Fst, AMOVA, He/Ho, PIC), GWAS
(Manhattan/QQ), genomic selection & prediction (via
[GSbench](https://github.com/mqfarooqi1/GSbench)), linkage disequilibrium, and
exportable PDF/HTML reports.

## Architecture

- **GUI:** R + [Shiny](https://shiny.posit.co/) + [bslib](https://rstudio.github.io/bslib/).
- **Analytics:** base R, `ape`, `vegan`, and the author's own R packages.
- **Packaging:** bundled into a self-contained Windows installer
  (portable R + app + launcher, compiled with Inno Setup).

## Running from source (developers)

```r
# from the repository root
shiny::runApp("app")
```

Requires: `shiny`, `bslib`, `DT`, `ggplot2`, `ape`, `vegan`.

---

Author: **Muhammad Farooqi** · MIT licensed.
