# How Can You Think That?

This repository contains the analysis and manuscript for *How Can You
Think That? Deliberation and the Learning of Opposing Arguments*, by Gaurav
Sood, Robert C. Luskin, and James S. Fishkin.

The study examines whether people can articulate reasons supporting and opposing
school-policy proposals after a Deliberative Poll in Omagh, Northern Ireland.
The rebuilt analysis treats the central participant--control comparison as an
association: event attendance was self-selected, and the open-ended outcome was
not measured at the recruitment interview. Current estimates and intervals are
generated in [`tabs/main_estimates.csv`](tabs/main_estimates.csv); the design
interpretation is recorded in [`docs/design.md`](docs/design.md).

## Reproduce the paper

The project uses R and XeLaTeX. From the repository root:

```sh
git clone --branch v0.2.2 --depth 1 https://github.com/soodoku/dp-data.git ../dp-data
make restore
make check
```

The public dp-data release supplies all three analytical inputs. A downloaded
release archive works too; extract it to `../dp-data`, or set `DP_DATA_ROOT`
to its location. Builds verify the pinned file hashes before reading data.
See [`docs/data.md`](docs/data.md) for the source contracts and update procedure.

The individual targets are:

```sh
make analysis
make lint
make test
make paper
make ci-docker
```

The compiled paper is [`ms/main.pdf`](ms/main.pdf), and the Supporting
Information is [`ms/supplement.pdf`](ms/supplement.pdf). Analytical results are
stored together in the generated `data/derived/analysis_results.rds` object.
The pipeline renders publication tables directly with `knitr::kable`; the two
headline CSV files in `tabs/` provide machine-readable estimates.
Inline manuscript numbers come from [`tabs/numbers.tex`](tabs/numbers.tex).

## Repository structure

- `data/`: source manifest and ignored generated analysis data
- `scripts/`: numbered R pipeline
- `tests/`: data-contract and coding tests
- `tabs/`: headline CSV results and generated LaTeX table fragments
- `figs/`: generated publication figures
- `ms/`: current manuscript, bibliography, and the August 2014 source PDF
- `docs/`: research-design and data documentation

The source files used by the current pipeline and their SHA-256 hashes are
pinned in [`data/manifest.yaml`](data/manifest.yaml). Sample membership,
demographics, policy attitudes, and group identifiers are reconstructed from the
raw survey export and group roster; historical derived survey variables are not
used.

## Main measurement decisions

The primary outcome is a respondent-level count of response slots containing at
least one substantive reason. Invalid, missing, and vague codes are excluded.
Question-specific answers that merely attribute the other position to prejudice
or ignorance are excluded in the primary measure and restored in a sensitivity
analysis. Multi-label codes are parsed as sets. Unadjudicated coder conflicts
remain unresolved; separate coder-specific estimates show the effect of that
choice.

Non-administered survey waves remain missing. They are never converted to zero.
Uncertainty estimates use CR2 small-sample corrections, clustering participants
by discussion group while treating ungrouped respondents as singleton clusters.

## Data responsibility

The public inputs contain a numeric survey, group roster, and coder labels.
Verbatim responses are excluded. Historical files containing response text remain
in the original repository history and the local source archive; they are not
required to reproduce the paper. See [`docs/data.md`](docs/data.md).

The MIT license covers code and documentation only. It does not relicense the
source data.
