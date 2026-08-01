# encodeUtils

[![R-CMD-check](https://github.com/ZohebKhan1/encodeUtils/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/ZohebKhan1/encodeUtils/actions/workflows/R-CMD-check.yaml)
[![pkgdown](https://github.com/ZohebKhan1/encodeUtils/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/ZohebKhan1/encodeUtils/actions/workflows/pkgdown.yaml)

`encodeUtils` provides a focused R workflow for querying ENCODE Portal
metadata, selecting files, planning bounded downloads, reading supported local
formats, and recording provenance. It converts nested ENCODE responses into
traceable experiment and file tables for downstream Bioconductor analyses.

The package is not affiliated with or endorsed by the ENCODE Project.

## Installation

Install the Bioconductor release with:

```r
if (!requireNamespace("BiocManager", quietly = TRUE)) {
  install.packages("BiocManager")
}
BiocManager::install("encodeUtils")
```

Until a Bioconductor release is available, install the development version
from GitHub:

```r
if (!requireNamespace("pak", quietly = TRUE)) {
  install.packages("pak")
}
pak::pak("ZohebKhan1/encodeUtils")
```

## Workflow

The exported API follows one sequence:

1. `encode_search()` finds ENCODE records.
2. `encode_list_files()` lists files attached to experiments.
3. `encode_select_files()` applies explicit criteria or a canonical preset.
4. `encode_download()` plans or transfers files.
5. `encode_read()` reads supported files already on disk.
6. `encode_manifest()` records query, file, download, and attribution metadata.

Use `encode_results()` whenever an ordinary data frame is needed.

```r
library(encodeUtils)

experiments <- encode_search(
  type = "Experiment",
  organism = "mouse",
  assay = "rna-seq",
  organ = "heart",
  limit = 5
)

files <- encode_list_files(
  experiments,
  file_format = "tsv",
  output_type = "gene quantifications",
  assembly = "mm10"
)

selected <- encode_select_files(
  files,
  preset = "rnaseq_gene_quant"
)

plan <- encode_download(
  selected,
  directory = tempdir(),
  dry_run = TRUE
)

# After reviewing the plan:
# downloaded <- encode_download(selected, directory = NULL)
# loaded <- encode_read(downloaded, values = c("raw_counts", "tpm"))
# loaded$metadata
# loaded$row_data
# loaded$matrices$raw_counts

manifest <- encode_manifest(plan, include_session = FALSE)
```

`encode_download()` only transfers files. `directory = NULL` uses the
persistent cache returned by `tools::R_user_dir("encodeUtils", "cache")`; use
`tempdir()` for transient work. Existing destinations are not overwritten by
default, and replacement downloads are verified before the previous file is
removed.

A local path passed to `encode_read()` returns the native reader output. A
downloaded-file table always returns an `encode_loaded_files` collection with
four components:

- `metadata`: complete input file metadata and provenance;
- `data`: one native object per file;
- `row_data`: feature identifiers aligned to combined expression matrices;
- `matrices`: numeric `raw_counts`, `tpm`, `fpkm`, or `rpkm` matrices when the
  requested values can be combined safely.

BED-like files use Bioconductor genomic classes when the optional reader stack
is installed. FASTQ and alignment files are returned as local path objects for
use with dedicated sequence-processing packages.

## Network behavior

Routine examples and tests are network-independent. Live requests use bounded
retries, a conservative default request rate, informative HTTP errors, and a
configurable cap on server-requested retry delays. Start with narrow searches
and use `dry_run = TRUE` before transferring ENCODE files.

## Documentation

See the [getting-started
vignette](https://zohebkhan1.github.io/encodeUtils/articles/get-started.html)
for a complete offline example and an interactive live-query pattern.

## References

- [ENCODE REST API](https://www.encodeproject.org/help/rest-api/)
- [ENCODE attribution guidance](https://www.encodeproject.org/help/citing-encode/)
- Kagda MS et al. Data navigation on the ENCODE portal. *Nature
  Communications*. 2025;16:9592. doi:10.1038/s41467-025-64343-9.
