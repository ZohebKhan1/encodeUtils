test_that("tabular readers return files verbatim", {
    path <- withr::local_tempfile(fileext = ".tsv")
    writeLines(
        c(
            "gene_id\texpected_count\tuser_note",
            "Gata4\t10\tkeep me"
        ),
        path
    )

    table <- encode_read(path)
    expect_named(table, c("gene_id", "expected_count", "user_note"))
    expect_false("raw_counts" %in% names(table))
    expect_equal(table$user_note, "keep me")
})

test_that("quantification preparation is explicit and preserves columns", {
    table <- data.frame(
        gene_id = c("Gata4", "N_unmapped"),
        expected_count = c(10, 2),
        user_note = c("keep", "summary")
    )
    prepared <- encode_prepare_quant(table)

    expect_named(
        prepared,
        c("gene_id", "expected_count", "user_note", "raw_counts")
    )
    expect_equal(prepared$gene_id, "Gata4")
    expect_equal(prepared$raw_counts, 10)
    expect_equal(prepared$user_note, "keep")
})

test_that("headerless HTSeq recognition occurs only on explicit preparation", {
    path <- withr::local_tempfile(fileext = ".tsv")
    writeLines(c("Gata4\t10", "Tbx5\t4", "N_unmapped\t2"), path)

    raw <- encode_read(path, header = FALSE)
    expect_named(raw, c("V1", "V2"))
    prepared <- encode_prepare_quant(raw)
    expect_named(prepared, c("gene_id", "raw_counts"))
    expect_equal(prepared$gene_id, c("Gata4", "Tbx5"))
})

test_that("read_all returns metadata and native objects without matrices", {
    directory <- withr::local_tempdir()
    paths <- file.path(directory, c("a.tsv", "b.tsv"))
    writeLines(c("gene_id\texpected_count", "Gata4\t10"), paths[[1L]])
    writeLines(c("gene_id\texpected_count", "Gata4\t12"), paths[[2L]])
    files <- data.frame(
        file_accession = c("ENCFFLOAD01", "ENCFFLOAD02"),
        file_format = "tsv",
        local_path = paths,
        download_status = "downloaded",
        provenance_note = c("first", "second")
    )

    loaded <- encode_read_all(files, quiet = TRUE)
    expect_s3_class(loaded, "encode_loaded_files")
    expect_named(loaded, c("metadata", "data"))
    expect_false("matrices" %in% names(loaded))
    expect_equal(loaded$metadata$provenance_note, c("first", "second"))
    expect_false("raw_counts" %in% names(loaded$data[[1L]]))
})

test_that("prepared tables convert explicitly to SummarizedExperiment", {
    directory <- withr::local_tempdir()
    paths <- file.path(directory, c("a.tsv", "b.tsv"))
    writeLines(c("gene_id\texpected_count", "Gata4\t10", "Tbx5\t20"), paths[[1L]])
    writeLines(c("gene_id\texpected_count", "Tbx5\t25", "Gata4\t12"), paths[[2L]])
    files <- data.frame(
        file_accession = c("ENCFFSE001", "ENCFFSE002"),
        organism = "Mus musculus",
        assembly = "mm10",
        output_type = "gene quantifications",
        file_format = "tsv",
        local_path = paths,
        download_status = "downloaded"
    )
    attr(files, "query_url") <- "https://encode.example/search/?type=File"
    loaded <- encode_prepare_quant(encode_read_all(files, quiet = TRUE))
    se <- encode_as_summarized_experiment(loaded)

    expect_s4_class(se, "SummarizedExperiment")
    expect_equal(SummarizedExperiment::assayNames(se), "raw_counts")
    expect_equal(colnames(se), files$file_accession)
    expect_equal(
        unname(SummarizedExperiment::assay(se)["Gata4", ]),
        c(10, 12)
    )
    expect_equal(
        S4Vectors::metadata(se)$encodeUtils$query_url,
        attr(files, "query_url")
    )
})

test_that("one feature from one file remains a matrix", {
    path <- withr::local_tempfile(fileext = ".tsv")
    writeLines(c("gene_id\traw_counts", "Gata4\t10"), path)
    files <- data.frame(
        file_accession = "ENCFFONE001",
        file_format = "tsv",
        local_path = path
    )
    se <- encode_as_summarized_experiment(
        encode_read_all(files, quiet = TRUE)
    )

    expect_equal(dim(se), c(1L, 1L))
    expect_equal(SummarizedExperiment::assay(se)[1L, 1L], 10)
})

test_that("matrix incompatibilities produce direct errors", {
    directory <- withr::local_tempdir()
    paths <- file.path(directory, c("a.tsv", "b.tsv"))
    writeLines(c("gene_id\traw_counts", "Gata4\t10"), paths[[1L]])
    writeLines(c("gene_id\traw_counts", "Tbx5\t12"), paths[[2L]])
    files <- data.frame(
        file_accession = c("ENCFFBAD001", "ENCFFBAD002"),
        organism = "Mus musculus",
        assembly = "mm10",
        file_format = "tsv",
        local_path = paths,
        download_status = "downloaded"
    )
    loaded <- encode_read_all(files, quiet = TRUE)

    expect_error(
        encode_as_summarized_experiment(loaded),
        "same feature set"
    )
    loaded$metadata$assembly[[2L]] <- "GRCh38"
    expect_error(
        encode_as_summarized_experiment(loaded),
        "assembly"
    )
})

test_that("BED tables and path fallbacks are explicit", {
    bed <- withr::local_tempfile(fileext = ".bed")
    writeLines("chr1\t0\t10\tpeak1\t100\t+", bed)
    table <- encode_read(bed, as = "data.frame")
    expect_equal(table[c("chrom", "start", "end")], data.frame(
        chrom = "chr1", start = 0L, end = 10L
    ))

    fastq <- withr::local_tempfile(fileext = ".fastq")
    writeLines(c("@read", "ACGT", "+", "!!!!"), fastq)
    expect_s3_class(encode_read(fastq), "encode_local_file")
})

test_that("read cap checks compressed content and can be disabled", {
    path <- withr::local_tempfile(fileext = ".tsv.gz")
    connection <- gzfile(path, open = "wt")
    writeLines(c("gene_id\tvalue", rep("Gata4\t10", 500L)), connection)
    close(connection)

    expect_error(
        encode_read(path, max_size = "1KB", unsupported = "error"),
        "after decompression"
    )
    expect_s3_class(encode_read(path, max_size = NULL), "data.frame")
})

test_that("read arguments reject ambiguous values", {
    path <- withr::local_tempfile(fileext = ".csv")
    writeLines(c("gene,value", "MYC,2.5"), path)
    expect_error(encode_read(path, format = c("csv", "tsv")), "format")
    expect_error(encode_read(path, allow_large = 1), "allow_large")
    expect_error(encode_read(data.frame(local_path = path)), "one local")
})
