test_that("stored fixtures preserve the ENCODE response contracts tests rely on", {
  search <- jsonlite::fromJSON(
    fixture_path("search-embedded-experiments.json"),
    simplifyVector = FALSE
  )
  expect_true(length(search$`@graph`) >= 2)
  expect_true(all(c("total", "filters", "facets", "columns") %in% names(search)))
  expect_true(all(c("@id", "@type", "accession", "status") %in% names(search$`@graph`[[1]])))
  expect_true(length(search$facets[[1]]$terms) >= 1)

  files <- jsonlite::fromJSON(
    fixture_path("file-search-mixed.json"),
    simplifyVector = FALSE
  )
  file_records <- files$`@graph`
  required_file_fields <- c(
    "@id", "@type", "accession", "dataset", "file_format",
    "output_type", "status", "href"
  )
  has_required_fields <- vapply(
    file_records,
    function(record) all(required_file_fields %in% names(record)),
    logical(1)
  )
  expect_true(all(has_required_fields))
  expect_true(any(vapply(
    file_records,
    function(record) identical(record$dataset, "/annotations/ENCSRANN001/"),
    logical(1)
  )))
  expect_true(any(vapply(
    file_records,
    function(record) is.list(record$dataset),
    logical(1)
  )))

  schema <- jsonlite::fromJSON(
    fixture_path("schema-file.json"),
    simplifyVector = FALSE
  )
  expect_true(all(c("title", "id", "required", "properties") %in% names(schema)))
  expect_true("accession" %in% names(schema$properties))
  expect_true("dataset" %in% names(schema$properties))
  expect_true("enum" %in% names(schema$properties$file_format))
})
