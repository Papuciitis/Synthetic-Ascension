# Save Integrity Design

## Goal

Prevent profile stash loss, preserve active-attempt vendor state across restarts, and protect each save slot from interrupted or invalid writes.

## Scope

This patch covers four persistence defects:

1. Copy `Global.meta_stash` into `SaveData.meta_stash` whenever global state is written to a save resource.
2. Copy the active attempt's vendor segment, refresh count, seed, and bag into the corresponding `SaveData` fields.
3. Replace direct primary-file writes with a validated temporary-file and backup workflow.
4. Bypass Godot's resource cache when loading save slots and validate that loaded resources are `SaveData`.

Developer Mode, `DevSetCollisionTools`, enemy drops, development-item filtering, progression, pricing, procedural generation, and packaging are explicitly out of scope.

## Existing Data Model

`SaveData` already exports all required fields:

- `meta_stash: StashInventory`
- `attempt_vendor_segment: int`
- `attempt_vendor_refreshes: int`
- `attempt_vendor_seed: int`
- `attempt_vendor_bag: BagInventory`

No save-schema migration or new fields are required. Older saves continue to receive the exported defaults for absent fields.

## Global State Serialization

`Global.write_save(save)` will assign `save.meta_stash = meta_stash` with the other profile-wide fields.

When `attempt_active` is true, it will assign all four vendor fields alongside the other attempt inventory resources. When `attempt_active` is false, the existing clearing behavior remains unchanged.

`Global.apply_save(save)` already restores the stash and active vendor snapshot. It will remain responsible for creating a new empty stash when an older save has no stash.

## Safe Save Transaction

Each slot uses three paths:

- Primary: `slot_N.tres`
- Temporary: `slot_N.tmp.tres`
- Backup: `slot_N.bak.tres`

Saving follows this sequence:

1. Serialize the in-memory `SaveData` resource to the temporary path.
2. Load the temporary resource with `ResourceLoader.CACHE_MODE_IGNORE`.
3. Reject the write unless loading succeeds and the resource is `SaveData`.
4. Remove any stale backup.
5. If a primary exists, rename it to the backup path.
6. Rename the validated temporary file to the primary path.
7. If the final rename fails, restore the backup to the primary path.

All filesystem return codes are checked. Failures are reported with `push_error`, and `save_slot` returns `false`; success returns `true`. Callers that do not need the result may continue ignoring it.

The backup is intentionally retained after a successful save so the previous known-good generation remains recoverable. A stale temporary file from an earlier interrupted write is overwritten on the next save and is never treated as a load candidate.

## Load and Recovery

`load_slot(slot)` loads the primary with `ResourceLoader.CACHE_MODE_IGNORE`. A resource is accepted only when it loads successfully and is `SaveData`.

If the primary is missing or invalid, the loader attempts the backup using the same uncached and type-checked path. A valid backup is returned without automatically rewriting disk during the read operation. The next normal save creates a new primary.

`has_save(slot)` reports true when either a primary or backup exists, allowing a recoverable profile to remain visible in save selection.

`delete_slot(slot)` removes the primary, temporary, and backup files for that exact slot.

## Testing

Tests will run through Godot 4.7.1 in headless mode and use an isolated user-data directory or test-specific slot paths so they cannot touch player saves.

Focused regression coverage will prove:

1. A non-empty `meta_stash` survives `write_save`, disk save, uncached load, and `apply_save`.
2. An active attempt's vendor segment, refresh count, seed, and bag survive the same round trip.
3. A successful second save leaves the new generation at the primary path and the previous valid generation at the backup path.
4. A corrupt primary causes `load_slot` to return the valid backup.
5. A failed or invalid temporary serialization does not destroy the existing primary.
6. Deleting a slot removes all three slot artifacts.

Every production change will be preceded by a failing regression test. After implementation, the focused suite and the project's existing headless smoke checks will be run.

## Success Criteria

- Fresh-profile stash contents persist after restart.
- Active vendor stock and refresh cost state persist after restart.
- Save loading never returns a cached stale slot resource.
- An invalid primary does not hide a valid backup.
- A failed save attempt preserves the last valid primary or restores it from backup.
- Developer Mode behavior and configuration are unchanged.

