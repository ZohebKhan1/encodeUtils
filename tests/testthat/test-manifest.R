test_that("manifests capture file provenance and round-trip to JSON", {
  files <- fixture_file_table()[1L, ]
  attr(files, "query_url") <- "https://www.encodeproject.org/search/?type=File"
  path <- withr::local_tempfile(fileext = ".json")
  manifest <- encode_manifest(
    files,
    include_session = FALSE,
    path = path
  )
  parsed <- jsonlite::fromJSON(path, simplifyVector = FALSE)

  expect_s3_class(manifest, "encode_manifest")
  expect_s3_class(manifest$attribution, "encode_attribution_table")
  expect_equal(manifest$attribution$file_accession, "ENCFF000AAA")
  expect_equal(manifest$retrieval$query_url, attr(files, "query_url"))
  expect_equal(parsed$package$name, "encodeUtils")
  expect_equal(attr(manifest, "path", exact = TRUE), path)
})

test_that("manifests support loaded collections and reject unsupported objects", {
  path <- withr::local_tempfile(fileext = ".tsv")
  writeLines(c("gene_id\texpected_count", "Gata4\t10"), path)
  files <- data.frame(
    file_accession = "ENCFFLOAD01",
    experiment_accession = "ENCSRLOAD01",
    file_format = "tsv",
    output_type = "gene quantifications",
    local_path = path,
    download_status = "downloaded",
    stringsAsFactors = FALSE
  )
  loaded <- encode_read(files)
  manifest <- encode_manifest(loaded, include_session = FALSE)

  expect_equal(manifest$files$file_accession, "ENCFFLOAD01")
  expect_equal(manifest$loaded_objects$name, "ENCFFLOAD01")
  expect_error(
    encode_manifest(list(unrelated = TRUE), include_session = FALSE),
    "not a supported"
  )
  expect_error(
    encode_manifest("ENCBS000AAA", include_session = FALSE),
    "supports ENCSR and ENCFF"
  )
})
