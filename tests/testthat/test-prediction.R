test_that("genomic relationship matrix is square and symmetric", {
  G <- GSbench::Gmatrix(X, min_maf = 0.05)
  expect_equal(dim(G), c(nrow(X), nrow(X)))
  expect_true(isSymmetric(unname(G), tol = 1e-6))
})

test_that("GBLUP returns heritability in [0,1] and one GEBV per individual", {
  gb <- GSbench::gblup(y, geno = X)
  expect_true(gb$h2 >= 0 && gb$h2 <= 1)
  expect_equal(length(gb$gebv), nrow(X))
  expect_true(all(is.finite(gb$gebv)))
})

test_that("cross-validation runs and reports a finite accuracy", {
  cv <- GSbench::gs_cv(y, X, models = "gblup", k = 5, seed = 1)
  s  <- as.data.frame(summary(cv))
  expect_true("gblup" %in% s$model)
  expect_true(is.finite(s$mean[s$model == "gblup"]))
})

test_that("LD r-squared matrix is valid (bounded, unit diagonal)", {
  Xs <- X[, apply(X, 2, stats::sd) > 0, drop = FALSE]
  r2 <- cor(Xs)^2
  expect_true(all(r2 >= -1e-9 & r2 <= 1 + 1e-9))
  expect_equal(unname(diag(r2)), rep(1, ncol(Xs)), tolerance = 1e-8)
})
