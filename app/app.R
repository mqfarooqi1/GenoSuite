# GenoSuite — modern numerical-genomics analytics
# ---------------------------------------------------------------------------
# A desktop analytics suite in the spirit of NTSYSpc, rebuilt for genomic-era
# marker data. Phase-1 modules:
#   1. Data import & preview
#   2. Genetic distance / similarity matrices
#   3. Clustering & dendrograms (UPGMA / Ward / neighbour-joining)
#   4. Ordination (PCA / PCoA)
#   5. Mantel matrix-correlation test
# ---------------------------------------------------------------------------

library(shiny)
library(bslib)
library(DT)
library(ggplot2)

# ---- helpers --------------------------------------------------------------

## Simulate a small, structured SNP dataset so the app is usable on first run.
simulate_demo <- function(n_per_pop = 12, n_markers = 60, n_pop = 3, seed = 1) {
  set.seed(seed)
  pops <- paste0("Pop", seq_len(n_pop))
  blocks <- vector("list", n_pop)
  for (k in seq_len(n_pop)) {
    p <- runif(n_markers, 0.1, 0.9)
    shift <- rep(0, n_markers)
    idx <- sample(n_markers, n_markers %/% 3)
    shift[idx] <- (k - (n_pop + 1) / 2) * 0.18          # structure across pops
    p <- pmin(pmax(p + shift, 0.02), 0.98)
    blocks[[k]] <- sapply(p, function(pp) rbinom(n_per_pop, 2, pp))
  }
  X <- do.call(rbind, blocks)
  colnames(X) <- sprintf("SNP%03d", seq_len(n_markers))
  data.frame(
    ID = sprintf("Ind%03d", seq_len(nrow(X))),
    Population = rep(pops, each = n_per_pop),
    X, check.names = FALSE, stringsAsFactors = FALSE
  )
}

## Pull the numeric marker matrix out of a data frame, dropping ID/group cols.
numeric_matrix <- function(df, id_col, group_col) {
  drop <- c(id_col, group_col)
  drop <- drop[nzchar(drop)]
  M <- df[, setdiff(names(df), drop), drop = FALSE]
  M <- M[, vapply(M, is.numeric, logical(1)), drop = FALSE]
  as.matrix(M)
}

## Distance metrics (classic + marker-appropriate).
DIST_CHOICES <- c(
  "Euclidean"               = "euclidean",
  "Manhattan (city-block)"  = "manhattan",
  "1 - Pearson correlation" = "correlation",
  "Jaccard (presence/absence)" = "jaccard",
  "Gower"                   = "gower"
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
  "UPGMA (average)" = "average",
  "Ward's (ward.D2)" = "ward.D2",
  "Complete linkage" = "complete",
  "Single linkage"   = "single",
  "Neighbour-joining (NJ)" = "nj"
)

# ---- UI -------------------------------------------------------------------

ui <- page_navbar(
  title = tags$span(tags$strong("GenoSuite"),
                    tags$small(" · numerical genomics", style = "opacity:.6")),
  theme = bs_theme(version = 5, primary = "#1f7a3d"),
  fillable = TRUE,

  # ---- Data ----
  nav_panel(
    "Data",
    layout_sidebar(
      sidebar = sidebar(
        width = 320,
        fileInput("file", "Upload data (CSV)", accept = c(".csv", ".txt")),
        checkboxInput("header", "First row is header", TRUE),
        actionButton("demo", "Load demo SNP dataset", class = "btn-primary w-100"),
        hr(),
        selectInput("id_col", "ID column", choices = NULL),
        selectInput("group_col", "Grouping column (optional)", choices = NULL),
        helpText("Rows = individuals/OTUs. Remaining numeric columns are treated",
                 "as markers/traits.")
      ),
      card(
        card_header("Data preview"),
        textOutput("data_summary"),
        DTOutput("preview")
      )
    )
  ),

  # ---- Distance ----
  nav_panel(
    "Distance",
    layout_sidebar(
      sidebar = sidebar(
        width = 320,
        selectInput("dist_metric", "Distance metric", choices = DIST_CHOICES),
        checkboxInput("dist_scale", "Standardise markers (z-score)", FALSE),
        actionButton("run_dist", "Compute distance", class = "btn-primary w-100"),
        downloadButton("dl_dist", "Download matrix (CSV)", class = "w-100 mt-2")
      ),
      card(
        card_header("Distance matrix heatmap"),
        plotOutput("dist_heatmap", height = "560px")
      )
    )
  ),

  # ---- Clustering ----
  nav_panel(
    "Clustering",
    layout_sidebar(
      sidebar = sidebar(
        width = 320,
        selectInput("clust_method", "Method", choices = CLUST_CHOICES),
        helpText("Uses the distance matrix from the Distance tab."),
        downloadButton("dl_tree", "Download tree (Newick)", class = "w-100 mt-2")
      ),
      card(
        card_header("Dendrogram / tree"),
        plotOutput("dendro", height = "600px")
      )
    )
  ),

  # ---- Ordination ----
  nav_panel(
    "Ordination",
    layout_sidebar(
      sidebar = sidebar(
        width = 320,
        radioButtons("ord_method", "Method",
                     c("PCA (on markers)" = "pca",
                       "PCoA (on distance)" = "pcoa")),
        numericInput("ord_x", "Axis (x)", 1, min = 1, max = 10),
        numericInput("ord_y", "Axis (y)", 2, min = 1, max = 10)
      ),
      layout_columns(
        col_widths = c(8, 4),
        card(card_header("Ordination plot"),
             plotOutput("ord_plot", height = "560px")),
        card(card_header("Variance explained"),
             plotOutput("ord_scree", height = "560px"))
      )
    )
  ),

  # ---- Mantel ----
  nav_panel(
    "Mantel test",
    layout_sidebar(
      sidebar = sidebar(
        width = 320,
        selectInput("mantel_a", "Matrix A metric", choices = DIST_CHOICES,
                    selected = "euclidean"),
        selectInput("mantel_b", "Matrix B metric", choices = DIST_CHOICES,
                    selected = "manhattan"),
        numericInput("mantel_perm", "Permutations", 999, min = 99, max = 9999),
        actionButton("run_mantel", "Run Mantel test", class = "btn-primary w-100")
      ),
      card(
        card_header("Mantel matrix-correlation result"),
        verbatimTextOutput("mantel_out"),
        plotOutput("mantel_plot", height = "420px")
      )
    )
  ),

  nav_spacer(),
  nav_item(tags$a("About", href = "#", onclick = "return false;",
                  title = "GenoSuite — modern numerical-genomics analytics"))
)

# ---- Server ---------------------------------------------------------------

server <- function(input, output, session) {

  rv <- reactiveValues(data = NULL)

  observeEvent(input$demo, {
    rv$data <- simulate_demo()
    showNotification("Loaded demo SNP dataset (36 individuals, 3 populations).",
                     type = "message")
  })

  observeEvent(input$file, {
    df <- tryCatch(
      utils::read.csv(input$file$datapath, header = input$header,
                      check.names = FALSE, stringsAsFactors = FALSE),
      error = function(e) {
        showNotification(paste("Could not read file:", conditionMessage(e)),
                         type = "error"); NULL
      })
    if (!is.null(df)) rv$data <- df
  })

  # keep column selectors in sync with the loaded data
  observeEvent(rv$data, {
    nm <- names(rv$data)
    updateSelectInput(session, "id_col", choices = nm, selected = nm[1])
    grp <- if (length(nm) > 1) c("(none)" = "", nm) else c("(none)" = "")
    updateSelectInput(session, "group_col", choices = grp,
                      selected = if (length(nm) > 1) nm[2] else "")
  })

  marker_mat <- reactive({
    req(rv$data, input$id_col)
    X <- numeric_matrix(rv$data, input$id_col, input$group_col)
    validate(need(ncol(X) >= 2, "Need at least two numeric marker columns."))
    rownames(X) <- as.character(rv$data[[input$id_col]])
    X
  })

  groups <- reactive({
    if (!is.null(input$group_col) && nzchar(input$group_col))
      factor(rv$data[[input$group_col]]) else NULL
  })

  output$data_summary <- renderText({
    if (is.null(rv$data)) return("No data loaded. Upload a CSV or load the demo dataset.")
    sprintf("%d rows x %d columns loaded.", nrow(rv$data), ncol(rv$data))
  })

  output$preview <- renderDT({
    req(rv$data)
    datatable(rv$data, options = list(scrollX = TRUE, pageLength = 8),
              rownames = FALSE)
  })

  # ---- distance ----
  scaled_mat <- reactive({
    X <- marker_mat()
    if (isTRUE(input$dist_scale)) {
      X <- scale(X)
      X[is.nan(X)] <- 0
    }
    X
  })

  dist_obj <- eventReactive(input$run_dist, {
    compute_distance(scaled_mat(), input$dist_metric)
  })

  output$dist_heatmap <- renderPlot({
    d <- dist_obj()
    m <- as.matrix(d)
    ord <- hclust(d, "average")$order
    m <- m[ord, ord]
    df <- expand.grid(x = rownames(m), y = colnames(m))
    df$value <- as.vector(m)
    df$x <- factor(df$x, levels = rownames(m))
    df$y <- factor(df$y, levels = rev(rownames(m)))
    ggplot(df, aes(x, y, fill = value)) +
      geom_tile() +
      scale_fill_viridis_c(option = "D", name = "distance") +
      theme_minimal(base_size = 11) +
      theme(axis.text.x = element_text(angle = 90, vjust = .5, hjust = 1),
            axis.title = element_blank())
  })

  output$dl_dist <- downloadHandler(
    filename = function() paste0("distance_", input$dist_metric, ".csv"),
    content = function(f) utils::write.csv(as.matrix(dist_obj()), f)
  )

  # ---- clustering ----
  tree_obj <- reactive({
    d <- dist_obj()
    if (input$clust_method == "nj") ape::nj(d)
    else hclust(d, method = input$clust_method)
  })

  output$dendro <- renderPlot({
    obj <- tree_obj()
    g <- groups()
    if (inherits(obj, "phylo")) {
      tipcol <- if (!is.null(g)) {
        pal <- grDevices::hcl.colors(nlevels(g), "Dark 3")
        pal[as.integer(g)][match(obj$tip.label, rownames(as.matrix(dist_obj())))]
      } else "black"
      ape::plot.phylo(obj, type = "unrooted", cex = .8, tip.color = tipcol,
                      lab4ut = "axial", no.margin = TRUE)
    } else {
      plot(obj, main = NULL, sub = "", xlab = "", cex = .8, hang = -1)
    }
  })

  output$dl_tree <- downloadHandler(
    filename = function() "genosuite_tree.nwk",
    content = function(f) {
      obj <- tree_obj()
      phy <- if (inherits(obj, "phylo")) obj else ape::as.phylo(obj)
      ape::write.tree(phy, file = f)
    }
  )

  # ---- ordination ----
  output$ord_plot <- renderPlot({
    ax <- input$ord_x; ay <- input$ord_y
    g <- groups()
    if (input$ord_method == "pca") {
      pr <- prcomp(scaled_mat(), scale. = FALSE)
      sco <- pr$x
      ve <- (pr$sdev^2) / sum(pr$sdev^2)
      xl <- sprintf("PC%d (%.1f%%)", ax, 100 * ve[ax])
      yl <- sprintf("PC%d (%.1f%%)", ay, 100 * ve[ay])
    } else {
      cm <- cmdscale(dist_obj(), k = max(ax, ay), eig = TRUE)
      sco <- cm$points
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
      pr <- prcomp(scaled_mat(), scale. = FALSE)
      ve <- (pr$sdev^2) / sum(pr$sdev^2)
    } else {
      cm <- cmdscale(dist_obj(), k = 8, eig = TRUE)
      ev <- cm$eig[cm$eig > 0]; ve <- ev / sum(ev)
    }
    ve <- head(ve, 10)
    df <- data.frame(axis = factor(seq_along(ve)), ve = 100 * ve)
    ggplot(df, aes(axis, ve)) +
      geom_col(fill = "#1f7a3d") +
      labs(x = "axis", y = "% variance") +
      theme_minimal(base_size = 13)
  })

  # ---- mantel ----
  mantel_res <- eventReactive(input$run_mantel, {
    X <- scaled_mat()
    da <- compute_distance(X, input$mantel_a)
    db <- compute_distance(X, input$mantel_b)
    list(r = vegan::mantel(da, db, permutations = input$mantel_perm),
         da = da, db = db)
  })

  output$mantel_out <- renderPrint({
    print(mantel_res()$r)
  })

  output$mantel_plot <- renderPlot({
    res <- mantel_res()
    df <- data.frame(a = as.vector(res$da), b = as.vector(res$db))
    ggplot(df, aes(a, b)) +
      geom_point(alpha = .4, colour = "#1f7a3d") +
      geom_smooth(method = "lm", se = FALSE, colour = "#b5651d") +
      labs(x = paste("distance:", names(which(DIST_CHOICES == input$mantel_a))),
           y = paste("distance:", names(which(DIST_CHOICES == input$mantel_b)))) +
      theme_minimal(base_size = 13)
  })
}

shinyApp(ui, server)
