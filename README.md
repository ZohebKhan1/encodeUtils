# encodeUtils

[![R-CMD-check](https://github.com/ZohebKhan1/encodeUtils/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/ZohebKhan1/encodeUtils/actions/workflows/R-CMD-check.yaml)
[![pkgdown](https://github.com/ZohebKhan1/encodeUtils/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/ZohebKhan1/encodeUtils/actions/workflows/pkgdown.yaml)
[![coverage 62.1%](https://img.shields.io/badge/coverage-62.1%25-yellow)](https://github.com/ZohebKhan1/encodeUtils/actions/workflows/test-coverage.yaml)
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

## End-to-end workflow

This example finds a released mouse heart RNA-seq experiment, selects its gene
quantification files, downloads them to a project directory, assembles count
and TPM matrices, and writes a provenance manifest.

```r
library(encodeUtils)

experiments <- encode_search(
    organism = "mouse",
    assay = "rna-seq",
    organ = "heart",
    limit = 1
)

files <- encode_list_files(experiments)

selected <- encode_select_files(
    files,
    preset = "rnaseq_gene_quant",
    assembly = "mm10",
    replicate_policy = "preferred_processed"
)

downloaded <- encode_download(
    selected,
    directory = "encode-data"
)

loaded <- encode_read(
    downloaded,
    values = c("raw_counts", "tpm")
)

manifest <- encode_manifest(
    loaded,
    path = "encode-manifest.json"
)
```

Use `encode_results()` to extract an ordinary data frame from a search,
selection, download, or loaded-file result. The complete input file table is
also available as `loaded$metadata`; `loaded$data` contains one native object
per file; `loaded$row_data` describes aligned features; and `loaded$matrices`
contains the requested numeric matrices.

Matrices are created only when all participating tables share a complete,
unique feature identifier. Tables with ambiguous identifiers remain available
in `loaded$data` and are not aligned by row order.

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
