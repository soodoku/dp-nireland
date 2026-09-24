# Data record

## Public upstream inputs

All analytical inputs are supplied by dp-data v0.2.2 under
`data/northern-ireland-2007/`. Clone that release beside this repository or
extract its source archive to `../dp-data`, then run `make restore` and
`make check`. Set `DP_DATA_ROOT` for a different location. CI checks out the
pinned upstream commit; no vault or historical Git extraction is needed.
`data/manifest.yaml` pins each input's SHA-256, and a build stops before analysis
if a file is missing or changed. Docker mounts dp-data read-only.

The three inputs are:

- `survey.parquet`: 868 rows and 449 columns, including `source_row`. The public
  numeric survey excludes 80 verbatim fields. Every variable used by the paper
  agrees with the previous CSV reader.
- `groups.csv`: the original headerless roster with 124 mappings. Its line endings
  differ from the former local copy, but all records agree. The reader still
  consumes the first record as column headings, preserving the historical result
  pending the separate correction described below.
- `argument-codes.parquet`: 65,760 records for 274 respondents, with columns
  `respondent_id`, `wave`, `topic`, `side`, `slot`, `coder`, and `raw_code`.
  The first six columns identify a record. Waves are 2/3, topics 18–21, sides
  a/b, slots 1–5, and coders ch/la/monty. The first two coders supplied independent
  labels; monty supplied adjudication. Missing labels remain missing.

Upstream `R/argument_codes.R` selects the ID and 240 coder fields from the
historical `data/open_ended/fin.csv` and reshapes them without adjudication.
Its original SHA-256 is
`314a9a9abb40c6094dab2e7c9af761041557b791240f0932b3848699e861f39c`;
the source is preserved at dp-nireland commit
`929e45d32213e0dd4516e510731ddb9e2c309006`. The typed extract preserves the
labels consumed by the original reader, including missing slots, while excluding
verbatim responses. The downstream paper retains normalization, adjudication,
scoring, and administration rules.

`audit/source_relocation.csv` preserves the earlier 54-file relocation inventory
as historical provenance. Those archival files are no longer runtime inputs;
the inventory is not a public-release availability claim.

## Numerical baseline and future changes

The baseline was rebuilt and tested before relocation. The external-input build
reproduced all 19 pinned CSV and LaTeX outputs exactly, including intermediate
survey and coding tables, estimates, standard errors, and manuscript numbers.
`audit/numerical_baseline.csv` records their hashes. Every full analysis writes
`audit/numerical_comparison.csv`. Seventeen outputs must match byte-for-byte.
For the two estimate CSVs, `audit/baseline/` retains the original full-precision
reference files, whose hashes must match the original baseline. The six
inferential statistics may differ by at most `1e-10` in absolute value;
column names, row order, text, missingness, sample sizes, and cluster counts must
match exactly. The report distinguishes byte identity (`unchanged`) from
acceptance (`equivalent`) and records the largest absolute numeric difference.
Missing outputs or larger differences fail the build.

Linux CI at commit `74206ed` reproduced all 17 other outputs exactly, but numerical
linear algebra produced coefficient differences up to `1.33e-14`, interval
endpoint differences up to `3.29e-14`, and degrees-of-freedom differences up to
`6.59e-11` relative to the Mac baseline. Counts and formatted paper numbers were
identical. This documented tolerance accommodates those differences without
rounding estimates, replacing reference values, or relaxing source checksums.
PDF bytes are excluded because creation metadata can change between builds.

Before changing a source, save the current generated outputs and record the old
source hashes. Compare old and new inputs by respondent and variable, identifying
added or removed IDs, changed values, missingness, and group membership. Update
the source pin only after documenting that evidence. Rebuild and use the failed
numerical comparison to locate affected outputs; compare estimates, uncertainty,
and sample sizes with the saved baseline. Record the cause, magnitude, and validation results in the commit description
before deliberately updating affected baseline hashes.
Never refresh all pins merely to make a failing check pass. Exact output checks
can also flag serialization or numerical-library changes; distinguish these from
source changes using the saved values and R environment.

## Deferred roster correction

The group roster begins with respondent `112084` in group `N`. The preserved
reader treats that record as a header, leaving 123 mappings and one participant
without a group. Correcting this can change clustering, standard errors,
degrees of freedom, and intervals. It must be evaluated separately against the
current baseline. dp-data records the issue as NI-01 in `docs/poll-issues.md`.

The public survey also differs from the historical CSV in `t1q10h_6` and
`intdate`, neither used here. Those differences are not recoding changes in this
migration. `output/memberships.parquet` is a knowledge-analysis product and is
not substituted for the original roster.

## Missingness

The open-ended prompts were administered at T2 to participants and at T3 to
returning participants and controls. A respondent-wave outside those groups is
structurally missing. The legacy data used `rowSums(..., na.rm = TRUE)`, which
created zeroes for non-administered waves. The rebuilt data keep those cells
missing.

An administered respondent can legitimately have zero valid reasons. Such a zero
is distinct from a non-administered wave. A primary total is missing if any coder
disagreement for that respondent-wave lacks adjudication. Coder-specific
sensitivities retain these observations.

## Coding provenance

Coder entries can contain sets such as `4,5` or `c4.c5`. The pipeline extracts
integer labels, sorts and deduplicates each set, and compares normalized sets.
Matching sets are accepted; disagreements use the third coder when available;
unadjudicated disagreements remain unresolved. Slot-level provenance is written
to `data/derived/coding_slots.csv` during the build.

## Historical response text

The public analytical inputs exclude verbatim answers. Earlier files in Git
history and the local archive still contain those answers; this migration does
not establish their suitability for redistribution. Their previously recorded
pattern scan is not evidence that the text is anonymous.
