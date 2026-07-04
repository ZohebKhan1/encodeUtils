# Created:
# 2026-07-04
#
# Inputs:
# - Current public ENCODE Portal metadata endpoints
#
# Outputs:
# - tests/testthat/fixtures/search-embedded-experiments.json
# - tests/testthat/fixtures/experiment-object.json
# - tests/testthat/fixtures/file-search-mixed.json
# - tests/testthat/fixtures/schema-file.json
# - tests/testthat/fixtures/matrix-small.json
# - tests/testthat/fixtures/report-small.tsv
# - tests/testthat/fixtures/report-empty.tsv
#
# Purpose:
# Refresh small offline test fixtures from live ENCODE API responses.
#
# Notes:
# Run from the package root with ENCODEUTILS_REFRESH_FIXTURES=true. Review the
# resulting diff before use. The file-search fixture keeps both
# experiment-backed and annotation-backed records.

if (!identical(base::Sys.getenv("ENCODEUTILS_REFRESH_FIXTURES"), "true")) {
  base::stop(
    "Refusing to refresh fixtures unless ENCODEUTILS_REFRESH_FIXTURES=true.",
    call. = FALSE
  )
}

for (package in c("httr2", "jsonlite")) {
  if (!base::requireNamespace(package, quietly = TRUE)) {
    base::stop("Package required to refresh fixtures is missing: ", package, call. = FALSE)
  }
}

fixture_dir <- base::file.path("tests", "testthat", "fixtures")
base::dir.create(fixture_dir, recursive = TRUE, showWarnings = FALSE)

base_url <- "https://www.encodeproject.org"

`%||%` <- function(x, y) {
  if (base::is.null(x)) {
    y
  } else {
    x
  }
}

fetch_json <- function(path, query = list()) {
  request <- httr2::request(base::paste0(base_url, path))
  request <- base::do.call(
    httr2::req_url_query,
    base::c(base::list(request), query, base::list(.multi = "explode"))
  )
  request <- httr2::req_headers(request, Accept = "application/json")
  request <- httr2::req_user_agent(request, "encodeUtils fixture refresh")
  response <- httr2::req_perform(request)
  httr2::resp_body_json(response, simplifyVector = FALSE)
}

write_json_data <- function(data, output) {
  jsonlite::write_json(
    data,
    path = base::file.path(fixture_dir, output),
    auto_unbox = TRUE,
    pretty = TRUE,
    null = "null"
  )
  data
}

write_json_fixture <- function(path, query, output) {
  write_json_data(fetch_json(path, query), output)
}

write_text_fixture <- function(path, query, output) {
  request <- httr2::request(base::paste0(base_url, path))
  request <- base::do.call(
    httr2::req_url_query,
    base::c(base::list(request), query, base::list(.multi = "explode"))
  )
  request <- httr2::req_headers(
    request,
    Accept = "text/tab-separated-values, text/plain, */*"
  )
  request <- httr2::req_user_agent(request, "encodeUtils fixture refresh")
  response <- httr2::req_perform(request)
  base::writeLines(
    httr2::resp_body_string(response),
    con = base::file.path(fixture_dir, output),
    useBytes = TRUE
  )
}

search <- write_json_fixture(
  path = "/search/",
  query = list(
    type = "Experiment",
    status = "released",
    assay_title = "total RNA-seq",
    limit = 2,
    format = "json",
    frame = "embedded"
  ),
  output = "search-embedded-experiments.json"
)

first_experiment <- search$`@graph`[[1L]]
first_experiment_id <- first_experiment$`@id`
if (base::is.null(first_experiment_id) || !base::nzchar(first_experiment_id)) {
  base::stop("Search fixture did not contain a usable experiment @id.", call. = FALSE)
}

write_json_fixture(
  path = first_experiment_id,
  query = list(format = "json", frame = "embedded"),
  output = "experiment-object.json"
)

experiment_files <- fetch_json(
  path = "/search/",
  query = list(
    type = "File",
    dataset = first_experiment_id,
    status = "released",
    limit = 2,
    format = "json",
    frame = "object"
  )
)
if (base::length(experiment_files$`@graph`) == 0L) {
  base::stop("Experiment file fixture query returned no files.", call. = FALSE)
}

annotation_search <- fetch_json(
  path = "/search/",
  query = list(
    type = "Annotation",
    status = "released",
    limit = 5,
    format = "json",
    frame = "object"
  )
)
annotation_paths <- base::vapply(
  annotation_search$`@graph`,
  function(record) record$`@id` %||% "",
  character(1L)
)
annotation_paths <- annotation_paths[base::nzchar(annotation_paths)]

annotation_files <- NULL
annotation_path <- NA_character_
for (path in annotation_paths) {
  candidate <- fetch_json(
    path = "/search/",
    query = list(
      type = "File",
      dataset = path,
      status = "released",
      limit = 1,
      format = "json",
      frame = "object"
    )
  )
  if (base::length(candidate$`@graph`) > 0L) {
    annotation_files <- candidate
    annotation_path <- path
    break
  }
}
if (base::is.null(annotation_files)) {
  base::stop("Could not find a released annotation-backed file fixture.", call. = FALSE)
}

experiment_accession <- first_experiment$accession
if (base::is.null(experiment_accession) || !base::nzchar(experiment_accession)) {
  experiment_accession <- base::sub("^/experiments/([^/]+)/$", "\\1", first_experiment_id)
}

# Preserve the specific edge cases guarded by test-fixture-contracts.R:
# experiment dataset metadata can arrive as an object, while annotation-backed
# file records must keep their original annotation dataset path.
experiment_files$`@graph`[[1L]]$dataset <- list(
  `@id` = first_experiment_id,
  `@type` = c("Experiment", "Dataset"),
  accession = experiment_accession
)
annotation_record <- annotation_files$`@graph`[[1L]]
annotation_record$dataset <- annotation_path

experiment_files$`@graph` <- base::c(
  experiment_files$`@graph`,
  base::list(annotation_record)
)
experiment_files$total <- base::length(experiment_files$`@graph`)
write_json_data(
  data = experiment_files,
  output = "file-search-mixed.json"
)

write_json_fixture(
  path = "/profiles/file.json",
  query = list(),
  output = "schema-file.json"
)

write_json_fixture(
  path = "/matrix/",
  query = list(type = "Experiment", status = "released", format = "json"),
  output = "matrix-small.json"
)

write_text_fixture(
  path = "/report.tsv",
  query = list(
    type = "Experiment",
    status = "released",
    field = c("accession", "assay_title"),
    limit = 2
  ),
  output = "report-small.tsv"
)

write_text_fixture(
  path = "/report.tsv",
  query = list(
    type = "Experiment",
    status = "released",
    searchTerm = "encodeUtils-intentionally-empty-fixture-query",
    field = "accession",
    limit = 0
  ),
  output = "report-empty.tsv"
)

base::cat("Refreshed test fixtures in ", fixture_dir, "\n", sep = "")
