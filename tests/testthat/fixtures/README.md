# Test Fixture Provenance

These fixtures are small offline ENCODE-shaped responses used by the test suite.
They are intentionally compact so routine `R CMD check` and Bioconductor checks
remain fast, deterministic, and network-independent.

Current fixture role:

- `search-embedded-experiments.json`: embedded experiment search response with
  linked lab, award, biosample, column, filter, and facet fields.
- `experiment-object.json`: one experiment object response.
- `file-search-mixed.json`: file search response with experiment-backed and
  annotation-backed file records. The refresh script combines separate live
  experiment-file and annotation-file queries, then lightly normalizes the
  dataset fields so tests preserve both object-valued and path-valued dataset
  representations.
- `schema-file.json`: profile/schema response with required, enum, and link
  fields.
- `matrix-small.json`: compact matrix endpoint response.
- `report-small.tsv` and `report-empty.tsv`: TSV report success and malformed
  table edge cases.

The fixtures are representative and manually curated from ENCODE response
shapes. They are not a substitute for opt-in live smoke tests. To refresh them
from current ENCODE API responses, run `inst/scripts/refresh_test_fixtures.R`
from the package root with `ENCODEUTILS_REFRESH_FIXTURES=true`.

Refreshes should be reviewed as API-contract changes. Keep fixtures small,
remove any large embedded payloads, and preserve edge cases that protect known
regressions such as annotation dataset paths, missing optional fields, and
mixed file formats.
