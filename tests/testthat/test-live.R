test_that("opt-in live ENCODE smoke test detects API drift", {
    skip_if_not(identical(Sys.getenv("ENCODEUTILS_LIVE_TESTS"), "true"))

    result <- encode_search(
        type = "Experiment",
        filters = list(
            "replicates.library.biosample.organism.scientific_name" =
                "Homo sapiens"
        ),
        limit = 1L,
        quiet = TRUE
    )
    expect_s3_class(result, "encode_search_result")
    expect_lte(nrow(encode_results(result)), 1L)

    if (nrow(encode_results(result)) == 1L) {
        files <- encode_list_files(result, limit = 1L, quiet = TRUE)
        expect_s3_class(files, "encode_file_table")
        expect_lte(nrow(files), 1L)
    }
})
