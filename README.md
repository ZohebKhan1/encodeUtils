# encodeUtils

[![R-CMD-check](https://github.com/ZohebKhan1/encodeUtils/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/ZohebKhan1/encodeUtils/actions/workflows/R-CMD-check.yaml)
[![pkgdown](https://github.com/ZohebKhan1/encodeUtils/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/ZohebKhan1/encodeUtils/actions/workflows/pkgdown.yaml)
[![coverage 62.7%](https://img.shields.io/badge/coverage-62.7%25-yellow)](https://github.com/ZohebKhan1/encodeUtils/actions/workflows/test-coverage.yaml)
[![R >= 4.6.0](https://img.shields.io/badge/R-%E2%89%A5%204.6.0-276DC3?logo=r)](https://www.r-project.org/)

`encodeUtils` searches the ENCODE Portal, converts nested metadata into
traceable experiment and file tables, selects files using explicit criteria,
downloads verified files, reads supported formats, and records provenance for
downstream Bioconductor analyses.

The package is not affiliated with or endorsed by the ENCODE Project.

## Installation

Install the current development version from GitHub:

```r
if (!requireNamespace("pak", quietly = TRUE)) {
    install.packages("pak")
}
pak::pak("ZohebKhan1/encodeUtils")
```

## End-to-end retrieval

In `encodeUtils`, an end-to-end workflow is a deliberate path from a biological
query to local, inspectable R objects:

1. Find candidate experiments.
2. Review their metadata and choose an experiment accession.
3. List its file records, then state the file-selection criteria.
4. Inspect a no-transfer download plan before downloading.
5. Verify the completed transfer, read compatible files, and record a manifest.

This is a retrieval and provenance workflow, not a substitute for assessing
biological comparability or designing a downstream analysis. The
[getting-started vignette](https://zohebkhan1.github.io/encodeUtils/articles/get-started.html)
walks through each decision and result object. The compact example below shows
the same sequence.

```r
library(encodeUtils)

# Find one candidate. `limit = 1` keeps the example small; inspect it before use.
experiments <- encode_search(
    organism = "mouse",
    assay = "rna-seq",
    organ = "heart",
    limit = 1
)
experiment_table <- encode_results(experiments)
chosen_experiment <- experiment_table$accession[[1L]]

# List metadata first; this does not download file contents.
files <- encode_list_files(chosen_experiment)
selected <- encode_select_files(
    files,
    preset = "rnaseq_gene_quant",
    assembly = "mm10",
    replicate_policy = "preferred_processed"
)
encode_results(selected)
selected$excluded

# Resolve paths and size limits without transferring bytes.
plan <- encode_download(
    selected,
    directory = "encode-data",
    dry_run = TRUE
)
encode_results(plan)

# After reviewing the selected files and plan:
downloaded <- encode_download(selected, directory = "encode-data")
loaded <- encode_read(downloaded, values = c("raw_counts", "tpm"))
manifest <- encode_manifest(loaded, path = "encode-manifest.json")
```

`encode_results()` extracts the main data frame from each workflow result. For
the loaded collection, `metadata` contains the input file table, `data`
contains one native object per file, `row_data` describes matrix features, and
`matrices` contains the requested numeric matrices. Matrices are created only
when every participating table has a complete, unique feature identifier;
otherwise the original tables remain in `loaded$data` without inferred
row-order alignment.

## Other entry points and formats

You can start with the information already available:

- ENCSR experiment accessions: pass them to `encode_list_files()`.
- ENCFF file accessions: pass them to `encode_download()`.
- Local paths or completed download rows: pass them to `encode_read()`.

BED, narrowPeak, and broadPeak files return `GenomicRanges::GRanges` by
default. GFF, GTF, BigWig, and BigBed files use `rtracklayer` when installed,
and FASTA files use `Biostrings`. FASTQ and alignment files remain local path
objects for dedicated sequence-processing packages. Use
`encode_read(path, as = "data.frame")` when a BED-like table is preferable to
genomic ranges.

`encode_download()` limits individual and total transfer size, refuses
unknown-size transfers unless explicitly allowed, verifies available size and
MD5 metadata, and installs replacement files only after verification. With
`directory = NULL`, files are stored in the package cache returned by
`tools::R_user_dir("encodeUtils", "cache")`.

## Documentation

See the [getting-started
vignette](https://zohebkhan1.github.io/encodeUtils/articles/get-started.html)
and [function reference](https://zohebkhan1.github.io/encodeUtils/reference/)
for the complete workflow and object contracts.

## References

- [ENCODE REST API](https://www.encodeproject.org/help/rest-api/)
- [ENCODE attribution guidance](https://www.encodeproject.org/help/citing-encode/)
- Kagda MS et al. Data navigation on the ENCODE portal. *Nature
  Communications*. 2025;16:9592. doi:10.1038/s41467-025-64343-9.
