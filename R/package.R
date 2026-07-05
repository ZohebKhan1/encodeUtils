#' encodeUtils: Work with ENCODE metadata and files from R
#'
#' encodeUtils queries ENCODE metadata, lists files attached to experiments,
#' selects files, checks and downloads chosen files, reads supported local files,
#' and records reproducibility manifests.
#'
#' The package is read-only. It does not submit, modify, or curate ENCODE
#' records.
#'
#' Start with `encode_search()` for experiments or files. Use `encode_results()`
#' to extract the displayed table, `encode_list_files()` to list files for
#' experiments, and `encode_download(dry_run = TRUE)` before transferring data.
"_PACKAGE"
