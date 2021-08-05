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
	$(MAKE) $(BACKGROUNDS)
generate-icons:
	$(MAKE) $(ICONSVGS)
generate-select:
	$(MAKE) $(SELECTSVGS)
generate-gif:
	cd docs/; \
	optipng *.png; \
	convert -delay 150 *.png +dither -alpha off -loop 0 Gallery.gif
generate-all:
	$(MAKE) generate-icons generate-select compress-backgrounds generate-gif

$(ICONSVGS): %.svg: %.svg
	resolutions=("32" "48" "64"); \
	for resolution in "$${resolutions[@]}"; do \
	  icon="$@"; \
	  type="coloured"; \
	  if [[ "$$icon" == *"/icons-colourless"* ]]; then \
	    type="colourless"; \
	  fi; \
	  ./install.sh "--generate" "$$resolution" "icons" "default" "$$icon" "$$type"; \
	done
$(SELECTSVGS): %.svg: %.svg
	resolutions=("37" "56" "74"); \
	for resolution in "$${resolutions[@]}"; do \
	  select="$@"; \
	  ./install.sh "--generate" "$$resolution" "select" "default" "$$select"; \
	done

$(BACKGROUNDS): %.png: %.png
	echo "Compressing $@..."; \
	  optipng --quiet "$@"
