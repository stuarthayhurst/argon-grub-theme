SHELL=bash

BACKGROUNDS1080p=$(wildcard ./backgrounds/1080p/*.png)
BACKGROUNDS2k=$(wildcard ./backgrounds/2k/*.png)
BACKGROUNDS4k=$(wildcard ./backgrounds/4k/*.png)

ICONSVGS=$(wildcard ./assets/svg/icons/*.svg)
SELECTSVGS=$(wildcard ./assets/svg/select/*.svg)

.PHONY: clean compress-backgrounds generate-icons generate-select generate-all

clean:
	rm -rvf "./assets/icons/"*
	rm -rvf "./assets/select/"*
compress-backgrounds:
	read -ra backgrounds <<< "$$(echo ./backgrounds/*/*.png)"; \
	make "$${backgrounds[@]}" "-j$$(nproc)"
generate-icons:
	read -ra icons <<< "$$(echo ./assets/svg/icons/*.svg)"; \
	make "$${icons[@]}" "-j$$(nproc)"
generate-select:
	read -ra select <<< "$$(echo ./assets/svg/select/*.svg)"; \
	make "$${select[@]}" "-j$$(nproc)"
generate-all:
	make generate-icons generate-select

$(ICONSVGS): ./assets/svg/icons/%.svg: ./Makefile
	dpis=("96" "144" "192"); \
	for dpi in "$${dpis[@]}"; do \
	  if [[ "$$dpi" == "96" ]]; then \
	    resolution="1080p"; \
	  elif [[ "$$dpi" == "144" ]]; then \
	    resolution="2k"; \
	  elif [[ "$$dpi" == "192" ]]; then \
	    resolution="4k"; \
	  fi; \
	  mkdir -p "./assets/icons/$$resolution"; \
	  icon="$@"; icon="$${icon##*/}"; icon="$${icon/.svg/.png}"; \
	  inkscape "--export-dpi=$$dpi" "--export-filename=./assets/icons/$$resolution/$$icon" "$@" >/dev/null 2>&1; \
	done
$(SELECTSVGS): ./assets/svg/select/%.svg: ./Makefile
	dpis=("96" "144" "192"); \
	for dpi in "$${dpis[@]}"; do \
	  if [[ "$$dpi" == "96" ]]; then \
	    resolution="1080p"; \
	  elif [[ "$$dpi" == "144" ]]; then \
	    resolution="2k"; \
	  elif [[ "$$dpi" == "192" ]]; then \
	    resolution="4k"; \
	  fi; \
	  mkdir -p "./assets/select/$$resolution"; \
	  select="$@"; select="$${select##*/}"; select="$${select/.svg/.png}"; \
	  inkscape "--export-dpi=$$dpi" "--export-filename=./assets/select/$$resolution/$$select" "$@" >/dev/null 2>&1; \
	done

$(BACKGROUNDS1080p): ./backgrounds/1080p/%.png: ./Makefile
	echo "Compressing $@..."; \
	  optipng --quiet "$@"
$(BACKGROUNDS2k): ./backgrounds/2k/%.png: ./Makefile
	echo "Compressing $@..."; \
	  optipng --quiet "$@"
$(BACKGROUNDS4k): ./backgrounds/4k/%.png: ./Makefile
	echo "Compressing $@..."; \
	  optipng --quiet "$@"
