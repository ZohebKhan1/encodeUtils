# inst/scripts

This directory is reserved for scripts that document how any package example
data or external metadata snapshots were obtained and prepared.

`refresh_test_fixtures.R` documents how the small offline test fixtures can be
refreshed from current ENCODE API responses. It is opt-in and requires
`ENCODEUTILS_REFRESH_FIXTURES=true` so package checks do not access the
network.
