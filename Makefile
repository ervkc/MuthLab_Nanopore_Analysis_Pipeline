all: conda dorado run

conda:
	@echo "installing miniconda and creating conda environment ..."
	bash tools/install_conda.sh

dorado:
	@echo "installing dorado ..."
	bash tools/install_dorado.sh

run:
	@echo "launching app ..."
	. ./miniconda/etc/profile.d/conda.sh && \
	conda activate pipeline_env && \
	R -e "shiny::runApp('$(shell pwd)/app.R')"




