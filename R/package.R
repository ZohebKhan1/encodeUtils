#' encodeUtils: Work with ENCODE metadata and files from R
#'
#' encodeUtils queries the ENCODE Portal REST API and converts nested metadata
#' into traceable experiment and file tables. It standardizes fields used in
#' scripted analyses, including accessions, assays, biosamples, organisms,
#' targets, assemblies, output types, file sizes, checksums, and download URLs.
#'
#' Use it to search ENCODE records with exact Portal filters, list files from
#' experiment accessions, apply reusable file presets, preview and verify
#' downloads, read local files without implicit simplification, explicitly
#' assemble quantification tables, and write reproducibility manifests. The
#' introductory vignette uses a deliberately small live request; the separate
#' live smoke test is opt-in.
#'
#' This package is not affiliated with or endorsed by the ENCODE Project.
#'
#' The package uses `httr2` to throttle requests to five per second, below the
#' ENCODE limit for programmatic GET requests.
#'
#' @section Development provenance:
#' AI (Codex 5.6 Sol) was used to write code for the test suite. All other code
#' was written primarily by a human. AI-generated code for the testing suite was
#' manually reviewed, edited, and tested by the maintainer. The maintainer
#' assumes responsibility for all package code and its ongoing maintenance.
"_PACKAGE"
