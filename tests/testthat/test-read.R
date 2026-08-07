test_that("local paths return native reader output", {
    path <- withr::local_tempfile(fileext = ".csv")
    writeLines(c("gene,value", "MYC,2.5"), path)
    result <- encode_read(path)

    expect_s3_class(result, "data.frame")
    expect_equal(result$gene, "MYC")
    expect_equal(result$value, 2.5)
})

test_that("BED-like paths return GRanges by default and tables on request", {
    path <- withr::local_tempfile(fileext = ".bed")
    writeLines("chr1\t0\t10\tpeak1\t100\t+", path)

    ranges <- encode_read(path)
    table <- encode_read(path, as = "data.frame")

    expect_s4_class(ranges, "GRanges")
    expect_equal(as.character(GenomicRanges::seqnames(ranges)), "chr1")
    expect_equal(IRanges::start(ranges), 1L)
    expect_s3_class(table, "data.frame")
    expect_equal(table[, c("chrom", "start", "end")], data.frame(
        chrom = "chr1",
        start = 0L,
        end = 10L
    ))
})

test_that("GFF readers handle UCSC directives and native import failures", {
    skip_if_not_installed("rtracklayer")

    path <- withr::local_tempfile(fileext = ".gff")
    writeLines(c(
        "track name=example type=gff",
        "chr1\tsource\tgene\t1\t10\t.\t+\t.\tgene_id 'GENE1';"
    ), path)
    ranges <- encode_read(path, unsupported = "error")

    expect_s4_class(ranges, "GRanges")
    expect_length(ranges, 1L)

    malformed_path <- withr::local_tempfile(fileext = ".gff")
    writeLines("not a GFF record", malformed_path)
    fallback <- encode_read(malformed_path, unsupported = "return_path")

    expect_s3_class(fallback, "encode_local_file")
    expect_equal(fallback$path, malformed_path)
    expect_match(fallback$reason, "rtracklayer::import\\(\\) failed")
})

test_that("table input always returns a stable loaded-file collection", {
    directory <- withr::local_tempdir()
    paths <- file.path(directory, c("a.tsv", "b.tsv"))
    writeLines(c("gene_id\texpected_count\tTPM", "Gata4\t10\t2.5", "Tbx5\t0\t1.5"), paths[[1L]])
    writeLines(c("gene_id\texpected_count\tTPM", "Gata4\t20\t3.5", "Tbx5\t5\t2.0"), paths[[2L]])
    files <- data.frame(
        file_accession = c("ENCFFLOAD01", "ENCFFLOAD02"),
        experiment_accession = "ENCSRLOAD01",
        file_format = "tsv",
        output_type = "gene quantifications",
        local_path = paths,
        download_status = "downloaded",
        provenance_note = c("first", "second"),
        stringsAsFactors = FALSE
    )

    one <- encode_read(files[1L, ], values = c("raw_counts", "tpm"))
    loaded <- encode_read(
        files,
        values = c("raw_counts", "TPM"),
        row_names = "gene_id"
    )

    expect_s3_class(one, "encode_loaded_files")
    expect_s3_class(loaded, "encode_loaded_files")
    expect_equal(names(loaded), c("metadata", "data", "row_data", "matrices"))
    expect_equal(loaded$metadata$provenance_note, c("first", "second"))
    expect_equal(names(loaded$matrices), c("raw_counts", "tpm"))
    expect_true(all(vapply(loaded$matrices, is.matrix, logical(1L))))
    expect_true(all(vapply(loaded$matrices, is.numeric, logical(1L))))
    expect_equal(colnames(loaded$matrices$raw_counts), files$file_accession)
    expect_equal(row.names(loaded$matrices$raw_counts), c("Gata4", "Tbx5"))
    expect_equal(unname(loaded$matrices$raw_counts["Gata4", ]), c(10, 20))
    expect_equal(row.names(loaded$row_data), row.names(loaded$matrices$raw_counts))
    expect_equal(encode_results(loaded), loaded$metadata)
})

test_that("aligned tables can be returned as a SummarizedExperiment", {
    directory <- withr::local_tempdir()
    paths <- file.path(directory, c("a.tsv", "b.tsv"))
    writeLines(c("gene_id\texpected_count\tTPM", "Gata4\t10\t2.5", "Tbx5\t20\t3.5"), paths[[1L]])
    writeLines(c("gene_id\texpected_count\tTPM", "Gata4\t12\t2.8", "Tbx5\t25\t4.0"), paths[[2L]])
    files <- data.frame(
        file_accession = c("ENCFFSE001", "ENCFFSE002"),
        file_format = "tsv",
        local_path = paths,
        download_status = "downloaded",
        stringsAsFactors = FALSE
    )
    retrieved_at <- as.POSIXct("2026-08-06 12:00:00", tz = "UTC")
    filters <- data.frame(
        field = "dataset",
        value = "ENCSRSE001",
        stringsAsFactors = FALSE
    )
    requests <- list(list(
        role = "file_search",
        url = "https://www.encodeproject.org/search/?type=File",
        retrieved_at = retrieved_at
    ))
    criteria <- list(
        file_accession = files$file_accession,
        status = "released"
    )
    files <- encode_attach_metadata(
        files,
        query_url = requests[[1L]]$url,
        retrieved_at = retrieved_at,
        filters = filters,
        request_history = requests,
        selection_criteria = criteria
    )

    se <- encode_read(
        files,
        values = c("raw_counts", "tpm"),
        as = "SummarizedExperiment"
    )

    expect_s4_class(se, "SummarizedExperiment")
    expect_equal(SummarizedExperiment::assayNames(se), c("raw_counts", "tpm"))
    expect_equal(colnames(se), files$file_accession)
    expect_equal(rownames(se), c("Gata4", "Tbx5"))
    expect_equal(SummarizedExperiment::colData(se)$file_accession, files$file_accession)
    expect_equal(unname(SummarizedExperiment::assay(se, "raw_counts")["Gata4", ]), c(10, 12))
    provenance <- S4Vectors::metadata(se)$encodeUtils
    expect_equal(provenance$query_url, requests[[1L]]$url)
    expect_equal(provenance$retrieved_at, retrieved_at)
    expect_equal(provenance$filters, filters)
    expect_equal(provenance$requests, requests)
    expect_equal(provenance$selection_criteria, criteria)

    duplicate <- files
    writeLines(c("gene_id\texpected_count", "Gata4\t10", "Gata4\t20"), duplicate$local_path[[2L]])
    expect_error(
        encode_read(duplicate, as = "SummarizedExperiment"),
        "No compatible expression matrices"
    )
})

test_that("SummarizedExperiment metadata follows only assay-producing files", {
    directory <- withr::local_tempdir()
    table_path <- file.path(directory, "counts.tsv")
    json_path <- file.path(directory, "metadata.json")
    writeLines(c("gene_id\texpected_count", "Gata4\t10", "Tbx5\t20"), table_path)
    writeLines('{"source":"ENCODE"}', json_path)
    files <- data.frame(
        file_accession = c("ENCFFTABLE1", "ENCFFJSON01"),
        file_format = c("tsv", "json"),
        local_path = c(table_path, json_path),
        download_status = "downloaded",
        stringsAsFactors = FALSE
    )

    se <- encode_read(files, as = "SummarizedExperiment")

    expect_s4_class(se, "SummarizedExperiment")
    expect_equal(dim(se), c(2L, 1L))
    expect_equal(colnames(se), "ENCFFTABLE1")
    expect_equal(SummarizedExperiment::colData(se)$file_accession, "ENCFFTABLE1")
})

test_that("matrix assembly refuses incompatible metadata and feature sets", {
    directory <- withr::local_tempdir()
    paths <- file.path(directory, c("a.tsv", "b.tsv"))
    writeLines(c("gene_id\texpected_count", "Gata4\t10", "Tbx5\t20"), paths[[1L]])
    writeLines(c("gene_id\texpected_count", "Gata4\t12", "Myh6\t25"), paths[[2L]])
    files <- data.frame(
        file_accession = c("ENCFFCOMP01", "ENCFFCOMP02"),
        organism = c("Mus musculus", "Homo sapiens"),
        assembly = c("mm10", "GRCh38"),
        output_type = "gene quantifications",
        file_format = "tsv",
        local_path = paths,
        download_status = "downloaded",
        stringsAsFactors = FALSE
    )

    loaded <- encode_read(files)
    expect_length(loaded$matrices, 0L)
    expect_match(attr(loaded$matrices, "reason"), "organism.*assembly")
    expect_error(
        encode_read(files, as = "SummarizedExperiment"),
        "incompatible metadata"
    )

    files$organism <- "Mus musculus"
    files$assembly <- "mm10"
    loaded <- encode_read(files)
    expect_length(loaded$matrices, 0L)
    expect_match(attr(loaded$matrices, "reason"), "different feature sets")
})

test_that("compressed text size is checked after decompression", {
    path <- withr::local_tempfile(fileext = ".tsv.gz")
    connection <- gzfile(path, open = "wt")
    writeLines(c("gene_id\texpected_count", rep("Gata4\t10", 5000L)), connection)
    close(connection)

    expect_lt(as.numeric(file.info(path)$size), 2000)
    expect_error(
        encode_read(path, max_size = "2KB", unsupported = "error"),
        "after decompression"
    )
})

test_that("explicit GRanges requests fail instead of returning a table", {
    path <- withr::local_tempfile(fileext = ".bed")
    writeLines("chr1\tnot-a-start\t10", path)

    expect_error(
        encode_read(path, as = "GRanges", unsupported = "return_path"),
        "Failed to convert BED-like file to GRanges"
    )
})

test_that("quantification value names are normalized case-insensitively", {
    path <- withr::local_tempfile(fileext = ".tsv")
    writeLines(c("gene_id\ttPm", "Gata4\t2.5"), path)

    table <- encode_read(path)
    expect_true("TPM" %in% names(table))
    expect_equal(table$TPM, 2.5)
})

test_that("simplify_quant false preserves raw table columns", {
    path <- withr::local_tempfile(fileext = ".tsv")
    writeLines(c("gene_id\texpected_count\tTPM", "Gata4\t10\t2.5"), path)
    files <- data.frame(
        file_accession = "ENCFFRAW001",
        file_format = "tsv",
        local_path = path,
        download_status = "downloaded",
        stringsAsFactors = FALSE
    )

    loaded <- encode_read(
        files,
        values = "all",
        simplify_quant = FALSE,
        row_names = "none"
    )
    expect_equal(names(loaded$data[[1L]]), c("gene_id", "expected_count", "TPM"))
    expect_false("raw_counts" %in% names(loaded$data[[1L]]))
    expect_equal(names(loaded$matrices), "tpm")
})

test_that("matrix assembly requires a shared unique biological key", {
    directory <- withr::local_tempdir()
    paths <- file.path(directory, c("duplicate-a.tsv", "duplicate-b.tsv"))
    writeLines(
        c("gene_id\texpected_count", "Gata4\t10", "Gata4\t20"),
        paths[[1L]]
    )
    writeLines(
        c("gene_id\texpected_count", "Gata4\t30", "Gata4\t40"),
        paths[[2L]]
    )
    files <- data.frame(
        file_accession = c("ENCFFDUP001", "ENCFFDUP002"),
        file_format = "tsv",
        local_path = paths,
        download_status = "downloaded",
        stringsAsFactors = FALSE
    )

    loaded <- encode_read(files)

    expect_length(loaded$matrices, 0L)
    expect_equal(nrow(loaded$row_data), 0L)
    expect_false(any(grepl("[.]encode_feature_id", names(loaded$data[[1L]]))))
})

test_that("mixed gene identifiers retain a complete matrix key", {
    directory <- withr::local_tempdir()
    paths <- file.path(directory, c("mixed-a.tsv", "mixed-b.tsv"))
    writeLines(
        c(
            "gene_id\texpected_count\tTPM",
            "10000\t10\t1.0",
            "ENSMUSG00000000001\t20\t2.0",
            "Gata4\t30\t3.0"
        ),
        paths[[1L]]
    )
    writeLines(
        c(
            "gene_id\texpected_count\tTPM",
            "10000\t11\t1.1",
            "ENSMUSG00000000001\t21\t2.1",
            "Gata4\t31\t3.1"
        ),
        paths[[2L]]
    )
    files <- data.frame(
        file_accession = c("ENCFFMIX001", "ENCFFMIX002"),
        file_format = "tsv",
        local_path = paths,
        download_status = "downloaded",
        stringsAsFactors = FALSE
    )

    loaded <- encode_read(files, values = c("raw_counts", "tpm"))

    expect_true("gene_id" %in% names(loaded$data[[1L]]))
    expect_equal(names(loaded$matrices), c("raw_counts", "tpm"))
    expect_equal(nrow(loaded$row_data), 3L)
    expect_equal(unname(loaded$matrices$raw_counts[, 1L]), c(10, 20, 30))
})

test_that("headerless and featureCounts tables expose raw counts consistently", {
    htseq <- withr::local_tempfile(fileext = ".tsv")
    writeLines(c("ENSMUSG00000000001\t10", "N_unmapped\t2"), htseq)
    feature_counts <- withr::local_tempfile(fileext = ".tsv")
    writeLines(c(
        "Geneid\tChr\tStart\tEnd\tStrand\tLength\tsample.bam",
        "ENSMUSG00000000001\t1\t1\t100\t+\t100\t12"
    ), feature_counts)

    expect_named(encode_read(htseq), c("gene_id", "raw_counts"))
    expect_named(encode_read(feature_counts), c("gene_id", "raw_counts"))
})

test_that("featureCounts simplification rejects ambiguous sample columns", {
    path <- withr::local_tempfile(fileext = ".tsv")
    writeLines(c(
        "Geneid\tChr\tStart\tEnd\tStrand\tLength\tsample_a.bam\tsample_b.bam",
        "ENSMUSG00000000001\t1\t1\t100\t+\t100\t12\t15"
    ), path)

    expect_error(
        encode_read(path),
        "exactly one sample-count column"
    )
    expect_named(
        encode_read(path, simplify_quant = FALSE),
        c(
            "Geneid", "Chr", "Start", "End", "Strand", "Length",
            "sample_a.bam", "sample_b.bam"
        )
    )
})

test_that("loaded print output is compact", {
    path <- withr::local_tempfile(fileext = ".tsv")
    writeLines(c("gene_id\texpected_count", "Gata4\t10"), path)
    files <- data.frame(
        file_accession = "ENCFFPRINT1",
        file_format = "tsv",
        local_path = path,
        download_status = "downloaded",
        stringsAsFactors = FALSE
    )
    loaded <- encode_read(files)
    output <- capture_print(loaded)

    expect_true(any(grepl("ENCODE loaded files", output, fixed = TRUE)))
    expect_true(any(grepl("feature rows", output, fixed = TRUE)))
})

test_that("read controls reject ambiguous values", {
    path <- withr::local_tempfile(fileext = ".csv")
    writeLines(c("gene,value", "MYC,2.5"), path)

    expect_error(encode_read(path, format = c("csv", "tsv")), "format")
    expect_error(encode_read(path, allow_large = 1), "allow_large")
    expect_error(encode_read(path, simplify_quant = NA), "simplify_quant")
})
