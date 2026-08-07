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

The package is not affiliated with or endorsed by the ENCODE Project.

## ENCODE API disclaimer

The following rate-limit disclaimer is reproduced directly from the
[ENCODE REST API documentation](https://www.encodeproject.org/help/rest-api/):

> Use of the programmatic API is limited to 10 GET requests/sec from any single
> user, group, company or lab.
>
> Abuse of this will result in denial of access by IP block

## Documentation

See the [getting-started vignette](https://zohebkhan1.github.io/encodeUtils/articles/get-started.html) and [function reference](https://zohebkhan1.github.io/encodeUtils/reference/).

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
install.packages("BiocManager")
BiocManager::install("encodeUtils")
```

Install the development version with:

```r
install.packages("pak")
pak::pak("ZohebKhan1/encodeUtils")
```

## Example workflow

This example shows how to retrieve replicate-level raw microRNA counts from
male 5xFAD mouse heart tissue.

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
    experiment_table[c(
        "accession", "assay_title", "organism", "biosample_summary",
        "life_stage_age", "sex", "status"
    )],
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

### 2. List the experiment's files

Use the accession returned by the search to retrieve metadata for every
released file associated with the experiment.

```r
files <- encode_list_files(
    experiment_table$accession[[1L]]
)

file_table <- as.data.frame(encode_results(files))

file_inventory <- unique(file_table[c("file_format", "output_type", "assembly")])

print(file_inventory, row.names = FALSE)
```

```text
#>  file_format                         output_type assembly
#>       bigWig    minus strand signal of all reads     mm10
#>        fastq                               reads     <NA>
#>          tsv            microRNA quantifications     mm10
#>          bam                          alignments     mm10
#>       bigWig  plus strand signal of unique reads     mm10
#>       bigWig     plus strand signal of all reads     mm10
#>       bigWig minus strand signal of unique reads     mm10
```

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
    size = selected_table$file_size_pretty
)

print(selected_display, row.names = FALSE)
```

The selection narrows the inventory to the two TSV files shown below. The
remaining steps use these two accessions.

```text
#>    accession replicate     size
#>  ENCFF859GWB         1 59.54 KB
#>  ENCFF838WBE         2 59.57 KB
```

### 4. Preview the download

Create a download plan before transferring data. The plan compares the file
sizes reported by ENCODE with the configured limits but does not download the
files. This example saves data in `encode-data` under the current working
directory; change `download_directory` to use a different location. Each
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

plan_table <- encode_results(plan)

plan_display <- data.frame(
    accession = plan_table$file_accession,
    status = plan_table$download_status,
    size = plan_table$file_size_pretty,
    file = basename(plan_table$local_path)
)

print(plan_display, row.names = FALSE)
```

```text
#>    accession  status     size            file
#>  ENCFF859GWB planned 59.54 KB ENCFF859GWB.tsv
#>  ENCFF838WBE planned 59.57 KB ENCFF838WBE.tsv
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

download_table <- encode_results(downloaded)

download_display <- data.frame(
    accession = download_table$file_accession,
    status = download_table$download_status,
    size_verified = download_table$size_verified,
    md5_verified = download_table$md5_verified
)

print(download_display, row.names = FALSE)
```

```text
#>    accession     status size_verified md5_verified
#>  ENCFF859GWB downloaded          TRUE         TRUE
#>  ENCFF838WBE downloaded          TRUE         TRUE
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

print(count_data)
```

```text
#> ENCODE loaded files
#> - files: 2
#> - file objects: 2
#> - feature rows: 2202
#> - matrices: 1
#> Metadata:
#>         file  experiment        assay     organism assembly file_size   status
#>  ENCFF859GWB ENCSR523CTA microRNA-seq Mus musculus     mm10  59.54 KB released
#>  ENCFF838WBE ENCSR523CTA microRNA-seq Mus musculus     mm10  59.57 KB released
```

`count_data` contains the source tables, file and feature metadata, and the
aligned raw-count matrix.

Show the first five rows of the raw-count matrix.

```r
print(head(count_data$matrices$raw_counts, 5L))
```

```text
#>                      ENCFF859GWB ENCFF838WBE
#> ENSMUSG00000093015.1           0           0
#> ENSMUSG00000093970.1           0           0
#> ENSMUSG00000076135.1           0           0
#> ENSMUSG00000098555.1           0           0
#> ENSMUSG00000099183.1          12          21
```

### 7. Write a manifest

Create a manifest that records the file-listing request stored in `count_data`,
the selection criteria, downloaded files, checksums, matrix dimensions, and R
session information. The earlier experiment search remains in `discovery` and
is not part of this manifest.

```r
manifest <- encode_manifest(count_data, path = "encode-manifest.json")

print(
    data.frame(
        manifest = basename(attr(manifest, "path")),
        files = nrow(manifest$files),
        requests = length(manifest$requests),
        matrices = nrow(manifest$matrices)
    ),
    row.names = FALSE
)
```

```text
#>             manifest files requests matrices
#> encode-manifest.json     2        1        1
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

print(se)
```

```text
#> class: SummarizedExperiment
#> dim: 2202 2
#> metadata(1): encodeUtils
#> assays(1): raw_counts
#> rownames(2202): ENSMUSG00000093015.1 ENSMUSG00000093970.1 ...
#>   ENSMUSG00000098868.1 ENSMUSG00000099228.1
#> rowData names(1): gene_id
#> colnames(2): ENCFF859GWB ENCFF838WBE
#> colData names(58): file_accession accession ... md5_verified
#>   failure_reason
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
