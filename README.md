## References

- ENCODE REST API: <https://www.encodeproject.org/help/rest-api/>
- ENCODE attribution guidance: <https://www.encodeproject.org/help/citing-encode/>

Kagda MS, Lam B, Litton C, Small C, Sloan CA, Spragins E, Tanaka F, Whaling I, Gabdank I, Youngworth I, Strattan JS, Hilton J, Jou J, Au J, Lee JW, Andreeva K, Graham K, Lin K, Simison M, Jolanki O, Sud P, Assis P, Adenekan P, Miyasato S, Zhong W, Luo Y, Myers Z, Cherry JM, Hitz BC. Data navigation on the ENCODE portal. Nat Commun. 2025 Oct 30;16(1):9592. doi: 10.1038/s41467-025-64343-9. PMID: 41168159; PMCID: PMC12575607.
  
# encodeUtils

`encodeUtils` queries ENCODE metadata from R and helps choose, download, read,
and record the files used in an analysis.

The package is read-only. It searches ENCODE, lists file metadata, checks
downloads, downloads selected files, reads supported local files, and records
provenance. It does not submit or modify ENCODE records.

## ENCODE Overview

These summaries show released ENCODE Experiment records for common sequencing
workflows.

<img src="man/figures/encode-database-overview.svg" width="780" alt="Released ENCODE RNA-seq, ChIP-seq, and ATAC-seq experiment counts with species, tissue, life-stage, and histone-target summaries.">

## Installation

```r
# install.packages("pak")
pak::pak("ZohebKhan1/encodeUtils")
```

## Workflow

Most analyses use the same sequence:

1. Search ENCODE records with `encode_search()`.
2. Extract the displayed table with `encode_results()` when needed.
3. List files for selected experiments with `encode_list_files()`.
4. Select files with `encode_select_files()`.
5. Check file paths and sizes with `encode_download(dry_run = TRUE)`.
6. Download with `encode_download()`.
7. Read supported downloaded files with `encode_read()` or `encode_download(read = TRUE)`.
8. Save provenance with `encode_manifest()`.

## Example

```r
library(encodeUtils)

experiments <- encode_search(
  type = "Experiment",
  search = "mouse heart total RNA-seq",
  status = "released",
  limit = 10
)

files <- encode_list_files(
  experiments,
  file_format = "tsv",
  output_type = "gene quantifications",
  assembly = "mm10"
)

dry_run <- encode_download(
  files,
  file_accession = c("ENCFF260OJQ", "ENCFF090VKE"),
  directory = tempdir(),
  dry_run = TRUE
)

downloaded <- encode_download(
  files,
  file_accession = c("ENCFF260OJQ", "ENCFF090VKE"),
  directory = "data/encode/rna-seq"
)

loaded <- encode_read(downloaded)

manifest <- encode_manifest(
  downloaded,
  include_session = FALSE,
  path = file.path(tempdir(), "encode-rna-manifest.json")
)
```
