# Test Fixture Notes

These fixtures are small offline ENCODE-shaped responses used by the test suite.
They are intentionally compact so routine `R CMD check` and Bioconductor checks
remain fast, deterministic, and network-independent.

Fixture role:

- `search-embedded-experiments.json`: embedded experiment search response with
  linked lab, award, biosample, column, filter, and facet fields.
- `file-search-mixed.json`: file search response with experiment-backed and
  annotation-backed file records.

The fixtures are representative and manually curated from ENCODE response
shapes. They are not a substitute for opt-in live smoke tests. Keep fixtures
small and preserve edge cases such as annotation dataset paths, missing optional
fields, and mixed file formats.
