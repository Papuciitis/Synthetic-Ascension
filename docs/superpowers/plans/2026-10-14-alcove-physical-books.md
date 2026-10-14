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
