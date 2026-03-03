# Makefile for moving files and cleaning simulation artifacts

# Default target
.PHONY: help
help:
	@echo "Usage:"
	@echo "  make move DIR=<directory>  - Move files to specified directory (e.g., make move DIR=b01)"
	@echo "  make clean                 - Remove simulation artifacts"

# Move target - requires DIR parameter
.PHONY: move
move:
ifndef DIR
	$(error DIR is not set. Usage: make move DIR=b01)
endif
	@echo "Moving files to $(DIR)/..."
	@mkdir -p $(DIR)
	@if [ -d "rtl" ]; then \
		mv rtl/*.v $(DIR)/ 2>/dev/null || echo "No .v files in rtl/ to move"; \
	else \
		echo "rtl/ directory not found"; \
	fi
	@if [ -d "tb" ]; then \
		mv tb/*.v $(DIR)/ 2>/dev/null || echo "No .v files in tb/ to move"; \
	else \
		echo "tb/ directory not found"; \
	fi
	@mv tb_top.vcd $(DIR)/ 2>/dev/null || echo "tb_top.vcd not found"
	@mv timeseries.csv $(DIR)/ 2>/dev/null || echo "timeseries.csv not found"
	@mv entropy_report.txt $(DIR)/ 2>/dev/null || echo "entropy_report.txt not found"
	@mv spectral_report.txt $(DIR)/ 2>/dev/null || echo "spectral_report.txt not found"
	@echo "Files moved to $(DIR)/ successfully"

# Clean target
.PHONY: clean
clean:
	@echo "Cleaning simulation artifacts..."
	rm -rf simv simv.daidir ucli.key simulation_log.txt
	@echo "Clean complete"
