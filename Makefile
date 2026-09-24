DP_DATA_ROOT ?= $(abspath ../dp-data)
export DP_DATA_ROOT

.PHONY: restore format lint test analysis paper check ci-docker clean

restore:
	Rscript -e 'renv::restore(prompt = FALSE)'

format:
	Rscript -e 'styler::cache_deactivate(verbose = FALSE); styler::style_dir("scripts"); styler::style_dir("tests")'

lint:
	Rscript -e 'l <- c(lintr::lint_dir("scripts"), lintr::lint_dir("tests")); print(l); quit(status = as.integer(length(l) > 0L))'

test: analysis
	Rscript tests/testthat.R

analysis:
	Rscript scripts/99_run_all.R

paper: analysis
	cd ms && ./compile.sh

check: lint test paper

ci-docker:
	docker run --rm -e RENV_PATHS_LIBRARY=/tmp/renv-library \
		-e DP_DATA_ROOT=/dp-data -v "$(DP_DATA_ROOT):/dp-data:ro" \
		-v "$(CURDIR):/work" -w /work rocker/r-ver:4.6.0 bash -lc \
		"apt-get update && apt-get install -y --no-install-recommends make cmake curl pandoc \
		libfontconfig1-dev libuv1-dev libx11-dev libxml2-dev \
		libfreetype6-dev libharfbuzz-dev libfribidi-dev libpng-dev libtiff-dev libjpeg-dev \
		latexmk texlive-xetex texlive-latex-extra texlive-fonts-recommended biber && \
		make restore check"

clean:
	cd ms && latexmk -C main.tex supplement.tex
