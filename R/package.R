#' encodeUtils: Work with ENCODE metadata and files from R
#'
#' encodeUtils queries the ENCODE Portal REST API and converts nested metadata
#' into traceable experiment and file tables. It standardizes fields used in
#' scripted analyses, including accessions, assays, biosamples, organisms,
#' targets, assemblies, output types, file sizes, checksums, and download URLs.
#'
#' Use it to search RNA-seq, ChIP-seq, and ATAC-seq experiments, list files from
#' ENCODE accessions, select common outputs, preview downloads before transfer,
#' load supported local files into native R objects, and write reproducibility
#' manifests for downstream R and Bioconductor workflows. The introductory
#' vignette and help pages use deliberately small live requests; the separate
#' live smoke test is opt-in.
#'
#' This package is not affiliated with or endorsed by the ENCODE Project.
#'
#' The package uses a conservative default request throttle below the ENCODE
#' REST API limit for programmatic GET requests.
#'
#' @section Development provenance:
#' AI (Codex 5.6 Sol) was used to write code for the test suite. All other code
#' was written primarily by a human. AI-generated code for the testing suite was
#' manually reviewed, edited, and tested by the maintainer. The maintainer
#' assumes responsibility for all package code and its ongoing maintenance.
"_PACKAGE"
