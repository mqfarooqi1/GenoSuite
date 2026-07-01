# GenoSuite — modern numerical-genomics analytics
# ---------------------------------------------------------------------------
# A desktop analytics suite in the spirit of NTSYSpc, rebuilt for genomic-era
# marker data.
#
# Modules:
#   1. Data import & preview (markers + optional phenotype)
#   2. Genetic distance / similarity matrices
#   3. Clustering & dendrograms (UPGMA / Ward / neighbour-joining)
#   4. Ordination (PCA / PCoA)
#   5. Mantel matrix-correlation test
#   6. Diversity & population differentiation (MAF, He, Ho, PIC, Fst)
#   7. GWAS (single-marker association, Manhattan + QQ)
#   8. Genomic prediction (GBLUP + machine learning, via GSbench)
# ---------------------------------------------------------------------------

library(shiny)
library(bslib)
library(DT)
library(ggplot2)
library(GSbench)

# allow large marker files (up to 300 MB)
options(shiny.maxRequestSize = 300 * 1024^2)

# ---- data helpers ---------------------------------------------------------

## Structured demo SNP dataset with a heritable quantitative trait.
simulate_demo <- function(n_per_pop = 12, n_markers = 60, n_pop = 3,
                          n_qtl = 8, h2 = 0.5, seed = 1) {
  set.seed(seed)
  pops <- paste0("Pop", seq_len(n_pop))
  blocks <- vector("list", n_pop)
  for (k in seq_len(n_pop)) {
    p <- runif(n_markers, 0.1, 0.9)
    shift <- rep(0, n_markers)
    shift[sample(n_markers, n_markers %/% 3)] <- (k - (n_pop + 1) / 2) * 0.18
    p <- pmin(pmax(p + shift, 0.02), 0.98)
    blocks[[k]] <- sapply(p, function(pp) rbinom(n_per_pop, 2, pp))
  }
  X <- do.call(rbind, blocks)
  colnames(X) <- sprintf("SNP%03d", seq_len(n_markers))
  # heritable trait from a handful of causal markers
  causal <- sort(sample(n_markers, n_qtl))
  gv <- as.numeric(scale(X[, causal, drop = FALSE]) %*% rnorm(n_qtl))
  ve <- stats::var(gv) * (1 - h2) / h2
  trait <- round(gv + rnorm(nrow(X), sd = sqrt(ve)), 3)
  data.frame(
    ID = sprintf("Ind%03d", seq_len(nrow(X))),
    Population = rep(pops, each = n_per_pop),
    Trait = trait,
    X, check.names = FALSE, stringsAsFactors = FALSE
  )
}

## Numeric marker matrix, dropping ID / group / phenotype columns.
numeric_matrix <- function(df, id_col, group_col, pheno_col = "") {
  drop <- c(id_col, group_col, pheno_col)
  drop <- drop[nzchar(drop)]
  M <- df[, setdiff(names(df), drop), drop = FALSE]
  M <- M[, vapply(M, is.numeric, logical(1)), drop = FALSE]
  as.matrix(M)
}

## Parse a HapMap genotype file (markers x samples) into an individuals x
## markers 0/1/2 dosage data frame (dosage = copies of the second listed
## allele). The first 11 columns are HapMap metadata; column 1 = marker id,
## column 2 = alleles "A/B"; the rest are sample genotype calls (e.g. "AA").
read_hapmap_geno <- function(path, ext) {
  hm <- if (ext %in% c("xlsx", "xls"))
          as.data.frame(readxl::read_excel(path), check.names = FALSE)
        else
          utils::read.delim(path, check.names = FALSE, stringsAsFactors = FALSE)
  meta_n  <- 11
  rs      <- as.character(hm[[1]])
  alleles <- toupper(as.character(hm[[2]]))
  a1 <- substr(alleles, 1, 1)
  a2 <- substr(sub(".*/", "", alleles), 1, 1)
  samp_cols <- (meta_n + 1):ncol(hm)
  samples   <- names(hm)[samp_cols]
  calls     <- toupper(as.matrix(hm[, samp_cols, drop = FALSE]))
  bases <- c("A", "C", "G", "T")
  dose  <- matrix(NA_real_, length(samples), nrow(calls),
                  dimnames = list(samples, rs))
  for (j in seq_len(nrow(calls))) {
    g  <- calls[j, ]
    c1 <- substr(g, 1, 1); c2 <- substr(g, 2, 2)
    ok <- c1 %in% bases & c2 %in% bases &
          (c1 == a1[j] | c1 == a2[j]) & (c2 == a1[j] | c2 == a2[j])
    d  <- (c1 == a2[j]) + (c2 == a2[j])
    d[!ok] <- NA_real_
    dose[, j] <- d
  }
  data.frame(ID = samples, dose, check.names = FALSE, stringsAsFactors = FALSE)
}

## Read an optional phenotype file (first column = ID).
read_pheno_file <- function(info) {
  if (is.null(info)) return(NULL)
  ext <- tolower(tools::file_ext(info$name))
  if (ext %in% c("xlsx", "xls"))
    as.data.frame(readxl::read_excel(info$datapath), check.names = FALSE)
  else
    utils::read.csv(info$datapath, check.names = FALSE, stringsAsFactors = FALSE)
}

## Merge a converted genotype data frame with an optional phenotype table by ID.
merge_uploads <- function(geno_df, pheno_df) {
  geno_df$ID <- as.character(geno_df$ID)
  if (is.null(pheno_df)) return(geno_df)
  names(pheno_df)[1] <- "ID"
  pheno_df$ID <- as.character(pheno_df$ID)
  merge(pheno_df, geno_df, by = "ID")
}

# ---- analysis helpers -----------------------------------------------------

DIST_CHOICES <- c(
  "Euclidean"                  = "euclidean",
  "Manhattan (city-block)"     = "manhattan",
  "1 - Pearson correlation"    = "correlation",
  "Jaccard (presence/absence)" = "jaccard",
  "Gower"                      = "gower"
)

compute_distance <- function(X, metric) {
  switch(metric,
    euclidean   = dist(X, method = "euclidean"),
    manhattan   = dist(X, method = "manhattan"),
    correlation = stats::as.dist(1 - cor(t(X))),
    jaccard     = vegan::vegdist(ifelse(X > 0, 1, 0), method = "jaccard"),
    gower       = vegan::vegdist(X, method = "gower"),
    dist(X)
  )
}

CLUST_CHOICES <- c(
  "UPGMA (average)"        = "average",
  "Ward's (ward.D2)"       = "ward.D2",
  "Complete linkage"       = "complete",
  "Single linkage"         = "single",
  "Neighbour-joining (NJ)" = "nj"
)

## Per-marker diversity statistics (assumes 0/1/2 allele dosage).
diversity_stats <- function(X) {
  p   <- colMeans(X, na.rm = TRUE) / 2
  q   <- 1 - p
  He  <- 2 * p * q
  Ho  <- colMeans(X == 1, na.rm = TRUE)
  PIC <- 1 - (p^2 + q^2) - 2 * p^2 * q^2
  data.frame(marker = colnames(X), Freq = p, MAF = pmin(p, q),
             He = He, Ho = Ho, PIC = PIC, row.names = NULL)
}

## Nei's Gst (Fst) per marker between groups.
fst_nei <- function(X, groups) {
  g <- factor(groups)
  freqs <- vapply(levels(g),
                  function(lev) colMeans(X[g == lev, , drop = FALSE], na.rm = TRUE) / 2,
                  numeric(ncol(X)))                      # markers x subpops
  Hs   <- rowMeans(2 * freqs * (1 - freqs))
  pbar <- rowMeans(freqs)
  Ht   <- 2 * pbar * (1 - pbar)
  Fst  <- ifelse(Ht > 0, (Ht - Hs) / Ht, NA_real_)
  data.frame(marker = colnames(X), Hs = Hs, Ht = Ht, Fst = Fst, row.names = NULL)
}

## Single-marker GWAS scan with optional PC correction for structure.
gwas_scan <- function(y, X, n_pc = 0) {
  keep <- !is.na(y)
  y <- y[keep]; X <- X[keep, , drop = FALSE]
  covar <- NULL
  if (n_pc > 0) covar <- prcomp(X, scale. = FALSE)$x[, seq_len(n_pc), drop = FALSE]
  out <- lapply(seq_len(ncol(X)), function(j) {
    dat <- data.frame(y = y, snp = X[, j])
    if (!is.null(covar)) dat <- cbind(dat, covar)
    fit <- tryCatch(lm(y ~ ., data = dat), error = function(e) NULL)
    if (is.null(fit)) return(c(NA, NA))
    co <- summary(fit)$coefficients
    if ("snp" %in% rownames(co)) co["snp", c("Estimate", "Pr(>|t|)")] else c(NA, NA)
  })
  out <- do.call(rbind, out)
  data.frame(marker = colnames(X), index = seq_len(ncol(X)),
             effect = out[, 1], p = out[, 2], logp = -log10(out[, 2]),
             row.names = NULL)
}

# ---- UI -------------------------------------------------------------------

ui <- page_navbar(
  title = tags$span(tags$strong("GenoSuite"),
                    tags$small(" · numerical genomics", style = "opacity:.6")),
  theme = bs_theme(version = 5, primary = "#1f7a3d"),
  fillable = TRUE,

  nav_panel(
    "Data",
    layout_sidebar(
      sidebar = sidebar(
        width = 330,
        radioButtons("data_mode", "Genotype format",
                     c("Table (individuals x markers)" = "table",
                       "HapMap (markers x samples)" = "hapmap")),
        fileInput("file", "Upload genotypes (CSV / Excel / HapMap)",
                  accept = c(".csv", ".txt", ".xlsx", ".xls", ".hmp")),
        conditionalPanel(
          "input.data_mode == 'hapmap'",
          fileInput("pheno_file",
                    "Phenotype file (optional; CSV/Excel, 1st column = ID)",
                    accept = c(".csv", ".xlsx", ".xls"))),
        checkboxInput("header", "First row is header", TRUE),
        actionButton("demo", "Load demo SNP dataset", class = "btn-primary w-100"),
        hr(),
        selectInput("id_col", "ID column", choices = NULL),
        selectInput("group_col", "Grouping column (optional)", choices = NULL),
        selectInput("pheno_col", "Phenotype column (GWAS / prediction)", choices = NULL),
        helpText("Table mode: rows = individuals, numeric columns = markers",
                 "(dosage 0/1/2). HapMap mode converts a markers x samples file",
                 "to individuals x markers and merges an optional phenotype file",
                 "by ID.")
      ),
      card(card_header("Data preview"),
           textOutput("data_summary"), DTOutput("preview"))
    )
  ),

  nav_panel(
    "Distance",
    layout_sidebar(
      sidebar = sidebar(
        width = 330,
        selectInput("dist_metric", "Distance metric", choices = DIST_CHOICES),
        checkboxInput("dist_scale", "Standardise markers (z-score)", FALSE),
        actionButton("run_dist", "Compute distance", class = "btn-primary w-100"),
        downloadButton("dl_dist", "Download matrix (CSV)", class = "w-100 mt-2")
      ),
      card(card_header("Distance matrix heatmap"),
           plotOutput("dist_heatmap", height = "560px"))
    )
  ),

  nav_panel(
    "Clustering",
    layout_sidebar(
      sidebar = sidebar(
        width = 330,
        selectInput("clust_method", "Method", choices = CLUST_CHOICES),
        helpText("Uses the distance matrix from the Distance tab."),
        downloadButton("dl_tree", "Download tree (Newick)", class = "w-100 mt-2")
      ),
      card(card_header("Dendrogram / tree"),
           plotOutput("dendro", height = "600px"))
    )
  ),

  nav_panel(
    "Ordination",
    layout_sidebar(
      sidebar = sidebar(
        width = 330,
        radioButtons("ord_method", "Method",
                     c("PCA (on markers)" = "pca", "PCoA (on distance)" = "pcoa")),
        numericInput("ord_x", "Axis (x)", 1, min = 1, max = 10),
        numericInput("ord_y", "Axis (y)", 2, min = 1, max = 10)
      ),
      layout_columns(
        col_widths = c(8, 4),
        card(card_header("Ordination plot"), plotOutput("ord_plot", height = "560px")),
        card(card_header("Variance explained"), plotOutput("ord_scree", height = "560px"))
      )
    )
  ),

  nav_panel(
    "Mantel test",
    layout_sidebar(
      sidebar = sidebar(
        width = 330,
        selectInput("mantel_a", "Matrix A metric", choices = DIST_CHOICES, selected = "euclidean"),
        selectInput("mantel_b", "Matrix B metric", choices = DIST_CHOICES, selected = "manhattan"),
        numericInput("mantel_perm", "Permutations", 999, min = 99, max = 9999),
        actionButton("run_mantel", "Run Mantel test", class = "btn-primary w-100")
      ),
      card(card_header("Mantel matrix-correlation result"),
           verbatimTextOutput("mantel_out"), plotOutput("mantel_plot", height = "420px"))
    )
  ),

  nav_panel(
    "Diversity",
    layout_sidebar(
      sidebar = sidebar(
        width = 330,
        helpText("Per-marker diversity from allele dosages."),
        helpText("Fst (Nei's Gst) needs a grouping column."),
        downloadButton("dl_div", "Download stats (CSV)", class = "w-100 mt-2")
      ),
      layout_columns(
        col_widths = c(12),
        layout_columns(
          col_widths = c(3, 3, 3, 3),
          value_box("Mean MAF", textOutput("vb_maf"), theme = "primary"),
          value_box("Mean He", textOutput("vb_he"), theme = "primary"),
          value_box("Mean PIC", textOutput("vb_pic"), theme = "primary"),
          value_box("Overall Fst", textOutput("vb_fst"), theme = "secondary")
        ),
        card(card_header("Diversity distributions"), plotOutput("div_plot", height = "360px")),
        card(card_header("Per-marker statistics"), DTOutput("div_table"))
      )
    )
  ),

  nav_panel(
    "GWAS",
    layout_sidebar(
      sidebar = sidebar(
        width = 330,
        numericInput("gwas_pc", "PCs for structure correction", 2, min = 0, max = 10),
        numericInput("gwas_alpha", "Significance (alpha)", 0.05, min = 1e-4, max = 1, step = 0.01),
        actionButton("run_gwas", "Run GWAS", class = "btn-primary w-100"),
        downloadButton("dl_gwas", "Download results (CSV)", class = "w-100 mt-2")
      ),
      layout_columns(
        col_widths = c(8, 4),
        card(card_header("Manhattan plot"), plotOutput("manhattan", height = "420px")),
        card(card_header("QQ plot"), plotOutput("qqplot", height = "420px")),
        card(card_header("Top associations"), DTOutput("gwas_table"))
      )
    )
  ),

  nav_panel(
    "Prediction",
    layout_sidebar(
      sidebar = sidebar(
        width = 330,
        checkboxGroupInput("pred_models", "Models",
                           choices = available_models(), selected = c("gblup")),
        numericInput("pred_k", "CV folds", 5, min = 2, max = 10),
        actionButton("run_pred", "Run cross-validation", class = "btn-primary w-100"),
        hr(),
        helpText("Then fit a final GBLUP for breeding values:"),
        actionButton("run_gebv", "Fit GBLUP & estimate GEBVs", class = "btn-outline-primary w-100"),
        downloadButton("dl_gebv", "Download GEBVs (CSV)", class = "w-100 mt-2")
      ),
      layout_columns(
        col_widths = c(7, 5),
        card(card_header("Cross-validated predictive ability"),
             plotOutput("pred_plot", height = "380px")),
        card(card_header("Accuracy by model"), DTOutput("pred_table")),
        card(card_header("Genomic breeding values (GBLUP)"),
             textOutput("gebv_h2"), DTOutput("gebv_table"))
      )
    )
  ),

  nav_panel(
    "Kinship",
    layout_sidebar(
      sidebar = sidebar(
        width = 330,
        helpText("Genomic relationship matrix (VanRaden) from marker dosages."),
        numericInput("grm_maf", "Minimum MAF", 0.05, min = 0, max = 0.5, step = 0.01),
        actionButton("run_grm", "Compute GRM", class = "btn-primary w-100"),
        downloadButton("dl_grm", "Download GRM (CSV)", class = "w-100 mt-2")
      ),
      layout_columns(
        col_widths = c(7, 5),
        card(card_header("Genomic relationship heatmap"),
             plotOutput("grm_heatmap", height = "560px")),
        card(card_header("Relationship coefficients"),
             plotOutput("grm_hist", height = "560px"))
      )
    )
  ),

  nav_panel(
    "LD",
    layout_sidebar(
      sidebar = sidebar(
        width = 330,
        helpText("Pairwise linkage disequilibrium (r²) between markers."),
        numericInput("ld_max", "Markers to include (first N)", 100, min = 5, max = 2000),
        actionButton("run_ld", "Compute LD", class = "btn-primary w-100")
      ),
      layout_columns(
        col_widths = c(7, 5),
        card(card_header("LD (r²) heatmap"), plotOutput("ld_heatmap", height = "520px")),
        card(card_header("LD decay"), plotOutput("ld_decay", height = "520px"))
      )
    )
  ),

  nav_spacer(),
  nav_item(actionLink("about_app", "About")),
  nav_item(actionLink("quit_app", "Quit", icon = icon("power-off")))
)

# ---- Server ---------------------------------------------------------------

server <- function(input, output, session) {

  rv <- reactiveValues(data = NULL)

  # desktop: quit the app (stops the local server)
  observeEvent(input$quit_app, {
    showNotification("GenoSuite is shutting down. You can close this tab.",
                     duration = NULL, type = "warning")
    shiny::stopApp()
  })

  observeEvent(input$demo, {
    rv$data <- simulate_demo()
    showNotification("Loaded demo dataset (36 individuals, 3 populations, 60 SNPs, 1 trait).",
                     type = "message")
  })

  observeEvent(input$file, {
    ext <- tolower(tools::file_ext(input$file$name))
    if (identical(input$data_mode, "hapmap")) {
      g <- tryCatch(
        withProgress(message = "Converting HapMap genotypes...",
                     read_hapmap_geno(input$file$datapath, ext)),
        error = function(e) {
          showNotification(paste("HapMap read failed:", conditionMessage(e)),
                           type = "error"); NULL })
      if (is.null(g)) return()
      rv$geno_hapmap <- g
      showNotification(sprintf("Converted HapMap: %d individuals x %d markers.",
                               nrow(g), ncol(g) - 1L), type = "message")
      rv$data <- merge_uploads(g, read_pheno_file(input$pheno_file))
    } else {
      df <- tryCatch(
        if (ext %in% c("xlsx", "xls")) {
          as.data.frame(readxl::read_excel(input$file$datapath,
                                           col_names = input$header),
                        check.names = FALSE, stringsAsFactors = FALSE)
        } else {
          utils::read.csv(input$file$datapath, header = input$header,
                          check.names = FALSE, stringsAsFactors = FALSE)
        },
        error = function(e) {
          showNotification(paste("Could not read file:", conditionMessage(e)),
                           type = "error"); NULL })
      if (!is.null(df)) rv$data <- df
    }
  })

  observeEvent(input$pheno_file, {
    if (identical(input$data_mode, "hapmap") && !is.null(rv$geno_hapmap))
      rv$data <- merge_uploads(rv$geno_hapmap, read_pheno_file(input$pheno_file))
  })

  observeEvent(rv$data, {
    nm  <- names(rv$data)
    num <- nm[vapply(rv$data, is.numeric, logical(1))]
    updateSelectInput(session, "id_col", choices = nm, selected = nm[1])
    updateSelectInput(session, "group_col",
                      choices = c("(none)" = "", nm),
                      selected = if ("Population" %in% nm) "Population" else "")
    updateSelectInput(session, "pheno_col",
                      choices = c("(none)" = "", num),
                      selected = if ("Trait" %in% num) "Trait" else "")
  })

  marker_mat <- reactive({
    req(rv$data, input$id_col)
    X <- numeric_matrix(rv$data, input$id_col, input$group_col, input$pheno_col)
    validate(need(ncol(X) >= 2, "Need at least two numeric marker columns."))
    rownames(X) <- as.character(rv$data[[input$id_col]])
    X
  })

  groups <- reactive({
    if (!is.null(input$group_col) && nzchar(input$group_col))
      factor(rv$data[[input$group_col]]) else NULL
  })

  pheno <- reactive({
    if (!is.null(input$pheno_col) && nzchar(input$pheno_col))
      as.numeric(rv$data[[input$pheno_col]]) else NULL
  })

  output$data_summary <- renderText({
    if (is.null(rv$data)) return("No data loaded. Upload a CSV or load the demo dataset.")
    sprintf("%d rows x %d columns loaded.", nrow(rv$data), ncol(rv$data))
  })

  output$preview <- renderDT(
    datatable(req(rv$data), options = list(scrollX = TRUE, pageLength = 8), rownames = FALSE)
  )

  # ---- distance ----
  scaled_mat <- reactive({
    X <- marker_mat()
    if (isTRUE(input$dist_scale)) { X <- scale(X); X[is.nan(X)] <- 0 }
    X
  })

  dist_obj <- eventReactive(input$run_dist, compute_distance(scaled_mat(), input$dist_metric))

  output$dist_heatmap <- renderPlot({
    d <- dist_obj(); m <- as.matrix(d)
    ord <- hclust(d, "average")$order; m <- m[ord, ord]
    df <- expand.grid(x = rownames(m), y = colnames(m))
    df$value <- as.vector(m)
    df$x <- factor(df$x, levels = rownames(m))
    df$y <- factor(df$y, levels = rev(rownames(m)))
    ggplot(df, aes(x, y, fill = value)) + geom_tile() +
      scale_fill_viridis_c(option = "D", name = "distance") +
      theme_minimal(base_size = 11) +
      theme(axis.text.x = element_text(angle = 90, vjust = .5, hjust = 1),
            axis.title = element_blank())
  })

  output$dl_dist <- downloadHandler(
    filename = function() paste0("distance_", input$dist_metric, ".csv"),
    content  = function(f) utils::write.csv(as.matrix(dist_obj()), f)
  )

  # ---- clustering ----
  tree_obj <- reactive({
    d <- dist_obj()
    if (input$clust_method == "nj") ape::nj(d) else hclust(d, method = input$clust_method)
  })

  output$dendro <- renderPlot({
    obj <- tree_obj(); g <- groups()
    if (inherits(obj, "phylo")) {
      tipcol <- "black"
      if (!is.null(g)) {
        pal <- grDevices::hcl.colors(nlevels(g), "Dark 3")
        names_order <- rownames(as.matrix(dist_obj()))
        tipcol <- pal[as.integer(g)][match(obj$tip.label, names_order)]
      }
      ape::plot.phylo(obj, type = "unrooted", cex = .8, tip.color = tipcol,
                      lab4ut = "axial", no.margin = TRUE)
    } else {
      plot(obj, main = NULL, sub = "", xlab = "", cex = .8, hang = -1)
    }
  })

  output$dl_tree <- downloadHandler(
    filename = function() "genosuite_tree.nwk",
    content  = function(f) {
      obj <- tree_obj()
      phy <- if (inherits(obj, "phylo")) obj else ape::as.phylo(obj)
      ape::write.tree(phy, file = f)
    }
  )

  # ---- ordination ----
  output$ord_plot <- renderPlot({
    ax <- input$ord_x; ay <- input$ord_y; g <- groups()
    if (input$ord_method == "pca") {
      pr <- prcomp(scaled_mat(), scale. = FALSE); sco <- pr$x
      ve <- (pr$sdev^2) / sum(pr$sdev^2)
      xl <- sprintf("PC%d (%.1f%%)", ax, 100 * ve[ax])
      yl <- sprintf("PC%d (%.1f%%)", ay, 100 * ve[ay])
    } else {
      cm <- cmdscale(dist_obj(), k = max(ax, ay), eig = TRUE); sco <- cm$points
      ve <- cm$eig[cm$eig > 0] / sum(cm$eig[cm$eig > 0])
      xl <- sprintf("PCoA %d (%.1f%%)", ax, 100 * ve[ax])
      yl <- sprintf("PCoA %d (%.1f%%)", ay, 100 * ve[ay])
    }
    df <- data.frame(x = sco[, ax], y = sco[, ay],
                     grp = if (!is.null(g)) g else factor("all"))
    ggplot(df, aes(x, y, colour = grp)) +
      geom_point(size = 3, alpha = .85) +
      labs(x = xl, y = yl, colour = NULL) +
      scale_colour_viridis_d(option = "D", end = .85) +
      theme_minimal(base_size = 13)
  })

  output$ord_scree <- renderPlot({
    if (input$ord_method == "pca") {
      pr <- prcomp(scaled_mat(), scale. = FALSE); ve <- (pr$sdev^2) / sum(pr$sdev^2)
    } else {
      cm <- cmdscale(dist_obj(), k = 8, eig = TRUE)
      ev <- cm$eig[cm$eig > 0]; ve <- ev / sum(ev)
    }
    ve <- head(ve, 10)
    ggplot(data.frame(axis = factor(seq_along(ve)), ve = 100 * ve), aes(axis, ve)) +
      geom_col(fill = "#1f7a3d") + labs(x = "axis", y = "% variance") +
      theme_minimal(base_size = 13)
  })

  # ---- mantel ----
  mantel_res <- eventReactive(input$run_mantel, {
    X <- scaled_mat()
    da <- compute_distance(X, input$mantel_a)
    db <- compute_distance(X, input$mantel_b)
    list(r = vegan::mantel(da, db, permutations = input$mantel_perm), da = da, db = db)
  })

  output$mantel_out  <- renderPrint(print(mantel_res()$r))
  output$mantel_plot <- renderPlot({
    res <- mantel_res()
    ggplot(data.frame(a = as.vector(res$da), b = as.vector(res$db)), aes(a, b)) +
      geom_point(alpha = .4, colour = "#1f7a3d") +
      geom_smooth(method = "lm", se = FALSE, colour = "#b5651d") +
      labs(x = names(which(DIST_CHOICES == input$mantel_a)),
           y = names(which(DIST_CHOICES == input$mantel_b))) +
      theme_minimal(base_size = 13)
  })

  # ---- diversity ----
  div_res <- reactive({
    X <- marker_mat()
    d <- diversity_stats(X)
    g <- groups()
    if (!is.null(g) && nlevels(g) > 1) d <- merge(d, fst_nei(X, g), by = "marker")
    d
  })

  output$vb_maf <- renderText(sprintf("%.3f", mean(div_res()$MAF, na.rm = TRUE)))
  output$vb_he  <- renderText(sprintf("%.3f", mean(div_res()$He,  na.rm = TRUE)))
  output$vb_pic <- renderText(sprintf("%.3f", mean(div_res()$PIC, na.rm = TRUE)))
  output$vb_fst <- renderText({
    d <- div_res()
    if ("Fst" %in% names(d)) sprintf("%.3f", mean(d$Fst, na.rm = TRUE)) else "n/a"
  })

  output$div_plot <- renderPlot({
    d <- div_res()
    long <- rbind(
      data.frame(stat = "MAF", value = d$MAF),
      data.frame(stat = "He",  value = d$He),
      data.frame(stat = "PIC", value = d$PIC)
    )
    ggplot(long, aes(value, fill = stat)) +
      geom_histogram(bins = 20, alpha = .8, colour = "white") +
      facet_wrap(~stat, scales = "free") +
      scale_fill_viridis_d(option = "D", end = .8, guide = "none") +
      theme_minimal(base_size = 12) + labs(x = NULL, y = "markers")
  })

  output$div_table <- renderDT(
    datatable(round_df(div_res()), options = list(pageLength = 8, scrollX = TRUE),
              rownames = FALSE)
  )

  output$dl_div <- downloadHandler(
    filename = function() "diversity_stats.csv",
    content  = function(f) utils::write.csv(div_res(), f, row.names = FALSE)
  )

  # ---- gwas ----
  gwas_res <- eventReactive(input$run_gwas, {
    y <- pheno()
    validate(need(!is.null(y), "Select a phenotype column on the Data tab."))
    gwas_scan(y, marker_mat(), n_pc = input$gwas_pc)
  })

  gwas_thresh <- reactive(-log10(input$gwas_alpha / nrow(gwas_res())))

  output$manhattan <- renderPlot({
    res <- gwas_res(); thr <- gwas_thresh()
    res$sig <- res$logp >= thr
    ggplot(res, aes(index, logp, colour = sig)) +
      geom_point(size = 2) +
      geom_hline(yintercept = thr, linetype = 2, colour = "#b5651d") +
      scale_colour_manual(values = c("FALSE" = "#9bb8a6", "TRUE" = "#1f7a3d"), guide = "none") +
      labs(x = "marker index", y = expression(-log[10](p))) +
      theme_minimal(base_size = 13)
  })

  output$qqplot <- renderPlot({
    res <- gwas_res()
    obs <- sort(res$logp[is.finite(res$logp)], decreasing = TRUE)
    exp <- -log10(ppoints(length(obs)))
    ggplot(data.frame(exp = exp, obs = obs), aes(exp, obs)) +
      geom_abline(slope = 1, intercept = 0, colour = "grey60") +
      geom_point(colour = "#1f7a3d", size = 2) +
      labs(x = expression(Expected~-log[10](p)), y = expression(Observed~-log[10](p))) +
      theme_minimal(base_size = 13)
  })

  output$gwas_table <- renderDT({
    res <- gwas_res()
    res <- res[order(res$p), c("marker", "index", "effect", "p", "logp")]
    datatable(round_df(res), options = list(pageLength = 8), rownames = FALSE)
  })

  output$dl_gwas <- downloadHandler(
    filename = function() "gwas_results.csv",
    content  = function(f) utils::write.csv(gwas_res(), f, row.names = FALSE)
  )

  # ---- prediction ----
  cv_res <- eventReactive(input$run_pred, {
    y <- pheno()
    validate(need(!is.null(y), "Select a phenotype column on the Data tab."))
    validate(need(length(input$pred_models) >= 1, "Select at least one model."))
    withProgress(message = "Cross-validating models...", {
      gs_cv(y, marker_mat(), models = input$pred_models, k = input$pred_k, seed = 1)
    })
  })

  output$pred_plot  <- renderPlot(plot(cv_res()))
  output$pred_table <- renderDT(
    datatable(round_df(as.data.frame(summary(cv_res()))),
              options = list(dom = "t"), rownames = FALSE)
  )

  gebv_res <- eventReactive(input$run_gebv, {
    y <- pheno()
    validate(need(!is.null(y), "Select a phenotype column on the Data tab."))
    X <- marker_mat()
    fit <- gblup(y, geno = X)
    list(h2 = fit$h2,
         tab = data.frame(ID = rownames(X), GEBV = round(as.numeric(fit$gebv), 4),
                          row.names = NULL))
  })

  output$gebv_h2 <- renderText({
    sprintf("Estimated genomic heritability (h2): %.3f", gebv_res()$h2)
  })
  output$gebv_table <- renderDT({
    tab <- gebv_res()$tab
    datatable(tab[order(-tab$GEBV), ], options = list(pageLength = 8), rownames = FALSE)
  })
  output$dl_gebv <- downloadHandler(
    filename = function() "gebv.csv",
    content  = function(f) utils::write.csv(gebv_res()$tab, f, row.names = FALSE)
  )

  # ---- kinship / GRM ----
  grm_obj <- eventReactive(input$run_grm, {
    X <- marker_mat()
    G <- GSbench::Gmatrix(X, min_maf = input$grm_maf)
    if (is.null(rownames(G))) { rownames(G) <- rownames(X); colnames(G) <- rownames(X) }
    G
  })

  output$grm_heatmap <- renderPlot({
    G <- grm_obj()
    ord <- hclust(dist(G), "average")$order
    G2 <- G[ord, ord]
    df <- expand.grid(x = rownames(G2), y = colnames(G2))
    df$value <- as.vector(G2)
    df$x <- factor(df$x, levels = rownames(G2))
    df$y <- factor(df$y, levels = rev(rownames(G2)))
    ggplot(df, aes(x, y, fill = value)) + geom_tile() +
      scale_fill_viridis_c(option = "D", name = "relationship") +
      theme_minimal(base_size = 11) +
      theme(axis.text.x = element_text(angle = 90, vjust = .5, hjust = 1),
            axis.title = element_blank())
  })

  output$grm_hist <- renderPlot({
    G <- grm_obj()
    df <- rbind(
      data.frame(type = "Off-diagonal (relatedness)", value = G[upper.tri(G)]),
      data.frame(type = "Diagonal (1 + inbreeding)",  value = diag(G))
    )
    ggplot(df, aes(value, fill = type)) +
      geom_histogram(bins = 25, alpha = .8, colour = "white") +
      facet_wrap(~type, scales = "free", ncol = 1) +
      scale_fill_viridis_d(option = "D", end = .7, guide = "none") +
      theme_minimal(base_size = 12) + labs(x = "relationship coefficient", y = "count")
  })

  output$dl_grm <- downloadHandler(
    filename = function() "grm.csv",
    content  = function(f) utils::write.csv(grm_obj(), f)
  )

  # ---- linkage disequilibrium ----
  ld_obj <- eventReactive(input$run_ld, {
    X  <- marker_mat()
    n  <- min(ncol(X), input$ld_max)
    Xs <- X[, seq_len(n), drop = FALSE]
    Xs <- Xs[, apply(Xs, 2, stats::sd) > 0, drop = FALSE]   # drop monomorphic
    validate(need(ncol(Xs) >= 2, "Need at least two polymorphic markers."))
    cor(Xs)^2
  })

  output$ld_heatmap <- renderPlot({
    r2 <- ld_obj()
    df <- expand.grid(i = seq_len(nrow(r2)), j = seq_len(ncol(r2)))
    df$r2 <- as.vector(r2)
    ggplot(df, aes(i, j, fill = r2)) + geom_raster() +
      scale_fill_viridis_c(option = "B", name = expression(r^2), limits = c(0, 1)) +
      coord_equal() + theme_minimal(base_size = 12) + labs(x = "marker", y = "marker")
  })

  output$ld_decay <- renderPlot({
    r2 <- ld_obj()
    ut <- upper.tri(r2)
    idx <- which(ut, arr.ind = TRUE)
    dd <- data.frame(dist = abs(idx[, 1] - idx[, 2]), r2 = r2[ut])
    ggplot(dd, aes(dist, r2)) +
      geom_point(alpha = .25, colour = "#1f7a3d") +
      geom_smooth(method = "loess", se = FALSE, colour = "#b5651d") +
      labs(x = "marker-pair separation (index distance)", y = expression(r^2)) +
      theme_minimal(base_size = 13)
  })

  # ---- about ----
  observeEvent(input$about_app, {
    showModal(modalDialog(
      title = "About GenoSuite", easyClose = TRUE, footer = modalButton("Close"),
      tags$p(tags$strong("GenoSuite 0.1.2"),
             " — modern numerical-genomics analytics."),
      tags$p("© 2026 Muhammad Farooqi. Released under the MIT License."),
      tags$p(tags$a(href = "https://mqfarooqi1.github.io/GenoSuite/", target = "_blank",
                    "Documentation & user manual")),
      tags$hr(),
      tags$p(tags$em("Disclaimer: "),
             "GenoSuite is provided “as is”, without warranty of any kind. ",
             "The author is not liable for any outcome arising from its use. ",
             "Always validate results before using them for decisions.")
    ))
  })
}

# round numeric columns of a data frame for display
round_df <- function(df, digits = 4) {
  num <- vapply(df, is.numeric, logical(1))
  df[num] <- lapply(df[num], round, digits)
  df
}

shinyApp(ui, server)
