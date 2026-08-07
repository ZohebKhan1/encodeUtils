# encodeUtils

[![R-CMD-check](https://github.com/ZohebKhan1/encodeUtils/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/ZohebKhan1/encodeUtils/actions/workflows/R-CMD-check.yaml)
[![pkgdown](https://github.com/ZohebKhan1/encodeUtils/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/ZohebKhan1/encodeUtils/actions/workflows/pkgdown.yaml)
[![test coverage](https://github.com/ZohebKhan1/encodeUtils/actions/workflows/test-coverage.yaml/badge.svg)](https://github.com/ZohebKhan1/encodeUtils/actions/workflows/test-coverage.yaml)
[![R >= 4.6.0](https://img.shields.io/badge/R-%E2%89%A5%204.6.0-276DC3?logo=r)](https://www.r-project.org/)

The [ENCODE Portal](https://www.encodeproject.org/) is a public repository of
experiment records, biosample descriptions, data files, and metadata from the
ENCODE Project.

`encodeUtils` provides an R interface for searching ENCODE metadata, selecting
and verifying files, reading supported formats, and recording retrieval
provenance. Recording this provenance supports reproducible analyses and
citation of the ENCODE data used.

ENCODE provides programmatic access to this information through a REST API. The
API returns data in JSON format, which `encodeUtils` converts into R and
Bioconductor objects.

The package is not affiliatedd with or endorsed by the ENCODE Project.

## ENCODE API disclaimer

The following rate-limit disclaimer is reproduced directly from the
[ENCODE REST API documentation](https://www.encodeproject.org/help/rest-api/):

> Use of the programmatic API is limited to 10 GET requests/sec from any single
> user, group, company or lab.
>
> Abuse of this will result in denial of access by IP block

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
| [`encode_manifest()`](https://zohebkhan1.github.io/encodeUtils/reference/encode_manifest.html) | Record retrieval provenance in a manifest. |

## Installation

```r
BiocManager::install("encodeUtils")
```

Install the development version with:

```r
pak::pak("ZohebKhan1/encodeUtils")
```

## Example workflow

This example shows how to retrieve replicate-level raw microRNA counts from
male 5xFAD mouse heart tissue. Each step derives its input from the output of
the preceding step.

### 1. Find the experiment

Begin with the biological criteria. The `search` argument looks for `5xFAD` in
ENCODE metadata, while the other arguments restrict the assay, tissue, sex, and
organism. To investigate a different question, change those five arguments.
`limit` sets the maximum number of results and does not filter by biology.

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

The search identifies a released microRNA-seq experiment from male 5xFAD/CAST
mouse heart tissue. Because the query currently returns one experiment, its
accession becomes the input to the file query. If a search returns several
experiments, compare their assay, biosample, age, sex, and status fields, then
refine the search arguments before continuing.

The row-count check stops the workflow unless the live search returns exactly
one experiment, preventing the code from selecting the first result without
explanation.

```r
stopifnot(nrow(experiment_table) == 1L)

experiment_accession <- experiment_table$accession[[1L]]
experiment_accession
```

### 2. List the experiment's files

Use the accession obtained above to retrieve metadata for every released file
associated with the experiment. This step does not download file contents.

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

`file_format` identifies the storage format, while `output_type` identifies the
data product. To build a count matrix, select TSV files containing `microRNA
quantifications`. These processed files use the `mm10` mouse assembly, and
`replicate_level` retains a separate file for each biological replicate. To
retrieve another data product, inspect the inventory and change the relevant
selection arguments.

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

The selection narrows the inventory to the two TSV files shown below. The
remaining steps use these two accessions.

| accession | replicate | format | output | assembly | size |
|---|---:|---|---|---|---:|
| ENCFF859GWB | 1 | tsv | microRNA quantifications | mm10 | 59.54 KB |
| ENCFF838WBE | 2 | tsv | microRNA quantifications | mm10 | 59.57 KB |

### 4. Preview the download

Create a download plan before transferring data. The plan compares the file
sizes reported by ENCODE with the configured limits but does not download the
files. This example saves data in `encode-data` under the current working
directory; change `download_directory` to use a different location. The limits
guard against an unexpectedly large transfer if ENCODE metadata changes. Each
selected file is about 60 KB, so the 100 KB per-file and 200 KB total limits
provide modest headroom above the expected 120 KB transfer.

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

Confirm the file accessions, destination paths, and expected total size before
continuing.

### 5. Download and verify the files

Run the same request without `dry_run`. Downloads are first written to temporary
`.part` files. `encode_download()` verifies each file's size and MD5 checksum
against ENCODE metadata before moving it to the requested destination.

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

Both verification columns should be `TRUE`, confirming that the downloaded
files match the sizes and checksums reported by ENCODE.

### 6. Read the count tables

The selected microRNA quantification files are four-column tables in HTSeq
output format. `encodeUtils` stores the raw-count column in a matrix named
`raw_counts`. Both tables contain complete, unique `gene_id` values, which the
package uses to align their rows.

```r
count_data <- encode_read(
    downloaded,
    values = "raw_counts",
    row_names = "gene_id"
)

count_data
count_data$matrices$raw_counts[seq_len(6L), , drop = FALSE]
```

`count_data` contains the source tables, file and feature metadata, and the
aligned raw-count matrix.

### 7. Write a manifest

Create a manifest that records the file-listing request stored in `count_data`,
the selection criteria, downloaded files, checksums, matrix dimensions, and R
session information. The earlier experiment search remains in `discovery` and
is not part of this manifest.

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

To work with a Bioconductor container instead, read the same verified local
files into a `SummarizedExperiment`. Rows represent features, columns represent
the two ENCODE files, and `colData()` stores the file metadata.

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
