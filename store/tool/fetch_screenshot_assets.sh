#!/usr/bin/env bash
# Downloads what test/store_screenshots_test.dart needs to draw realistic
# store screenshots into build/store_cache/ (git-ignored):
#   fonts/  Inter (the app's Google Font; same files google_fonts fetches)
#   img/    the demo shop and barber photos from assets/seed/addis_seed.json
#           (Unsplash), smaller sizes
#   tiles/  three OpenStreetMap tiles around the Crown Cuts Bole pin
# Re-running skips files that are already there. Without these files the
# test still runs: Roboto from the Flutter SDK, grey photos and no map tiles.
#
#   bash store/tool/fetch_screenshot_assets.sh
set -u
cd "$(dirname "$0")/../.."
OUT=build/store_cache
mkdir -p "$OUT/fonts" "$OUT/img" "$OUT/tiles"
UA="CrownAndBlade-store-screenshots/1.0 (et.crownblade.app)"

get() { # url file
  [ -s "$2" ] && return 0
  curl -sSfL --retry 6 --retry-delay 3 --retry-all-errors -A "$UA" -o "$2.part" "$1" && mv "$2.part" "$2" \
    && echo "ok   $2" || { rm -f "$2.part"; echo "FAIL $1"; }
}

# Inter weights (hashes from google_fonts' Inter table).
for p in 400:15b294b67f2f8bbc04d990023ef4aec66502b87dc9040d84abe5f896ccb693de \
         500:36a36ff7ac46dc2aeceac3a80a87a67e7b844b8fc936699259aac8fba9bcf734 \
         600:334bb2c51aeba5f566abac8d03a7e75ab3234d6926b52e92a85dc704129258b5 \
         700:76121a34a606cc8a0e1ef5a47d2b9ba9678c41f5c852d63eb28f62069373bfad \
         800:6af943899936fd3fd15a5889db4a384cec311c9bfe33d74bcfd3e0ae56f1b1d1; do
  get "https://fonts.gstatic.com/s/a/${p#*:}.ttf" "$OUT/fonts/Inter-${p%%:*}.ttf"
done

# Photos: the file name is the Unsplash photo id the seed URL uses.
for id in photo-1503951914875-452162b0f3f1 photo-1585747860715-2ba37e788b70 \
          photo-1622286342621-4bd786c2447c photo-1599351431202-1e0f0137899a \
          photo-1512690459411-b9245aed614b; do
  get "https://images.unsplash.com/$id?w=640&q=60&fm=jpg" "$OUT/img/$id.jpg"
done
for id in photo-1534528741775-53994a69daeb photo-1507003211169-0a1dd7228f2d \
          photo-1500648767791-00dcc994a43e photo-1519085360753-af0119f7cbe7 \
          photo-1472099645785-5658abf4ff4e photo-1506794778202-cad84cf45f1d; do
  get "https://images.unsplash.com/$id?w=200&h=200&fit=crop&q=60&fm=jpg" "$OUT/img/$id.jpg"
done

# OpenStreetMap tiles (zoom 16) around shop_1 (8.99633, 38.78776).
for x in 39828 39829 39830; do
  get "https://tile.openstreetmap.org/16/$x/31123.png" "$OUT/tiles/16_${x}_31123.png"
done
