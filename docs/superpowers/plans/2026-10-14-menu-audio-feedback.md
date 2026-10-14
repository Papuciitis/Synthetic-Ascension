# Interface sound feedback

Scope: the user's requested sound audit after the physical library recheck. Keep combat audio and game rules unchanged. Quiet Alcove keeps its authored book, paper and cloth sounds.

1. Add an always-processing child router to SfxManager. Observe controls as they enter the tree. Ordinary buttons, toggles, options, list/tab selection and sliders receive short feedback only when driven by actual mouse, keyboard or controller input. Opening a screen, rebuilding lists and restoring focus are quiet.
2. Defer generic feedback until the input has finished. Coalesce focus/hover, rate-limit navigation and prefer activation over navigation. Any authored semantic sound from that input takes priority; a library subtree marked ui_sound_manual omits generic activation.
3. Replace the long interface hover/click recordings with unchanged Kenney UI Audio recordings, CC0 with source/license retained. Add a quiet toggle sound. Preserve the existing back/error sounds.
4. Migrate ArcaneMenuItem and TactileButton audio into the router; retain their visual behavior and give TactileButton keyboard-focus visuals. Observe custom Archive and Ascension signals. Add semantic failure/closing feedback where actions bypass ordinary buttons.
5. Test startup silence, real-input routing, mouse/focus deduplication, toggle/list/option feedback, disabled controls, paused processing, semantic priority, library exclusion, late-created controls and UI bus mute/settings. Run the combat audio regression, relevant menu tests and parser. Inspect scope for material remaining silent actions and report them.

No commits or pushes from the audio agent. Root reviews and integrates this phase with the library rebuild.

Verification: MenuAudioTest 55/0; KillAudioTest 29/0; AscensionScreenTest 39/0; SettingsScreenTest 20/0; ReliquaryScreenTest 70/0; ImprintDossierTest 63/0; ScriptParseAuditTest 504/0. The isolated SaveSelectUnreadableSlotTest is 11/0, with expected parse diagnostics from its deliberately corrupt fixture.

The broad test's initial teardown warnings were isolated to its loose runtime loading of HubShop. All diagnostic prefixes through Ascension exited clean, while adding that shop introduced retained scene/script resources. Owning HubShop as a preload fixture, matching production HubWorld and the existing Reliquary test, corrected the test lifecycle. The shop-only prefix is 48/0 and the complete 55/0 run now exit successfully with no resource/RID warnings or stderr. Cleanup also waits for a physics frame and defers quit until the async test stack returns.
