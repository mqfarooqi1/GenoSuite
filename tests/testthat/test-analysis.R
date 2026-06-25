test_that("simulate_demo returns the expected structure", {
  expect_s3_class(demo, "data.frame")
  expect_equal(nrow(demo), 36L)
  expect_true(all(c("ID", "Population", "Trait") %in% names(demo)))
  expect_equal(nlevels(factor(demo$Population)), 3L)
})

test_that("numeric_matrix drops ID / group / phenotype columns", {
  expect_true(is.matrix(X))
  expect_true(is.numeric(X))
  expect_equal(ncol(X), 60L)
  expect_false(any(c("ID", "Population", "Trait") %in% colnames(X)))
  expect_equal(rownames(X), demo$ID)
})

test_that("all distance metrics return valid dist objects", {
  for (m in DIST_CHOICES) {
    d <- compute_distance(X, m)
    expect_s3_class(d, "dist")
    expect_equal(length(d), choose(nrow(X), 2))
    expect_true(all(is.finite(as.numeric(d))))
    expect_true(all(as.numeric(d) >= -1e-9))
  }
})

test_that("diversity statistics fall in valid ranges", {
  dv <- diversity_stats(X)
  expect_equal(nrow(dv), ncol(X))
  expect_true(all(dv$MAF >= 0 & dv$MAF <= 0.5 + 1e-9))
  expect_true(all(dv$He  >= 0 & dv$He  <= 0.5 + 1e-9))   # 2pq, biallelic
  expect_true(all(dv$Ho  >= 0 & dv$Ho  <= 1))
  expect_true(all(dv$PIC >= 0 & dv$PIC <= 1))
})

test_that("Nei's Fst is bounded in [0, 1]", {
  fs <- fst_nei(X, demo$Population)
  expect_equal(nrow(fs), ncol(X))
  expect_true(all(fs$Fst >= -1e-9 & fs$Fst <= 1, na.rm = TRUE))
})

test_that("GWAS scan returns valid p-values and detects signal", {
  gw <- gwas_scan(y, X, n_pc = 2)
  expect_equal(nrow(gw), ncol(X))
  expect_true(all(gw$p >= 0 & gw$p <= 1, na.rm = TRUE))
  expect_true(max(gw$logp, na.rm = TRUE) > 1)   # at least some association
})
