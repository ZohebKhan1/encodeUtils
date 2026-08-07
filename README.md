# encodeUtils

[![R-CMD-check](https://github.com/ZohebKhan1/encodeUtils/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/ZohebKhan1/encodeUtils/actions/workflows/R-CMD-check.yaml)
[![pkgdown](https://github.com/ZohebKhan1/encodeUtils/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/ZohebKhan1/encodeUtils/actions/workflows/pkgdown.yaml)
[![test coverage](https://github.com/ZohebKhan1/encodeUtils/actions/workflows/test-coverage.yaml/badge.svg)](https://github.com/ZohebKhan1/encodeUtils/actions/workflows/test-coverage.yaml)
[![R >= 4.6.0](https://img.shields.io/badge/R-%E2%89%A5%204.6.0-276DC3?logo=r)](https://www.r-project.org/)

`encodeUtils` searches the ENCODE Portal, converts nested metadata into
traceable experiment and file tables, selects files using explicit criteria,
downloads verified files, reads supported formats, and records provenance for
downstream Bioconductor analyses.

The package is not affiliated with or endorsed by the ENCODE Project.

## Installation

Install the released package through Bioconductor:

```r
if (!requireNamespace("BiocManager", quietly = TRUE)) {
    install.packages("BiocManager")
}
BiocManager::install("encodeUtils")
```

The development version is available with
`pak::pak("ZohebKhan1/encodeUtils")`.

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

# Discover current candidates. Search ordering can change as ENCODE evolves.
discovery <- encode_search(
    organism = "mouse",
    assay = "microRNA-seq",
    organ = "heart",
    limit = 5
)
encode_results(discovery)

# Pin downstream work to one released experiment and two small files.
files <- encode_list_files(
    "ENCSR523CTA",
    file_format = "tsv",
    output_type = "microRNA quantifications",
    assembly = "mm10"
)
selected <- encode_select_files(
    files,
    file_accession = c("ENCFF859GWB", "ENCFF838WBE"),
    file_format = "tsv",
    output_type = "microRNA quantifications",
    assembly = "mm10",
    replicate_policy = "replicate_level"
)
encode_results(selected)
selected$excluded

# Resolve paths and size limits without transferring bytes.
plan <- encode_download(
    selected,
    directory = "encode-data",
    max_file_size = "100KB",
    max_total_size = "200KB",
    dry_run = TRUE
)
encode_results(plan)

# After reviewing the selected files and plan:
downloaded <- encode_download(
    selected,
    directory = "encode-data",
    max_file_size = "100KB",
    max_total_size = "200KB"
)
loaded <- encode_read(downloaded, values = "raw_counts")
manifest <- encode_manifest(loaded, path = "encode-manifest.json")
```

`encode_results()` extracts the main data frame from each workflow result. For
the loaded collection, `metadata` contains the input file table, `data`
contains one native object per file, `row_data` describes matrix features, and
`matrices` contains the requested numeric matrices. Matrices are created only
when participating tables have compatible ENCODE metadata and the same
complete, unique feature set; otherwise the original tables remain in
`loaded$data` without inferred alignment.

When compatible matrices are available, use
`encode_read(downloaded, as = "SummarizedExperiment")` to pass the expression
assays, feature metadata, and file metadata to Bioconductor methods in one
standard container. The `metadata(se)$encodeUtils` entry retains the source
query, request history, filters, and file-selection criteria.

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

`encode_download()` checks ENCODE-reported individual and total sizes before
transfer, refuses unknown-size transfers unless explicitly allowed, verifies
the observed size and MD5 after transfer, and installs replacement files only
after verification. With `directory = NULL`, files are stored in the package
cache returned by `tools::R_user_dir("encodeUtils", "cache")`.

## Related Bioconductor resources

`ENCODExplorerData` provides ENCODE metadata snapshots through
`AnnotationHub` and helpers for regenerating those tables. Its former companion
software package, `ENCODExplorer`, was removed from Bioconductor in release
3.15. `encodeUtils` instead queries the current Portal for each retrieval and
carries explicit file choices through size planning, verified download,
Bioconductor containers, and a provenance manifest.

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
