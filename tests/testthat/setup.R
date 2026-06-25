# Load the app's functions and a shared demo dataset for all tests.
app_file <- testthat::test_path("..", "..", "app", "app.R")
suppressWarnings(suppressMessages(source(app_file, local = FALSE)))

demo <- simulate_demo()
X    <- numeric_matrix(demo, "ID", "Population", "Trait")
rownames(X) <- demo$ID
y    <- demo$Trait
