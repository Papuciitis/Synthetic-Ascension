# Domestic interiors v1

20 October 2026. Two purpose cues for an ordinary medieval dwelling: a human timber cot and a low cooking hearth. Each is one original built-in image_gen output, copied unchanged into this separate folder. No variants or additional furnishings were generated.

Both original sources were provisionally kept by the lead for native fitting. Preserve their alpha. This delivery does not approve native fit, final aesthetics, placement, cover, collision or roof/room ownership. Production owns all integration and engine work. No further furniture was generated.

Exact prompts/arguments/output paths: [prompts.json](prompts.json). Dimensions, alpha, contact measurements and SHA256: [manifest.json](manifest.json).

| Source | Actual source size | Contact datum | Meaningful alpha >=128 bounds |
| --- | --- | --- | --- |
| [timber_cot.png](timber_cot.png) | 1024 x 1536 | (530,1345), midpoint between front feet | [215,113,847,1359), 632 x 1246 |
| [cooking_hearth.png](cooking_hearth.png) | 1593 x 987 | (800,805), front base contact | [69,175,1534,819), 1465 x 644 |

Coordinates are original source pixels from upper-left, x right/y down; right/bottom bounds are exclusive. Contact datums and footprints were selected on the personally viewed actual outputs and checked with pixel samples. A contact datum need not be painted: the cot's front midpoint lies in the transparent gap between its two feet.

## Cot contact and fitting

The bed runs north-south: pillow/head at top, foot at bottom. It has one pillow, worn cream linen, a muted grey-sage wool blanket and a plain worn timber frame. The broad mattress top and shallow frame planes suit the requested high view; scale/physical fit still need real-camera review.

The two visible front foot contacts are (250,1345), alpha253, and (800,1345), alpha252. Use their midpoint datum (530,1345), alpha0, when placing the front baseline; this is deliberately not the blanket center. A ground-center estimate is (530,800). Approximate projected ground footprint is [215,230,847,1359), size632 x1129; rear contact is partly hidden, uncertainty about30 source pixels.

The brief target is55–75 world pixels wide by90–120 ground length. Start at60 visible world pixels wide: uniform scale60/632 =0.094937 gives about60 x107.18 estimated ground footprint and60 x118.29 total visible extent. Full image is about97.22 x145.82. At75px width the source ground length is about134px, so the lower part of the width range fits the requested length better. One floor cell is64px. Do not stretch either dimension.

Place image upper-left at front_ground_datum minus scale times (530,1345).

## Hearth contact and fitting

This is a low coherent stone cooking assembly with one ordinary blackened iron pot, dark cold fire recess and a little stacked fuel in its own side nook. It is unlit, with no flame, glow, chimney tower, wall panel or surrounding kitchen/floor. Its back is north/top, intended to fit beside a future real wall.

Contact datum (800,805) is just inside the front base, pixel alpha250. Ground-center estimate is (800,540), and approximate projected ground footprint [69,265,1534,819), size1465 x554, with about40px source uncertainty around the rear raised stones. The inferred north wall-fit line is near source y265; it is not an authored wall or mask.

The brief width/depth guide is80–120 by50–75 world pixels. The actual source is shallower: visible aspect1465/644 =2.275:1. Start review at120 visible world pixels wide, uniform scale120/1465 =0.081911. This gives about120 x52.75 total visible extent, an estimated120 x45.38 ground footprint, and130.48 x80.85 full-image extent. At80px width ground depth is about30.25. Preserve source aspect; production must resolve the fitting difference against the actual room, rather than stretching the bitmap to the guide rectangle.

Place image upper-left at front_ground_datum minus scale times (800,805).

## Alpha and personal inspection

Both actual outputs were personally viewed. The accepted08 city concept and actual clay-domestic cutaway were also personally inspected as material, camera and scale context; see the exact paths in the manifest. Neither reference was an edit target.

Both files have real zero alpha outside their meaningful silhouette:
- Cot alpha range0–254; alpha>=8 bounds [214,112,848,1360). Most painted pixels are alpha253. Raw alpha>0 bounds [105,23,988,1504) include faint residue.
- Hearth alpha range0–255; alpha>=8 bounds [67,174,1535,820). Most painted pixels are alpha252–253. Raw alpha>0 bounds [0,0,1569,987) include faint residue.

The cot stores brown RGB in its transparent surround; sampled points (200,500) and (512,50) have alpha0. Some previews may show that hidden RGB. Preserve and correctly composite the alpha channel; do not export it as opaque RGB. Alpha>=8 bounds remain tight around the object. There is no meaningful opaque floor/background or large baked shadow rectangle. Faint alpha residue, small colored fringes and dense source fabric/stone detail remain, with no cleanup or re-encoding.

These checks establish file properties and source appearance, not exact native compositing, actor/room scale, geometry or aesthetic approval. The source ground footprints are estimates under visible height and must not be turned into automatic colliders.

## Ownership and provenance

Fit to a real dwelling's usable floor and actual wall/door data; preserve entries, routes and floor loot. Interior furniture must follow production's real roof/room state and visible solid-furniture contract. The hearth does not supply a light, interaction or gameplay device. No collision, cover or navigation is prescribed here.

Original outputs remain under C:/Users/NaurisKrišjānis/.codex/generated_images/01a1586b-b69a-7d30-a6ac-49d746d881c9/:
- Cot: exec-1c72f371-61f8-4972-bde5-abe46a5ad985.png; SHA256 22549e75329ee9164f9f41fbefcdea2e6b028309a7c358362b4c11a2fc69c143.
- Hearth: exec-133d3011-e960-46e9-84de-a2b930d521d9.png; SHA256 fd6a6434311135e5c7b09ca6b2c3c3ca47333c33b78fed69f826527c9bc7e26b.

No stock/downloads, CLI/API fallback, repainting, trimming, resize, alpha editing, compositing or PNG re-encoding. No engine/import/test/capture, native renderer, product-code or Git actions.
