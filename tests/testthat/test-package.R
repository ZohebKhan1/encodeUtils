local_mock_options <- function() {
  withr::local_options(list(
    encodeUtils.rate_per_second = FALSE,
    encodeUtils.max_tries = 3,
    encodeUtils.retry_base_seconds = 0
  ))
}

mock_json_response <- function(body, status = 200) {
  httr2::response(
    status,
    headers = "Content-Type: application/json",
    body = charToRaw(body)
  )
}

mock_text_response <- function(body, status = 200) {
  httr2::response(
    status,
    headers = "Content-Type: text/tab-separated-values",
    body = charToRaw(body)
  )
}

experiment_search_json <- paste0(
  '{',
  '"@graph":[',
  '{"accession":"ENCSR000AAA","@id":"/experiments/ENCSR000AAA/",',
  '"assay_title":"total RNA-seq","assay_term_name":"RNA-seq",',
  '"target":{"label":"POLR2A"},',
  '"simple_biosample_summary":"female adult heart",',
  '"life_stage_age":"adult 34 years",',
  '"biosample_summary":"Homo sapiens heart tissue","biosample_ontology":{',
  '"classification":"tissue","term_name":"heart"},"status":"released",',
  '"lab":{"title":"Example Lab","institute_label":"Example University"},',
  '"award":{"project":"ENCODE","name":"U01HG000000"},',
  '"files":["/files/ENCFF000AAA/","/files/ENCFF000AAB/"]},',
  '{"accession":"ENCSR000AAB","@id":"/experiments/ENCSR000AAB/",',
  '"assay_title":"ChIP-seq","target":{"label":"H3K36me3"},',
  '"biosample_ontology":"/biosample-types/tissue_UBERON_0000000/",',
  '"lab":"/labs/example/","award":"/awards/example/",',
  '"status":"released"},',
  '{"accession":"ENCSR000AAC","@id":"/experiments/ENCSR000AAC/",',
  '"assay_title":"Control ChIP-seq","control_type":"input library",',
  '"biosample_ontology":"/biosample-types/tissue_UBERON_0000000/",',
  '"lab":"/labs/example/","award":"/awards/example/",',
  '"status":"released"}',
  '],',
  '"total":42,',
  '"columns":{"accession":{"title":"Accession"}},',
  '"filters":[{"field":"type","term":"Experiment"},',
  '{"field":"status","term":"released"}],',
  '"facets":[{"field":"assay_title","title":"Assay",',
  '"terms":[{"key":"total RNA-seq","doc_count":10}]}]',
  '}'
)

experiment_object_json <- paste0(
  '{',
  '"@type":["Experiment","Item"],"accession":"ENCSR000AAA",',
  '"@id":"/experiments/ENCSR000AAA/","assay_title":"total RNA-seq",',
  '"assay_term_name":"RNA-seq","target":{"label":"POLR2A"},',
  '"simple_biosample_summary":"female adult heart",',
  '"life_stage_age":"adult 34 years",',
  '"biosample_summary":"Homo sapiens heart tissue",',
  '"biosample_ontology":{"classification":"tissue","term_name":"heart"},',
  '"status":"released","lab":{"title":"Example Lab","institute_label":"Example University"},',
  '"award":{"project":"ENCODE","name":"U01HG000000"},',
  '"files":["/files/ENCFF000AAA/"]',
  '}'
)

file_search_json <- paste0(
  '{',
  '"@graph":[{',
  '"@type":["File","Item"],"accession":"ENCFF000AAA",',
  '"@id":"/files/ENCFF000AAA/","dataset":"/experiments/ENCSR000AAA/",',
  '"assay_title":"total RNA-seq","assay_term_name":"RNA-seq",',
  '"target":{"label":"POLR2A"},',
  '"simple_biosample_summary":"heart tissue","file_format":"txt",',
  '"file_type":"txt","output_type":"metadata","output_category":"metadata",',
  '"assembly":"GRCh38","genome_annotation":"GENCODE V29","file_size":3,',
  '"md5sum":"900150983cd24fb0d6963f7d28e17f72",',
  '"status":"released","href":"/files/ENCFF000AAA/@@download/ENCFF000AAA.txt",',
  '"biological_replicates":[1],"technical_replicates":["1_1"],',
  '"paired_end":"1","paired_with":"/files/ENCFF000AAB/",',
  '"preferred_default":true,"analyses":["/analyses/ENCAN000AAA/"],',
  '"analysis_step_version":"/analysis-step-versions/example-step/",',
  '"audit":{"WARNING":[{"category":"low read depth","detail":"small fixture"}]},',
  '"lab":{"title":"Example Lab","institute_label":"Example University"},',
  '"award":{"project":"ENCODE","name":"U01HG000000"},',
  '"biosample_ontology":{"organism":{"scientific_name":"Homo sapiens"}}',
  '}],',
  '"total":1,',
  '"filters":[{"field":"type","term":"File"}],',
  '"facets":[]',
  '}'
)

matrix_json <- paste0(
  '{',
  '"total":3,"filters":[],',
  '"matrix":{',
  '"x":{"group_by":"assay_title","label":"Assay","doc_count":3,',
  '"assay_title":{"buckets":[',
  '{"key":"total RNA-seq","doc_count":2},',
  '{"key":"ChIP-seq","doc_count":1}]}},',
  '"y":{"group_by":["biosample_ontology.classification","biosample_ontology.term_name"],',
  '"label":"Biosample","doc_count":3,',
  '"biosample_ontology.classification":{"buckets":[{',
  '"key":"tissue","doc_count":3,',
  '"biosample_ontology.term_name":{"buckets":[{',
  '"key":"heart","doc_count":3,',
  '"assay_title":{"buckets":[',
  '{"key":"total RNA-seq","doc_count":2},',
  '{"key":"ChIP-seq","doc_count":1}]}}]}}]}}}}'
)

schema_json <- paste0(
  '{',
  '"title":"Experiment","type":"object","id":"/profiles/experiment.json",',
  '"required":["award","lab"],',
  '"properties":{',
  '"accession":{"type":"string","title":"Accession","description":"ENCODE accession"},',
  '"files":{"type":"array","title":"Files","items":{"type":"string"}},',
  '"status":{"type":"string","enum":["released","archived"]}',
  '}}'
)

file_selection_table <- function() {
  data.frame(
    file_accession = c(
      "ENCFF000AAA", "ENCFF000AAB", "ENCFF000AAC", "ENCFF000AAD",
      "ENCFF000AAE", "ENCFF000AAF"
    ),
    experiment_accession = c(
      "ENCSR000AAA", "ENCSR000AAA", "ENCSR000AAB", "ENCSR000AAC",
      "ENCSR000AAD", "ENCSR000AAE"
    ),
    file_format = c("bed", "bed", "bed", "bed", "bigWig", "fastq"),
    output_type = c(
      "optimal IDR thresholded peaks", "replicated peaks",
      "optimal IDR thresholded peaks", "optimal IDR thresholded peaks",
      "fold change over control", "reads"
    ),
    assembly = c("GRCh38", "GRCh38", "hg19", "GRCh38", "GRCh38", NA),
    status = c("released", "released", "released", "archived", "released", "released"),
    href = c(
      "/files/ENCFF000AAA/@@download/ENCFF000AAA.bed",
      "/files/ENCFF000AAB/@@download/ENCFF000AAB.bed",
      "/files/ENCFF000AAC/@@download/ENCFF000AAC.bed",
      NA,
      "/files/ENCFF000AAE/@@download/ENCFF000AAE.bigWig",
      "/files/ENCFF000AAF/@@download/ENCFF000AAF.fastq.gz"
    ),
    file_size = c(100, 200, 300, 400, 500, 600),
    md5sum = NA_character_,
    biological_replicates = c(NA, "1", NA, NA, NA, "1"),
    preferred_default = c(TRUE, FALSE, TRUE, TRUE, TRUE, NA),
    stringsAsFactors = FALSE
  )
}

test_that("encode_search parses experiment results and metadata", {
  local_mock_options()
  result <- httr2::with_mocked_responses(
    function(req) mock_json_response(experiment_search_json),
    encode_search(quiet = TRUE)
  )

  testthat::expect_s3_class(result, "encode_search_result")
  testthat::expect_equal(result$total, 42)
  testthat::expect_equal(nrow(result$results), 3)
  testthat::expect_equal(result$results$accession[[1]], "ENCSR000AAA")
  testthat::expect_equal(result$results$organism[[1]], "Homo sapiens")
  testthat::expect_equal(result$results$sample_summary[[1]], "female adult heart")
  testthat::expect_equal(result$results$life_stage_age[[1]], "adult 34 years")
  testthat::expect_equal(result$results$sex[[1]], "female")
  testthat::expect_equal(result$results$file_count[[1]], 2)
  testthat::expect_true(is.na(result$results$biosample_classification[[2]]))
  testthat::expect_equal(result$results$control_type[[3]], "input library")
  testthat::expect_equal(result$facets$count[[1]], 10)
  testthat::expect_equal(result$columns$field[[1]], "accession")
  testthat::expect_match(encode_query_url(result), "/search/", fixed = TRUE)
  testthat::expect_match(encode_query_url(result), "frame=embedded", fixed = TRUE)
  testthat::expect_match(attr(result$results, "query_url"), "/search/", fixed = TRUE)
  testthat::expect_equal(encode_facets(result)$term[[1]], "total RNA-seq")
  testthat::expect_true("status" %in% encode_filters(result)$field)
})

test_that("object frame is available but produces lean linked metadata", {
  local_mock_options()
  observed_url <- NULL
  result <- httr2::with_mocked_responses(
    function(req) {
      observed_url <<- req$url
      mock_json_response(experiment_search_json)
    },
    encode_search(metadata = "basic", quiet = TRUE)
  )

  testthat::expect_match(observed_url, "frame=object", fixed = TRUE)
  testthat::expect_equal(result$frame, "object")
  testthat::expect_equal(result$metadata, "basic")
  testthat::expect_equal(result$results$lab[[2]], "example")
  testthat::expect_true(is.na(result$results$institution[[2]]))
  testthat::expect_equal(result$results$control_type[[3]], "input library")
})

test_that("metadata maps to ENCODE frame values", {
  local_mock_options()
  observed_url <- NULL
  result <- httr2::with_mocked_responses(
    function(req) {
      observed_url <<- req$url
      mock_json_response(experiment_search_json)
    },
    encode_search(metadata = "basic", quiet = TRUE)
  )

  testthat::expect_match(observed_url, "frame=object", fixed = TRUE)
  testthat::expect_equal(result$metadata, "basic")
  testthat::expect_equal(result$frame, "object")
})

test_that("encode_search uses ENCODE-compatible negation and repeated filters", {
  local_mock_options()
  observed_url <- NULL
  httr2::with_mocked_responses(
    function(req) {
      observed_url <<- req$url
      mock_json_response('{"@graph":[],"total":0}')
    },
    encode_search(
      filters = list(
        "control_type!=" = "*",
        perturbed = FALSE,
        assay_title = c("total RNA-seq", "ChIP-seq")
      ),
      quiet = TRUE
    )
  )

  testthat::expect_match(observed_url, "control_type%21=%2A", fixed = TRUE)
  testthat::expect_match(observed_url, "perturbed=false", fixed = TRUE)
  testthat::expect_match(observed_url, "assay_title=total%20RNA-seq", fixed = TRUE)
  testthat::expect_match(observed_url, "assay_title=ChIP-seq", fixed = TRUE)
  testthat::expect_false(grepl("control_type%21%3D", observed_url, fixed = TRUE))
})

test_that("encode_search handles empty ENCODE search responses without masking invalid objects", {
  local_mock_options()
  observed_url <- NULL
  result <- httr2::with_mocked_responses(
    function(req) {
      observed_url <<- req$url
      mock_json_response(
        '{"@graph":[],"total":0,"title":"Search","notification":"No results found"}',
        status = 404
      )
    },
    encode_search(include_facets = FALSE, quiet = TRUE)
  )

  testthat::expect_equal(nrow(result$results), 0)
  testthat::expect_equal(result$total, 0)
  testthat::expect_equal(nrow(result$facets), 0)
  testthat::expect_false(grepl("facets=false", observed_url, fixed = TRUE))
  testthat::expect_false(grepl("facets=", observed_url, fixed = TRUE))
})

test_that("HTTP errors, malformed JSON, and transient retries fail clearly", {
  local_mock_options()
  testthat::expect_error(
    httr2::with_mocked_responses(
      function(req) mock_json_response(
        '{"description":"No such object","title":"Not found"}',
        status = 404
      ),
      encode_search(quiet = TRUE)
    ),
    "HTTP 404.*No such object"
  )

  testthat::expect_error(
    httr2::with_mocked_responses(
      function(req) httr2::response(
        200,
        headers = "Content-Type: application/json",
        body = charToRaw('{"@graph":')
      ),
      encode_search(quiet = TRUE)
    ),
    "malformed JSON"
  )

  calls <- 0L
  testthat::expect_error(
    httr2::with_mocked_responses(
      function(req) {
        calls <<- calls + 1L
        mock_json_response('{"description":"try later"}', status = 503)
      },
      encode_search(quiet = TRUE)
    ),
    "HTTP 503"
  )
  testthat::expect_equal(calls, 3L)

  calls_429 <- 0L
  testthat::expect_error(
    httr2::with_mocked_responses(
      function(req) {
        calls_429 <<- calls_429 + 1L
        mock_json_response('{"description":"rate limited"}', status = 429)
      },
      encode_search(quiet = TRUE)
    ),
    "HTTP 429"
  )
  testthat::expect_equal(calls_429, 3L)
})

test_that("limit and retry-count validation reject unsafe values", {
  local_mock_options()
  testthat::expect_error(
    encode_search(limit = 1.5, quiet = TRUE),
    "whole number"
  )
  testthat::expect_error(
    encode_search(limit = -1, quiet = TRUE),
    "whole number"
  )
  withr::local_options(list(encodeUtils.max_tries = 0))
  testthat::expect_error(
    httr2::with_mocked_responses(
      function(req) mock_json_response('{"@graph":[],"total":0}'),
      encode_search(quiet = TRUE)
    ),
    "positive whole number"
  )
})

test_that("Retry-After headers are parsed for retry backoff", {
  response <- httr2::response(
    429,
    headers = list("Retry-After" = "0.25"),
    body = charToRaw("")
  )
  testthat::expect_equal(encode_retry_after(response), 0.25)
})

test_that("encode_count returns live totals without returned rows", {
  local_mock_options()
  observed_url <- NULL
  count <- httr2::with_mocked_responses(
    function(req) {
      observed_url <<- req$url
      mock_json_response('{"@graph":[],"total":12,"filters":[{"field":"type","term":"Experiment"}]}')
    },
    encode_count(filters = list(assay_title = "RNA-seq"), quiet = TRUE)
  )

  testthat::expect_s3_class(count, "encode_count_result")
  testthat::expect_equal(count$total, 12)
  testthat::expect_match(observed_url, "limit=0", fixed = TRUE)
  testthat::expect_match(count$query_url, "/search/", fixed = TRUE)
})

test_that("encode_list_files normalizes file metadata from experiments", {
  local_mock_options()
  files <- httr2::with_mocked_responses(
    function(req) mock_json_response(file_search_json),
    encode_list_files("ENCSR000AAA", file_format = "txt", quiet = TRUE)
  )

  testthat::expect_s3_class(files, "encode_file_table")
  testthat::expect_equal(nrow(files), 1)
  testthat::expect_equal(files$file_accession[[1]], "ENCFF000AAA")
  testthat::expect_equal(files$experiment_accession[[1]], "ENCSR000AAA")
  testthat::expect_equal(files$dataset[[1]], "/experiments/ENCSR000AAA/")
  testthat::expect_equal(files$dataset_accession[[1]], "ENCSR000AAA")
  testthat::expect_equal(files$dataset_type[[1]], "Experiment")
  testthat::expect_equal(files$genome_annotation[[1]], "GENCODE V29")
  testthat::expect_true(files$preferred_default[[1]])
  testthat::expect_equal(files$analyses[[1]], "/analyses/ENCAN000AAA/")
  testthat::expect_equal(files$institution[[1]], "Example University")
  testthat::expect_equal(files$project[[1]], "ENCODE")
  testthat::expect_equal(files$organism[[1]], "Homo sapiens")
  testthat::expect_match(files$audit_warnings[[1]], "low read depth")
  testthat::expect_equal(files$file_size_pretty[[1]], "3 B")
  testthat::expect_match(attr(files, "url"), "dataset=%2Fexperiments%2FENCSR000AAA%2F", fixed = TRUE)
  testthat::expect_match(encode_query_url(files), "/search/", fixed = TRUE)
})

test_that("file metadata preserves non-experiment dataset identity", {
  local_mock_options()
  annotation_json <- paste0(
    '{',
    '"@graph":[{',
    '"@type":["File","Item"],"accession":"ENCFF000ANN",',
    '"@id":"/files/ENCFF000ANN/","dataset":"/annotations/ENCSR000ANN/",',
    '"file_format":"bed","output_type":"annotation","status":"released",',
    '"href":"/files/ENCFF000ANN/@@download/ENCFF000ANN.bed"',
    '}],',
    '"total":1,"filters":[],"facets":[]',
    '}'
  )
  files <- httr2::with_mocked_responses(
    function(req) mock_json_response(annotation_json),
    encode_search(type = "File", quiet = TRUE)$results
  )

  testthat::expect_equal(files$dataset[[1]], "/annotations/ENCSR000ANN/")
  testthat::expect_equal(files$dataset_accession[[1]], "ENCSR000ANN")
  testthat::expect_equal(files$dataset_type[[1]], "Annotation")
  testthat::expect_true(is.na(files$experiment_accession[[1]]))
})

test_that("encode_file_summary and size helpers summarize file tables", {
  files <- file_selection_table()
  summary <- encode_file_summary(files)

  testthat::expect_s3_class(summary, "encode_file_summary")
  testthat::expect_equal(summary$n_files, 6)
  testthat::expect_equal(summary$n_experiments, 5)
  testthat::expect_equal(summary$total_size, 2100)
  testthat::expect_equal(encode_size(files), 2100)
  testthat::expect_equal(encode_largest_files(files, n = 1)$file_accession[[1]], "ENCFF000AAF")
  testthat::expect_equal(encode_summary(files)$n_files, 6)

  mixed_sizes <- files
  mixed_sizes$file_size <- c("100", "NA", NA_character_, "bad", "400", "0")
  mixed_summary <- encode_file_summary(mixed_sizes)
  testthat::expect_equal(mixed_summary$total_size, 500)
  testthat::expect_equal(encode_size(mixed_sizes), 500)
  testthat::expect_equal(encode_largest_files(mixed_sizes, n = 1)$file_accession[[1]], "ENCFF000AAE")
})

test_that("file print methods do not recurse on file table subclasses", {
  files <- file_selection_table()
  class(files) <- c("encode_file_table", "data.frame")
  selected <- encode_select_files(files, preset = "peaks", explain = FALSE)
  capture_print <- function(expr) {
    expr <- substitute(expr)
    utils::capture.output(
      utils::capture.output(eval(expr, parent.frame()), type = "message")
    )
  }

  subset <- files[, c("file_accession", "file_size")]
  testthat::expect_false(inherits(subset, "encode_file_table"))
  testthat::expect_no_error(capture_print(print(subset)))
  testthat::expect_no_error(capture_print(print(selected)))
})

test_that("encode_select_files applies presets and keeps exclusion reasons", {
  files <- file_selection_table()
  attr(files, "query_url") <- "https://www.encodeproject.org/search/?type=File"
  selected <- encode_select_files(
    files,
    preset = "peaks",
    assembly = "GRCh38",
    replicate_policy = "preferred_processed",
    explain = FALSE
  )

  testthat::expect_s3_class(selected, "encode_selected_files")
  testthat::expect_s3_class(selected$files, "encode_file_table")
  testthat::expect_equal(selected$files$file_accession, "ENCFF000AAA")
  testthat::expect_true(any(grepl("lower-priority output type", selected$excluded$reason)))
  testthat::expect_true(any(grepl("wrong assembly", selected$excluded$reason)))
  testthat::expect_true(any(grepl("wrong status", selected$excluded$reason)))
  testthat::expect_true(any(grepl("wrong file format", selected$excluded$reason)))
  testthat::expect_match(encode_query_url(selected), "type=File", fixed = TRUE)

  replicate_level <- encode_select_files(
    files,
    preset = "raw_reads",
    replicate_policy = "replicate_level",
    explain = FALSE
  )
  testthat::expect_equal(replicate_level$files$file_accession, "ENCFF000AAF")
  preferred <- encode_select_files(
    files,
    preset = "chipseq_peaks",
    prefer_default = TRUE,
    explain = FALSE
  )
  testthat::expect_true(all(preferred$files$preferred_default))
  testthat::expect_true(any(grepl("not preferred_default", preferred$excluded$reason)))
  testthat::expect_true(preferred$criteria$preferred_default_used)
  fastq_preferred <- encode_select_files(
    files,
    preset = "raw_reads",
    prefer_default = TRUE,
    explain = FALSE
  )
  testthat::expect_equal(fastq_preferred$files$file_accession, "ENCFF000AAF")
  testthat::expect_false(fastq_preferred$criteria$preferred_default_used)
  testthat::expect_false(fastq_preferred$criteria$preferred_default_available)
  empty <- encode_select_files(files[0, ], preset = "peaks", explain = FALSE)
  testthat::expect_s3_class(empty, "encode_selected_files")
  testthat::expect_equal(nrow(empty$files), 0)
  testthat::expect_error(encode_file_preset("not_a_preset"), "must be one of")
})

test_that("encode_explain_selection returns selected and excluded reasons", {
  selected <- encode_select_files(
    file_selection_table(),
    preset = "raw_fastq",
    explain = FALSE
  )
  explanation <- encode_explain_selection(selected)

  testthat::expect_equal(
    explanation$decision[match("ENCFF000AAF", explanation$file_accession)],
    "selected"
  )
  testthat::expect_true(any(explanation$decision == "excluded"))
  testthat::expect_true("chipseq_idr_peaks" %in% encode_select_files())
  testthat::expect_equal(encode_select_files(preset = "rna_gene_tpm")$preset, "rna_gene_tpm")

  all_selected <- data.frame(
    file_accession = "ENCFF000AAA",
    experiment_accession = "ENCSR000AAA",
    file_format = "fastq",
    output_type = "reads",
    status = "released",
    href = "https://example.org/file.fastq.gz",
    stringsAsFactors = FALSE
  )
  no_exclusions <- encode_select_files(all_selected, preset = "raw_fastq", explain = FALSE)
  testthat::expect_equal(nrow(encode_explain_selection(no_exclusions)), 1)
})

test_that("encode_select_files can select explicit file accessions", {
  files <- file_selection_table()
  selected <- encode_select_files(
    files,
    file_accession = c("ENCFF000AAF", "ENCFF000AAA"),
    status = NULL,
    require_href = FALSE,
    explain = FALSE
  )
  testthat::expect_equal(selected$files$file_accession, c("ENCFF000AAF", "ENCFF000AAA"))
  testthat::expect_true(any(grepl("not requested file accession", selected$excluded$reason)))
  testthat::expect_error(
    encode_select_files(
      files,
      file_accession = "ENCFFDOESNOTEXIST",
      status = NULL,
      require_href = FALSE,
      explain = FALSE
    ),
    "not found"
  )
})

test_that("encode_download plans safely and verifies existing files", {
  local_mock_options()
  destination <- withr::local_tempdir()
  existing_path <- file.path(destination, "ENCFF000AAA.txt")
  writeBin(charToRaw("abc"), existing_path)
  files <- data.frame(
    file_accession = "ENCFF000AAA",
    experiment_accession = "ENCSR000AAA",
    href = "/files/ENCFF000AAA/@@download/ENCFF000AAA.txt",
    file_size = 3,
    md5sum = "900150983cd24fb0d6963f7d28e17f72",
    status = "released",
    stringsAsFactors = FALSE
  )

  dry <- encode_download(files, directory = destination, dry_run = TRUE, quiet = TRUE)
  testthat::expect_s3_class(dry, "encode_download_result")
  testthat::expect_equal(dry$download_status[[1]], "planned")
  testthat::expect_equal(dry$local_path[[1]], existing_path)
  testthat::expect_equal(dry$md5sum_expected[[1]], files$md5sum[[1]])

  result <- encode_download(files, directory = destination, quiet = TRUE)
  testthat::expect_equal(result$download_status[[1]], "exists")
  testthat::expect_true(result$size_verified[[1]])
  testthat::expect_true(result$md5_verified[[1]])
  testthat::expect_true(result$size_ok[[1]])
  testthat::expect_true(result$md5_ok[[1]])

  files$file_size <- 10^9
  testthat::expect_error(
    encode_download(files, directory = destination, max_file_size = "1MB", dry_run = TRUE, quiet = TRUE),
    "max_file_size"
  )
})

test_that("encode_download reports and gates unknown-size files", {
  local_mock_options()
  destination <- withr::local_tempdir()
  files <- data.frame(
    file_accession = "ENCFF000UNK",
    href = "/files/ENCFF000UNK/@@download/ENCFF000UNK.txt",
    file_size = NA_real_,
    md5sum = "900150983cd24fb0d6963f7d28e17f72",
    stringsAsFactors = FALSE
  )

  dry <- encode_download(files, directory = destination, dry_run = TRUE, quiet = TRUE)
  testthat::expect_equal(attr(dry, "unknown_size_count"), 1L)
  testthat::expect_equal(attr(dry, "known_total_size"), 0)
  testthat::expect_error(
    encode_download(files, directory = destination, quiet = TRUE),
    "unknown file size"
  )

  testthat::local_mocked_bindings(
    encode_perform_file = function(url, path, timeout = NULL) {
      writeBin(charToRaw("abc"), path)
      list(url = url, status_code = 200L, retrieved_at = Sys.time())
    }
  )
  allowed <- encode_download(
    files,
    directory = destination,
    allow_unknown_size = TRUE,
    quiet = TRUE
  )
  testthat::expect_equal(allowed$download_status[[1]], "downloaded")
  testthat::expect_true(is.na(allowed$size_verified[[1]]))
  testthat::expect_true(allowed$md5_verified[[1]])
})

test_that("encode_download removes stale part files after failed transfer", {
  local_mock_options()
  destination <- withr::local_tempdir()
  files <- data.frame(
    file_accession = "ENCFF000BAD",
    href = "/files/ENCFF000BAD/@@download/ENCFF000BAD.txt",
    file_size = 3,
    md5sum = "900150983cd24fb0d6963f7d28e17f72",
    stringsAsFactors = FALSE
  )
  planned <- encode_download(files, directory = destination, dry_run = TRUE, quiet = TRUE)

  testthat::local_mocked_bindings(
    encode_perform_file = function(url, path, timeout = NULL) {
      writeBin(charToRaw("abc"), path)
      cli::cli_abort("simulated transfer failure")
    }
  )
  testthat::expect_warning(
    failed <- encode_download(files, directory = destination, quiet = TRUE),
    "Failed to download or verify"
  )

  testthat::expect_equal(failed$download_status[[1]], "failed")
  testthat::expect_false(file.exists(paste0(planned$local_path[[1]], ".part")))
})

test_that("encode_download handles cloud fallback, duplicate paths, and verification failures", {
  local_mock_options()
  destination <- withr::local_tempdir()
  files <- data.frame(
    file_accession = c("ENCFF000AAA", "ENCFF000AAB"),
    href = c(NA_character_, NA_character_),
    cloud_url = c(
      "https://example.org/shared.txt",
      "https://example.org/shared.txt"
    ),
    file_size = c(3, 3),
    md5sum = c("900150983cd24fb0d6963f7d28e17f72", "900150983cd24fb0d6963f7d28e17f72"),
    stringsAsFactors = FALSE
  )

  dry <- encode_download(
    files,
    directory = destination,
    prefer_cloud = TRUE,
    dry_run = TRUE,
    quiet = TRUE
  )
  testthat::expect_equal(dry$download_url, files$cloud_url)
  testthat::expect_equal(length(unique(dry$local_path)), 2)

  files_with_unknown_size <- files
  files_with_unknown_size$file_size <- c("NA", "3")
  dry_unknown_size <- encode_download(
    files_with_unknown_size,
    directory = destination,
    prefer_cloud = TRUE,
    max_file_size = "4B",
    dry_run = TRUE,
    quiet = TRUE
  )
  testthat::expect_true(is.na(dry_unknown_size$file_size[[1]]))
  testthat::expect_equal(dry_unknown_size$file_size[[2]], 3)

  testthat::local_mocked_bindings(
    encode_perform_file = function(url, path, timeout = NULL) {
      writeBin(charToRaw("bad"), path)
      list(url = url, status_code = 200L, retrieved_at = Sys.time())
    }
  )
  testthat::expect_warning(
    failed <- encode_download(files[1, , drop = FALSE], directory = destination, prefer_cloud = TRUE, quiet = TRUE),
    "Failed to download or verify"
  )
  testthat::expect_equal(failed$download_status[[1]], "failed")
  testthat::expect_match(failed$failure_reason[[1]], "failed size or MD5")
  testthat::expect_error(
    encode_download(
      data.frame(file_accession = "ENCFF000AAC", href = NA_character_, cloud_url = NA_character_),
      directory = destination,
      dry_run = TRUE,
      quiet = TRUE
    ),
    "download"
  )
})

test_that("encode_download writes new files through the transfer path", {
  local_mock_options()
  destination <- withr::local_tempdir()
  files <- data.frame(
    file_accession = "ENCFF000AAA",
    experiment_accession = "ENCSR000AAA",
    href = "/files/ENCFF000AAA/@@download/ENCFF000AAA.txt",
    file_size = 3,
    md5sum = "900150983cd24fb0d6963f7d28e17f72",
    status = "released",
    stringsAsFactors = FALSE
  )

  testthat::local_mocked_bindings(
    encode_perform_file = function(url, path, timeout = NULL) {
      writeBin(charToRaw("abc"), path)
      list(url = url, status_code = 200L, retrieved_at = Sys.time())
    }
  )

  result <- encode_download(files, directory = destination, quiet = TRUE)

  testthat::expect_equal(result$download_status[[1]], "downloaded")
  testthat::expect_true(file.exists(result$local_path[[1]]))
  testthat::expect_true(result$size_verified[[1]])
  testthat::expect_true(result$md5_verified[[1]])
  testthat::expect_equal(result$downloaded_size[[1]], 3)
  testthat::expect_equal(result$md5sum_observed[[1]], "900150983cd24fb0d6963f7d28e17f72")
})

test_that("encode_download preserves successful rows when later rows fail", {
  local_mock_options()
  destination <- withr::local_tempdir()
  files <- data.frame(
    file_accession = c("ENCFF000AAA", "ENCFF000AAB"),
    href = c(
      "/files/ENCFF000AAA/@@download/ENCFF000AAA.txt",
      "/files/ENCFF000AAB/@@download/ENCFF000AAB.txt"
    ),
    file_size = c(3, 3),
    md5sum = c(
      "900150983cd24fb0d6963f7d28e17f72",
      "900150983cd24fb0d6963f7d28e17f72"
    ),
    stringsAsFactors = FALSE
  )
  calls <- 0L
  testthat::local_mocked_bindings(
    encode_perform_file = function(url, path, timeout = NULL) {
      calls <<- calls + 1L
      if (calls == 1L) {
        writeBin(charToRaw("abc"), path)
      } else {
        writeBin(charToRaw("bad"), path)
      }
      list(url = url, status_code = 200L, retrieved_at = Sys.time())
    }
  )

  testthat::expect_warning(
    result <- encode_download(files, directory = destination, quiet = TRUE),
    "Failed to download or verify"
  )

  testthat::expect_equal(result$download_status, c("downloaded", "failed"))
  testthat::expect_true(result$md5_verified[[1]])
  testthat::expect_false(result$md5_verified[[2]])
  testthat::expect_match(result$failure_reason[[2]], "failed size or MD5")
})

test_that("encode_read loads safe text and JSON files and returns local-file objects otherwise", {
  csv_path <- withr::local_tempfile(fileext = ".csv")
  json_path <- withr::local_tempfile(fileext = ".json")
  bam_path <- withr::local_tempfile(fileext = ".bam")
  fastq_path <- withr::local_tempfile(fileext = ".fastq")
  bw_path <- withr::local_tempfile(fileext = ".bigWig")
  writeLines(c("a,b", "1,2"), csv_path)
  writeLines('{"a":1,"b":[2,3]}', json_path)
  writeBin(charToRaw("abc"), bam_path)
  writeBin(charToRaw("abc"), fastq_path)
  writeBin(charToRaw("abc"), bw_path)

  csv <- encode_read(csv_path)
  json <- encode_read(json_path)
  bam <- encode_read(bam_path)
  fastq <- encode_read(fastq_path)
  bw <- encode_read(bw_path)

  testthat::expect_equal(csv$a[[1]], 1L)
  testthat::expect_equal(json$a, 1)
  testthat::expect_s3_class(bam, "encode_local_file")
  testthat::expect_match(bam$reason, "alignment files")
  testthat::expect_s3_class(fastq, "encode_local_file")
  testthat::expect_match(fastq$reason, "FASTQ")
  testthat::expect_s3_class(bw, "encode_local_file")
  testthat::expect_match(bw$reason, "region")
  testthat::expect_error(encode_read(fastq_path, unsupported = "error"), "FASTQ")
  testthat::expect_s3_class(encode_read(csv_path, max_size = 1), "encode_local_file")
})

test_that("optional Bioconductor readers load small local files when installed", {
  testthat::skip_if_not_installed("rtracklayer")
  bed_path <- withr::local_tempfile(fileext = ".bed")
  writeLines("chr1\t0\t10\tpeak1", bed_path)
  bed <- encode_read(bed_path)
  testthat::expect_s4_class(bed, "GRanges")
})

test_that("optional FASTA reader loads small local files when installed", {
  testthat::skip_if_not_installed("Biostrings")
  fasta_path <- withr::local_tempfile(fileext = ".fa")
  writeLines(c(">seq1", "ACGT"), fasta_path)
  fasta <- encode_read(fasta_path)
  testthat::expect_s4_class(fasta, "DNAStringSet")
})

test_that("encode_get_schema returns property metadata", {
  local_mock_options()
  schema <- httr2::with_mocked_responses(
    function(req) mock_json_response(schema_json),
    encode_get_schema("Experiment", quiet = TRUE)
  )

  testthat::expect_s3_class(schema, "encode_schema_result")
  testthat::expect_equal(schema$title, "Experiment")
  testthat::expect_true("accession" %in% schema$properties$property)
  testthat::expect_true("lab" %in% schema$required)
  testthat::expect_match(schema$url, "/profiles/experiment.json", fixed = TRUE)
  fields <- httr2::with_mocked_responses(
    function(req) mock_json_response(schema_json),
    encode_search_fields("Experiment")
  )
  testthat::expect_true("accession" %in% fields$property)
})

test_that("encode_manifest adds ENCODE attribution metadata", {
  files <- data.frame(
    file_accession = c("ENCFF000AAA", "ENCFF000AAB"),
    experiment_accession = c("ENCSR000AAA", "ENCSR000AAA"),
    lab = c("Example Lab", "Example Lab"),
    institution = c("Example University", "Example University"),
    project = c("ENCODE", "ENCODE"),
    assay_title = c("total RNA-seq", "total RNA-seq"),
    biosample_summary = c("heart tissue", "heart tissue"),
    organism = c("Homo sapiens", "Homo sapiens"),
    file_format = c("txt", "txt"),
    output_type = c("metadata", "metadata"),
    assembly = c("GRCh38", "GRCh38"),
    md5sum = c(
      "900150983cd24fb0d6963f7d28e17f72",
      "900150983cd24fb0d6963f7d28e17f72"
    ),
    status = c("released", "released"),
    url = c(
      "https://www.encodeproject.org/files/ENCFF000AAA/",
      "https://www.encodeproject.org/files/ENCFF000AAB/"
    ),
    download_url = c(
      "https://www.encodeproject.org/files/ENCFF000AAA/@@download/ENCFF000AAA.txt",
      "https://www.encodeproject.org/files/ENCFF000AAB/@@download/ENCFF000AAB.txt"
    ),
    stringsAsFactors = FALSE
  )

  manifest <- encode_manifest(files, include_session = FALSE)
  table <- manifest$attribution

  testthat::expect_s3_class(table, "encode_attribution_table")
  testthat::expect_equal(table$dataset_accession[[1]], "ENCSR000AAA")
  testthat::expect_equal(table$dataset_type[[1]], "Experiment")
  testthat::expect_equal(table$experiment_accession[[1]], "ENCSR000AAA")
  testthat::expect_equal(nrow(table), 2)
  testthat::expect_match(table$dataset_url[[2]], "/experiments/ENCSR000AAA/", fixed = TRUE)
  testthat::expect_match(table$experiment_url[[2]], "/experiments/ENCSR000AAA/", fixed = TRUE)
  testthat::expect_match(table$attribution_guidance_url[[1]], "citing-encode", fixed = TRUE)
})

test_that("manifest attribution can enrich file tables from parent experiments", {
  local_mock_options()
  files <- data.frame(
    file_accession = "ENCFF000AAA",
    experiment_accession = "ENCSR000AAA",
    lab = "example-lab",
    status = "released",
    stringsAsFactors = FALSE
  )

  enriched <- httr2::with_mocked_responses(
    function(req) mock_json_response(experiment_search_json),
    encode_attribution(files, quiet = TRUE)
  )

  testthat::expect_equal(enriched$lab[[1]], "Example Lab")
  testthat::expect_equal(enriched$institution[[1]], "Example University")
  testthat::expect_equal(enriched$project[[1]], "ENCODE")
  testthat::expect_equal(enriched$organism[[1]], "Homo sapiens")
})

test_that("manifest attribution handles annotation datasets and bounded auto enrichment", {
  annotation_files <- data.frame(
    file_accession = "ENCFF000ANN",
    dataset = "/annotations/ENCSR000ANN/",
    dataset_accession = "ENCSR000ANN",
    dataset_type = "Annotation",
    status = "released",
    url = "https://www.encodeproject.org/files/ENCFF000ANN/",
    stringsAsFactors = FALSE
  )
  annotation <- encode_manifest(annotation_files, include_session = FALSE)$attribution

  testthat::expect_equal(annotation$dataset_accession[[1]], "ENCSR000ANN")
  testthat::expect_equal(annotation$dataset_type[[1]], "Annotation")
  testthat::expect_true(is.na(annotation$experiment_accession[[1]]))
  testthat::expect_match(annotation$dataset_url[[1]], "/annotations/ENCSR000ANN/", fixed = TRUE)
  testthat::expect_true(is.na(annotation$experiment_url[[1]]))

  many <- data.frame(
    file_accession = paste0("ENCFF", sprintf("%06d", 1:11)),
    experiment_accession = paste0("ENCSR", sprintf("%06d", 1:11)),
    status = "released",
    stringsAsFactors = FALSE
  )
  testthat::expect_message(
    skipped <- encode_attribution(many, max_enrich_datasets = 10, quiet = FALSE),
    "Skipping attribution enrichment"
  )
  testthat::expect_equal(nrow(skipped), 11)
})

test_that("encode_manifest records selected files and writes JSON", {
  selected <- encode_select_files(
    file_selection_table(),
    preset = "peaks",
    assembly = "GRCh38",
    explain = FALSE
  )
  path <- withr::local_tempfile(fileext = ".json")
  manifest <- encode_manifest(selected, include_session = FALSE, path = path)

  parsed <- jsonlite::fromJSON(path, simplifyVector = FALSE)

  testthat::expect_s3_class(manifest, "encode_manifest")
  testthat::expect_true(file.exists(path))
  testthat::expect_equal(attr(manifest, "path", exact = TRUE), path)
  testthat::expect_equal(parsed$package$name, "encodeUtils")
  testthat::expect_equal(length(manifest$selected_files$file_accession), nrow(selected$files))
  testthat::expect_equal(nrow(manifest$excluded_files), nrow(selected$excluded))
  testthat::expect_error(encode_manifest(selected, path = ""), "non-empty JSON path")
})

test_that("encode_filter_results and encode_select work without web requests", {
  local_mock_options()
  result <- httr2::with_mocked_responses(
    function(req) mock_json_response(experiment_search_json),
    encode_search(quiet = TRUE)
  )

  filtered <- encode_filter_results(result, list(assay_title = "total RNA-seq"))
  selected <- encode_select(result, rows = 1)

  testthat::expect_equal(nrow(filtered), 1)
  testthat::expect_equal(filtered$accession[[1]], "ENCSR000AAA")
  testthat::expect_equal(selected$accession[[1]], "ENCSR000AAA")
  testthat::expect_error(encode_select(result), "rows")
})

test_that("generated Rd files keep literal ENCODE download paths valid", {
  man_files <- list.files("man", pattern = "[.]Rd$", full.names = TRUE)
  text <- unlist(lapply(man_files, readLines, warn = FALSE), use.names = FALSE)
  testthat::expect_false(any(grepl("[^@]@download", text, perl = TRUE)))
})
