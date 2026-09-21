# Data record

## Current analytical inputs

`data/orig_data/nireland.csv` is the flat-file mirror of the original merged
Stata survey export. The pipeline reconstructs sample membership, demographics,
and policy-attitude variables from its raw columns. `data/groups.csv` supplies
the discussion-group identifier. Historical derived survey variables are not
used.

`data/open_ended/fin.csv` contains respondent identifiers, verbatim responses,
two independent coder labels, and adjudicator labels. The pipeline reshapes the
coder fields to one row per respondent, wave, topic, side, slot, and coder.

`data/orig_data/nireland.dta` is retained as the original merged Stata file. Its
CSV mirror has the same 868 rows and 528 columns. Source hashes are in
`data/manifest.yaml`.

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

## Privacy review

The open-ended file contains pseudonymous IDs and verbatim responses. Screening
the analyzed response fields covered 3,423 nonmissing text entries and found no
matches to email-address, telephone-number, or UK-postcode patterns. Regex
screening cannot establish anonymity: names, workplaces, family relationships,
or rare events may still identify a respondent in context.

Before a new public release, a human reviewer should inspect verbatim text under
an approved disclosure standard and confirm that the original consent permits
public redistribution. Git preserves earlier versions, so removing a file in a
new commit does not remove it from repository history.
