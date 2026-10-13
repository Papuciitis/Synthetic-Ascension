# Quiet Alcove discovery library

The user approved the library direction and explicitly requested autonomous design and implementation while asleep, including visual research, consistency with the existing game, build exploration and lore. No interactive handoff is needed for this request.

## Experience

Replace the existing catalogue panel with a physical shelf and an open-book reader. Match the actual outdoor Quiet Alcove sprite: muted red/cream striped canopy, Chronicler's counter, low wooden book ledges, candles and simple cloth motifs. Use original pixel-style raster assets with nearest-neighbour sampling, paired with ChamberKit's fonts and palette. Discard the initial HD indoor cabinet direction. Reference screenshots are inspiration, never shipped assets. Preserve pause, courtyard return, keyboard/controller navigation, search and scaled-window readability. Opening, turning and closing books animate; Reduced Motion presents pages immediately and cancels an unfinished leaf turn when navigating.

Nine subject books: Buildcraft, Manifestations, Pairs, Enemies, Items, Augments, Sets, Recipes and Chronicles. Buildcraft contains accurate general instructions; Recipes adapts the existing non-record Grimoire catalogue; Chronicles presents existing authored records. Subject spines remain legible while their completion and dim/closed treatment indicate what remains undiscovered. Discovered pages show their name, image and rule. Hidden pages expose only an ordinal, subject and deliberate clue. Their real names, icons, rules and IDs cannot leak through search or tooltips.

The reader opens a selected subject, lists its pages, and renders the selected page on warm dark parchment. It offers discovery filters, unread bookmarks, and one saved research target. Pinning a clue is a planning aid only. No library action changes equipment, currency, RNG, unlocks or combat rules.

## Knowledge

Reuse enemy discovery and Grimoire keys. Add profile-wide library discovery/read/target fields for ordinary items, manifestations, pairs, sets and augment knowledge. Discover equipment when successfully acquired, not when vendor stock is generated or a detached preview is built. Discover pairs when active. A set becomes known with a discovered member; reading its tiers then helps plan a build. Preserve discoveries through death; isolate profiles; backfill only evidence still in an old save (owned augments, equipped/bag/stash items, imprints, seen pairs). Historical items absent from the old save cannot be inferred and are learned on their next acquisition.

Global interface: `library_discoveries: Array[String]`, `library_read_entries: Array[String]`, `library_target_key: String`; `library_has(key: String) -> bool`, `library_note(key: String) -> bool`, `library_mark_read(key: String) -> void`, `library_set_target(key: String) -> void`, `library_note_item(inst: ItemInstance) -> void`. Ordinary prefixes: item, manifestation, pair, augment, set. Grimoire keys retain their existing format. Reader-facing dictionaries include category/id/key/title/subtitle/body/icon/search plus discovered, unread, hint, trackable. Hidden dictionaries are sanitized before sorting and searching. Buildcraft pages are always known and non-trackable.

## Visual references inspected

- Book of Hours library: https://cdn.cloudflare.steamstatic.com/steam/apps/1028310/ss_cc33034abbb66ea6742b2d61b47bea58ceed95fa.1920x1080.jpg — physical shelves and rooms with objects, quiet warm details.
- Hades Codex: https://attackofthefanboy.com/wp-content/uploads/2020/09/Hades-Codex.jpg — clear subject navigation, broad reading surface and explicit unknown rows.
- Hollow Knight journal: https://steamuserimages-a.akamaihd.net/ugc/92726030145099625/304EA7708260487F3EC2ECE82CC72D4D23BA2E70/ — restrained ornaments and spacious legible prose.
- Vampire Survivors collection: https://volx.jp/wp-content/uploads/2022/01/vampire-survivors-collection.jpg — visible question-mark gaps, without exposing undiscovered identities.

## Verification

Meaningful tests cover hidden/search leakage, live-catalogue fidelity, real acquisition hooks, save round trip, old-save backfill, death/profile isolation, target/read bookkeeping, and browsing without gameplay side effects. Render and inspect shelves, known/hidden pages, Recipes, Chronicles and empty searches at normal and 150% interface scale. Run related Grimoire, story and hub regressions and a fresh code review before claiming completion.

## Verified implementation

Implemented nine physical subject books over a close-up of the existing striped courtyard stall. Original pixel-style art and its exact built-in ImageGen prompts are recorded in `docs/art/2026-10-14-alcove-library-art.md`; rejected HD cabinet/binding drafts were removed from the project. Open/close motions respect Reduced Motion; turning leaves carry the previous page's print. Keyboard, pointer and controller navigation work, including right-stick scrolling of long prose. Guide links and saved research bookmarks navigate to their intended pages.

Final focused verification on Godot 4.7.1:

| Check | Passed | Failed |
| --- | ---: | ---: |
| HubLibraryDataTest | 1794 | 0 |
| LibraryDiscoveryTest | 41 | 0 |
| HubLibraryPresentationTest | 27 | 0 |
| HubLibraryTest | 221 | 0 |
| SaveMigrationMatrixTest | 34 | 0 |
| ScriptParseAuditTest | 499 | 0 |

Related agent-run regressions also passed: InventoryRouter 115, ManifestationPairBehaviour 237, ReliquaryCore 87, StoryDirector 166 and ManifestationImprint 22. SaveMigrationMatrix deliberately emits its existing newer-format warning; all assertions pass and it writes no files. Screenshot probes used isolated save state, captured 1280x720 and 1920x1080 plus 150% interface scale, and reported zero layout failures. Independent code review found and verified fixes for guide links, retained recipe ingredients, detached-merge discovery, and controller scrolling.

Old saves can reconstruct knowledge from their saved discoveries, owned augments, equipment, bags, stash and held imprints. Items acquired and sold before this feature have no historical evidence and become known on reacquisition. A pre-existing detached ItemInstance merge can still add an imprint to the global pouch; the library now refuses immediate discovery from that operation. Actual vendor stock never uses that merge path. Imprint-storage gameplay was deliberately left outside this library change.
