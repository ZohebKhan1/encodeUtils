#' encodeUtils: Work with ENCODE metadata and files from R
#'
#' encodeUtils is an unofficial R package for convenient, traceable analysis of
#' ENCODE datasets. It queries the ENCODE REST API, parses JSON returned by
#' experiment and file searches, and standardizes fields used in scripted
#' analyses, including accessions, assays, biosamples, organisms, targets,
#' assemblies, output types, file sizes, checksums, and download URLs.
#'
#' Use it to search RNA-seq, ChIP-seq, and ATAC-seq experiments, list files from
#' ENCODE accessions, select common outputs, preview downloads before transfer,
#' load supported files into native R objects, and write reproducibility
#' manifests for downstream R and Bioconductor workflows.
#'
#' This package is not officially affiliated with the ENCODE Project.
#'
#' The package uses a conservative default request throttle below the ENCODE
#' REST API limit for programmatic GET requests.
"_PACKAGE"
