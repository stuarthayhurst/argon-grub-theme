SHELL=bash

BACKGROUNDS=$(wildcard ./backgrounds/*/*.png)
ICONSVGS=$(wildcard ./assets/svg/icons*/*.svg)
SELECTSVGS=$(wildcard ./assets/svg/select/*.svg)
PREVIEWS=$(wildcard ./docs/*.png)

ICON_RESOLUTIONS=32 48 64

.PHONY: prune clean full-clean compress-backgrounds generate-icons generate-select generate-gif generate-all $(ICONSVGS) $(SELECTSVGS) $(BACKGROUNDS) $(PREVIEWS)

clean:
	rm -rvf "./build"
full-clean:
	rm -rvf "./assets/icons"*"/"*
	rm -rvf "./assets/select/"*
	rm -rvf "./build"
compress-backgrounds:
	$(MAKE) $(BACKGROUNDS)
generate-icons: prune
	$(MAKE) $(ICONSVGS)
generate-select: prune
	$(MAKE) $(SELECTSVGS)
generate-gif:
	$(MAKE) $(PREVIEWS)
	cd docs/; \
	convert -delay 150 *.png +dither -alpha off -loop 0 Gallery.gif
generate-all:
	$(MAKE) generate-icons generate-select compress-backgrounds generate-gif
	$(MAKE) check
check:
	./icon_builder.py "--check-files" "assets"
prune:
	./clean-svgs.py
$(ICONSVGS):
	./icon_builder.py "--generate" "icon" "$(ICON_RESOLUTIONS)" "$@"
$(SELECTSVGS):
	./icon_builder.py "--generate" "select" "$(ICON_RESOLUTIONS)" "$@"
$(BACKGROUNDS) $(PREVIEWS):
	echo "Compressing $@..."; \
	  optipng --quiet "$@"
