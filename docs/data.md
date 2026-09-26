# Data record

## Public upstream inputs

All analytical inputs are supplied by dp-data v0.2.2. The survey and coding
files are under `data/northern-ireland-2007/`; typed group memberships are in
`output/memberships.parquet`. Clone that release beside this repository or
extract its source archive to `../dp-data`, then run `make restore` and
`make check`. Set `DP_DATA_ROOT` for a different location. CI checks out the
pinned upstream commit; no vault or historical Git extraction is needed.
`data/manifest.yaml` pins each input's SHA-256, and a build stops before analysis
if a file is missing or changed. Docker mounts dp-data read-only.

The three inputs are:

- `survey.parquet`: 868 rows and 449 columns, including `source_row`. The public
  numeric survey excludes 80 verbatim fields. Every variable used by the paper
  agrees with the previous CSV reader.
- `output/memberships.parquet`: typed memberships across polls. The Northern
  Ireland deliberation session has 124 respondent-to-group mappings, including
  the first record of its original headerless roster.
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

## Updating sources

The analysis verifies the SHA-256 pins in `data/manifest.yaml` before reading
inputs. When an upstream file changes, compare respondent IDs, variables,
missingness, and group membership before updating its pin. Rebuild with
`make check` and review changes in the generated estimates, sample sizes,
figures, and manuscript.

## Group roster correction

The source roster is headerless and contains 124 mappings. The former reader
treated its first record, respondent `112084` in group `N`, as a header. That
attendee became a singleton cluster even though the source assigns them to an
existing discussion group. The reader now uses dp-data's typed membership
export and checks all 124 mappings. It retains the upstream group labels
instead of assigning arbitrary numeric IDs. That changes the representation
of known groups; only respondent `112084` changes group membership. The
respondent-wave and slot tables carry the corrected assignment forward.
Point estimates, coded responses and analysis sample sizes are unchanged.
Cluster counts fall by one in affected comparisons, changing CR2 standard
errors, degrees of freedom, intervals and p-values. Across all generated
result tables, no p-value crosses 0.05 and no confidence interval changes
whether it includes zero. The main paired comparison has 19 clusters rather
than the historical 20. The previous values remain in Git history. dp-data
records the source issue as NI-01 in `docs/poll-issues.md`.

The public survey also differs from the historical CSV in `t1q10h_6` and
`intdate`, neither used here. Those differences are not recoding changes in this
migration.

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
