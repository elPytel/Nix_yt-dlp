

`playlists.conf`
```conf
Společenstvo Prstenu - Kniha první - The Ring Sets Out | https://www.youtube.com/watch?v=_RvohVltJA0&list=PL9wib0YDd2dc8A5T8s4YWC6zDwtiJxUAi
Společenstvo Prstenu - Kniha druhá - The Ring Goes South | https://www.youtube.com/watch?v=oFHJmy12PJM&list=PL9wib0YDd2deT48AQ8oeAToZj-fJP_m2N
Dvě věže - Kniha třetí - The Treason of Isengard | https://www.youtube.com/watch?v=2MIEZDqzdVE&list=PL9wib0YDd2ddAFTbHHWZohe1SR0WguWVI
Dvě věže - Kniha čtvrtá - The Ring Goes East | https://www.youtube.com/watch?v=49ZREAe2yb4&list=PL9wib0YDd2ddRy5EmwFld3D0GYASoHERQ
```

Příkaz:
```bash
yt-dlp \
    --js-runtimes node \
    --extract-audio \
    --audio-format m4a \
    --embed-metadata \
    --embed-thumbnail \
    --output "$$NAME/%(playlist_index)02d - %(title)s.%(ext)s" \
    "$$URL"
```

Stáhny videa z playlistu $URL a ulož je do složky $NAME. Videa budou pojmenována podle indexu v playlistu a názvu videa, s příponou .m4a. Metadata a náhledy budou vloženy do souborů.