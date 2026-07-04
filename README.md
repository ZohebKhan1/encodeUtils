# encodeUtils

`encodeUtils` queries ENCODE metadata from R and helps choose, download, read,
cite, and record the files used in an analysis.

The package is read-only. It searches ENCODE, lists file metadata, previews
downloads, downloads selected files, and records provenance. It does not submit
or modify ENCODE records.

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
5. Check file paths and sizes with `encode_preview_download()`.
6. Download with `encode_download()`.
7. Save provenance with `encode_manifest()` and `encode_cite()`.

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

plan <- encode_preview_download(
  files,
  file_accession = c("ENCFF260OJQ", "ENCFF090VKE"),
  directory = tempdir()
)

dry_run <- encode_download(
  files,
  file_accession = c("ENCFF260OJQ", "ENCFF090VKE"),
  directory = tempdir(),
  dry_run = TRUE
)

manifest <- encode_manifest(
  dry_run,
  include_session = FALSE,
  path = file.path(tempdir(), "encode-rna-manifest.json")
)

encode_cite(dry_run, enrich = "auto")
```

## Main Functions

- `encode_search()` finds ENCODE experiments, files, and other records.
- `encode_get()` retrieves one ENCODE record by accession, path, or URL.
- `encode_matrix()` summarizes ENCODE record counts by assay and biosample.
- `encode_report()` returns a selected-field metadata table.
- `encode_results()` extracts the main table from result objects.
- `encode_list_files()` lists files attached to experiments.
- `encode_select_files()` selects files by accession, format, output type, or preset.
- `encode_explain_selection()` shows why files were selected or excluded.
- `encode_preview_download()` checks destination paths, file sizes, and required overrides.
- `encode_download()` downloads selected files with size and checksum checks.
- `encode_read()` reads supported local ENCODE files.
- `encode_manifest()` records queries, selected files, downloads, and citation metadata.
- `encode_cite()` creates ENCODE dataset and file attribution tables.

## References

- ENCODE REST API: <https://www.encodeproject.org/help/rest-api/>
- ENCODE Search: <https://www.encodeproject.org/search/>
- ENCODE Matrix: <https://www.encodeproject.org/matrix/>
- ENCODE citation guidance: <https://www.encodeproject.org/help/citing-encode/>
