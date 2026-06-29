# encode-api-util

Private development repository for an R package that will query the ENCODE
Portal REST API and help users inspect, download, and load selected ENCODE
datasets from R.

## Development Status

This repository is in the planning and package-setup phase. The current R
package name is `encodeapiutil` because R package names cannot contain hyphens.
Core ENCODE query, download, and read functions have not been implemented yet.

## Current Design Direction

The package will start with a lean, read-only public API:

- `encode_search()` for ENCODE Search endpoint queries.
- `encode_get()` for one accession, path, or URL.
- `encode_list_files()` for file metadata only.
- `encode_download()` for deliberate selected downloads.
- `encode_read()` for supported local file loading.
- `encode_get_schema()` for ENCODE schema/profile inspection.
- `encode_cite()` for dataset and file citation summaries.
- `encode_matrix()` for ENCODE Matrix endpoint summaries.

The implementation should stay R-native, straightforward, and auditable. Large
downloads should be explicit, cache-aware, and size-aware.

Detailed planning notes are in:

- [design/user_workflows.md](design/user_workflows.md)
- [encode_package_notes.md](encode_package_notes.md)

## Developer Setup

This project uses `renv` for the local development environment. Package users
will install dependencies from the package `DESCRIPTION`; `renv.lock` is only
for reproducing this development checkout.

```r
renv::restore()
```

For local checks in this WSL environment, use:

```bash
tools/r_codex_utils preflight
```

## References

- ENCODE REST API: <https://www.encodeproject.org/help/rest-api/>
- ENCODE Search: <https://www.encodeproject.org/search/>
- ENCODE Matrix: <https://www.encodeproject.org/matrix/>
- Bioconductor contribution guide: <https://contributions.bioconductor.org/>
