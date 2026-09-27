Okay, for my game, this is how it looks now. How could I make it not look that blocky?, It's now blocks on blocks - the roads, and the buildings are just rectangle walls, which don't tehnically fit right

Yeah — the problem isn't really that you're using square tiles. It's that the tile grid is currently controlling the macro-shape of the whole district.

In this screenshot, almost every major shape is some version of:

rectangle → 90° corner → rectangle → 90° corner

The road is a giant rectangular slab, buildings are rectangular outlines, grass patches are rectangular cutouts, and even the gaps between buildings follow the same grid. So your eye immediately sees the generator rather than a place.

The good news is you don't need to throw away your tile system. I'd keep the underlying grid for pathfinding/collision and make the visible geometry much less obedient to it.
What I'd change

    Stop generating roads as rectangles. Generate a road path first, 2–4 tiles wide, then widen/narrow it irregularly. Let it shift sideways by one tile occasionally, use diagonal/45° transitions, and make intersections open into small plazas instead of perfect crosses. Your current central area could easily become something like narrow street → wider square around the objective → narrow alley.

    Use irregular building footprints. A building shouldn't start as Rect2(x,y,w,h). Start with a rectangle, then mutate it: remove a corner, add a wing, carve a courtyard, push one wall inward, add a recessed entrance. Even just allowing L, T, U and stepped shapes would massively change this screenshot.

    Offset buildings from one another. Right now several walls line up on the exact same X/Y axes. Avoid that. If building A ends here, building B should often start 1–4 tiles forward/backward. Real streets get visual rhythm from staggered façades.

    Break long straight walls. This is probably the single biggest building improvement. After ~5–8 tiles of uninterrupted wall, add something: doorway recess, pillar/buttress, ruined section, small extension, stairs, fence, tree, pile of junk, balcony shadow, etc. The collision can still be basically straight underneath.

    Create a difference between "road" and "walkable ground." At the moment the entire pale stone area reads as ROAD™. Make the actual street occupy part of it, then have sidewalks, broken paving, dirt strips, weeds, drainage channels, courtyards, loading spaces, little patches of grass, etc. That stops every walkable area becoming another rectangle.

    Use visual edge tiles that lie about the grid. Rounded/chipped corners, diagonal rubble, grass creeping over stone, uneven paving edges, wall foundations sticking out, shadows, decals. A cell may mechanically be STONE, but visually only 60–80% of it needs to look paved. This is how you hide the grid without making navigation complicated.

    Generate "negative space" deliberately. Right now empty space often seems to be whatever remains between rectangles. Instead make explicit little spaces: alley, courtyard, shrine nook, abandoned garden, collapsed lot, tiny square, service passage. Then fit buildings around those. That makes the district feel designed rather than tiled.

For example, your current building logic is probably conceptually close to:
██████████████
█            █
█            █
█            █
██████████████

Even staying 100% tile-based, you want footprints more like:
██████
█    ████
█       █
██      █
 █   ████
 █   █
 █████

Or:
████████
█      █
█  █████
█  █
█  █  ███
████  █ █
      ███

And crucially, don't make the neighbouring road trace the exact inverse of that shape. Give it dirt/vegetation/setback between the two.

For Synthetic Ascension specifically, I think you can push this even harder because the district doesn't need to feel like a pristine planned modern city. Your occult/fantastical institution-city setting actually benefits from architecture that has been extended, repurposed, partially collapsed and built over. One original rectangular building might have acquired an annex, enclosed courtyard, barricaded entrance, crumbling wing, improvised passage, etc. That gives you a lore justification for procedural weirdness rather than treating irregularity as decoration.

The biggest generator-level change I'd make would be this:
CURRENT

choose rectangle
→ place building
→ fill remaining area with road/grass

becomes
generate primary street spine
→ generate 1–3 secondary paths/alleys
→ identify parcels formed beside those paths
→ place irregular building footprints into parcels
→ create setbacks/courtyards between footprint and street
→ decorate/hide grid boundaries

That means the streets define the neighbourhood, instead of the neighbourhood being the leftovers of rectangular chunks.

And you don't even need proper Bézier curved roads. With your current art, something like this would already look dramatically better:
       ╱████
  ███ ╱
█████╱
    ╱       ███
   ╱   ░░░░████
  ╱  ░░░░
██  ░░      ███
 ███░   █████

Where ░ is a plaza/rough paving area. You can fake those slopes using staircase patterns + diagonal-edge sprites.

Looking at this exact screenshot, I'd probably keep the central objective square roughly where it is, but turn that giant pale rectangle into a crooked junction/plaza. The street coming from the left would narrow around the buildings, flare open around the objective, then split into two uneven routes to the right/top. I'd pull some of the grass inward with rubble/overgrown boundaries and bring 2–3 building masses further into the current giant open rectangle. Suddenly the combat area would have cover, landmarks and route decisions instead of reading like one gigantic tiled floor.

Your actual sprite art isn't causing most of the blockiness here. It's ~80% layout/silhouette, ~20% tileset dressing. Fixing the procedural footprints before redoing artwork will give you much more return.
User attachment
lmao, some next gens start making the game like this, but it starts becoming semi 3d game already with the buildings, but the game is purely 2d in code lol

Lmao yeah — this is exactly where “make it less blocky” can accidentally mutate into “congratulations, you made Diablo-lite.” 😭

But technically, that isn’t a problem. You can absolutely keep the entire game 100% 2D in code and make it look like this. What you’re seeing is basically 2.5D presentation: flat gameplay plane, but sprites are painted/rendered with height, perspective, occlusion, and shadows.

And actually, I think this image shows a pretty good target for how far you could push Synthetic Ascension — with one important restriction: don’t make the geometry itself truly 3D-dependent.

Your gameplay can still be:
Vector2 positions
2D collision
NavigationRegion2D
TileMap / procedural grid
Area2D hitboxes
2D projectiles
2D enemy steering

while the player sees:
       visible wall top
     ┌───────────────┐
     │               │
     │   BUILDING    │ ← decorative sprite
     │               │
═════╪═══════════════╪════ gameplay plane
     collision line

The wall sprite might visually extend 70 px upward from its actual collision footprint. That's just artwork.
The image actually solves a lot of your current problem

Compare it with your current screenshot.

Your current buildings effectively look like:
████████████
█          █
█          █
████████████

from directly overhead.

The generated version does more like:
      ╔════════╗   ← visible top surface
      ║        ║
      ╚════════╝
      ██████████    ← vertical face
──────XXXXXXXXXX──── gameplay footprint

So suddenly a 1-tile wall has volume.

And because walls cast shadows and you see their top surfaces, they stop looking like lines painted on the ground.

That's probably one of the reasons the new version looks so much more expensive visually.
But I would NOT go fully as far as that image

There are three things I'd steal from it:

1. Wall height.
Give walls/buildings a visible vertical façade. Not huge — maybe roughly 0.5–1 tile visually.

2. Strong grounding shadows.
Walls, trees, characters, ruins, pillars. Right now some of your existing world elements feel like decals. Shadows immediately establish which things have volume.

3. Angled / irregular wall silhouettes.
Notice that even though the image is still heavily tiled, your eye no longer screams GRID because vegetation, ruined edges, wall caps, shadows and interrupted geometry obscure it.

But I'd keep your camera closer to top-down than this generated image.

Something like:
PURE TOP DOWN            TARGET                 TOO FAR

     ▓▓                   ▓▓▓▓                   ▓▓▓▓▓
     ▓▓                  ▓    ▓                 ▓     ▓
─────▓▓─────         ────▓████▓────         ───╱█████╲──
       90°              fake depth             perspective

Basically 80–85° camera illusion, rather than 60–70°.

That gives you architectural depth without requiring your entire art/world system to pretend it's an isometric game.
There's an especially useful trick for your procedural buildings

Don't generate a "building sprite".

Generate:
BUILDING FOOTPRINT
        ↓
wall segments
        ↓
wall cap
        ↓
wall face
        ↓
shadow
        ↓
decorations

So procedurally:
XXXXXXXXXXXX
X..........X
X..........X
XXXX....XXXX

remains the actual collision footprint.

Your renderer turns the northern wall into something visually like:
      ╔══════════════╗
      ║ stone / roof ║
      ╚══════════════╝
      ████████████████
XXXXXXXXXXXXXXX

Those upper pixels don't exist to gameplay.

Same thing with your irregular buildings.

An L-shaped footprint:
███████
█
█
█   ███
███████

can get caps, facades, broken corners, vines and shadows independently.

That is way easier than actually moving your project into 3D.
You already have an advantage because Synthetic Ascension is top-down combat

Your VFX don't care much.

That Precision effect in this new screenshot actually demonstrates it nicely. The beam calculation can literally still be:
var start := global_position
var end := target.global_position

two Vector2s.

The renderer draws this absurd glowing occult geometry over it and nobody cares that there is no Z-coordinate anywhere. 😂

The only annoying part becomes occlusion.

For example:
          WALL SPRITE
        █████████████
PLAYER       🧍
───────────────

If the player walks "behind" the wall, you want:
       █████████████
        🧍

rather than them being painted on top of it.

But even that is standard 2D stuff:

    Y-sorting;
    separate wall base / wall upper sprite;
    occluder regions;
    fade roofs/walls when player goes behind them.

You don't need actual depth.
I think this might actually be the visual direction you're searching for

Not "make Synthetic Ascension 3D."

More:

    Keep the simulation completely 2D, but stop requiring the artwork to admit that.

Your ground can remain tiled.

Your movement remains planar.

Your enemies remain 2D.

Your procedural generation remains grid-based.

But the world renderer gets to cheat:
tile grid
    ↓
irregular footprints
    ↓
fake height
    ↓
wall faces/caps
    ↓
shadows
    ↓
foliage/rubble over boundaries
    ↓
decals

And then the grid becomes almost invisible.

The generated screenshot has arguably gone ~25% too far toward 3D for your current game, but it exposed something valuable: your problem isn't really “I need non-square tiles.”

It's more like:

your current world has almost no visual Z-axis.

Even a fake 20–40 px Z-axis for walls, ruins, trees, gates, monuments, etc. would transform it.

And the funny part is you could still open every single gameplay script afterward and find nothing but Vector2. 😭

This is the Hub now, and the 2.5d doesn't actually kinda work, like i discussed in Game Shape Improvement chat, can you find how it would be generated in code, like in actual game, and can you generate how the hub for the game could look like
Worked for 1m 34s
Okay, how hard would it be to generate hub like this and also the game itself how would you make it to look like it?
Domāja 25s

Yes — but I wouldn’t build it by procedurally drawing a whole beautiful city from code. That would be painful and would probably end up looking procedural in the bad way.

The much better approach for Synthetic Ascension is:

code generates structure → handcrafted modular assets make it look authored → procedural dressing hides repetition.

And importantly, you do not need to turn the game into 2.5D to get most of what that concept image is doing.
How hard is the hub?

Your hub specifically? Very doable. Maybe 5/10 technically.

The current hub already has the important gameplay pieces: entrance, Quiet Alcove, Gear & Stash, player spawn, etc. What makes the current screenshot feel unfinished is mainly that almost the entire screen is one material and one enormous rectangular shape.

I would actually make the hub mostly fixed, not fully procedural. There's no real benefit in making your home base randomly rearrange itself every run unless that's a specific mechanic.

Code would define something roughly like:
                     [ Shrine / Ascension ]
                              │
                       ╭──────┴──────╮
                       │ CENTRAL HUB │
                       │    NEXUS    │
               ╭───────╯             ╰───────╮
               │                               │
        Quiet Alcove                    Gear / Stash
               │                               │
        little side room                workshop/storage
               │                               │
               ╰────────╮             ╭────────╯
                        │             │
                        │  entrance   │
                        ╰──────┬──────╯
                               │
                            PLAYER

But those aren't rectangles visually.

The generated polygon could instead be something like:
                 █████████████
              ███             ███
            ██      SHRINE       ██
            █                   █
       █████                     █████
      █                               █
      █ alcove       NEXUS        forge █
      █   █                         █   █
      █   ███                    ███    █
       ██                           ██
         ███        ███        ███
           █        █ █        █
           █        █ █        █
           █████    █ █    █████
               █    █ █    █
               █    █ █    █
                    ↑
                 entrance

Suddenly you've removed the "giant box" problem without changing your gameplay at all.
The visual trick

The previous generated image is actually doing something slightly deceptive.

It's not really the buildings that make it impressive.

It's the density hierarchy.

You have a relatively calm navigable ground surface, then increasingly dense details toward the edges:

floor → cracks/decal → curb → clutter → wall → furniture/buildings → lighting/background darkness.

Your current hub basically has:

floor → wall.

That's why it feels empty.

I'd make SA's rendering layers something like:
Z -30    background void
Z -20    ground base
Z -18    secondary floor materials
Z -16    cracks / stains / runes / dirt
Z -10    curbs / floor borders
Z  -5    floor props
Z   0    player + enemies
Z   2    furniture / crates / low obstacles
Z   4    walls
Z   6    tall props / banners / pillars
Z  10    foreground pieces
Z  20    VFX
Z  30    atmospheric overlays

You can still use completely normal CharacterBody2D movement underneath.

No fake Z coordinate.

No perspective calculations.

No pseudo-3D collision bullshit.
How I'd make the hub look like that concept

I'd keep your current brown/grey synthetic-fantasy palette, because I think the bright fantasy-town look in the generated example is too cheerful for your game.

The central empty space would become an Ascension Nexus.

Not a cute town fountain.

Something like a stone structure/rune mechanism embedded into the floor:
         ╱─────╲
       ╱    │    ╲
      │   ╲ │ ╱   │
      │ ─── ◉ ─── │
      │   ╱ │ ╲   │
       ╲    │    ╱
         ╲─────╱

Quiet Alcove becomes visually obvious because the environment changes around it: broken walls, cloth, books, benches, candles, Beka's spot, softer lighting and less visual noise.

Gear & Stash becomes the opposite: weapon racks, crates, hanging tools, shelves, piles of recovered junk, maybe a workbench.

Then the architecture itself tells you what an area does before you see its UI marker.

That would be a big improvement.
And then apply the same idea to the actual game

This is where it gets more interesting.

I would not generate city blocks like Minecraft rectangles anymore.

Your generator should think in terms of:
ROAD GRAPH
    ↓
DISTRICT SHAPES
    ↓
LOTS
    ↓
BUILDING FOOTPRINTS
    ↓
WALL EDGES
    ↓
DOORS / ALLEYS
    ↓
PROPS
    ↓
DECALS
    ↓
LIGHTS

Instead of:
make rectangle
make rectangle
make rectangle
road
rectangle

For example, the road system can stay grid-aware internally.

But once you determine that this is a block:
+----------------------+
|                      |
|                      |
|                      |
|                      |
+----------------------+

you deform the usable footprint.
+----------+
|          |____
|               \
|    BUILDING    |
|              __|
|      ____   |
+-----+    +--+

Then create little negative spaces:
building
██████████
██████████
█████    ← alley
█████  ████
█████  ████
       ████

Those alleys are exactly the sort of spaces where your game can put:

    loot,
    secondary objectives,
    ambushes,
    safe routes,
    lore,
    shops,
    shortcuts,
    hidden NEG/POS interactions.

So visual improvement also improves your level design.

That's the nice part.
Buildings

I think this is the most important change from our previous 2.5D discussion.

Don't render an entire building façade like:
       /\
      /  \
     /roof\
    |      |
    |      |

because suddenly the game starts pretending to have a camera angle it doesn't actually have.

Instead treat buildings like large top-down obstacles.

Something closer to:
╔══════════════════╗
║ rubble   chimney ║
║                  ║
║        ROOF      ║
║                  ║
╚══════     ═══════╝
       entrance

And if the player enters it:
roof fades
↓
interior revealed

That gives you the feel of those dense RPG environments without changing the game dimensionally.

It's basically the approach I'd use for your city districts too.
The art kit is the important part

You don't need 500 unique building sprites.

I'd rather build maybe 30–50 extremely reusable modules:

    straight stone wall;
    damaged straight wall;
    inner corner;
    outer corner;
    cracked corner;
    doorway;
    archway;
    pillar;
    ruined pillar;
    wall end;
    narrow wall;
    several floor edges;
    4–6 floor materials;
    rubble clusters;
    crates;
    shelves;
    cloth;
    banners;
    lamps;
    pipes/occult conduits;
    statues;
    rune decals;
    drainage/grates;
    vegetation.

Then code goes:
if wall_length > 5:
    maybe_add_crack()

if near_corner:
    maybe_add_rubble()

if district == District.ARCANE:
    decoration_pool = arcane_props

if district == District.INDUSTRIAL:
    decoration_pool = industrial_props

That's enough variation that the player stops seeing "tile #7 repeated 40 times."

And this part fits extremely well with your procedural district system.
Lighting would do an absurd amount of work

Your screenshot is basically flatly illuminated.

I'd darken ambient illumination slightly and let important areas create light.

Hub entrance:
dim

Central Ascension thing:
orange / pale synthetic glow

Quiet Alcove:
small warm localized lights

Gear area:
stronger forge/lantern glow

Exit Rite:
VERY visually distinct

And in the actual city, lighting can become navigational.

A player subconsciously thinks:

    light = interesting place

Which means you can guide exploration without another floating arrow.

Godot's PointLight2D + a controlled number of occluders can handle this perfectly well. I wouldn't put a shadow-casting light on every candle; several candles can visually belong to one actual light source.
The actual hard part

The generator isn't actually the scary part.

Your project already has much more complicated systems than this.

The hard part is producing a visual kit that is coherent enough that the generator has good ingredients.

I'd roughly rate it:

Hub layout generation: 4/10
Hub gameplay integration: 3/10
Hub art/dressing: 6/10
Making one city district look this rich: 6–7/10
Converting every procedural district: 8/10
Performance: probably manageable, provided decorative objects are mostly TileMap/MultiMesh/sprites rather than hundreds of processing Nodes.

And you don't need to redo everything at once.

I would make one ~2-screen chunk of the city at final visual quality first.

Not the entire map.

Basically make the equivalent of a vertical slice:
main road
   │
   ├──── building
   │        └─ enterable room
   │
   ├──── alley ─── secret
   │
   └──── plaza
             │
          objective

Put the final walls, ground, lighting, clutter and building treatment into that one area.

Then we see whether Synthetic Ascension actually looks good in that language.

Only after that would I teach ChunkGen to reproduce it.

And I think this direction would fit SA way better than the pseudo-3D experiment did. You could get much of the density of the generated hub image while the game remains mechanically and visually a proper 2D top-down horde game.

The big visual transformation I'd aim for is basically:

current SA: geometry defines the world

→

new SA: geometry defines navigation; art hides the geometry.

That distinction is what your current map is missing.
Okay, this is theory, but actual code? Can you find some solutions on the net, what we could take or be inspired from?
Worked for 2m 25s

Yeah. I went past the theory and looked at both existing Godot proc-gen implementations online and the current enemy-world-work generator in your repo. There is a pretty clear path here, and we do not need to throw away ChunkGen.

The important discovery is that the blockiness really is coming from the current code. ChunkGenDistrict.gd builds roads from Rect2i, plazas from a square Rect2i, sidewalks from rectangular strips, parcels from rectangular regions, while ChunkGenStructures.gd starts buildings as w × h rectangles. Even the road-edge noise is just little 1–2-cell rectangles. So the screenshot is basically an accurate visualization of what the generator is being told to make. Your current ChunkGenDistrict.gd Your current ChunkGenStructures.gd
There are actual projects we can steal ideas/code from
Source	What it does	What I'd take for SA
GDQuest Godot 4 PCG Dungeon	Godot 4; rectangular and organic rooms, corridors	Their polygon→cell technique for irregular building/hub footprints
t-mw/citygen-godot	GDScript city road generation with growing road segments, snapping and intersections	Road-generation logic; bends, T-junctions, non-perfect grids
alexishachemi/godot-procgen	Godot 4.5; BSP + Kruskal MST + cellular automata	Dense irregular blocks, interiors, ruins
AlexeyBond constraint-solving/WFC	Godot 4 TileMapLayer WFC/constraint solver	Dressing/detail pass, not primary map layout
Godot Geometry2D	Polygon merge/offset, polyline offset, Delaunay	Turn road center-lines into actual road areas
TileMapLayer terrains	Autoconnecting terrain/path tiles	Automatically choose corners/edges instead of hand-picking every visual tile

GDQuest's demo is particularly relevant because its organic-room generator literally constructs an irregular polygon and checks each grid point with Geometry2D.is_point_in_polygon(). That's almost exactly what we want for your building footprints. Their source code is MIT; their included art has a separate CC-BY-NC-SA license, so the code is the useful part for us.

The other really interesting one is t-mw/citygen-godot. Instead of saying "road = rectangle through chunk centre", it grows segments. Each segment attempts to continue or branch, and local constraints make new roads intersect or snap to nearby existing roads. It even varies direction slightly rather than requiring perfect 90° geometry. It is older Godot 3 code, but it is GDScript and MIT-licensed, and the underlying algorithm ports cleanly. t-mw/citygen-godot

And Godot already gives us the geometry operation that makes this useful: Geometry2D.offset_polyline() can take a line such as a street centreline and inflate it into a polygon of a chosen width. Geometry2D also exposes polygon merging and Delaunay triangulation.
What I would actually change in SA

I wouldn't replace your macro generator.

You already have things I don't want to lose:
DistrictPlan
    ↓
chunk roles
    ↓
connector masks
    ↓
urban access
    ↓
roads / parcels / donjons
    ↓
walls
    ↓
decoration

That's actually a decent architecture.

I'd change the layer below DistrictPlan.

Right now:
connector
    ↓
Rect2i road
    ↓
Rect2i sidewalk
    ↓
Rect2i parcel
    ↓
Rect2i building

Change that to:
connector
    ↓
ROAD POLYLINE
    ↓
ROAD MASK / POLYGON
    ↓
IRREGULAR PARCEL
    ↓
IRREGULAR BUILDING FOOTPRINT
    ↓
boundary extraction
    ↓
YOUR EXISTING wall spawning

That last bit is important.

Your existing wall connection system can stay.

You already do:
var mask: int = gen._wall_connections_mask(cell, wall_cells)
gen._spawn_block(chunk, scene, cell.x, cell.y, mask)

That's useful.

The generator does not actually care whether those wall cells came from a rectangle.

So we stop producing rectangular wall sets.
A real first implementation

I'd add:
core/systems/world/proc/chunkgen/
    ChunkShapeGen.gd

Something along these lines:
extends RefCounted
class_name ChunkShapeGen

const DIRS_4: Array[Vector2i] = [
    Vector2i(1, 0),
    Vector2i(-1, 0),
    Vector2i(0, 1),
    Vector2i(0, -1),
]


static func rasterize_polygon(
    polygon: PackedVector2Array,
    bounds: Rect2i
) -> Dictionary:
    var cells: Dictionary = {}

    for y in range(bounds.position.y, bounds.end.y):
        for x in range(bounds.position.x, bounds.end.x):
            # Cell centre rather than top-left corner.
            var point := Vector2(x + 0.5, y + 0.5)

            if Geometry2D.is_point_in_polygon(point, polygon):
                cells[Vector2i(x, y)] = true

    return cells


static func rect_cells(rect: Rect2i) -> Dictionary:
    var cells: Dictionary = {}

    for y in range(rect.position.y, rect.end.y):
        for x in range(rect.position.x, rect.end.x):
            cells[Vector2i(x, y)] = true

    return cells


static func subtract_rect(
    cells: Dictionary,
    rect: Rect2i
) -> void:
    for y in range(rect.position.y, rect.end.y):
        for x in range(rect.position.x, rect.end.x):
            cells.erase(Vector2i(x, y))


static func add_rect(
    cells: Dictionary,
    rect: Rect2i
) -> void:
    for y in range(rect.position.y, rect.end.y):
        for x in range(rect.position.x, rect.end.x):
            cells[Vector2i(x, y)] = true


static func boundary_from_fill(fill: Dictionary) -> Dictionary:
    var walls: Dictionary = {}

    for value in fill.keys():
        var cell: Vector2i = value

        for dir in DIRS_4:
            if not fill.has(cell + dir):
                walls[cell] = true
                break

    return walls

That tiny module is surprisingly significant.

Now a building no longer needs to be:
████████████
████████████
████████████
████████████

It can be:
████████████
████████████
██████
██████
██████  ████
██████  ████
████████████

while your existing:
_spawn_wall_cells()
_wall_connections_mask()
window logic
door logic
cover scenes

can continue to operate.

That's directly inspired by the polygon/cell approach in GDQuest's Godot 4 generator.
Generate an actual irregular building

Then we can make a footprint generator:
static func generate_building_footprint(
    rng: RandomNumberGenerator,
    rect: Rect2i
) -> Dictionary:
    var cells := rect_cells(rect)

    # --- Cut one corner ---
    if rng.randf() < 0.75:
        var notch_w := rng.randi_range(2, maxi(2, rect.size.x / 3))
        var notch_h := rng.randi_range(2, maxi(2, rect.size.y / 3))

        var corner := rng.randi_range(0, 3)

        var notch := Rect2i()

        match corner:
            0:
                notch = Rect2i(
                    rect.position,
                    Vector2i(notch_w, notch_h)
                )

            1:
                notch = Rect2i(
                    Vector2i(rect.end.x - notch_w, rect.position.y),
                    Vector2i(notch_w, notch_h)
                )

            2:
                notch = Rect2i(
                    Vector2i(rect.position.x, rect.end.y - notch_h),
                    Vector2i(notch_w, notch_h)
                )

            3:
                notch = Rect2i(
                    rect.end - Vector2i(notch_w, notch_h),
                    Vector2i(notch_w, notch_h)
                )

        subtract_rect(cells, notch)

    # --- Optional second indentation ---
    if rng.randf() < 0.35:
        var side := rng.randi_range(0, 3)

        if side == 0 or side == 2:
            var notch_w := rng.randi_range(2, 4)
            var x := rng.randi_range(
                rect.position.x + 2,
                rect.end.x - notch_w - 2
            )

            var y := (
                rect.position.y
                if side == 0
                else rect.end.y - 2
            )

            subtract_rect(
                cells,
                Rect2i(Vector2i(x, y), Vector2i(notch_w, 2))
            )

        else:
            var notch_h := rng.randi_range(2, 4)
            var y := rng.randi_range(
                rect.position.y + 2,
                rect.end.y - notch_h - 2
            )

            var x := (
                rect.position.x
                if side == 3
                else rect.end.x - 2
            )

            subtract_rect(
                cells,
                Rect2i(Vector2i(x, y), Vector2i(2, notch_h))
            )

    return cells

That produces seeded:

    L shapes,
    shallow U shapes,
    stepped buildings,
    recessed entrances,
    asymmetric workshops,
    ruined footprints.

Still 100% grid-compatible with your current game.

No 2.5D.

No new physics system.

No bizarre collision solution.
And then _spawn_building() becomes fundamentally different

Your current ChunkGenStructures.gd starts:
var w: int = rng.randi_range(10, 16)
var h: int = rng.randi_range(8, 14)

That's fine.

Keep that.

But instead of:
_spawn_wall_rect_cells(...)

we do approximately:
var base_rect := Rect2i(
    Vector2i(x0, y0),
    Vector2i(w, h)
)

var footprint := ChunkShapeGen.generate_building_footprint(
    rng,
    base_rect
)

var wall_cells := ChunkShapeGen.boundary_from_fill(
    footprint
)

Then remove a doorway:
var candidate_walls: Array[Vector2i] = []

for value in wall_cells.keys():
    var c: Vector2i = value

    # Example: prefer walls facing an exterior/open cell.
    if not footprint.has(c + Vector2i(0, 1)):
        candidate_walls.append(c)

if not candidate_walls.is_empty():
    var door := candidate_walls[
        rng.randi_range(0, candidate_walls.size() - 1)
    ]

    wall_cells.erase(door)
    wall_cells.erase(door + Vector2i(1, 0))

And then literally:
gen._spawn_wall_cells(
    chunk,
    wall_cells,
    {}
)

Your current wall scenes are now drawing an irregular building.

That is a much smaller refactor than I initially expected after actually seeing the current code.
The roads are where the big transformation happens

Here's where I'd borrow the idea from t-mw/citygen-godot.

Their generator works around:
Segment
start -------- end

             /
start -------+------ continuation
             \
              branch

New segments are proposed, then checked against existing ones.

They:

    snap nearby endpoints;
    cut segments at intersections;
    reject nearly parallel accidental intersections;
    branch roughly ±90°;
    allow small angular deviation;
    use a noise/heat map to influence growth.

Their city generation source

We don't actually need the whole system because DistrictPlan already decides where roads go globally.

That's good.

I'd steal only the concept of a segment-based local road.

Currently your chunk does essentially:
lane_rect_h = Rect2i(...)
lane_rect_v = Rect2i(...)

Instead:
var sockets: Array[Vector2] = []

if conn_mask & _DIR_N:
    sockets.append(Vector2(lane_cx, 0))

if conn_mask & _DIR_E:
    sockets.append(Vector2(cells, lane_cy))

if conn_mask & _DIR_S:
    sockets.append(Vector2(lane_cx, cells))

if conn_mask & _DIR_W:
    sockets.append(Vector2(0, lane_cy))

Then define a local hub that isn't always exact centre:
var local_hub := Vector2(
    lane_cx + rng.randf_range(-3.0, 3.0),
    lane_cy + rng.randf_range(-3.0, 3.0)
)

And connect each socket with one intermediate bend:
static func build_road_path(
    from: Vector2,
    to: Vector2,
    rng: RandomNumberGenerator
) -> PackedVector2Array:

    var midpoint := (from + to) * 0.5

    var perpendicular := Vector2(
        -(to - from).y,
        (to - from).x
    ).normalized()

    midpoint += perpendicular * rng.randf_range(-2.5, 2.5)

    return PackedVector2Array([
        from,
        midpoint,
        to
    ])

Now instead of:
============================

every time, you can get:
================
               \
                ============

or:
          ========
         /
=========

without affecting where roads leave the chunk.

Chunk seams still work.

That's the trick I like for SA.
And Godot can turn that line into a road

This is one of the useful pieces I found in the official API:
var road_polygon_parts := Geometry2D.offset_polyline(
    road_path,
    lane_width * 0.5,
    Geometry2D.JOIN_ROUND,
    Geometry2D.END_SQUARE
)

offset_polyline() literally inflates a polyline into polygon geometry.

So:
       road centre
           ↓

───────╲
        ╲──────


       becomes


████████\
█████████\
         █████████
         █████████

That's exactly what we want.
Or even easier: use Line2D for the visual road

For the first prototype, I wouldn't even immediately rewrite your floor renderer.

Make a Line2D:
static func spawn_road_visual(
    chunk: Node2D,
    path_cells: PackedVector2Array,
    cell_size: float,
    road_width_cells: float,
    texture: Texture2D
) -> Line2D:

    var line := Line2D.new()

    line.width = road_width_cells * cell_size
    line.joint_mode = Line2D.LINE_JOINT_ROUND
    line.begin_cap_mode = Line2D.LINE_CAP_BOX
    line.end_cap_mode = Line2D.LINE_CAP_BOX

    line.texture = texture
    line.texture_mode = Line2D.LINE_TEXTURE_TILE

    line.z_index = -95

    for p in path_cells:
        line.add_point(p * cell_size)

    chunk.add_child(line)

    return line

Underneath it you can put a second wider Line2D for sidewalks:
sidewalk width = road width + 2 cells
road width     = actual road

Meaning this:
▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
████████████████
████████████████
▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒

can bend naturally.

That would already make the city look dramatically less Minecraft-blocky.
Keep gameplay on cells

This is the important engineering compromise.

The visuals can be continuous geometry:
Vector2
Polygon
Line2D

while gameplay continues to use:
Vector2i
64 px cell
Dictionary[Vector2i]

To determine which cells a road occupies:
static func rasterize_road(
    path: PackedVector2Array,
    radius_cells: float,
    bounds: Rect2i
) -> Dictionary:

    var result: Dictionary = {}

    for y in range(bounds.position.y, bounds.end.y):
        for x in range(bounds.position.x, bounds.end.x):

            var p := Vector2(x + 0.5, y + 0.5)

            for i in range(path.size() - 1):
                var a := path[i]
                var b := path[i + 1]

                var nearest := Geometry2D.get_closest_point_to_segment(
                    p,
                    a,
                    b
                )

                if p.distance_to(nearest) <= radius_cells:
                    result[Vector2i(x, y)] = true
                    break

    return result

Then that mask becomes your:
keepout
navigation
spawn exclusion
building exclusion
objective clearance

So the pretty road and the gameplay road remain identical.
The hub becomes easy after this

The funny thing is that the Hub doesn't actually require a separate technology anymore.

Use the same shape system.

Instead of:
GIANT RECTANGLE HUB

give it a fixed layout definition:
var nexus := PackedVector2Array([
    Vector2(-10, -12),
    Vector2(8, -12),
    Vector2(8, -8),
    Vector2(14, -8),
    Vector2(14, 6),
    Vector2(9, 6),
    Vector2(9, 11),
    Vector2(-7, 11),
    Vector2(-7, 7),
    Vector2(-14, 7),
    Vector2(-14, -5),
    Vector2(-10, -5),
])

Then:
var nexus_cells = ChunkShapeGen.rasterize_polygon(
    nexus,
    hub_bounds
)

Quiet Alcove can be another polygon.

Gear & Stash another.

Entrance is a polyline.

Nexus floor can be circular/irregular decoration in the middle.

And because the hub is persistent, I'd author those polygons by hand rather than randomize them.
A third internet solution: cellular automata

There's a newer Godot 4.5 project called godot-procgen which uses:

BSP → Kruskal minimum spanning tree → cellular automata.

The CA step intentionally turns initially mechanical spaces into more natural/irregular terrain.

It's MIT licensed.

alexishachemi/godot-procgen

And amusingly, you already have half of this concept.

Your current settings contain:
donjon_fill_wall_chance
donjon_ca_steps
donjon_room_attempts

So rather than introducing another system, we could repurpose your Donjon logic.

For example:
NORMAL STREET DISTRICT

road
███████████████

side space
┌──────────┐
│          │
│          │
└──────────┘

could become:
road
███████████████

built block
██████████
████████  █
█████     █
█████  ████
██     ████

using your existing CA.

That means your repo is actually closer to this than the screenshot makes it look.
WFC: useful, but not where I would start

I also found a pretty capable Godot 4 constraint-solving/WFC addon. It directly supports TileMapLayer, can learn valid combinations from an example map, supports negative examples, and importantly can fill around tiles you've already placed.

That last part is interesting.

Our generator could first place:
road
door
building outline
objective

and then WFC could fill:
cracks
wall variations
corner clutter
rubble
vegetation
drains
floor variations

But I would not let WFC design the city.

Otherwise we're trading your deterministic, gameplay-aware generator for a constraint solver that occasionally decides life is pain.

Use it as:
MACRO STRUCTURE
our generator

        ↓

MICRO VISUAL DRESSING
WFC

Potentially later.
Godot's Terrain system is even simpler

Before WFC, there's an easier option.

TileMapLayer.set_cells_terrain_connect() automatically picks the tile that fits neighboring cells, while set_cells_terrain_path() does the same for a path.

So if we have art for:
straight
corner
inner corner
outer corner
T
end
damaged variant

code simply says:
wall_layer.set_cells_terrain_connect(
    wall_cells,
    TERRAIN_SET_WALLS,
    TERRAIN_STONE
)

instead of manually asking:
N?
E?
S?
W?

mask 13 -> choose X scene

Your current connections_mask wall system is basically implementing part of this manually.

I wouldn't necessarily replace it immediately because it already works, but this is very attractive once we have an actual tileset.
So the implementation I'd give Claude/Codex is now quite concrete

Rather than:

    "Make the game less blocky."

I'd make the first development pass:

    Add ChunkShapeGen.gd. Support arbitrary cell masks, polygon rasterization, fill→boundary extraction, union/subtraction, deterministic L/U/notched footprints.
    Change only building generation first. Leave roads untouched. Replace rectangular building perimeter generation with irregular footprint → boundary → existing _spawn_wall_cells().
    Make a visual comparison test. Same world seed, old vs new building generator.
    Then replace Rect2i roads with connector-preserving polylines. The global DistrictPlan remains untouched.
    Render them with Line2D first, with a wider sidewalk line behind them.
    Rasterize the line into keepout_rects' replacement: keepout_cells.
    Once that works, convert plazas from square Rect2i into authored polygon families.
    Hub uses the exact same polygon system, except its shape is fixed rather than randomized.

That is the one list I'll give you, because that's actually the implementation order I'd use.

And crucially: I wouldn't start by making new assets.

We can prove the geometry first with your existing stone walls and floor textures.

If irregular buildings + bent roads already look substantially better using the current art, then we know the new generation language works. Then we make the fancy modular wall/roof/clutter kit.

I think we can make a first working “non-block city” prototype without touching the combat/game systems at all, because your current ChunkGen architecture already provides most of the plumbing we need.
