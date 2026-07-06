#' encodeUtils: Work with ENCODE metadata and files from R
#'
#' encodeUtils helps R users find ENCODE datasets and turn ENCODE Portal
#' metadata into analysis-ready file tables. It queries the ENCODE REST API,
#' parses JSON returned by experiment and file searches, and standardizes fields
#' used in scripted analyses, including accessions, assays, biosamples,
#' organisms, targets, assemblies, output types, file sizes, checksums, and
#' download URLs.
#'
#' Use it to search RNA-seq, ChIP-seq, and ATAC-seq experiments, list files from
#' ENCODE accessions, select common outputs, preview downloads before transfer,
#' read supported local files into R, and write reproducibility manifests.
"_PACKAGE"
