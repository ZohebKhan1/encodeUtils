# encodeUtils

[![R >= 4.6.0](https://img.shields.io/badge/R-%E2%89%A5%204.6.0-276DC3?logo=r)](https://www.r-project.org/)

The [ENCODE Portal](https://www.encodeproject.org/) is a public repository of
experiment records, biosample descriptions, data files, and metadata from the
ENCODE Project.

`encodeUtils` provides an R interface for searching ENCODE metadata, selecting
and verifying files, reading supported local formats, and recording retrieval
provenance. The package is not affiliated with or endorsed by the ENCODE
Project.

## Documentation

See the [getting-started vignette](https://zohebkhan1.github.io/encodeUtils/articles/get-started.html)
for the complete workflow and the [function reference](https://zohebkhan1.github.io/encodeUtils/reference/)
for argument and return-value details.

## Installation

```r
install.packages("BiocManager")
BiocManager::install("encodeUtils")
```

Install the development version with:

```r
install.packages("pak")
pak::pak("ZohebKhan1/encodeUtils")
```

## Main functions

| Function | Purpose |
|---|---|
| `encode_search()` | Search ENCODE records with exact Portal filters. |
| `encode_results()` | Extract the main result table. |
| `encode_list_files()` | List and filter files for experiments. |
| `encode_file_presets()` | List or inspect file-selection presets. |
| `encode_select_files()` | Apply file presets and replicate policies. |
| `encode_download()` | Plan, download, and verify exact files. |
| `encode_read()` | Read one local file without simplification. |
| `encode_read_all()` | Read every file in a completed download table. |
| `encode_prepare_quant()` | Explicitly prepare common quantification tables. |
| `encode_as_summarized_experiment()` | Combine prepared tables explicitly. |
| `encode_manifest()` | Record retrieval provenance as JSON. |

## API and file-handling behavior

ENCODE limits programmatic access to 10 GET requests per second from one user,
group, company, or lab, and warns that abuse can result in an IP block.
`encodeUtils` uses `httr2` to throttle requests to five per second and retry
transient failures.

Downloads are uncapped by default because common FASTQ files exceed hundreds of
megabytes; `max_file_size` and `max_total_size` are opt-in guardrails. When no
directory is supplied, files use the package cache from `tools::R_user_dir()`.
An existing destination is reported as `"exists"` and is not replaced unless
`overwrite = TRUE`. Transfers use temporary `.part` files. Size is checked when
reported by ENCODE, and MD5 is checked when ENCODE supplies a checksum.

API responses are not cached. `encode_read()` limits in-memory reads to 100 MB
by default; use `max_size = NULL` only when a larger import is intentional.
Large, unsupported, FASTQ, and alignment inputs return an `encode_local_file`
path object by default so another format-specific tool can process them.

See the [ENCODE data-use policy](https://www.encodeproject.org/help/citing-encode/)
for citation guidance.
