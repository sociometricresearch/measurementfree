validate_medesign <- function(x) {
  expect_length(x, 5)
  expect_s3_class(x, "medesign")
  expect_named(x)
  expect_true(all(names(x) == c("parsed_model",
                                ".data",
                                "me_data",
                                "corr",
                                "covv")))

  expect_true(all(vapply(x, nrow, FUN.VALUE = numeric(1)) > 0))
  expect_true(all(vapply(x, is.data.frame, FUN.VALUE = logical(1))))
  expect_s3_class(x$me_data, "me")
}

test_that("medesign raises error when bad model_syntax", {
  # 1) The variables defined in the model are present in `me_data`.
  model_syntax <- "~ mpg + cyl + drat"
  .data <- mtcars
  me_data <- data.frame(stringsAsFactors = FALSE,
                        question = c("mpg", "cyl"),
                        reliability = c(0.729, 0.815),
                        validity = c(0.951, 0.944),
                        quality = c(0.693, 0.77)
                        )

  expect_error(
    medesign(model_syntax, .data, me_data),
    regexp = "Variable(s) drat must be available in `me_data`",
    fixed = TRUE
  )

  # 2) The variables defined in the model have no missing values in `me_data`.
  model_syntax <- "~ mpg + cyl + drat"
  .data <- mtcars
  me_data <- data.frame(stringsAsFactors = FALSE,
                        question = c("mpg", "cyl", "drat"),
                        reliability = c(0.729, 0.815, 0.68),
                        validity = c(0.951, 0.944, NA),
                        quality = c(0.693, 0.77, 0.89)
                        )

  expect_error(
    medesign(model_syntax, .data, me_data),
    regexp = "`me_data` must have non-missing values at columns reliability and validity for all variables", #nolintr
    fixed = TRUE
  )

  # 3) The variables defined in the model are present in `data`.
  model_syntax <- "~ mpg + cyl + whatever + sec"
  .data <- mtcars
  me_data <- data.frame(stringsAsFactors = FALSE,
                        question = c("mpg", "cyl", "whatever", "sec"),
                        reliability = c(0.729, 0.815, 0.68, 0.79),
                        validity = c(0.951, 0.944, 0.79, 0.67),
                        quality = c(0.693, 0.77, 0.89, 0.9)
                        )
  expect_error(
    medesign(model_syntax, .data, me_data),
    regexp = "Variable(s) whatever, sec not available in `.data`",
    fixed = TRUE
  )

  # 4) The variables defined in the model are not complete missing in `data`.
  model_syntax <- "~ mpg + cyl + whatever"
  .data <- mtcars
  .data$whatever <- NA
  me_data <- data.frame(stringsAsFactors = FALSE,
                        question = c("mpg", "cyl", "whatever"),
                        reliability = c(0.729, 0.815, 0.68),
                        validity = c(0.951, 0.944, 0.79),
                        quality = c(0.693, 0.77, 0.89)
                        )

  expect_error(
    medesign(model_syntax, .data, me_data),
    regexp = "Variable(s) whatever are all NA in `.data`. Estimates cannot be calculated using these variables", #nolintr
    fixed = TRUE
  )

  # 5) Defining CMV with one variable raises error.
  model_syntax <- "~ mpg + cyl + whatever; ~ drat"
  .data <- mtcars
  me_data <- data.frame(stringsAsFactors = FALSE,
                        question = c("mpg", "cyl", "whatever"),
                        reliability = c(0.729, 0.815, 0.68),
                        validity = c(0.951, 0.944, 0.79),
                        quality = c(0.693, 0.77, 0.89)
                        )

  expect_error(
    medesign(model_syntax, .data, me_data),
    regexp = "You need to supply at least two variables to calculate the Common Method Variance (CMV) in '~ drat'", #nolintr
    fixed = TRUE
  )
})

test_that("medesign returns expected format", {
  # These three variables share a common method
  me_syntax <- "~ mpg + cyl + drat"
  # Fake data for the example
  me_data <- data.frame(stringsAsFactors = FALSE,
                        question = c("mpg", "cyl", "drat"),
                        reliability = c(0.729, 0.815, 0.68),
                        validity = c(0.951, 0.944, 0.79),
                        quality = c(0.693, 0.77, 0.89)
                        )
  res <- medesign(me_syntax, mtcars, me_data)
  validate_medesign(res)
})

test_that("medesign checks for wrong format of me_data", {
  num_vars <- paste0(me_env$me_columns, collapse = ", ")
  all_vars <- paste0(c(me_env$me_question, me_env$me_columns), collapse = ", ")

  names(mtcars)[1:3] <- c("V1", "V2", "V3")

  me_df <-
    tibble(question = paste0("V", 1:3),
           not_indf = c(0.2, 0.3, 0.5),
           reliability = c(NA, 0.4, 0.5),
           validity = c(NA, NA, 0.6))

  me_syntax <- "~ V1 + V2"
  expect_error(
    medesign(me_syntax, mtcars, me_df),
    paste0("Columns ",  all_vars, " must be available in `me_data`")
  )

  me_df <-
    tibble(question = paste0("V", 1:3),
           not_indf = c(0.2, 0.3, 0.5),
           reliability = c(NA, 0.4, 0.5),
           validity = c(NA, NA, 0.6))

  expect_error(
    medesign(me_syntax, mtcars, me_df),
    paste0("Columns ",  all_vars, " must be available in `me_data`")
  )

  me_df <-
    tibble(question = c("V1", "V2", "V3"),
           quality = c(0.2, 0.3, 0.5),
           reliability = c(NA, 0.4, 0.5),
           validity = c(NA, NA, 1.2))

  expect_error(
    medesign(me_syntax, mtcars, me_df),
    paste0(num_vars,
           " must be numeric columns with values between/including 0 and 1 in `me_data`" #nolintr
           )
  )

  me_df <-
    tibble(question = 1:3,
           quality = c(0.2, 0.3, 0.5),
           reliability = c(0.5, 0.4, 0.5),
           validity = c(0.1, 0.2, 0.9))

  expect_error(
    medesign(me_syntax, mtcars, me_df),
    paste0("Column ",
           me_env$me_question,
           " must be a character vector containing the question names"
           )
  )
  
})