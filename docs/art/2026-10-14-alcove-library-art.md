# Quiet Alcove library art — 2026-10-14

## Final corrected direction: existing courtyard stall, simple pixel art

The initial cabinet backdrop and HD book cutouts below are **discarded design variants and must not ship**. The first courtyard expansion was also rejected for painterly detail and remains only in the built-in output directory. The final direction follows the user's correction: the current Quiet Alcove's sheltered outdoor red/cream striped stall, rendered in simple low-resolution pixel-art language matching the existing hub sprites. No mansion/cabinet setting.

Selected new files:
- `assets/ui/library/alcove_library_courtyard.png` — 1672 × 941 RGB, opaque; coarse pixel clusters, striped canopy, simple low shelves, Chronicler and candle. Empty shelf slots approx upper x212–1029/y479–579; lower x212–1020/y630–749. Small diamond textile motif echoes the original sprite; no filigree.
- `assets/ui/library/book_spine_pixel.png` — 724 × 2172 RGBA, alpha 0–255; plain brown spine, simple bands, blank center.
- `assets/ui/library/open_book_pixel.png` — 1586 × 992 RGBA, alpha 0–255; plain blank ochre pages, stepped edges, simple dark cover. Reading areas approx left x160–750/y120–830; right x860–1420/y120–830.

These are the unchanged large-canvas built-in originals, drawn with low-resolution pixel aesthetics. No Python resizing or image editing was performed. Runtime/import nearest-neighbor sampling or native-resolution conversion may be used by the game asset pipeline. Visual inspection confirms coherent objects and no text or stray reading-surface symbols.

### Exact final courtyard prompt

Built-in `image_gen__imagegen`, `transparent_background: false`, `referenced_image_paths: [absolute path to assets/textures/hub/hub_stall_alcove.png]` (edit target inspected before generation).

```text
Edit/expand the supplied pixel-art sprite of the Quiet Alcove into a landscape game background. THE FINAL IMAGE MUST BE SIMPLE LOW-RES PIXEL ART, as if natively drawn on a 480x270 pixel grid then enlarged with NEAREST-NEIGHBOR. Very obvious crisp large square pixel clusters on ONE UNIFORM GRID, stepped pixel edges, limited muted palette, flat clustered shading. NO smooth painterly strokes, photographic details, grain, fine texture, 3D rendering or antialiasing.
Use the supplied sprite as exact authority: same muted red and cream striped cloth canopy on plain wooden posts, wooden book counter, simple book stacks, candle/lantern. This is the SAME small outdoor courtyard stall. Close-up landscape view at counter height. Dark gray broken courtyard stone and a little moss in background. Upper 12 percent quiet dark shadow space for title. In left 65 percent of foreground place TWO low simple wooden shelf ledges with broad completely EMPTY dark horizontal slots for interactive books; no decorative books in these slots. A simple hooded Chronicler silhouette at right behind counter and one candle and small book. Everything modest and handmade. Large coherent geometric objects and simple pixel clusters only. Red/cream canopy should read immediately, with no complicated trim.
No tall cabinet, gothic interior, windows, mansion, armillary, clock, emblems, filigree, decorative symbols, random linework. No letters, words, numbers, runes, UI panels or logos. Opaque canvas, wide 16:9. Native low-resolution pixel art matching the supplied tiny sprite, NOT HD concept art.
```

### Exact final pixel spine prompt

Built-in `image_gen__imagegen`, `transparent_background: true`.

```text
Create ONE simple dark brown upright antique book SPINE as transparent isolated pixel-art game item. The image MUST LOOK NATIVELY DRAWN AT 32x96 PIXELS and enlarged using nearest-neighbor: large clearly visible square pixel clusters on a uniform grid, stepped outlines, about 12 muted brown/ochre shades total. NO realistic texture, fine grain, painterly brushwork, antialiasing, 3D render, ornament or filigree.
Single straight-on book spine, aspect 1:3, little side edge. Worn plain dark brown leather, simple horizontal lighter leather bands at extreme top/bottom, thin single-pixel tan edge. Broad center totally BLANK for programmatic vertical title. Lighting a few simple warm flat clusters on upper left, dark right edge. Very simple medieval low-res game inventory sprite matching a tiny pixel-art wooden stall. Genuinely transparent alpha background with tight small margins. No extra objects, ground shadow or scenery. No text, letters, numbers, symbols, runes, emblems, decorative curls or corner ornaments. Single coherent upright rectangular book spine only.
```

### Exact final pixel open-book prompt

Built-in `image_gen__imagegen`, `transparent_background: true`.

```text
ONE plain open book for a low-resolution pixel-art medieval game. Genuine transparent alpha cutout, full book visible, near perfectly straight TOP-DOWN, wide 16:10. MUST LOOK NATIVELY DRAWN AT 320x200 PIXELS enlarged using nearest-neighbor: crisp obvious square pixel clusters on ONE uniform grid, stepped outlines, limited muted warm palette, simple flat clustered shading. NO smooth painterly edges, realistic texture, fine grain, filigree, 3D rendering, antialiasing or HD illustration.
Simple dark brown leather cover peeks around thick simple stepped page edges. Two broad rectangular completely BLANK warm muted medium-dark ochre paper pages with a simple dark central binding seam. Page interiors nearly uniform in color, low contrast and empty, so cream typography can be overlaid legibly. Slight simple darkening only near page perimeter. No decorative gold corners, ornamental frame, fancy stitches or ribbon. Worn corners shown using a few simple pixel clusters. Only a few dark/light brown shades for leather, few warm ochre shades for pages.
No text, writing, letters, numbers, runes, symbols, images, lines, maps or decorations on pages. No surrounding desk, objects or cast shadow surface. Genuine alpha background, NOT painted checkerboard. Modest handmade old library book matching a small pixel-art wooden courtyard book stall, simple coherent silhouette and materials.
```

Final original output filenames under `C:/Users/NaurisKrišjānis/.codex/generated_images/01a1371c-33d8-79d3-a587-c7f30a29b7f4/`:
- Courtyard: `exec-77f78edf-3f64-46f1-b86a-1f69fe0fa96c.png`
- Spine: `exec-cd717027-e959-42cb-86e0-7e166b850751.png`
- Open book: `exec-98f9d6a7-950e-44f7-933d-37365ffc6dd5.png`

## Discarded initial HD direction (historical prompt record)

## Provenance

Three original project assets were generated with the built-in `image_gen__imagegen` tool (default built-in mode). No CLI, external image API, API key, compositing, recoloring, or post-generation image editing was used. The generated PNGs were copied into the project while preserving the originals and alpha. The requested transparent assets have actual RGBA alpha ranging from 0 to 255.

Existing art inspected for style context: `assets/ui/menu/threshold_backdrop.jpg`, `assets/ui/menu/vigil_backdrop.jpg`, `assets/textures/hub/hub_stall_alcove.png`, and `assets/textures/hub/hub_npc_chronicler.png`. These were visual style references only; no existing asset was edited or overwritten.

## Deliverables and visual inspection

| Project file | Dimensions | Mode | Inspection |
| --- | --- | --- | --- |
| `assets/ui/library/alcove_library_backdrop.png` | 1672 × 941 | RGB opaque | Two broad empty front-facing shelf compartments, warm worn cabinet, candlelit chronicler at right, quiet top shadow and foreground table. No baked text. |
| `assets/ui/library/library_book_spine.png` | 724 × 2172 | RGBA | One upright leather spine, blank center, coherent brass borders and bands. Transparent horizontal padding is substantial; visible spine approx x155–530. |
| `assets/ui/library/library_open_book.png` | 1586 × 992 | RGBA | Two blank warm ochre page surfaces, worn leather cover, regular binding stitches, corner ornament outside reading surface. No stray writing, symbols, or lines inside pages. |

Backdrop shelf spaces, approximate pixels: upper x153–1033/y177–421; lower x153–1033/y456–714. Open-book page reading regions: left x132–755/y90–885; right x824–1437/y90–885. Alpha bounding boxes: spine (43,15,711,2158), open book (0,15,1586,970). Spine alpha bounds include nearly invisible edge pixels beyond the main visible object. These are placement hints rather than hard geometry.

The artwork uses detailed worn materials and coherent antique corner ornament. The open-book reading surfaces remain deliberately plain; any further dimming for cream typography should be a runtime treatment. No extra decorative UI was baked into the files.

## Exact final prompts

### 1. Alcove library backdrop

`transparent_background: false`

```text
Use case: stylized-concept
Asset type: original opaque 16:9 landscape background art for a dark fantasy game's physical Quiet Alcove library, ideally 2048x1152.
Primary request: an ancient arcane workshop still running, inside a quiet ruined stone alcove, painterly atmospheric fantasy illustration.
Composition: a two-tier antique wooden book cabinet occupies the left 65 percent of the picture, with exactly TWO very broad front-facing EMPTY shelf compartments, one above the other. Both shelf interiors are dark warm wood with open unobstructed rectangular spaces so the game can later place interactive book spines inside them. The cabinet faces the viewer almost squarely; keep both shelves flat and clearly visible, with no pillars or partitions in their central spaces. Decorative books only in distant background or at far outer corners, never filling these two shelf compartments. A worn reading desk with a warm candle, brass instrument, and a subtle seated hooded chronicler suggestion occupies the right third. Lower foreground is a broad worn tabletop. Upper 12 percent is calm dark stone/shadow reserved for a title overlay.
Style: painterly illustrated dark fantasy, softly textured brushwork, rich depth and solemn quiet mood, worn wood and dark leather, antique brass and restrained gold, dim warm candlelight against deep charcoal and cool blue-gray stone shadows, restrained dusty crimson fabric hanging at right echoes an old alcove awning. A place that has survived centuries and remains inhabited.
Constraints: no text, letters, numbers, readable writing, logos, interface panels, icons, watermark. Opaque background. No modern furnishings. The two broad shelf interiors must remain EMPTY and spacious, together dominating the left of the image.
```

### 2. Library book spine

`transparent_background: true`

```text
Use case: stylized-concept
Asset type: original single tall leather book spine cutout for a dark fantasy game, portrait canvas about 1:3.
Primary request: exactly ONE old upright leather-bound book spine seen straight-on with only a slim side edge. Genuine transparent background, clean isolated silhouette with generous small transparent margins.
Style: painterly fantasy illustration, ancient arcane library craft, candlelight gently from upper left, subtle worn leather grain and scuffs. Dark muted brown leather base suitable for programmatic color tinting. Antique brass embossed thin borders, restrained aged gold corner ornament and raised leather bands near top and bottom. A broad central flat worn leather region is completely BLANK, uninterrupted and dark, taking most of the spine height and width, for a programmatic vertical title.
Composition: narrow upright spine aspect about 1:3, vertical edges straight, full spine visible. Ornamental detail concentrated at extreme top, bottom and borders.
Constraints: actual alpha transparency around the book, not a checkerboard painted into the image. No background, tabletop, cast shadow on a surface, extra books, text, letters, numbers, runes, emblems, logos or watermark. No title plate across center. No readable markings. Single object only.
```

### 3. Library open book

`transparent_background: true`

```text
Use case: stylized-concept
Asset type: original wide open ancient book cutout for a dark fantasy game's reading overlay, wide canvas about 16:10.
Primary request: one large open antique book viewed almost perfectly straight top-down, symmetrically spread, two fully BLANK warm dark ochre parchment pages. Genuine transparent background, isolated full object with slight transparent margin.
Style: painterly atmospheric fantasy illustration matching an ancient arcane workshop, dark worn brown leather cover beneath thick page edges, deep central binding crease, antique gold ornate outer cover corners, restrained brass, subtle candlelight from upper left. Warm aged parchment is muted medium-dark ochre, not white or bright ivory, allowing cream game typography to be legible.
Composition: book fills the wide frame. Each page reading surface is broad, flat, mostly blank, low-contrast and even-toned. Subtle wear confined to perimeter and binding crease. No intrusive folds, streaks, illustrations or ornaments across reading area. Straight top-down makes page surfaces rectangular and usable for overlaying title, contents and prose. Thick pages and cover visible at outer edges.
Constraints: true alpha transparency around the entire object, no painted checkerboard, no desk or scenery. No text, letters, numbers, runes, symbols, ruled lines, maps or illustrations anywhere inside the reading surface. No logo or watermark. No objects lying on book. Entire open book visible.
```

## Original built-in output paths

- `C:/Users/NaurisKrišjānis/.codex/generated_images/01a1371c-33d8-79d3-a587-c7f30a29b7f4/exec-baf8d86a-1171-475c-83ed-f911938cdb15.png`
- `C:/Users/NaurisKrišjānis/.codex/generated_images/01a1371c-33d8-79d3-a587-c7f30a29b7f4/exec-6ec62885-57d6-402f-8465-a2b06b4984de.png`
- `C:/Users/NaurisKrišjānis/.codex/generated_images/01a1371c-33d8-79d3-a587-c7f30a29b7f4/exec-14dcb340-1078-4585-a698-1307ff5de12e.png`
