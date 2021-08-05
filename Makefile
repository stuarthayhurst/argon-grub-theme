SHELL=bash

BACKGROUNDS=$(wildcard ./backgrounds/*/*.png)
ICONSVGS=$(wildcard ./assets/svg/icons*/*.svg)
SELECTSVGS=$(wildcard ./assets/svg/select/*.svg)

.PHONY: clean full-clean compress-backgrounds generate-icons generate-select generate-gif generate-all $(ICONSVGS) $(SELECTSVGS) $(BACKGROUNDS)

clean:
	rm -rvf "./build"
full-clean:
	rm -rvf "./assets/icons/"*
	rm -rvf "./assets/select/"*
	rm -rvf "./build"
compress-backgrounds:
	read -ra backgrounds <<< "$$(echo ./backgrounds/*/*.png)"; \
	make "$${backgrounds[@]}" "-j$$(nproc)"
generate-icons:
	read -ra icons <<< "$$(echo ./assets/svg/icons*/*.svg)"; \
	make "$${icons[@]}" "-j$$(nproc)"
generate-select:
	read -ra select <<< "$$(echo ./assets/svg/select/*.svg)"; \
	make "$${select[@]}" "-j$$(nproc)"
generate-gif:
	cd docs/; \
	optipng *.png; \
	convert -delay 150 *.png +dither -alpha off -loop 0 Gallery.gif
generate-all:
	make generate-icons generate-select compress-backgrounds generate-gif

$(ICONSVGS): %.svg: ./Makefile
	resolutions=("32" "48" "64"); \
	for resolution in "$${resolutions[@]}"; do \
	  icon="$@"; \
	  type="coloured"; \
	  if [[ "$$icon" == *"/icons-colourless"* ]]; then \
	    type="colourless"; \
	  fi; \
	  ./install.sh "--generate" "$$resolution" "icons" "default" "$$icon" "$$type"; \
	done
$(SELECTSVGS): ./assets/svg/select/%.svg: ./Makefile
	resolutions=("37" "56" "74"); \
	for resolution in "$${resolutions[@]}"; do \
	  select="$@"; \
	  ./install.sh "--generate" "$$resolution" "select" "default" "$$select"; \
	done

$(BACKGROUNDS): %.png: %.png
	echo "Compressing $@..."; \
	  optipng --quiet "$@"
