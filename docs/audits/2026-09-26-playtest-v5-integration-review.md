# Playtest, Ranged V5 and presentation integration review

Reviewed 2026-09-26 against `de1d48b` on `feat/authoritative-enemy-world`.

This is a review, not a completed repair pass. Evidence is the current source,
the user's three screenshots and playtest descriptions, the local V5 handoff,
and the two reference conversations retrieved during this review. No engine
or gameplay test was launched in this continuation; no save files were changed.
Previously reported suite totals are not fresh verification by this reviewer.
The earlier PC crash has no established cause from this evidence.

## Conclusion

The claim that only rendered verification remains is not supported. There is
substantial V5 implementation, including ranked locals, Spin Up, optional Heat,
Grenadier, tap/hold Designate and several hybrid adapters. However, ordinary
new runs still select V4, several V5 combinations are incomplete, and the new
hub and VFX have specific integration defects. Passing tests that explicitly
construct V5 do not establish that the player's normal run uses V5.

Do not silently convert an existing V4 save to V5: the same node IDs have
different meanings and purchase receipts must remain valid. A fresh-run
selection/default decision and a visible run-version label are needed; V4
must remain available as the control requested by the handoff.

## Highest priority functional findings

### 1. V5 is not reachable through the ordinary new-run selection

`autoload/Global.gd:1206` defaults `new_run_tree_version` to `"v4"`.
`ascension_ledger()` uses that value when the attempt has no ledger, and keeps
the saved ledger's version otherwise. A repository search found no production
writer or player-facing selector for the new-run setting. The V5 suites instead
explicitly call `fresh_state(..., "v5_ranged")`.

`AscensionRunner.gd:309` correctly chooses the V5 engines only for a V5 ledger.
Consequently, regular play cannot exercise the new mechanics simply because
the V5 scripts and data exist. This identifies the normal launch path; it is
not a direct inspection of the user's particular live ledger.

Useful visible checks: V4 BR01/BR03 are Heat/Heat Sink, whereas V5 names them
Spin Up/Hot Core. V4 OR02 is Caltrops; V5 OR02 is Grenadier. V4 OR10 is
Magazine; V5 OR10 is Bandolier.

Acceptance: start a new run through the actual menu, verify the selected data
and instantiated engines, save/resume that version, and separately resume an
old V4 fixture without changing its ownership or payments.

### 2. The gear panel traps station interaction and leaves the bag lock held

`scenes/hub/HubWorld.gd:232` creates a full-screen wrapper containing only the
HUD `BagUI`, opens it, and disables all station input. It provides no explicit
close button or keyboard close routing. `BagUI` declares a toggle action but
does not handle that keyboard action itself; the gameplay HUD normally does.
Its quick-bar pointer toggle is not an adequate discoverable close flow.

`BagUI.gd:255` holds the global active-input lock while open. Player dash checks
that lock at `player.gd:312`. The bag releases its lock on closure or destruction,
so this is not evidence of a permanently leaked lock after actual destruction.
While the wrapper stays open, station input also stays disabled, explaining
both the unavailable dash and inability to interact with the departure gate.

Binding the core inventory to this component supplies routing, not an equipment
screen or a persistent stash. The station title promises more than is displayed.

Acceptance: open via the station, close via a visible button, Escape and the bag
key independently; repeat; then dash, reopen another service and depart. Verify
one open/one release without stealing locks held by another overlay.

### 3. Merchant return is mislabeled and can inherit departure gating

`ui/screens/HubShop.gd:172` initially sets the embedded button to Close, but
`_refresh()` at line 418 overwrites it with Continue to Segment. The callback
at line 1813 does still close the embedded merchant; the return behavior is
hidden behind a misleading departure label, rather than entirely absent.

Closing its nested Ascension or Augment screen restores the button's enabled
state according to `pending_big_choice` (lines 1783 and 1806), even in embedded
mode. A mandatory reward must not disable returning to the courtyard. The
screen also keeps the old full-screen Exchange structure and service shortcuts.

Acceptance: embedded return remains visible, accurately named and usable after
refresh, purchases and child overlays, including a pending mandatory choice.
Departure remains the courtyard gate's responsibility.

### 4. Exit pressure still follows circle occupancy instead of the encounter

`ExitRite.gd:765` immediately removes `exit_rite_channeling` on body exit.
`ThreatDirector.gd:221` observes this; `EncounterDirector.gd:262` then disables
the spawner's rite mode. `spawner.gd:855` allows ambient spawning again.
The existing 1.5-second channel-progress grace does not protect spawning.

This matches the user's clarification: a small dodge outside the circle brings
ordinary horde pressure back. Existing melee enemies also remain; stopping new
spawns cannot instantly turn an already crowded encounter into a sniper fight.

The intended proximity/latch, sniper budget and occasional melee design already
exists in `docs/superpowers/plans/2026-09-17-item-set-exit-balance.md`, section 6.
Its separate exit-encounter lifecycle is not supplied by the current occupancy
flag. Do not describe this as a new request to increase an enemy multiplier.

Acceptance: approach an eligible exit; repeatedly cross the channel edge;
verify normal ambient spawning stays suppressed, specialist reservations stay
bounded, re-entry does not duplicate the initial wave, and departure/death/reset
clean up correctly. Audit remaining section-6 requirements separately, including
recovery and overtime limits; this review has not proven those complete.

### 5. HUD titles stay stale when an ascension slot changes

`AscensionRunner._sync_slot()` reuses an existing `AscensionSlotHud` and updates
its title through `configure()`. `ui/widgets/ActiveAbilityHUD.gd:123` reads title
and icon only when binding. Once bound, its poll at line 81 refreshes cooldown
and resource state, not the title/icon. Changing Q or V can therefore execute
the new ability under the old label.

Acceptance: equip two different Qs and two Vs sequentially on the same player;
verify name, icon, cooldown and actual action all agree, including unequip.

### 6. The hub itself has no developer-console instance

The gameplay scene and legacy HubShop own a `PerformanceOverlay` instance;
`HubWorld.tscn` and its script do not. Closing/destroying the embedded shop also
destroys its console. This accounts for lost dev-tool availability in the hub;
it is not evidence that the global developer preference was erased.

## Additional V5 gaps

### 7. Thermal Fury does not follow Overclock's sustained Meltdown

`BarrageEngineV5.gd:175-198` only calls `_begin_meltdown()` on the non-Overclock
branch. Thermal Fury's special volley is inside `_begin_meltdown()` (line 263),
its aura doubling checks `_meltdown_left > 0` (line 258), and its health payment
is in `_end_meltdown()` (line 281). Overclock never establishes that state on
crossing 100 Heat. BRF2 and BRK1 are a legal combination in the authored data.

Thus this combination does not deliver Thermal Fury's advertised sustained-
Meltdown effects. Regression coverage must include both acquiring Overclock
before heating and adding it during an ordinary Meltdown, and define one
entry/exit event for cooling and emergency vent.

### 8. Heavy Barrel's Overclock emergency-vent adapter is absent

The V5 specification explicitly includes a BRK1 emergency vent as an MR8
release. `_auto_vent_volley()` at line 569 spends Force and distributes the
bonus, but `_overclock_vent()` at line 293 calls `_radial_volley()` directly.
It neither spends Force nor supplies the damage/pierce/snapshot adapter.
The hybrid suite exercises the ordinary Vent Volley path only.

Acceptance: at 180 Heat with MR8 and 60 Force, verify one Force spend, total
distributed damage bonus, pierce and the optional BRC half-snapshot. Include
the zero-Force case and prevent a second spend by BRC.

### 9. Foreign Spin Up only expires when another Witness arrives

`BarrageEngineV5.on_witness_strike()` at line 512 resets a stale foreign stage
on the next Witness. `tick()` does not expire `_foreign_stage` after four
seconds. Meanwhile `on_kill()` uses that stored stage for Kill Throttle and
the HUD reads it directly. A delayed Ranged-source kill can therefore qualify
using an expired stage. The existing test advances the timestamp and sends
another Witness, so it does not check the intervening idle state.

Acceptance: reach foreign stage 3, wait past four seconds without Witnesses,
verify stage/HUD zero and no stale Kill Throttle credit on a later kill.

### 10. Passive Barrage feedback depends on which Q is equipped

`AscensionRunner.gd:1910` merges HUD state from `engine_for(q_id)` only, and
the Q slot does not exist without an equipped Q. Spin/Heat state is provided
by `BarrageEngineV5.hud_state("q")` at line 970. A build with passive Barrage
but no Q, or a Precision/Ordnance Q, loses that persistent Spin/Heat readout.
There are world popups and limited world effects; that does not supply a
stable resource display for these legal builds.

### 11. Some acceptance claims remain unproven by the supplied tests

`AscensionPrecisionV5Test.gd:112` injects three `HitLedger` events carrying the
same synthetic projectile ID to trigger the boss fallback. This verifies its
counter threshold, not the handoff's required legal projectile trajectory
producing three actual hits on one durable target. It is not sufficient to
claim the route is either working in play or impossible.

The phase checklist still has an unchecked checkpoint 4 despite related code
and tests existing. Neither the unchecked boxes nor the broad completion prose
are an accurate node-by-node status. A complete audit must trace each changed
node and affected hybrid to a real activation and relevant assertions. The
findings above are confirmed gaps, not a claim to have exhaustively verified
every other node.

## VFX findings

### 12. Ordinary projectile impact bursts are scaled down by 64

`ImpactBurstRenderer.gd:42` uses a 2-by-2 world-unit quad, but line 109 scales
it by `radius / 64` as if its mesh were 128-by-128. At the configured maximum
radius 74, the quad is about 2.31 world units across rather than 148. This is
a concrete visibility defect, not merely a preference for stronger bloom.

### 13. The last faint frame can remain after Judgment ends

`AscensionRunner.gd:1705` expires transient effects and rebuilds marker arrays,
but queues redraw only if something remains. Godot retains CanvasItem drawing
until it is redrawn. Transitioning from nonempty to empty must also invalidate
the old drawing. The early idle return also needs consideration when an engine
or slot is removed. Precision does clear its logical Judgment lines; stale
rendering can remain after that logical cleanup.

### 14. The Ordnance pressure ring understates the blast radius

`OrdnanceEngineV5.gd:521` sends
`footprint * (32.0 / 27.0) * 0.5` as texture half-size. The texture's edge is
27/32 of its half-size, so the visible pressure ring ends at half the damage
radius. A separate faint full-radius circle exists, but the stronger ring is
misleading, especially with Danger Close.

### 15. Discipline-specific visual language is only partially integrated

- `ProjectileSimulationManager.gd:715` uses `bullet_shared.png`. The dedicated
  `needle_bullet` and `tracer_bullet` textures are not selected at runtime.
  Default ordinary shot bodies are 18 by 4 world units before camera zoom.
- `BarrageEngineV5.gd:949` draws fragment darts as square billboards. The runner's
  texture-point representation has no rotation, so the darts cannot follow
  their current trajectory.
- V5 grenade simulation moves `pos` by straight interpolation; the renderer
  draws at that same point. There is no separate visible arc or ground shadow
  for a heavy thrown payload in this path. Do not alter its collision path
  merely to create a visual arc.
- Spin feedback is currently a small muzzle glow; Heat adds a ring and
  popups. The references describe a readable progression of firing apertures,
  output and heat/instability. That full presentation is not present here.
- The generator preweights RGB by alpha while storing alpha, despite describing
  its output as premultiplied-free. Audit the import/blending convention in the
  rendered pass before attributing all weak glow to size alone.

Acceptance for this whole section requires a rendered scene at gameplay zoom:
base shot, set proc, Weak Point, Deadshot, Judgment, Spin stages, Heat tiers,
grenade attachment/ground fuse and artillery. Compare readable footprints and
lifetimes; wait after effects end to catch cached drawing. A contact sheet or
parse pass cannot establish this.

## Hub, world and tree presentation

The screenshots agree with the source. `HubWorld._build_courtyard()` uses three
large flat polygons, perimeter walls, an undersized statue and a few crates.
It has no visual furnishing pass adequate to establish merchant/gear/rest
areas. The quiet-alcove interaction at line 268 only produces an ellipsis.
It is a Beka rest location when equipped, not an implemented recovery service.
Either communicate that purpose visually or remove the misleading service
interaction; do not invent an unrequested healing mechanic to justify it.

The shallow-depth implementation adds cap lift and one south-facing wall face
selected from connectivity. This is a limited layer of dressing, not the full
reference direction of irregular silhouettes, restrained height, consistent
grounding shadows and broken ground/building transitions. Keep the simulation
2D. Establish the look on a small representative courtyard/wall corner with an
actor alongside it before spreading the same assets over a large map.

`AscensionTreeView.gd:247` draws many fixed-width labels regardless of the low
overview zoom; it does not resolve collisions among labels and displays the
full edge network. The user's screenshot demonstrates overlap and a cramped
side-panel footer. The input handler at line 119 does not interpret double-
click as purchase. Required interaction: double-click an eligible node, show
the name/rank and exact cost in a confirmation, and recheck eligibility on
confirmation. Gate choices still need a Core selection. Declutter the overview
with selection/hover labels and relevant connections, and keep actions visible
while details scroll. This does not require changing the actual graph/rules.

The item manifest labels the new curse icons as procedural placeholders and
Beka as a provisional likeness. File coverage is complete according to that
manifest; visual quality is not established by filling every icon field. Use
the existing approved asset-sourcing policy for the art pass, rather than
silently interpreting historical generated reference images as shipping art.

## Recovered reference direction

Both conversations were retrieved by their supplied IDs:

- Game Shape Improvement (`6ab586a0-9dbc-83eb-84ef-ced27ffa3cab`): irregular
  footprints, staggered facades, distinct roads/walkable ground, modest visible
  wall height, grounding shadows and appropriate occlusion, keeping planar
  gameplay. Its text does not approve conversion to a 3D game.
- JSON lasisana (`6ab43789-d6b4-83ed-8701-e8def9dd570c`): the user's explicit
  rejection of excessive ornament and purple/whimsical generated effects;
  restrained Precision in near-white/pale gold with small violet accents.
  The subsequent assistant proposes Barrage as repeated apertures/darts with
  escalating instability and Ordnance as heavy sealed charges and pressure
  bursts. Its questions about literal heat and payload appearance are
  unanswered in the retrieved transcript; those are proposals, not additional
  user decisions. The original preferred image is not recovered in the text;
  the available attachment is associated with the rejected later direction.

## Warning cleanup and verification boundaries

The supplied integer-division and shadowing messages are GDScript warnings;
they do not by themselves explain the panel locks or the PC crash. Resolve
integer intent explicitly and rename shadowing locals/parameters in
SiteParcelsImpl, AscensionLedger, MissingPalisEffect, AscensionRunner and
HubWorld, then run the parse audit when no human playtest is active.

Recommended repair order:

1. Hub close/input lifetime, merchant return, developer-console availability
   and stale ability titles.
2. Explicit V5 new-run selection/version display with V4 save preservation.
3. Exit encounter persistence through dodges and the existing authored budget.
4. The confirmed V5 combinations and missing real-path acceptance coverage.
5. VFX scaling, final-frame cleanup, footprint correctness and orientation.
6. Rendered composition pass for the hub, wall depth, tree and item assets.

Run new regression tests without touching player saves. Merely choosing slot
97 is not full isolation; prefer in-memory state, or an explicitly isolated
test user-data directory where disk behavior must be exercised. Test real UI
input and transitions rather than directly emitting a close signal. Update
the phase checklist only with evidence from the path actually tested.
