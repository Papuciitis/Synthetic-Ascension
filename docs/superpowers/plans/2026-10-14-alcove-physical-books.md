# Quiet Alcove physical-book rebuild

Execution is autonomous at the user's explicit request. Work uses the existing linked worktree; unrelated item/enemy changes are excluded from commits.

1. Reference and art: inspect actual game assets and official game screenshots; generate/copy coherent leaf, cloth, wax and cover assets with prompt manifest. Owner: art/research agents.
2. Pagination: add LibraryPagination.gd, measured text/BBCode splitting with focused red/green tests. Owner: research agent.
3. Reader: replace ItemList with identity/account spread, in-volume find and three local landmarks; preserve set_filter/result_count, discovered data, saved research and pause restoration. Owner: root. Prove no ribbon changes volume, no hidden-name leak, physical folio navigation and correct Back behavior.
4. Motion: add LibraryLeafMesh.gd; use real alpha paper plus captured print for curved forward/back turns; cover opening/closing is a separate rigid mesh. Match static/animated leaf bounds. Owner: root.
5. Binding: fit lettering within measured book inset, simplify marks and improve focused subject note; replace geometric ribbon/seal widgets with raster assets. Owner: root.
6. Verify: import with main Godot executable and Dummy audio; run focused library/data/discovery/hub tests and parser; expand screenshot probe with open/close/forward/back phases, pagination and ribbon-root captures at both resolutions/150%. Independent review plus root second inspection, repair all material findings.
7. Menu audio: after library recheck, implement separate bounded audio plan based on the completed silent-control audit; verify input-driven feedback, muted buses, no duplicate semantic sounds or initialization noise. Owner: audio agent after explicit root handoff.
8. Commit and push only relevant reviewed changes to existing enemy-world-work upstream; preserve unrelated local modifications. Report previews, sources and material limitations accurately.

## Verification completed

The reader has no ItemList. Each binding remembers its account and spread. Beginning, Unread and Research stay within the volume; filtered navigation remaps the current account by key. Explicit reading states queue repeated requests and preserve complete close/return/pickup/open exchanges. Last-spread reading markers wait for the sheet to land. Full-page captures carry print, folios and corners; old facing paper remains beneath the turning sheet. Cover transfer uses a frozen rendered texture that survives title and size changes. Cloth pulls retain their stitched roots and respect Reduced Motion.

Fresh focused results: presentation 56/0, hub library 222/0, data 1813/0, discovery 41/0, pagination 421/0, physical art 100/0 headless and 131/0 OpenGL. Full import exits 0. Parser checks 504 scripts with zero failures. The rendered probe reports zero layout failures at 1280x720, 1920x1080 and 150% UI scale, with empty stderr. Independent reviews checked full cover/page motion, six shelf transfer stages, cloth pulls, sealed/known plates, every spine and the audio fixes; no remaining concrete P1/P2 finding.

The separate sound plan records its focused menu and existing UI/combat checks. Preview PNGs, the motion clip and downloaded reference screenshots remain outside the repository. Generated source art and CC0 sound provenance are included.

## Save-test incident

During the audio verification pass, the original SaveSelectUnreadableSlotTest was run before its directory was checked. It deleted, wrote and cleaned its slot 97 fixture in the normal save directory. Prior slot 97 presence was not recorded and cannot be established. The ordinary slots 1–3 were only read; existing profile file timestamps predate this work. No SaveIntegrityTest was run.

The regression now sets SaveManager.save_dir to user://saves_test_save_select_unreadable/ and clears current_save before any operation, including card/list reads; its isolated run passes 11/0. Remaining checks use isolated save directories. Copies of the current regular profile files were preserved outside the repository and compared after final verification. The incident and the unknown prior slot 97 contents are disclosed to the user.

## Motion-review follow-up

The newly accessible Game UI Eyesores Analysis includes the actual MP4 review. Its relevant findings are transparent opening paper, late print/bookmark appearance, rubbery full-page compression, sparse composition and small navigation. The closed cover is brief transitional artwork, so this pass retains its existing restrained design rather than adding decoration.

1. Root: replace opening opacity fades with opaque fixed right paper and geometrically revealed left paper. Capture complete, already laid-out printed leaves before opening/closing. Keep cloth opaque and attached to its own leaf. Red baseline: LibraryOpeningTest 2 passed / 10 failed.
2. Curl owner: use an inextensible cylindrical fold traveling across the sheet, with local front/back faces and lift-sorted strips. Retain frozen complete-page print and matching native alpha. Numerical and rendered regressions must cover both turn directions and fallback faces.
3. Readability owner: enlarge native-font navigation and cloth purposes, expand actual native illustrations, add the existing canonical pair nouns/count study, and let first right leaves use their available measured height. Paragraph preference must reflect rendered occupancy while preserving exact text and BBCode.
4. Root integration: rendered inspection at 1280x720, 1920x1080 and 150% UI scale; fix real short/empty-account paths, image settlement and any clipping. Preview clip uses actual cover/turn durations with brief holds. Independent review checks opening/closing, print handoff, resize and complete spreads.
5. Verify relevant isolated library checks and script audit, preserve profile hashes and unrelated changes, then selectively commit and push the refinement to the existing upstream.

Follow-up verification: opening 22/0 headless and 35/0 OpenGL, curl 70/0 and 94/0, readability 90/0 and 94/0, existing physical art 100/0 and 131/0. Final presentation 56/0, hub library 222/0, data 1813/0, pagination 421/0, menu audio 55/0 and script audit 504/0. Full Godot import exits 0. Fresh final probe reports zero layout failures and empty stderr at all three sizes/scales. Independent rendered review has no remaining material finding.

Integration caught and repaired the short/empty-account typed-array branch, initial portrait settlement and 150% context clipping. A further rendered regression caught differing frozen/live illustration geometry; two invisible preparation frames now settle the complete printed leaf before capture. Actual native portrait height is about 161 px at 720p and 126 px with 150% UI scaling. Opening/closing and resize regressions confirm opaque paper, fresh closing print and correctly recaptured leaves. The final MP4 samples actual sine easing and capture delays, repeated three times for inspection; PNGs and preview files remain outside the repository. Existing regular profile primary/backup hashes still match the preserved copies.

## Side section ribbons

The requested direct section navigation is a bounded addition to the existing reader. Every account in the current volume gets a cloth bookmark on the painted outer edge. Known accounts use their names (short captions for the five primer subjects, full titles in tooltips); sealed accounts show only an ordinal and their existing public clue. The full volume's landmarks remain available during a filtered or empty search. Selecting one returns to that account's first spread using the existing captured paper, turn direction and cue, with queued inputs cancelled on putting the volume away. No ribbon changes the main book or awards discovery.

A bounded fan shows up to seven accounts. Edge arrows advance one bank with overlap, the wheel advances one account, and D-pad focus crosses bank boundaries. Same-account layout/read updates preserve a manually browsed fan. Local controller confirmation covers an unmapped A button while preserving native mapped confirmation. Cloth roots stay fixed while pulled print follows the cloth. Existing pixel assets and fonts are reused, and space for the fan is reserved outside the pages.

Verification: new integration test red 3/2 to green 28/0, including real mouse, Enter and controller A; widget 46/0 headless and 47/0 OpenGL, including secrecy, bank/wheel navigation, mapped/unmapped confirmation, physical pull and safe ink bounds. Existing presentation 56/0, hub 222/0 and readability 90/0 headless plus 94/0 OpenGL pass. Script audit 505/0; full import exits 0. Rendered probe reports zero layout failures at 720p, 1080p and 150% UI scale with empty error logs. Independent final review confirms the caption-trim overlap was repaired and has no remaining material finding. Preview scenarios use an isolated test profile.
