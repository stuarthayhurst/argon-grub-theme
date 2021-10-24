SHELL=bash

BACKGROUNDS=$(wildcard ./backgrounds/*/*.png)
ICONSVGS=$(wildcard ./assets/svg/icons*/*.svg)
SELECTSVGS=$(wildcard ./assets/svg/select/*.svg)

ICON_RESOLUTIONS=32 48 64

.PHONY: prune clean full-clean compress-backgrounds generate-icons generate-select generate-gif generate-all $(ICONSVGS) $(SELECTSVGS) $(BACKGROUNDS)

clean:
	rm -rvf "./build"
full-clean:
	rm -rvf "./assets/icons/"*
	rm -rvf "./assets/select/"*
	rm -rvf "./build"
compress-backgrounds:
	$(MAKE) $(BACKGROUNDS)
generate-icons: prune
	$(MAKE) $(ICONSVGS)
generate-select:
	$(MAKE) $(SELECTSVGS)
generate-gif:
	cd docs/; \
	optipng *.png; \
	convert -delay 150 *.png +dither -alpha off -loop 0 Gallery.gif
generate-all:
	$(MAKE) generate-icons generate-select compress-backgrounds generate-gif
check:
	read -ra icons <<< "$(ICONSVGS)"; \
	for icon in "$${icons[@]}"; do \
	  #Validate all symlinks \
	  if [[ -L "$$icon" ]]; then \
	    if [[ ! -e "$$icon" ]]; then \
	      echo "$$icon is a broken symlink, exiting"; \
	      exit 1; \
	    fi; \
	  fi \
	  #Check all icons have colourless counterparts \
	  if [[ "$$icon" == *"/icons/"* ]]; then \
	    if [[ ! -f "$${icon/'/icons/'/'/icons-colourless/'}" ]]; then \
	      echo "$$icon is missing a colourless conterpart, exiting"; \
	      exit 1; \
	    fi; \
	  fi; \
	done
prune:
	./clean-svgs.py

$(ICONSVGS):
	./icon_builder.py "--generate" "icon" "$(ICON_RESOLUTIONS)" "$@"
$(SELECTSVGS):
	./icon_builder.py "--generate" "select" "$(ICON_RESOLUTIONS)" "$@"

$(BACKGROUNDS):
	echo "Compressing $@..."; \
	  optipng --quiet "$@"
