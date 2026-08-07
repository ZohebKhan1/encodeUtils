# encodeUtils

[![R-CMD-check](https://github.com/ZohebKhan1/encodeUtils/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/ZohebKhan1/encodeUtils/actions/workflows/R-CMD-check.yaml)
[![pkgdown](https://github.com/ZohebKhan1/encodeUtils/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/ZohebKhan1/encodeUtils/actions/workflows/pkgdown.yaml)
[![test coverage](https://github.com/ZohebKhan1/encodeUtils/actions/workflows/test-coverage.yaml/badge.svg)](https://github.com/ZohebKhan1/encodeUtils/actions/workflows/test-coverage.yaml)
[![R >= 4.6.0](https://img.shields.io/badge/R-%E2%89%A5%204.6.0-276DC3?logo=r)](https://www.r-project.org/)

The ENCODE Portal is a public database of experiments, biosamples, files, and
associated metadata produced by the ENCODE Project.

`encodeUtils` searches ENCODE metadata, selects and verifies ENCODE-related
datasets and files, reads supported file formats, and records retrieved ENCODE
metadata to improve reproducibility and citation of relevant ENCODE datasets.

The Portal exposes its records through an HTTP-based REST API that returns JSON.
This allows `encodeUtils` to query the Portal and convert its responses into R
and Bioconductor objects.

The package is not affiliatedd with or endorsed by the ENCODE Project.

## Warning

Use of the programmatic API is limited to 10 GET requests/sec from any single
user, group, company or lab.

Abuse of this will result in denial of access by IP block

## Documentation

See the [getting-started vignette](https://zohebkhan1.github.io/encodeUtils/articles/get-started.html) and [function reference](https://zohebkhan1.github.io/encodeUtils/reference/)

## Functions

| Function | Purpose |
|---|---|
| [`encode_search()`](https://zohebkhan1.github.io/encodeUtils/reference/encode_search.html) | Search ENCODE experiments, biosamples, and files. |
| [`encode_results()`](https://zohebkhan1.github.io/encodeUtils/reference/encode_results.html) | Extract the main result table. |
| [`encode_list_files()`](https://zohebkhan1.github.io/encodeUtils/reference/encode_list_files.html) | List files for ENCODE experiments. |
| [`encode_file_presets()`](https://zohebkhan1.github.io/encodeUtils/reference/encode_file_presets.html) | List reusable file-selection presets. |
| [`encode_select_files()`](https://zohebkhan1.github.io/encodeUtils/reference/encode_select_files.html) | Select files using explicit criteria. |
| [`encode_download()`](https://zohebkhan1.github.io/encodeUtils/reference/encode_download.html) | Plan, download, and verify files. |
| [`encode_read()`](https://zohebkhan1.github.io/encodeUtils/reference/encode_read.html) | Read supported local ENCODE files. |
| [`encode_manifest()`](https://zohebkhan1.github.io/encodeUtils/reference/encode_manifest.html) | Create a retrieval-provenance manifest. |

## Installation

```r
BiocManager::install("encodeUtils")
```

Install the development version with:

```r
pak::pak("ZohebKhan1/encodeUtils")
```

## Example workflow

This example retrieves replicate-level raw microRNA counts for male 5xFAD
mouse heart tissue. Each step uses the result of the preceding step.

### 1. Find the experiment

Start with the biological criteria. The `search` argument matches `5xFAD` in
the ENCODE record, while the other arguments restrict the assay, tissue, sex,
and organism. For another question, change those five biological arguments.
`limit` controls the maximum number of returned rows; it is not a biological
filter.

```r
library(encodeUtils)

discovery <- encode_search(
    organism = "mouse",
    assay = "microRNA-seq",
    organ = "heart",
    sex = "male",
    search = "5xFAD",
    limit = 5
)

experiment_table <- encode_results(discovery)

print(
    experiment_table[, c(
        "accession", "assay_title", "organism", "biosample_summary",
        "life_stage_age", "sex", "status"
    ), drop = FALSE],
    row.names = FALSE
)
```

```text
#>   accession  assay_title     organism
#> ENCSR523CTA microRNA-seq Mus musculus
#>                                                                 biosample_summary
#> Mus musculus strain 5xFAD/CAST (...) heart tissue male adult (8-10 months)
#>     life_stage_age  sex   status
#> adult 8-10 months male released
```

The result is a released male mouse-heart microRNA-seq experiment whose
biosample summary contains `5xFAD/CAST`. The query currently returns one
experiment, so its accession becomes the input to the file query. If a search
returns several rows, compare their assay, biosample, age, sex, and status
fields, then refine the search arguments before continuing.

The row-count check prevents the workflow from silently selecting the first
experiment if the live search changes.

```r
stopifnot(nrow(experiment_table) == 1L)

experiment_accession <- experiment_table$accession[[1L]]
experiment_accession
```

### 2. List the experiment's files

Use the returned experiment accession to list all of its released files. This
call retrieves file metadata only.

```r
files <- encode_list_files(
    experiment_accession
)

file_table <- encode_results(files)

file_inventory <- data.frame(
    accession = file_table$file_accession,
    replicate = file_table$biological_replicates,
    format = file_table$file_format,
    output = file_table$output_type,
    assembly = file_table$assembly,
    size = file_table$file_size_pretty
)

file_inventory
```

| accession | replicate | format | output | assembly | size |
|---|---:|---|---|---|---:|
| ENCFF894LZS | 1 | bigWig | minus strand signal of all reads | mm10 | 14.94 MB |
| ENCFF272MTQ | 2 | bigWig | minus strand signal of all reads | mm10 | 14.50 MB |
| ENCFF568APO | 1 | fastq | reads | NA | 266.89 MB |
| ENCFF859GWB | 1 | tsv | microRNA quantifications | mm10 | 59.54 KB |
| ENCFF511JFU | 1 | bam | alignments | mm10 | 268.56 MB |
| ENCFF838WBE | 2 | tsv | microRNA quantifications | mm10 | 59.57 KB |
| ENCFF672YIA | 2 | bigWig | plus strand signal of unique reads | mm10 | 7.37 MB |
| ENCFF330SVB | 2 | bigWig | plus strand signal of all reads | mm10 | 14.30 MB |
| ENCFF186WHP | 2 | bam | alignments | mm10 | 343.95 MB |
| ENCFF545SFH | 1 | bigWig | plus strand signal of unique reads | mm10 | 7.81 MB |
| ENCFF888ILZ | 2 | bigWig | minus strand signal of unique reads | mm10 | 7.52 MB |
| ENCFF520ASQ | 1 | bigWig | minus strand signal of unique reads | mm10 | 7.94 MB |
| ENCFF873LHR | 1 | bigWig | plus strand signal of all reads | mm10 | 14.81 MB |
| ENCFF975MFU | 2 | fastq | reads | NA | 344.88 MB |

### 3. Select replicate-level files

`file_format` describes how a file is encoded; `output_type` describes the data
product it contains. The goal is a count matrix, so select the TSV rows whose
output type is `microRNA quantifications`. `mm10` is the mouse assembly used for
these processed files, and `replicate_level` keeps separate biological
replicates. For another data product, inspect the inventory and change the
relevant selection arguments.

```r
selected <- encode_select_files(
    files,
    file_format = "tsv",
    output_type = "microRNA quantifications",
    assembly = "mm10",
    replicate_policy = "replicate_level"
)

selected_table <- encode_results(selected)

selected_display <- data.frame(
    accession = selected_table$file_accession,
    replicate = selected_table$biological_replicates,
    format = selected_table$file_format,
    output = selected_table$output_type,
    assembly = selected_table$assembly,
    size = selected_table$file_size_pretty
)

selected_display
```

The selection reduces the displayed inventory to the TSV rows below. These are
the file accessions used in the remaining steps.

| accession | replicate | format | output | assembly | size |
|---|---:|---|---|---|---:|
| ENCFF859GWB | 1 | tsv | microRNA quantifications | mm10 | 59.54 KB |
| ENCFF838WBE | 2 | tsv | microRNA quantifications | mm10 | 59.57 KB |

### 4. Preview the download

Create a download plan before transferring data. The plan compares the sizes
reported by ENCODE with the configured limits; it does not inspect remote file
contents. This example writes to `encode-data` in the current working directory.
Change `download_directory` if the files should be stored elsewhere. The limits
prevent an unexpected large transfer if the Portal records change. Each
selected file is about 60 KB, so the 100 KB per-file and 200 KB total limits
leave modest headroom above the expected 120 KB transfer.

```r
download_directory <- "encode-data"

plan <- encode_download(
    selected,
    directory = download_directory,
    max_file_size = "100KB",
    max_total_size = "200KB",
    dry_run = TRUE
)

plan
```

Review the planned accessions, paths, and total size before continuing.

### 5. Download and verify the files

Run the same request without `dry_run`. `encode_download()` verifies the
reported file size and MD5 checksum before keeping each file.

```r
downloaded <- encode_download(
    selected,
    directory = download_directory,
    max_file_size = "100KB",
    max_total_size = "200KB"
)

downloaded

download_table <- encode_results(downloaded)

download_table[, c(
    "file_accession", "download_status", "size_verified", "md5_verified"
), drop = FALSE]
```

Observed size and checksum verification occurs after each transfer. The two
verification columns should both be `TRUE`.

### 6. Read the count tables

The selected microRNA quantification files are four-column HTSeq-style tables.
`encodeUtils` maps the second count column to `raw_counts`. The tables share a
complete, unique `gene_id` field, so it is used to align rows across files.

```r
count_data <- encode_read(
    downloaded,
    values = "raw_counts",
    row_names = "gene_id"
)

count_data
count_data$matrices$raw_counts[seq_len(6L), , drop = FALSE]
```

`count_data` contains the individual file tables, their metadata, feature
metadata, and the aligned raw-count matrix.

### 7. Write a manifest

Record the file-listing request carried by `count_data`, selection criteria,
downloaded files, checksums, matrix dimensions, and R session. The earlier
experiment search remains in `discovery`; it is not included in this manifest.

```r
manifest <- encode_manifest(count_data, path = "encode-manifest.json")

data.frame(
    manifest = basename(attr(manifest, "path")),
    files = nrow(manifest$files),
    requests = length(manifest$requests),
    matrices = nrow(manifest$matrices)
)
```

### Optional: create a SummarizedExperiment

Instead of working with the list and matrix result, request the same verified
local files as a `SummarizedExperiment`. Rows are features, columns are the two
ENCODE file accessions, and `colData()` contains the file metadata.

```r
se <- encode_read(
    downloaded,
    values = "raw_counts",
    row_names = "gene_id",
    as = "SummarizedExperiment"
)

se
```

## Other inputs and formats

- Pass ENCSR accessions to `encode_list_files()`.
- Pass ENCFF accessions to `encode_download()`.
- Pass local paths or completed download rows to `encode_read()`.

BED, narrowPeak, and broadPeak files return `GenomicRanges::GRanges`. GFF,
GTF, BigWig, and BigBed files use `rtracklayer` when installed; FASTA files use
`Biostrings`.

## References

- [ENCODE REST API](https://www.encodeproject.org/help/rest-api/)
- [ENCODE attribution guidance](https://www.encodeproject.org/help/citing-encode/)
- Kagda MS et al. Data navigation on the ENCODE portal. *Nature
  Communications*. 2025;16:9592. doi:10.1038/s41467-025-64343-9.
