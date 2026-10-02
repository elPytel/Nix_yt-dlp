# Read playlists, expand them into video targets, and download in parallel.

CONFIG   := playlists.conf
MANIFEST := .yt-dlp-items.tsv
STATE    := .yt-dlp-state
STAGING  := $(STATE)/downloads
PARALEL  := 4

.DEFAULT_GOAL := all

# The manifest is generated before the recursive make starts.
ITEM_TARGETS := $(shell awk -F '\t' '{print $$1}' $(MANIFEST) 2>/dev/null)

.PHONY: all podcast video audiobook convert FORCE $(ITEM_TARGETS)

all: podcast

$(CONFIG):
	@echo "Configuration file $(CONFIG) not found. Please create it with playlist names and URLs."

# Expand every configured playlist into one Make target per video.
$(MANIFEST): FORCE $(CONFIG)
	@tmp="$@.tmp"; \
	rm -f "$$tmp"; \
	: > "$$tmp"; \
	awk -F'|' '/^[^#[:space:]]/ {name = $$1; sub(/[[:space:]]+$$/, "", name); url = $$2; sub(/^[[:space:]]+/, "", url); sub(/[[:space:]]+$$/, "", url); print NR "\t" name "\t" url}' $(CONFIG) | \
	while IFS=$$(printf '\t') read -r line name url; do \
		yt-dlp --js-runtimes node --flat-playlist --ignore-errors \
			--print '%(playlist_index)s|%(id)s' "$$url" | \
		while IFS='|' read -r index id; do \
			[ -n "$$id" ] || continue; \
			printf 'item-%s-%s-%s\t%s\t%s\thttps://www.youtube.com/watch?v=%s\n' "$$line" "$$index" "$$id" "$$name" "$$index" "$$id" >> "$$tmp"; \
		done; \
	done; \
	if [ ! -s "$$tmp" ]; then \
		echo "No playlist videos were found. Check yt-dlp access to YouTube." >&2; \
		rm -f "$$tmp"; exit 1; \
	fi; \
	mv "$$tmp" "$@"

# Download one video selected from its original playlist.
$(ITEM_TARGETS): item-%:
	@NAME=$$(awk -F '\t' -v target="$@" '$$1 == target {print $$2}' $(MANIFEST)); \
	INDEX=$$(awk -F '\t' -v target="$@" '$$1 == target {print $$3}' $(MANIFEST)); \
	URL=$$(awk -F '\t' -v target="$@" '$$1 == target {print $$4}' $(MANIFEST)); \
	echo "Starting $(MODE) download: $$NAME [$$INDEX]"; \
	if [ "$(MODE)" = "podcast" ] || [ "$(MODE)" = "audiobook" ]; then \
		rm -f "$(STATE)/$@.done" "$(STATE)/$@.skipped" "$(STATE)/$@.converted"; \
		rm -rf "$(STAGING)/$@"; \
		mkdir -p "$(STAGING)/$@" "$(STATE)"; \
		if yt-dlp --js-runtimes node --format 'bestaudio/best' \
			--output "$(STAGING)/$@/%(title)s.%(ext)s" "$$URL"; then \
			touch "$(STATE)/$@.done"; \
		else \
			echo "Skipping unavailable video: $$NAME [$$INDEX]" >&2; \
			touch "$(STATE)/$@.skipped"; \
		fi; \
	elif [ "$(MODE)" = "video" ]; then \
		rm -f "$(STATE)/$@.skipped"; \
		mkdir -p "$$NAME"; \
		if yt-dlp --js-runtimes node --embed-metadata --embed-thumbnail \
			--output "$$NAME/$$(printf '%02d' "$$INDEX") - %(title)s.%(ext)s" "$$URL"; then \
			:; \
		else \
			echo "Skipping unavailable video: $$NAME [$$INDEX]" >&2; \
			touch "$(STATE)/$@.skipped"; \
		fi; \
	else \
		echo "Unknown MODE: $(MODE)" >&2; exit 1; \
	fi

# Convert downloaded audio as soon as its download stamp appears.
convert:
	@if [ "$(MODE)" = "video" ]; then exit 0; fi; \
	mkdir -p "$(STATE)"; \
	while :; do \
		pending=0; \
		while IFS=$$(printf '\t') read -r target name index url; do \
			done="$(STATE)/$$target.done"; \
			skipped="$(STATE)/$$target.skipped"; \
			converted="$(STATE)/$$target.converted"; \
			if [ -f "$$skipped" ]; then continue; fi; \
			if [ -f "$$done" ] && [ ! -f "$$converted" ]; then \
				source=$$(find "$(STAGING)/$$target" -type f -print -quit); \
				if [ -z "$$source" ]; then echo "Downloaded file missing: $$target" >&2; exit 1; fi; \
				base=$${source##*/}; base=$${base%.*}; mkdir -p "$$name"; \
				if [ "$(MODE)" = "podcast" ]; then output="$$name/$$(printf '%02d' "$$index") - $$base.m4a"; \
				else output="$$name/$$base.m4a"; fi; \
				ffmpeg -y -i "$$source" -map_metadata 0 -vn -c:a aac -b:a 192k "$$output" && \
				rm -rf "$(STAGING)/$$target" && touch "$$converted"; \
			elif [ ! -f "$$converted" ]; then pending=1; fi; \
		done < "$(MANIFEST)"; \
		[ "$$pending" -eq 0 ] && break; \
		sleep 1; \
	done

podcast: MODE := podcast
podcast: $(MANIFEST)
	$(MAKE) MODE=$(MODE) -j $(PARALEL) $(ITEM_TARGETS) & download_pid=$$!; \
	$(MAKE) MODE=$(MODE) convert & convert_pid=$$!; \
	wait $$download_pid; download_status=$$?; wait $$convert_pid; convert_status=$$?; \
	[ $$download_status -eq 0 ] && [ $$convert_status -eq 0 ]
	@echo "All playlists have been processed. Podcast is ready."

video: MODE := video
video: $(MANIFEST)
	$(MAKE) MODE=$(MODE) -j $(PARALEL) $(ITEM_TARGETS)
	@echo "All playlists have been processed. Video is ready."

audiobook: MODE := audiobook
audiobook: $(MANIFEST)
	$(MAKE) MODE=$(MODE) -j $(PARALEL) $(ITEM_TARGETS) & download_pid=$$!; \
	$(MAKE) MODE=$(MODE) convert & convert_pid=$$!; \
	wait $$download_pid; download_status=$$?; wait $$convert_pid; convert_status=$$?; \
	[ $$download_status -eq 0 ] && [ $$convert_status -eq 0 ]
	@echo "All playlists have been processed. Audiobook is ready."

FORCE: