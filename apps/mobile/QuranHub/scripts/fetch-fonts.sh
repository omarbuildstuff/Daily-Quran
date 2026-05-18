#!/bin/bash
# Inter + Playfair Display were Google-Fonts @import in the PWA. Bundle the
# exact weights it used so iOS renders identically offline. Source: fontsource
# (jsdelivr), TTF (iOS Core Text supports TTF/OTF, not woff2).
set -e
D="$(cd "$(dirname "$0")/.." && pwd)/Sources/Resources/Fonts"
get() { for i in 1 2 3 4; do curl -fsSL --max-time 30 "$1" -o "$2" && return 0; sleep $i; done; return 1; }

for w in 300 400 500 600 700; do
  get "https://cdn.jsdelivr.net/fontsource/fonts/inter@latest/latin-${w}-normal.ttf" "$D/Inter-${w}.ttf"
done
for w in 400 700; do
  get "https://cdn.jsdelivr.net/fontsource/fonts/playfair-display@latest/latin-${w}-normal.ttf" "$D/PlayfairDisplay-${w}.ttf"
  get "https://cdn.jsdelivr.net/fontsource/fonts/playfair-display@latest/latin-${w}-italic.ttf" "$D/PlayfairDisplay-${w}i.ttf"
done
echo "Fonts fetched:"
ls -1 "$D"/Inter-*.ttf "$D"/PlayfairDisplay-*.ttf
