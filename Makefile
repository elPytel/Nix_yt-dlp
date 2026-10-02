# Makefile
# Read config and execute yt-dlp per playlist in parallel

CONFIG := playlists.conf
PARALEL := 4

# Use line numbers as Make targets because playlist names contain spaces.
PLAYLIST_IDS := $(shell awk -F'|' '/^[^#[:space:]]/ {print NR}' $(CONFIG))
TARGETS := $(addprefix playlist-,$(PLAYLIST_IDS))

.PHONY: all podcast video audiobook $(TARGETS)

all: podcast

$(CONFIG):
	@echo "Configuration file $(CONFIG) not found. Please create it with playlist names and URLs."

# Static rule for each playlist line
$(TARGETS): playlist-%:
	@NAME=$$(awk -F'|' -v line="$*" 'NR == line && /^[^#[:space:]]/ {name = $$1; sub(/[[:space:]]+$$/, "", name); print name}' $(CONFIG)); \
	URL=$$(awk -F'|' -v line="$*" 'NR == line && /^[^#[:space:]]/ {url = $$2; sub(/^[[:space:]]+/, "", url); sub(/[[:space:]]+$$/, "", url); print url}' $(CONFIG)); \
	echo "Starting $(MODE) download for playlist: $$NAME"; \
	mkdir -p "$$NAME"; \
	if [ "$(MODE)" = "podcast" ]; then \
		yt-dlp --js-runtimes node --extract-audio --audio-format m4a \
			--embed-metadata --embed-thumbnail \
			--output "$$NAME/%(playlist_index)02d - %(title)s.%(ext)s" "$$URL"; \
	elif [ "$(MODE)" = "video" ]; then \
		yt-dlp --js-runtimes node --embed-metadata --embed-thumbnail \
			--output "$$NAME/%(playlist_index)02d - %(title)s.%(ext)s" "$$URL"; \
	elif [ "$(MODE)" = "audiobook" ]; then \
		yt-dlp --js-runtimes node --extract-audio --audio-format m4a \
			--embed-metadata --embed-thumbnail \
			--output "$$NAME/%(title)s.%(ext)s" "$$URL"; \
	else \
		echo "Unknown MODE: $(MODE)" >&2; exit 1; \
	fi

podcast: MODE := podcast
podcast: $(CONFIG)
	$(MAKE) -j $(PARALEL) $(TARGETS)
	@echo "All playlists have been processed. Podcast is ready."

video: MODE := video
video: $(CONFIG)
	$(MAKE) -j $(PARALEL) $(TARGETS)
	@echo "All playlists have been processed. Video is ready."

audiobook: MODE := audiobook
audiobook: $(CONFIG)
	$(MAKE) -j $(PARALEL) $(TARGETS)
	@echo "All playlists have been processed. Audiobook is ready."