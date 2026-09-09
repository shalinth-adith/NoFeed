# App icon — Eclipse

Source of truth for `Zenly/Assets.xcassets/AppIcon.appiconset`.

The tile is a disc sitting exactly over a ring of light, corona bleeding out
around it. Ring at 47.7% of the tile, corona spread to 75%. Zenly ships night
only — there is **no Light appearance**, so a light home screen gets the dark
tile. Tinted is authored by hand rather than derived, because the corona is
painted into the artwork.

| Appearance | File | Source |
|---|---|---|
| Any (used for light + dark) | `AppIcon.png` | `icon-default.html` |
| Tinted | `AppIconTinted.png` | `icon-tinted.html` |

## Re-rendering

```sh
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
for v in default tinted; do
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars \
    --window-size=264,264 --force-device-scale-factor=3.87878787879 \
    --screenshot="icon-$v.png" "file://$PWD/icon-$v.html"
done
```

The HTML is authored at the design's native 264pt tile and rasterised at
3.8788x to land on exactly 1024x1024. Output is RGB with no alpha channel,
which is what App Store validation requires. Artwork is full-bleed — no corner
radius is drawn by us; the system masks it with its own enclosure. Do not let
Icon Composer stack a second specular pass over the baked corona.
