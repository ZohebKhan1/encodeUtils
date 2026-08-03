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
    loaded <- encode_read(files, values = c("raw_counts", "TPM"))

    expect_s3_class(one, "encode_loaded_files")
    expect_s3_class(loaded, "encode_loaded_files")
    expect_equal(names(loaded), c("metadata", "data", "row_data", "matrices"))
    expect_equal(loaded$metadata$provenance_note, c("first", "second"))
    expect_equal(names(loaded$matrices), c("raw_counts", "tpm"))
    expect_true(all(vapply(loaded$matrices, is.matrix, logical(1L))))
    expect_true(all(vapply(loaded$matrices, is.numeric, logical(1L))))
    expect_equal(colnames(loaded$matrices$raw_counts), files$file_accession)
    expect_equal(unname(loaded$matrices$raw_counts["Gata4", ]), c(10, 20))
    expect_equal(row.names(loaded$row_data), row.names(loaded$matrices$raw_counts))
    expect_equal(encode_results(loaded), loaded$metadata)
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
    expect_false(any(grepl("by_experiment", output, fixed = TRUE)))
})

test_that("read controls reject ambiguous values", {
    path <- withr::local_tempfile(fileext = ".csv")
    writeLines(c("gene,value", "MYC,2.5"), path)

    expect_error(encode_read(path, format = c("csv", "tsv")), "format")
    expect_error(encode_read(path, allow_large = 1), "allow_large")
    expect_error(encode_read(path, simplify_quant = NA), "simplify_quant")
})
