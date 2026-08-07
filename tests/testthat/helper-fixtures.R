fixture_path <- function(...) {
    testthat::test_path("fixtures", ...)
}

fixture_text <- function(name) {
    paste(readLines(fixture_path(name), warn = FALSE), collapse = "\n")
}

fixture_json_response <- function(name, status = 200L) {
    httr2::response(
        status,
        headers = "Content-Type: application/json",
        body = charToRaw(fixture_text(name))
    )
}

local_encode_test_options <- function() {
    withr::local_options(list(
        encodeUtils.rate_per_second = FALSE,
        encodeUtils.max_tries = 1L
    ))
}

fixture_file_table <- function() {
    data.frame(
        file_accession = c(
            "ENCFF000AAA", "ENCFF000AAB", "ENCFF000AAC", "ENCFF000AAD"
        ),
        experiment_accession = c(
            "ENCSR000AAA", "ENCSR000AAA", "ENCSR000AAB", "ENCSR000AAC"
        ),
        file_format = c("bed", "bed", "fastq", "bigWig"),
        output_type = c(
            "optimal IDR thresholded peaks",
            "replicated peaks",
            "reads",
            "fold change over control"
        ),
        assembly = c("GRCh38", "hg19", NA_character_, "GRCh38"),
        status = c("released", "released", "released", "archived"),
        href = c(
            "/files/ENCFF000AAA/@@download/ENCFF000AAA.bed",
            "/files/ENCFF000AAB/@@download/ENCFF000AAB.bed",
            "/files/ENCFF000AAC/@@download/ENCFF000AAC.fastq.gz",
            "/files/ENCFF000AAD/@@download/ENCFF000AAD.bigWig"
        ),
        file_size = c(100, 200, 300, 400),
        md5sum = NA_character_,
        biological_replicates = c(
            NA_character_, NA_character_, "1", NA_character_
        ),
        preferred_default = c(TRUE, FALSE, NA, TRUE),
        stringsAsFactors = FALSE
    )
}

capture_print <- function(x) {
    utils::capture.output(
        utils::capture.output(print(x), type = "message")
    )
}
