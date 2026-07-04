# encodeUtils

`encodeUtils` is an R package for working with ENCODE Portal metadata and
selected files from R. It is designed around a metadata-first workflow: search
or summarize what exists, inspect selected experiments and files, deliberately
download only the files you chose, then read supported local files when that is
safe.

## Development Status

This package now implements the core read-only ENCODE workflow:

- `encode_search()` searches ENCODE metadata and prints compact result tables.
  It defaults to `metadata = "full"` so linked lab, award, organism, and
  biosample fields are useful in the console.
- `encode_results()` extracts the compact table from search, object, matrix,
  report, selected-file, preview, and download result objects.
- `encode_get()` retrieves one ENCODE record by accession, path, or URL.
- `encode_matrix()` summarizes Matrix endpoint assay-by-biosample counts.
- `encode_report()` creates selected-field metadata tables.
- `encode_list_files()` lists file metadata for selected experiments.
- `encode_select_files()` applies transparent file-selection presets, can prefer
  ENCODE `preferred_default` files when available, keeps an exclusion log, and
  lists preset definitions when called without files.
- `encode_explain_selection()` returns a tidy selected/excluded decision table.
- `encode_preview_download()` shows destination paths, size lower bounds,
  unknown-size files, checksum availability, and required overrides before
  transfer.
- `encode_download()` downloads selected files with size and checksum guardrails.
- `encode_read()` reads safe local text/JSON files and delegates optional
  genomic formats to Bioconductor readers when installed.
- `encode_cite()` creates dataset and file provenance tables or text/markdown
  summaries for reports and methods sections.
- `encode_manifest()` creates reproducibility manifests for selected/downloaded
  data and can write them to JSON with `path =`.

The package remains read-only with respect to ENCODE. It does not implement
submission, `POST`, or `PATCH` workflows.

## Basic Examples

```r
library(encodeUtils)

experiments <- encode_search(
    type = "Experiment",
    search = "mouse heart total RNA-seq",
    status = "released",
    limit = 10,
    metadata = "full"
)

files <- encode_list_files(
    experiments,
    file_format = "tsv",
    output_type = "gene quantifications",
    assembly = "mm10",
    metadata = "full"
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

See the pkgdown article `Get started` for complete RNA-seq, ATAC-seq, and
ChIP-seq workflows.

## Developer Setup

This project uses `renv` for the local development environment. Package users
will install dependencies from `DESCRIPTION`; `renv.lock` is only for
reproducing this development checkout.

```r
renv::restore()
```

For local checks in this WSL environment, use:

```bash
tools/r_codex_utils preflight
tools/r_codex_utils check R/search.R
```

For package checks, build the source package first:

```bash
R CMD build .
R CMD check --no-manual encodeUtils_0.99.0.tar.gz
```

## Design Notes

Detailed planning notes are in:

- [docs/design/user_workflows.md](docs/design/user_workflows.md)
- [docs/design/encode_package_notes.md](docs/design/encode_package_notes.md)

Recent external review notes and implementation triage are in:

- [docs/reviews/consolidated_audit_synthesis.md](docs/reviews/consolidated_audit_synthesis.md)
- [docs/reviews/encodeUtils_review.md](docs/reviews/encodeUtils_review.md)
- [docs/reviews/encodeUtils_review_addendum.md](docs/reviews/encodeUtils_review_addendum.md)
- [docs/reviews/feedback_triage.md](docs/reviews/feedback_triage.md)

## References

- ENCODE REST API: <https://www.encodeproject.org/help/rest-api/>
- ENCODE Search: <https://www.encodeproject.org/search/>
- ENCODE Matrix: <https://www.encodeproject.org/matrix/>
- ENCODE schemas: <https://www.encodeproject.org/profiles/>
- ENCODE citation guidance: <https://www.encodeproject.org/help/citing-encode/>
- Bioconductor contribution guide: <https://contributions.bioconductor.org/>
