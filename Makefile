SHELL=bash

BACKGROUNDS1080p=$(wildcard ./backgrounds/1080p/*.png)
BACKGROUNDS2k=$(wildcard ./backgrounds/2k/*.png)
BACKGROUNDS4k=$(wildcard ./backgrounds/4k/*.png)

ICONSVGS=$(wildcard ./assets/svg/icons/*.svg)
SELECTSVGS=$(wildcard ./assets/svg/select/*.svg)

.PHONY: clean full-clean compress-backgrounds generate-icons generate-select generate-all $(ICONSVGS) $(SELECTSVGS) $(BACKGROUNDS1080p) $(BACKGROUNDS2k) $(BACKGROUNDS4k)

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
	read -ra icons <<< "$$(echo ./assets/svg/icons/*.svg)"; \
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

$(ICONSVGS): ./assets/svg/icons/%.svg: ./Makefile
	resolutions=("32" "48" "64"); \
	for resolution in "$${resolutions[@]}"; do \
	  icon="$@"; \
	  ./install.sh "--generate" "$$resolution" "icons" "default" "$$icon"; \
	done
$(SELECTSVGS): ./assets/svg/select/%.svg: ./Makefile
	resolutions=("37" "56" "74"); \
	for resolution in "$${resolutions[@]}"; do \
	  select="$@"; \
	  ./install.sh "--generate" "$$resolution" "select" "default" "$$select"; \
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
