# Run the GenoSuite test suite:  Rscript tests/run_tests.R
library(testthat)
test_dir("tests/testthat", reporter = "summary", stop_on_failure = TRUE)
