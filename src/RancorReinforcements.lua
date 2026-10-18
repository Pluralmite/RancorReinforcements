-- Rancor Reinforcements v1.9.163  (Dragon's Dogma 2: Dark Arisen, Title Update 4.0)
--
-- Adds extra major enemies to the spawn pool of Rancor vortex fights (regular and
-- Virulent). While a vortex fight is active, each MAJOR wave enemy the game is about
-- to spawn has a chance to become one of the reinforcement monsters instead. The event
-- spawns them itself, so they count toward clearing the wave, on any wave layout.
-- Swapped-in monsters get Lesser Demon HP (192,000) and a damage multiplier.
-- Each swap is undone right after use, so nothing carries over between fights.
--
-- Medusa was removed in v1.0 (her AI cannot pick actions in Rancor arenas) and returns in v1.8.
-- v1.2: Evil Eye fixes - blocks reinforcement teleport/escape calls, removes leftover
--       reinforcements when the vortex ends (and any that reappear near it afterwards),
--       and logs Evil Eye warp/summon activity for research.
-- v1.3: Evil Eye brings its minions (ch271000_00): a wave rolled for an Evil Eye also turns
--       some of its minor slots (Ghouls / Rancor skeletons) into minions. Evil Eye chance is
--       now per wave. Blocks the Evil Eye being re-queued as a world spawn mid-fight.
-- v1.4: stability - v1.3's 176 research hooks (incl. per-frame Evil Eye methods) and per-line
--       log writes are gone (crash suspect). Only 5 light watch hooks remain, log-only, and the
--       log file is written once per second. When a wave ends with the Evil Eye still alive the
--       game re-queues it as a world spawn; that request is now neutralised so it can't come back
--       after the Rancor. Vortex center = player position when the fight starts.
-- v1.5: Evil Eye capped per Rancor EVENT (default 1) and its minions capped per event too
--       (default 3), instead of per wave. Counters reset when a new vortex fight starts.
-- v1.6: keeps the Evil Eye in the arena. Its warp attack (app.Ch270.startWarpAction) jumps to
--       its dungeon warp points ~3 km away; for mod-spawned Evil Eyes it is skipped and the
--       game's own onFailWarp() is called instead. Its "guest" body (the warp destination copy,
--       created right after it spawns, shares its HP) is hidden and frozen, since with no warp
--       it has nothing to do. Both are menu options.
-- v1.7: blocking the warp froze the Evil Eye, and hiding the guest isn't needed, so both are
--       gone. Its warp works like this: the guest body is teleported to the destination, then
--       the Eye swaps into it. The mod now re-teleports that body to a spot 12-20 m from you,
--       so the warp plays out normally but it reappears in the arena.
--       The Rancor no longer removes a living Evil Eye at the end of its wave (crash suspect):
--       GenerateManager.requestDestroy for an Evil Eye is skipped while it still has HP.
-- v1.8: Medusa is back. Her AI needs "battle positions" from her lair's waypoint network,
--       which Rancor arenas don't have; the mod now supplies spots near the player.
-- v1.8.1: v1.8 handed out a NEW random spot on every search (~45 per second), so her walk
--       never finished and she never got to re-think and attack. Now each spot is kept until
--       she reaches it or 8 seconds pass, and spots are 5-10 m from the player.
-- v1.8.2: research build - logs which of Medusa's think-table rows pass and how her
--       attack-range checks come out, to find why she follows but never attacks.
-- v1.8.3: the trace showed she never enters her combat table: in her main table the row
--       "if in battle state -> go to main combat table" always fails, so she loops through her
--       non-combat wander table, which targets a free position. Two fixes: (1) the old v0.19
--       "retarget" forced target type 25, which is FreePosition01, not the player - removed;
--       (2) that row is now let through for Medusas spawned by this mod. Row ranges are logged.
-- v1.8.4: in combat she runs toward "FreePosition01", which was still a stale point ~3.7 km
--       away (her lair), so she ran into the arena wall. FreePosition01 is now kept on her
--       battle spot (TargetController.setFreePosition01). After reaching a spot she now stays
--       there ~6 s (time to turn and attack) before getting a new one.
-- v1.8.5: setFreePosition01 didn't stick - her FreePosition01 target stayed ~3.7 km away (her
--       lair), so she kept running off with the player behind her, and every attack failed its
--       facing/range check. Now when her think table switches her target to FreePosition01
--       (type 25), the mod switches it to type 4 (the player / party member she's fighting) instead.
-- v1.8.6: with a moving character as her run target she never "arrives", so the run never
--       ends and her attack rows (only checked on a fresh decision) never get a turn - she only
--       attacked right after a fresh decision (one full petrify beam). Back to a fixed spot, set
--       three more ways (waypoint NextPatrolPos, setTypeTarget(25, pos), FreePosition01); the
--       player redirect is only used if FreePosition01 is still far away after that.
-- v1.8.7: v1.8.6 DID put FreePosition01 on her spot (she ran to it), but within ~5 s the game
--       moved it back to ~3.7 km away (the open-world spot the Rancor started from). Now the
--       game's own TargetController position setters are intercepted for mod Medusas: calls
--       that would move FreePosition01 are blocked (and logged), and the spot is re-applied
--       every frame. The player redirect stays as a fallback.
-- v1.8.8: blocking setFreePosition01 changed nothing - the far point lives in the target
--       controller's own position target (TargetController._AITarget._Position, an
--       AITargetPosition), which the game refills when her target becomes FreePosition01.
--       That field is now overwritten with her battle spot every frame while she targets 25.
-- v1.8.9: v1.8.8 crashed the game (null read in app.Ch255.updateTarget during her think update).
--       Cause: the mod called TargetController methods (setTypeTarget / setFreePosition01) from
--       the render thread every frame while her AI thread was using the same controller. Now the
--       spot is applied ONLY as a plain field write (_AITarget._Position), and only from inside
--       her own AI update (thread-safe); no game methods are called on her target controller.
-- v1.8.10: no crash, but the write didn't hold: updateTarget refills _AITarget from the
--       FreePosition01 slot itself (TargetController._TargetArray[25], an AITargetPosition).
--       Now that slot is written too, before AND after updateTarget, still plain field writes on
--       her own thread. The player-redirect fallback now needs 5 s of "far" and switches back off
--       as soon as the spot holds.
-- v1.8.11: v1.8.10 crashed in app.Ch255.updateTarget right after the mod called
--       Ch255BattleWayPointCtrl.setCachedPosition() from inside her AI (REFramework also flagged
--       updateTarget as re-entering itself through the mod's hook). Removed: the updateTarget hook
--       and EVERY game-method call from inside her AI hooks. All spot changes are now plain data
--       writes done at the start and end of her think update.
-- v1.9: VIRTUAL LAIR. When a Medusa spawns in a Rancor the mod lays out battle / wait / beam
--       spots around the arena center and answers her waypoint questions from them (see section 3).
--       Removed the risky v1.8.8-1.8.11 target-slot writes and the setFreePosition01 block: the
--       spot is put into her waypoint controller's own fields and the game moves her there itself.
--       The per-row decision trace is now off by default (config medusa_trace).
-- v1.9.1: the virtual lair is centered on YOU, where you interacted with the Rancor (your
--       position when the vortex fight starts), radius set in the menu (default 20 m).
--       BIG FIX: DD2 has two coordinate systems. Transform.get_Position is local (it shifts when the
--       world re-centers - the "moved 128 m in 1 s" jumps), while via.Position fields (battle
--       positions, FreePosition01, teleports) are absolute world coordinates. Every spot written
--       since v1.8 was local coordinates stored as absolute - i.e. a point ~3.8 km away. That was
--       the "far point" all along. Lair spots and Evil Eye recalls now use absolute coordinates
--       (Transform.get_UniversalPosition).
-- v1.9.2: v1.9.1 worked - spots landed in the arena and she moved between them - but she got
--       stuck for minutes running at a spot 3 m away she couldn't reach (wall / different height).
--       Now: (1) the mod records where enemies and you actually stand during the fight
--       ("walkable samples") and snaps every lair spot to the nearest such place, so spots sit on
--       real floor at the right height; (2) the arena radius is estimated from those samples
--       (90th percentile distance from the center) unless you calibrate it with the menu button
--       while standing at the edge; (3) stuck detection: no progress toward a spot for 5 s ->
--       the spot is dropped and she gets a new one. The lair is rebuilt every 20 s as samples grow.
-- v1.9.3: STABILITY. v1.9.2 crashed in app.Ch255.updateTarget (same spot as the v1.8.8 / v1.8.10
--       crashes). Common factor of every crash: the mod changing her TargetController's
--       FreePosition01 / _AITarget data; v1.9.1 never touched it and ran 5+ minutes fine. The
--       "unstick" write is removed. Unsticking now uses her own rule instead: her combat tables
--       end a move when the timer "汎用時間終了タイマー" (generic end-of-move timer) runs out; when she
--       is stuck the mod makes that timer check pass once, so she ends the move and re-decides.
--       Stuck detection now only counts while she is actually walking/running (not attacking).
-- v1.9.4: stable, she moves spot to spot, but only ever attacks with the opening beam. Her
--       attack rows check the player 6-12 m in FRONT of her (and some need her to be in a "wait
--       area"); she only re-decides when a move ends. Changes: (1) spots are chosen on the line
--       from her toward you, ~8.5 m short of you, so she arrives facing you in attack range (beam
--       spots ~14 m); (2) arrival assist: within 3.5 m of her spot her move is ended right away so
--       she re-decides immediately; (3) any lair spot counts as a wait/battle area.
-- v1.9.5: the v1.9.4 log proved spots/elevation are fine (she arrives within 1-3 m) but her
--       attack rows are rejected BEFORE their range check runs (1 range check in 5 minutes).
--       New: (a) "pass row" gate (ThinkTableController.isEnablePassRow) is let through for Rancor
--       Medusas (config medusa_force_pass) and counted; unique/common action-flag gates counted;
--       (b) STUDY MODE: observe a normal world Medusa in her lair (log only) - her real battle
--       spots (distance/height), the rows she passes when attacking, and the same gates;
--       (c) stuck-after-arrival fix; area radius for "standing on a spot" raised to 8 m.
-- v1.9.6: BUG: a world Medusa in her lair was taken over by the mod (HP scaled, Rancor fixes
--       applied) because any monster with a reinforcement ID was claimed while the mod thought a
--       vortex was active (vortex detection matched an object near the lair). Now a monster is
--       only claimed if the mod actually swapped a spawn slot to that ID and hasn't matched it yet
--       (Evil Eye companion bodies within 5 s of a claimed Evil Eye still count).
-- v1.9.7: Lair study showed how a world Medusa really fights: run toward a spot, and while
--       running her think re-checks every few seconds; "wait" (turn to face) then Attack01 pass
--       as soon as a party member is 6-12 m in front of her. Those two rows are gated by her
--       "Ch255EnableChangeMoveAction" unique flag, and in the Rancor her attack-range check was
--       almost never even evaluated (1 time per fight) - the gate in front of it stays shut.
--       New: (a) that unique flag is kept on for Rancor Medusas (config medusa_force_uniq);
--       (b) attack-window assist: a failed attack-range check passes when you are 3-14 m away
--       and within 40 deg of her front (not within 3 s of her last attack) (medusa_attack_assist);
--       (c) decision funnel log for the Rancor Medusa (and the studied world Medusa): every think
--       pass as one line - each row checked, pass/fail, and which condition failed;
--       unique-flag / move-type / waypoint-navigation state in the status lines.
-- v1.9.8: The v1.9.7 funnel log found the real block. Her "wait/turn-to-face", Attack01/02 and
--       snake-bow rows are refused BEFORE their range check is even looked at, while the run row
--       (same unique flag) passes - so the unique flag was not it. The refused rows are exactly the
--       ones marked "EnableAttack" (attack permission) plus the "pass" rows. Her attack permission
--       comes from Ch200000.checkEnableAttack / updateCommonAttackFlag (likely the game's limit on
--       how many enemies may attack at once - a Rancor wave is crowded).
--       New: attack permission is granted to Rancor Medusas (config medusa_force_attack): the
--       checkEnableAttack answer is turned to yes and the EnableAttack common flag is kept on.
--       Funnel lines now start with her flags (EA = may attack, DA = attack disabled, NP = no-pass).
--       Unique-flag lookup retries instead of giving up (v1.9.7 gave up too early).
-- v1.9.9: v1.9.8 works - in the Rancor she uses snake-bow volleys, Attack01, the fixed and the
--       moving petrify beam, turn-to-face and the climber shake-off. Tuning:
--       (a) aggression (config medusa_aggression, 0..0.9, default 0.5): her attack cooldowns
--           (general attack reload ~15 s, snake-bow interval ~9 s, petrify-beam reload ~25 s) end
--           early - 0.5 = half as long. Only the cooldown timers are touched, nothing else.
--       (b) BUG: after the moving petrify beam she sometimes got a battle spot ~2800 m away (her
--           own waypoint search "succeeded" with a junk point) and wandered off for a minute.
--           Found spots more than 40 m from her / outside the arena are now replaced with ours,
--           and the far-target fallback also runs when she has no spot.
--       (c) the dead Rancor Medusa is no longer picked up by STUDY mode over and over;
--           decision-funnel log now off by default (research only).
-- v1.9.10: less running around between attacks. The v1.9.9 log showed her spots were often
--       20-30 m from you (fixed rings, other side of the arena) - long runs, then she attacks
--       from out of range. Spots are now made on the fly: about 8 m from you (her Attack01
--       range; 12 m for the beam), on her side of you so the run is short, inside the arena.
--       If she is already at fighting distance she gets a spot right where she is, so she
--       stops and attacks. She re-picks sooner (3 s after arriving, 8 s if not there yet, or
--       when you move away). Aggression fix: v1.9.9's cooldown cut never fired (a field check
--       failed) - it now works by timer name.
-- v1.9.11: "Norgan frost" look for Rancor Medusas (config medusa_frost): her model's colour
--       parameters are pushed toward pale frost blue, surfaces made matte, and emissive parts
--       (if any) get an icy glow. Per instance - the Medusa in her lair is untouched. Every
--       material parameter of her model is listed in data/RancorReinforcements_medusa_materials.txt.
-- v1.9.12: petrify beam more often - her beam normally unlocks only after 2 attacks; for Rancor
--       Medusas it also unlocks once medusa_beam_interval seconds (default 18) have passed since
--       her last beam. Research for beam size / petrify build-up: one-time dump of her
--       petrification parameters and your status controller (data/RancorReinforcements_petrify_dump.txt)
--       plus call counts of the petrification / status methods. Frost look now off by default.
-- v1.9.13: research for beam TRACKING: while she fires, her aim vs. you is logged twice a second
--       (who she is aiming at, how far off her nose you are), and the first beam writes her
--       running action data, look-at controller and move controller to
--       data/RancorReinforcements_petrify_beam_dump.txt. Log only.
-- v1.9.14: the v1.9.13 beam research showed her beam locks onto your MAIN PAWN (its action target
--       was the pawn, not you), so it seemed not to track you. Now, while a Rancor Medusa fires,
--       her look-at / attack target answers with you (config medusa_beam_at_you). Petrify build-up
--       from any hit while a Rancor Medusa is alive is multiplied by medusa_petrify_mult (1.3).
--       Beam size: one dump of the beam shell object when it is created (research for next step).
-- v1.9.15: v1.9.14 confirmed: petrify build-up x1.3 works (45 -> 58.5 per tick), beam aims at you.
--       New: beam turn assist - while she fires she turns toward you up to medusa_beam_turn deg/s
--       (default 60) on top of her own turning; bigger beam - her beam shell's ExpandRate is set to
--       medusa_beam_width (default 1.5). Beam research logging reduced.
-- v1.9.16: v1.9.15 confirmed: turn assist kept by the game (30/30), beam widened. New:
--       (a) smart beam target: while she fires, the beam goes to whoever is in beam range
--           (6-32 m, not climbing her) - you first if you are in range, else the pawn closest to
--           her line of sight; if nobody is in range it stays on you;
--       (b) beam chase: while firing she slides toward her beam target when it is farther than
--           12 m and backs off when it is closer than 6 m (medusa_beam_chase m/s, default 3),
--           staying inside the arena.
-- v1.9.17: BUG: the beam turn assist could turn her AWAY from her target (the direction of the
--       rotation was worked out from her rotation value, which can be mirrored vs. the game's own
--       "forward" axis). Now her facing is read from the game's forward axis, and the turn direction
--       checks itself: if her facing moves the wrong way after a turn, the direction is flipped
--       (logged). The chase only moves her while she is roughly facing her target (within 60 deg).
-- v1.9.18: PILLAR SCOUT (research, log only): finds Medusa's climbable pillars (app.Gm81_097)
--       wherever they are loaded (her lair) and writes their objects, scene folder, components,
--       parents/children and fields to data/RancorReinforcements_pillar_scout.txt - the first
--       step toward spawning a pillar at the Rancor center.
-- v1.9.19: pillar research step 2: the scout found each lair pillar is one self-contained,
--       game-generated object (mesh + collision + climb data, GimmickID 235, gm81_098). Menu
--       buttons: "Find pillar prefab" (searches the game's gimmick managers for its prefab file and
--       tests likely paths) and "Spawn test pillar in front of me" / "Remove test pillar".
-- v1.9.20: pillar prefab hunt fixed: DD2's via.Prefab has no set_Path, so v1.9.19's path tests
--       never really tested anything. Prefabs are now opened the REFramework way
--       (sdk.create_resource + create_holder); the manager search also walks dictionaries and
--       lists every field of the gimmick / generate managers; self-references are filtered out.
-- v1.9.21: pillar prefab hunt round 3: a control test with a prefab the game is known to have
--       (AppSystem/Gimmick/gm_common/Marker.pfb) to prove the loading method; the pillar's mesh /
--       collision / material resource paths (prefabs usually sit next to them); more path guesses
--       built from those folders; and the game's own create/generate/instantiate methods.
-- v1.9.22: two breakthroughs from round 3: (1) prefabs load as "via.PrefabResource" (the control
--       test proved "via.Prefab" never works, so no earlier guess was really tested); (2) the game has
--       GimmickManager.createGimmick(GimmickID, position, rotation, ...) - spawning a gimmick by its
--       ID, no file path needed. The pillar is GimmickID 235. "Spawn test pillar" now asks the game
--       to create gimmick 235 8 m in front of you (on the game's update thread), then finds the new
--       pillar; "Remove" uses the game's own deleteCreatedObj.
-- v1.9.23: the test pillar SPAWNED (createGimmick 235 works) but the game crashed ~16 s later in
--       its spawn system (GenerateManager sorting pending spawns). Fixes: (1) the pillar scout
--       (research, re-ran every 10 s) is switched off once - its field dump called get_Item(index)
--       on Dictionary fields of the new pillar (wrong key type -> access violations right before the
--       crash); the dump now only walks lists/arrays. (2) The pillar is created with
--       DisableRegenerateOnUnload + RemoveContextOnUnload and load area LoadedArea, so the game never
--       tries to re-generate it on its own. (3) Remove runs on the game's update thread. (4) The
--       game's own createGimmick calls are logged (first 15) to learn its real arguments.
-- v1.9.24: "Remove test pillar" crashed v1.9.22 inside GimmickManager.deleteCreatedObj (called from the
--       menu thread). Removal now runs on the game's update thread and uses the generate system's own
--       GenerateManager.requestDestroyAndCancelGenerate(GameObject) first (the same call the mod uses
--       for monster cleanup); deleteCreatedObj is only a fallback. Each step is logged BEFORE it runs.
-- v1.9.25: removing the spawned pillar (deleteCreatedObj, now on the game thread) still crashed - in the
--       game's destroy step (DestroyReqeustDistributorUnit.lateUpdate -> Dictionary<UniqueID,..>.Remove).
--       The lair pillars have a readable UniqueID; the spawned one's could not even be read. Now: the
--       pillar's UniqueID is checked (and logged) on the game thread 2 s after it spawns; Remove first
--       tries the gimmick's own setupUniqId() to repair it and only deletes when the ID reads cleanly.
--       If it still cannot be repaired, the pillar is HIDDEN instead (no drawing, no collision, moved
--       far below ground) so the game never runs the crashing destroy step.
-- v1.9.26: v1.9.25 crashed ~1 s after the spawn, again hashing the pillar's broken UniqueID, this time
--       from another system (a pawn came up to talk - pawns comment on "situation objects" like the
--       pillar). So the ID must be valid from the moment it exists: the new pillar is now detected on
--       the game thread the same frame it appears and repaired at once (setupUniqId), logged before
--       and after. Research at load (log only, no spawning): parameter names of createGimmick /
--       setupUniqId, the layout of app.UniqueID, and the IDs of a few normal gimmicks for comparison.
-- v1.9.27: root cause found: app.UniqueID is an OBJECT (class: _RowID Guid + _Index), and the spawned
--       pillar's UniqId points at freed memory (reading it is an access violation; setupUniqId did not
--       help). Normal gimmicks all hold the game's shared "empty" ID (00000000-..._0). The pillar's
--       UniqId and its ContextHolder's UniqueIDContext.UniqueID are now pointed at UniqueID.Empty
--       (fields written directly, no setter that would touch the dead object), right after the spawn
--       call in the same game-thread step, before other systems (pawn chatter, hit control, destroy)
--       can hash it.
-- v1.9.28: v1.9.27 test: no crash. Caught in the act: right after the spawn the pillar's UniqueID was a
--       valid, brand-new ID ("15110875-..._0"); 26 s later it was freed memory. The game creates that ID
--       object without keeping a reference, so it gets released while the pillar still uses it. Now
--       the ID object (and the ContextHolder's copy) is pinned with a permanent reference the moment
--       the pillar appears, so it can never be freed; Empty is only used if it is already gone.
-- v1.9.29: v1.9.28 test: pinned ID stayed valid, pillar removed cleanly - spawning is safe. ARENA PILLAR:
--       while a Rancor Medusa is alive, one climbable pillar (GimmickID 235) is spawned at the arena
--       center (where you stood when the Rancor started - the rift point). It is removed 8 s after the
--       last Rancor Medusa is gone or the fight ends. Config medusa_pillar (menu). Research (log only):
--       when she runs her pillar search (route 8) the result and her ClimberTargetGimmick are logged,
--       to see whether she finds the spawned pillar on her own.
-- v1.9.30: v1.9.29 test went wrong because the ARENA CENTER WAS STALE: the vortex was already "found"
--       when the save loaded (at the previous Rancor), so the center stayed there while you travelled
--       4.3 km to another Rancor. Medusa's spots were 4 km away (she ran around instead of attacking),
--       the pillar was requested in an unloaded area 4.4 km away (never appeared), and the game then
--       crashed in its spawn reserve queue. Fixes: (1) the center is re-taken from your position when
--       the first wave of a new fight is requested (you are at the rift then) if it is more than 25 m
--       off, and (2) whenever you are more than 80 m from it during a fight with a Rancor Medusa;
--       (3) the arena pillar is only spawned when the center is within 60 m of you.
-- v1.9.31: v1.9.30 test: arena center right, pillar spawned 5 m from you, Medusa attacking - then a
--       crash 9 s later in the game's spawn reserve queue (GenerateReserveDistributor.ReserveQueue.update),
--       the same place as the 18:42 crash. Like the UniqueID, objects the game creates inside our
--       createGimmick call are not held and get freed; the busy Rancor wave queue then trips over them.
--       Now: the spawn system's reserve/distributor objects are snapshotted right before and after the
--       call (same game-thread step) and every NEW object is pinned permanently; everything reachable
--       from the new pillar's components is pinned too. Counts and types are logged.
-- v1.9.32: v1.9.31 test: the pinned ID still "went bad" 5 s after the spawn inside an active Rancor, and
--       the crash came from the Rancor's own quest action walking the spawn system's generated objects
--       (UniqueAction097 -> GenerateManager.getGeneratedInstanceInfos). A pillar made by createGimmick
--       is a generate-system object that the Rancor event manages/cleans up - a dead end in a Rancor.
--       New approach: instantiate the pillar PREFAB directly (plain object, not in the spawn system).
--       Its path is unknown, but createGimmick loads it: after a test spawn the prefab is searched for
--       in the spawn catalog / gimmick manager / the pillar's own generate components and remembered
--       (config pillar_prefab_path). Arena pillar uses ONLY the prefab method (never createGimmick in a
--       Rancor) and is skipped until the prefab is known. Menu: "Spawn pillar (prefab method)".
-- v1.9.33: the "first wave of a new fight" center re-take also fired between two waves of the SAME
--       fight (waves can be more than 60 s apart) and moved the center 27 m to where you stood. Rancors
--       are kilometres apart, so it now only re-takes the center when the old one is more than 150 m away.
-- v1.9.34: crash at 19:15 (still v1.9.32) right when a test spawn ran: the broad memory walks (spawn-
--       system snapshot before/after createGimmick, pillar pinning, prefab hunt) read raw dictionary
--       entries / spare list slots that can hold freed objects. Removed the spawn-system snapshot and the
--       broad pillar pinning (the createGimmick pillar is no longer used in Rancors; the ID pin alone made
--       it safe outside). The walker no longer opens dictionaries/sets/queues at all and reads lists only
--       through Count/get_Item. The prefab hunt is narrow: the pillar's own GenerateInfo/GenerateSetting
--       and the spawn catalog (GenerateManager._CatalogCtrl). Catalog method names are logged too.
-- v1.9.35: Item giver (separate menu "Rancor Reinforcements - Item giver"): search the game's item list
--       by name and give yourself any amount (game-thread calls). Writes the item list + the item
--       manager's give-methods to data/RancorReinforcements_item_methods.txt.
-- v1.9.36: item giver picked getItem(Int32, Int32, CharacterID, GetItemOption) and passed no option
--       object, so the game threw. It now prefers the simple overload getItem(itemId, count, CharacterID)
--       and, for the option overload, creates a real GetItemOption object.
-- v1.9.37: "Spawn test pillar" refused to run in the open world: the vortex check only means "Rancor
--       objects are loaded somewhere nearby" and is on in many places. The block now applies only during
--       an actual fight: Rancor waves spawned in the last 3 minutes and you are within 80 m of the arena.
-- v1.9.38: the createGimmick test pillar crashed outside a Rancor too (its UniqueID was already freed when
--       first seen) - that method is REMOVED. New "Find pillar prefab (safe)": asks the spawn catalog to
--       load gimmick 235 (GenerateCatalogController.addGimmickRefCount) - no pillar is spawned - then reads
--       _GimmickCatalog[235] -> PrefabController -> via.Prefab and remembers it (config pillar_prefab_path).
--       The pillar is then made only with the prefab method (plain instantiate).
-- v1.9.39: the catalog entry for gimmick 235 is a RefCounter<PrefabController> wrapper; the finder now
--       unwraps it (_Item) and searches the PrefabController (and one level below it) for the via.Prefab.
-- v1.9.40: (1) the arena pillar failed in a new session ("could not open" the prefab file): opening the
--       saved path directly does not work; the prefab is now always taken from the spawn catalog
--       (ref-count + lookup, the method that worked), and it is fetched ahead of time ~10 s after the
--       game loads so it is ready before Medusa arrives. (2) The "first wave" center re-take fired on a
--       non-Rancor spawn 129 m from the arena; it now only counts wave requests for Rancor enemies.
-- v1.9.41: v1.9.40 Rancor test: the arena pillar spawned with Medusa, stood the whole 4-min fight, was
--       removed after - no crash. She never tried it: her "go coil around the pillar" row needs a
--       pillar start spot from her lair waypoints (route 8), which never resolves in a Rancor. Now:
--       when that row is checked and the arena pillar exists (and 60 s since her last try,
--       medusa_pillar_interval), the row is passed and her spot is set 4 m from the pillar on her side;
--       when she stands there the "am I on a pillar spot" check (route 8) passes; her own
--       "find climbable gimmick" check is logged and, if it misses, pointed at the arena pillar.
--       Gives up after 25 s if she never climbs. Config medusa_pillar_use.
-- v1.9.42: v1.9.41 test: attempt #2 worked up to the climb - she reached the start spot, the climb
--       search was pointed at the pillar, she chose "Ch255:ギミック登り" and sat in Ch255CimbGimmickLoop
--       (moveType Climb, target SpTarget01) for ~15 s but never got "Ch255GimmickClimbed". Research
--       (log only): the arena pillar's climb data (Gm81_097 fields incl. _ClimbPosSet root/top) 3 s after
--       it spawns, and her climb controller every 2 s while an attempt is running ->
--       data/RancorReinforcements_pillar_climb.txt
-- v1.9.43: climb research result: the lair pillar has Status 3 and one climb point set (_ClimbPosSet:
--       root/top found by a ray cast straight down from its origin, which sits 11.0 m above the lair
--       floor). The arena pillar (origin AT the floor) has Status 1 and NO climb points - so her search
--       ignores it and her climb loop never finishes. The pillar's origin is now raised by
--       medusa_pillar_lift (default 11 m, menu slider). Its climb points, status and mesh bounds are
--       logged 3 s after it spawns. Climb-search pointing range widened to 10 m.
-- v1.9.44: the 11 m lift was wrong - the pillar's origin is its base (mesh goes origin..+15 m), so it
--       floated; lift back to 0 (reset once). Status bits are PreClimbInfoDone=1, EnableToClimb=2: ours
--       only reaches 1 with no climb points even when lifted. Research (any prefab-method pillar, also
--       the test button): its climb offset data, its ray-cast query/result, then a second
--       updatePreClimbInfo() call and a re-check 2 s later -> data/RancorReinforcements_pillar_climb.txt
-- v1.9.45: open-world test: the pillar prepares itself fine there (status 3 = info done + enabled to
--       climb, one climb point set: root = floor +0.56 m, top = floor +14 m; its ray is cast from
--       origin +14 m straight down, 14 m long, and hits once). In the Rancor arena it got status 1 and
--       no climb points (the ray finds nothing at the arena centre). Now, 3 s after a prefab pillar
--       appears, if it has no climb points they are filled in by hand (same layout) and it is marked
--       "enabled to climb".
-- v1.9.46: (1) the hand-made climb point set could not be created (sdk.create_instance failed for the
--       nested type) - now tries the type's own create_instance, both create_instance forms and, for a
--       struct, ValueType; logs which worked. (2) She got stuck in her climb loop (Ch255CimbGimmickLoop)
--       for over a minute: if she is in the climb loop for 12 s without finishing, her climb target is
--       released (and again every 6 s while she stays stuck).
-- v1.9.47: v1.9.46: the hand-made climb point set WAS added (count 1, root floor+0.56, top floor+14) but
--       setting the status threw, so the pillar stayed "not enabled to climb" and she sat in her climb
--       loop; releasing her climb target did not end the loop. Now: the status is set in a separate
--       step with several methods (flag methods of TempStatusFlag, then the raw Data field), each logged,
--       and re-checked every 2 s while the pillar exists (bit 2 = EnableToClimb). Stuck-in-climb-loop
--       escape: let her "end of action" timer pass and send her back to her combat table.
-- v1.9.48: v1.9.47: the arena pillar is now fully climbable in the Rancor (status 3 via add(), one
--       climb point set). Her pillar attempt #1 ended at once because the "end your stuck move" timer
--       pass was active at that moment and her pillar table also ends on that timer. A pillar attempt
--       now clears that pass, the arrival nudge is not used for the pillar spot, and the stuck-move
--       nudges are not applied while a pillar attempt is running.
-- v1.9.49: the arena pillar could appear right on top of you (e.g. when the arena centre was re-taken
--       from your position) and trap you inside it. It now only appears when you, your pawns and the
--       Rancor Medusa are all at least 4.5 m from the spot; until then it waits (logged once).
-- v1.9.50: SHE CLIMBS THE PILLAR and does both pillar attacks (coiled snake-bow volley + coiled petrify
--       beam). Her own coiled targeting is "highest-priority character not climbing her", usually a pawn
--       100-160 deg behind her, so she fired at nobody. While she is coiled (attack packs
--       Ch255000Climb*), her look-at and attack target now answer with you - or, with "beam goes to
--       whoever is in range" on, the best party member in range (6-32 m, not climbing her).
--       Config medusa_pillar_aim. The climb-loop release no longer fires during a normal climb (the
--       climb takes ~18 s): 40 s when the pillar is climbable, 12 s only when it is not.
-- v1.9.51: (1) coiled aiming: the look-at override alone did not help - her coiled body stays facing
--       one way. While a coiled attack runs she is now rotated AROUND THE PILLAR (position + facing
--       orbit the pillar axis) toward her target at up to medusa_pillar_turn deg/s (default 120).
--       (2) beam pitch: on the ground and on the pillar, her petrify beam shell is tilted toward the
--       target's chest height every frame, so targets above/below her get hit (medusa_beam_pitch).
--       (3) leftover pillars: any mod-made pillar (named exactly gm81_098) that this script is not
--       tracking - e.g. after Reset Scripts or a save reload - is removed on the game thread.
-- v1.9.52: bow tracking: her snake-bow only locks on to targets inside a 20 deg cone
--       (Ch255000ActionParam._ArrowLockOnAngle; the beam's cone is 180). While a Rancor Medusa is alive
--       it is widened to medusa_arrow_lockon (default 180) and put back afterwards (the parameter
--       file is shared with the lair Medusa). Research: during her bow actions the shells near her are
--       listed once (type, owner fields) and the newest ones are turned toward her target's chest
--       (medusa_arrow_pitch) - logged so we can see whether arrows follow their transform.
-- v1.9.53: crash ~8 s into her climb. Removed the climb research dumps (her climb controller + the
--       pillar every 2 s during a climb; object ToString calls can blow up on some game types) and the
--       pillar data dump 3 s after spawn. Beam tilt (works: 9 deg -> ~1 deg off) now only runs while she
--       is actually firing (ground beam actions or the coiled beam pack), and a beam shell that stops
--       answering is never touched again (it kept reaching a deleted shell after the beam ended).
-- v1.9.54: both crashes (v1.9.52/53) came 6-8 s into her SECOND climb; v1.9.50 (no coiled turning)
--       did two climbs fine. Turning her around the pillar while coiled (moving her root) is the prime
--       suspect - it is now OFF by default (medusa_pillar_turn 0, reset once; slider still there). The
--       "keep the pillar climbable" re-check every 2 s from the render thread is removed (one fix at
--       3 s + 5 s only). Coiled bow: no arrow was ever found by the arrow aimer, so it now logs what
--       shells exist during her bow (type, name, owner) once per volley, and also accepts arrows whose
--       owner is found through other owner fields.
-- v1.9.55: v1.9.54: no crash over several climbs (turning around the pillar stays off). Coiled beam
--       aim works (75 deg -> 1 deg with you 9 m below). (1) Her eye light (Ch255000PetrificationControl
--       .SpotLight) now matches the real beam: it gets the same tilt as the beam every frame and its cone
--       is widened by medusa_beam_width (the hit area was 1.5x wider and tilted while the light was not).
--       (2) Arrows: her arrow shells (ShellBase) carry no owner, so new shells that appear within 8 m of
--       her head while a bow pack runs are taken as hers and pointed at her target (+ homing target).
-- v1.9.56: CRASH FIX: every recurring crash (same game address, a small number like 0x1fffd used as a
--       pointer) matches the wave-spawn hook turning EVERY requestGenerate argument into an object -
--       including flags / bools / ints. It now only reads the GenerateInfoContainer argument as an object
--       and checks the callback argument for null. Coiled beam: its hit area is now widened like the
--       ground beam (the light was 1.5x wider than the coiled beam). Pillar attempts after the first one
--       wait 120 s (was 60; the first still comes 15 s after the pillar). Head aim research: her head /
--       neck joints are listed once while she aims (for turning her head toward her target next).
-- v1.9.57: v1.9.56: long session, no crash (the wave-spawn hook fix holds). HEAD AIM: during her beams
--       (ground and coiled) and her coiled bow, her neck (Neck_0, Neck_1) and head (Head_0, forward = its
--       Z axis) are turned toward her target every frame after her animation - up to medusa_head_aim
--       degrees (default 70, her own head limit), neck 25%% / 25%%, head the rest. Beam + eye light follow
--       the head; the shell / light tilt only fine-tunes what is left. Separate eye-light size slider
--       (medusa_light_scale, default = beam size) to match the light circle to the petrify area.
-- v1.9.58: same crash signature again (0x1fffd in RAX/RCX, game address +0x5202615 reached through a
--       hook trampoline), so the wave-spawn hook was not the whole story. Every hooked game function's
--       address is now written to data/RancorReinforcements_hooks.txt at load, so the next crash log
--       (module base + RIP) names the exact hook. Eye light: aimed by itself at the same point as the
--       beam (its own forward axis, learned against the beam shell) instead of copying the beam's tilt.
-- v1.9.59: her WALKING petrify beam (pack Ch255000WalkPetrification*, body action Ch255Walk) was not
--       seen as a beam, so it got no aim override / head turn / beam + light correction and she aimed at
--       her move spot (target 25). Any Petrification pack now counts as a beam for aiming (body turning
--       and chase stay limited to her standing beam). Head-aim log lines thinned out.
-- v1.9.60: with the beam now tracking and tilting properly, petrify build-up is back to the game's own
--       value (medusa_petrify_mult 1.0, reset once from 1.3; the slider is still in the menu).
-- Research notes: reframework/data/rancor_snapshots/PROJECT_NOTES.txt
--
-- Install: <DD2>/reframework/autorun/RancorReinforcements.lua
-- Menu:    Insert > Script Generated UI > Rancor Reinforcements

-- v1.9.93: constants live in one table (K) - the main chunk was at Lua's 200-local limit
local K = {}
-- v1.9.120: RELEASE build switch. true = the Nexus build: no log/research files, no research hooks, no test/research
-- menus, no item giver, sdk.hook left alone; the reinforcements and their boss fixes work exactly the same.
K.RELEASE = false
-- every fs.write in this script goes through here (the release build writes no files; its settings use json)
local fs = setmetatable({ write = function(...) if K.RELEASE then return true end return _G.fs.write(...) end }, { __index = _G.fs })
K.CONFIG_FILE = "RancorReinforcements.json"
K.LOG_FILE    = "RancorReinforcements_log.txt"
local VERSION     = "v1.9.184"
-- v1.9.58: record every hooked game function's address (to identify the crash's hook from the crash log)
RR_HOOK_LIST = {}
RR_HOOK_ORIG = RR_HOOK_ORIG or sdk.hook
if not K.RELEASE then sdk.hook = function(m, pre, post, ...)
    pcall(function()
        local addr = m:get_function()
        local tn = m:get_declaring_type():get_full_name()
        local num = tonumber(addr) or (type(addr) == "userdata" and sdk.to_int64(addr)) or 0
        table.insert(RR_HOOK_LIST, { a = num, n = tn .. "." .. m:get_name() })
    end)
    return RR_HOOK_ORIG(m, pre, post, ...)
end end

-- Reinforcement monsters ---------------------------------------------------------------
-- id      : character ID to spawn
-- key     : config key prefix
-- can_fly : may take "flying" major slots (Lich/Wight spawn points are set up for
--           hovering monsters; non-flyers spawn badly there)
local REINFORCEMENTS = {
    { id = "ch253000_60", key = "griffin", name = "Griffin (Norgan)", can_fly = true, chance = 0.2 },
    -- Evil Eye (Dark Arisen, Battahl dungeon boss). Flies (Ch27FlightControl), 500,000 HP,
    -- multi-part body (ch270011-ch270032) and summons ch271000_00 minions. Confirmed in-game 2026-10-11.
    { id = "ch270000_00", key = "evil_eye", name = "Evil Eye", can_fly = true, native_hp = 500000 },
    -- (v1.9.168 turned its "tentacles into the ground" move off after the 13:17:35 crash; v1.9.169 brings it back
    -- with its tentacles steered onto arena spots - K.EYEPW)
    -- World Medusa (ch255000_01; _00 is the scripted lair one). Ground slots only.
    { id = "ch255000_01", key = "medusa", name = "Medusa", can_fly = false, chance = 0.2, regular_only = true },   -- v1.9.123: not in the Devouring Rancor (pillar clash with the Purgener)
    -- v1.9.157 (user): the Hydra, its own character ch255000_90 (the game's unused "MedusaC" slot) pointed at the
    -- Hydra prefab by the Hydra files (data/hydra_lab_load_e_mode.lua). Only in the pool while those files are
    -- loaded and report the Hydra ready (K.hydra_ready), so without them it never spawns a stray MedusaC.
    -- Medusa's Rancor AI fixes (battle spots, unstick, combat table, attack permission) apply; her pillar, petrify
    -- beam, frost look, bow and head/beam aim do not (the Hydra files drive its necks and breath). Never leashed:
    -- a teleport splits its body from its hitbox. One per Rancor, one alive at a time; own HP / damage settings.
    { id = "ch255000_90", key = "hydra", name = "Hydra", can_fly = false, chance = 0.2, regular_only = true,
      max_per_event = 1, max_alive = 1, no_leash = true, needs = "hydra", hp_key = "hydra_hp", atk_key = "hydra_attack" },
    -- Gagana (ch253012_00, Griffin family, own HP 200,000). Confirmed working in a Rancor 2026-10-13.
    -- v1.9.66: max 1 per Rancor event (setting) and never more than one alive at a time.
    -- v1.9.126: never teleported by the arena leash - a teleport moves its body but leaves its model behind
    -- (17:05: three leash recalls, then its hitbox walked next to you, invisible, while its model stood 77 m away)
    { id = "ch253012_00", key = "gagana", name = "Gagana", can_fly = true, chance = 0.2, max_per_event = 1, max_alive = 1, no_leash = true },
    -- v1.9.90: "Nasty Dragon" = the Lesser Dragon (ch257001_00, flies, own HP 100,000), user-named. Regular pool,
    -- at most 1 per Rancor and 1 alive at a time (like Gagana); scaled to the Lesser Demon HP setting.
    { id = "ch257001_00", key = "nasty_dragon", name = "Nasty Dragon", can_fly = true, chance = 0.2, max_per_event = 1, max_alive = 1 },
    -- v1.9.83: Sacred Arbor Purgener (ch255010_00, Medusa-family AI, own HP 96,000): Devouring Rancor final boss.
    -- Only in the Devouring Rancor, only from wave purgener_min_wave on, 1 per Rancor, own HP setting.
    { id = "ch255010_00", key = "purgener", name = "Sacred Arbor Purgener", can_fly = false, chance = 0.5,
      max_per_event = 1, max_alive = 1, devour_only = true, min_wave_key = "purgener_min_wave", hp_key = "purgener_hp",
      atk_key = "purgener_attack", final_boss = true },   -- v1.9.143 (user): its own damage multiplier (2.5x)
    -- v1.9.91: the Dragon (ch258000_10, flies, own HP 189,000): Devouring final boss, shares the final-boss roll.
    -- Own HP (300,000), size (2/3 via the spawn's ScaleRate) and damage (x2) settings.
    { id = "ch258000_10", key = "dragon", name = "Dragon", can_fly = true, chance = 0.5,
      max_per_event = 1, max_alive = 1, devour_only = true, min_wave_key = "purgener_min_wave", hp_key = "dragon_hp",
      scale_key = "dragon_scale", atk_key = "dragon_attack", final_boss = true,
      off = true },   -- v1.9.121: out of the pool until all of its moves are in (user); Devouring final = Purgener / none
    -- v1.9.149 (user): Brine Minotaur (ch256001_50, Goreminotaur family brine variant, own HP 192,000 with a boss
    -- bar - snapshotted 2026-10-11) and Brine Ogre. Ordinary pool members: ground slots, even weight,
    -- Lesser-Demon scaling like the Griffin. v1.9.150 (user): the Brine Ogre is the purple GRIMOGRE brine
    -- variant ch251001_50 (the plain Ogre brine variant would be ch251000_50).
    { id = "ch256001_50", key = "brine_minotaur", name = "Brine Minotaur", can_fly = false, chance = 0.2 },
    { id = "ch251001_50", key = "brine_ogre", name = "Brine Ogre (Grimogre)", can_fly = false, chance = 0.2 },
    -- v1.9.151 (user): Brine Golem (ch252000_53, the purple brine recolor). Ordinary pool member like the base
    -- Golem: regular Rancors only, max 1, its own HP multiple spread across the medallions and 3x damage.
    -- v1.9.160 (user: wrong golem - the brine one has PURPLE medallions): ch252000_53 has no entry in the game's enemy
    -- catalog (it never spawned; the _50/_51/_53 IDs are unused). The Golem that IS the Dark Arisen content is
    -- ch252000_13: its prefab's think table, status and parameters live in ch252/000/050 (Contents0014 data, the
    -- brine set - like the Brine Cyclops' ch250/000/50), own HP 59,800, 5 bar segments. The plain Golem is out.
    { id = "ch252000_13", key = "brine_golem", name = "Brine Golem", can_fly = false, chance = 0.2,
      max_per_event = 1, max_alive = 1, regular_only = true,
      hp_mult_key = "brine_golem_hp_mult", atk_key = "brine_golem_attack" },
    -- v1.9.144 (user): Drake (ch257000_00, flies). Shares the regular / Virulent finale roll with the Evil Eye
    -- and the Thimble (the ice dragon ch257003): one even share each by default. Gets the Thimble's HP, guard,
    -- damage and defence (learned from real Thimble finales, kept per kind of Rancor in the settings;
    -- 150,000 HP and its own damage until one has been seen).
    -- v1.9.155 (user): Vermund Purgener as a pool boss - 2x Lesser Demon HP (384,000) spread over its
    -- weak points, 2.5x damage. Never teleported (parasite: a warp separates its model from its body).
    { id = "ch253010_00", key = "vermund", name = "Vermund Purgener", can_fly = false, chance = 0.2,
      max_per_event = 1, max_alive = 1, hp_key = "vermund_hp", atk_key = "vermund_attack", no_leash = true,
      finale_only = true },   -- v1.9.166 (user 12:58): only a Virulent finale option next to the Thimble, never a wave slot
    -- v1.9.153 (user): the finale Drake is now the BRINE Drake (ch257000_50), same scaling: it still
    -- shares the finale roll and still gets the Thimble's learned HP / guard / damage / defence.
    -- v1.9.158 (user): Brine Sphinx, Brine Dullahan, Brine Cyclops join the pool (the Brine Golem already is).
    --   Brine Sphinx (ch253001_50, flies, own 130,000 HP): 1 per Rancor / 1 alive, own HP (240,000 = a Thimble's) and
    --     damage settings; also a Virulent Rancor FINALE option (shares the Thimble's slot, see the finale roll).
    --     Not teleported by the leash (a teleport split the Gagana's model from its body).
    --   Brine Dullahan (ch229000_50, own 360,000 HP, 5 bar segments): 1 per Rancor / 1 alive, keeps its own HP.
    --   Brine Cyclops (ch250000_51, own 120,000 HP, brine AI ch250/000/50; _50 itself failed to spawn in the 10-16
    --     bestiary scan): ordinary pool member, Lesser-Demon scaling like the Brine Minotaur / Ogre.
    { id = "ch253001_50", key = "brine_sphinx", name = "Brine Sphinx", can_fly = true, chance = 0.2, max_per_event = 1, max_alive = 1,
      hp_key = "brine_sphinx_hp", atk_key = "brine_sphinx_attack", no_leash = true, no_teleport = true,
      finale_only = true,   -- v1.9.166 (user 12:58): only a Virulent finale option next to the Thimble, never a wave slot
      -- v1.9.163 (user 12:20: spawned and teleported away instantly): her AI's "petrify-ray dodge warp" row - which
      -- also starts her opening warp (【戦闘】≪地上≫初回転移, first warp move; she is Medusa's companion in her own
      -- fight) - never passes for a Rancor Sphinx. Her warp ATTACKS (warp blast / warp orb, near her target) still
      -- happen; only a teleport aimed far from you (her lair / out-of-range warp) is turned to an arena spot.
      -- v1.9.165 (user 12:40: "turn the gaze warp off"): the whole act is off again - opening warp AND gaze-dodge
      -- rows - and the warp controller cancels the gaze-dodge situation (AvoidPetrificationIrradiation) too.
      block_acts = { ["Ch253001_50:石化光線回避ワープ"] = true }, sphinx_warp = true },
    -- v1.9.159 (user 00:13): 1 s after spawning the Brine Sphinx called its own Teleporter.teleport (back to its lair)
    -- and left the scene - no_teleport: during a Rancor that teleport is cancelled, it stays in the fight.
    -- v1.9.161 (user 12:01: "she doesn't move naturally ... teleported out"): VIRTUAL LAIR like the Evil Eye / Medusa -
    -- every teleport of hers lands on a spot around the arena instead (ring 10-26 m, never next to her last spot), and a
    -- Sphinx that spawns far away (her lair; 11:58 she was tracked 4,365 m off) is brought to the arena 1 s after it.
    -- v1.9.162 (user 12:15: after her spawn teleport her body / collision split from her model): her teleport is no longer
    -- cancelled and redone by the mod (that second move is what split them) - the DESTINATION of her own teleport is
    -- rewritten in place, so the game's warp moves model and body together. Her teleport right after spawning (first
    -- 4 s) goes nowhere (destination = where she stands). Her scaled HP is put back if a warp resets it (12:13: max
    -- went 240,000 -> 39,000 after her first teleport).
    { id = "ch229000_50", key = "brine_dullahan", name = "Brine Dullahan", can_fly = false, chance = 0.2, max_per_event = 1, max_alive = 1,
      finale_only = true,   -- v1.9.183 (user 16:44): a REGULAR Rancor finale option only (shares the Thimble's slot), never a wave slot
      native_hp = 360000 },
    { id = "ch250000_51", key = "brine_cyclops", name = "Brine Cyclops", can_fly = false, chance = 0.2 },
    { id = "ch257000_50", key = "drake", name = "Brine Drake", can_fly = true, chance = 0, max_per_event = 1, max_alive = 1,
      finale_only = true, match_native = true, native_of = "ch257003_", variant_label = "Thimble (ice dragon)",
      native_default_hp = 150000.0 },
    -- v1.9.99: Golem (ch252000_00, ground). Regular (non-Devouring) Rancors only, double size, ~1,000,000 HP (user).
    { id = "ch252000_00", key = "golem", name = "Golem", can_fly = false, chance = 0.2, max_per_event = 1, max_alive = 1,
      regular_only = true, hp_mult_key = "golem_hp_mult", atk_key = "golem_attack",
      off = true },   -- v1.9.160 (user): replaced by the Brine Golem   -- v1.9.106: normal size, 3x its own HP
    -- v1.9.141 (user): Rancor-only VARIANTS - not part of the reinforcement pool or the per-Rancor count. A Rancor's own
    -- Skeleton Lord / Norgan Lich slot becomes the Brine version at its chance (50%). The last boss wave stays the game's.
    -- Brine Skeleton Lord (ch226003_50, 140,000 HP, seen 2026-10-16): keeps its own HP and damage.
    { id = "ch226003_50", key = "brine_skeleton_lord", name = "Brine Skeleton Lord", can_fly = false, chance = 0.5,
      variant_of = "ch226003_6", variant_label = "Skeleton Lord", keep_own_stats = true, no_leash = true },
    -- Brine Lich (ch227000_10, flies, own 48,000 HP, seen 2026-10-16): gets the HP and damage of the Norgan Lich
    -- (ch227002) it replaces - read from the Rancor's own Norgan Liches (learned per kind of Rancor and kept in the
    -- settings), 120,000 HP until one has been seen (the Norgan Lich's HP in two regular Rancors, 2026-10-15).
    { id = "ch227000_10", key = "brine_lich", name = "Brine Lich", can_fly = true, chance = 0.5,
      variant_of = "ch227002_", variant_label = "Norgan Lich", match_native = true, native_default_hp = 120000.0, no_leash = true },
}

-- MAJOR Rancor wave enemies (the big health-bar ones) whose slots may be swapped.
-- MINOR Rancor wave enemies whose slots may become Evil Eye minions.
K.MINOR_PREFIXES = { "ch231000_", "ch226002_6" }
K.MINION_ID = "ch271000_00"   -- 8,000 HP, seen around the Evil Eye in its dungeon
K.EYE_ID = "ch270000_00"

K.MAJOR_PREFIXES = {
    { "ch261000_",  "Lesser Demon",                 false },
    { "ch254001_6", "Gorechimera (Rancor)",         false },
    { "ch226003_6", "Skeleton Lord (Rancor)",       false },
    { "ch227002_",  "Norgan Lich/Wight (ch227002)", true  },
    -- v1.9.132 (user): these count as big enemies too
    { "ch250002_",  "Norgan Giant",                 false },
    { "ch229000_0", "Dullahan",                     false },
    { "ch229000_6", "Dullahan (Rancor)",            false },   -- v1.9.158: not "ch229000_" - that caught the Brine Dullahan (_50)
    { "ch222006_",  "Flying enemy (ch222006)",      true  },
    { "ch223004_",  "Black Dog",                    false },   -- v1.9.135 (user): no boss bar, but a boss (120,000 HP)
    -- v1.9.124 (user): Death (ch227003) is never an ordinary slot any more; only the Devouring finale can hand it to the Purgener
}
-- v1.9.124: over how many big-enemy slots the per-Rancor reinforcement count is spread. From the game's own Rancor
-- tables (Death and Satanica's demons not counted; v1.9.132 with the Giant, Dullahan and ch222006 flyer added) a
-- regular Rancor has 2-5 such slots (avg 3.4), a Virulent one 3-7 (avg 4.8), the Devouring one 4-15 (avg 8.9, fewer
-- when Satanica ends it). Planning on the short end means even a short Rancor gets its full count.
K.SLOTS_EXPECTED = { regular = 3, virulent = 4, devour = 5 }
if not K.RELEASE then
    local ok, txt = pcall(fs.read, "rr_dev_prefer.txt")
    K.DEV_PREFER = ok and type(txt) == "string" and txt:match("^%s*([%w_]+)") or nil
    -- v1.9.164 dev test: data/rr_dev_sphinx_test.txt present -> a Rancor Sphinx runs through every warp situation
    local ok2, t2 = pcall(fs.read, "rr_dev_sphinx_test.txt")
    K.DEV_SPX_TEST = ok2 and type(t2) == "string" and #t2 > 0 or nil
    -- v1.9.180 dev test: data/rr_dev_finale.txt = "drake" / "sphinx" / "vermund" / "eye" forces every Thimble finale
    -- roll to that pick (survives script resets, unlike RR_DEV.force_finale)
    local ok4, t4 = pcall(fs.read, "rr_dev_finale.txt")
    K.DEV_FINALE_FILE = ok4 and type(t4) == "string" and t4:match("^%s*([%w_]+)") or nil
    -- v1.9.171 dev research: data/rr_dev_genres.txt present -> where the Evil Eye's own spawn requests get stuck
    local ok3, t3 = pcall(fs.read, "rr_dev_genres.txt")
    K.DEV_GENRES = ok3 and type(t3) == "string" and #t3 > 0 or nil
end
K.FINALE_PREFIXES = { "ch258002_", "ch227003_" }   -- Devouring finales the Purgener may take: Rancorous Dragon Carcass, Death

local default_config = {
    enabled = true,
    require_vortex = true,
    hp = 192000.0,          -- Lesser Demon max HP
    guard_hp = 30000.0,     -- Lesser Demon guard HP
    attack_rate = 1.5,      -- damage multiplier
    block_warp = true,      -- (unused since v1.4)
    eye_redirect_warp = true, -- Evil Eye warps land near the player instead of its dungeon
    eye_keep_alive = true,    -- don't let the Rancor delete a living Evil Eye at wave end
    leash = true,             -- v1.9.62: pull a Griffin (or other flyer) back if it ends up outside the arena
    leash_dist = 45,          -- metres from the arena center (flat) before it counts as outside
    leash_height = 35,        -- metres above the arena center before it counts as outside
    leash_secs = 6,           -- seconds outside before it's pulled back
    leash_dist_devour = 160,  -- v1.9.68: leash distance in the Devouring Rancor (much bigger arena)
    leash_max_recalls = 3,
    purgener_watch = true,    -- v1.9.80: log what Purgeners do (AI, actions, climb searches, escapes)
    purgener_pillar = true,   -- v1.9.80: spawn the climbable pillar next to a Purgener when one appears
    purgener_pillar_gid = 235, -- v1.9.89: back to Medusa's pillar (proven); 408 = its own big pillar (not climbable yet) -- v1.9.86: the Purgener's own pillar (gm81_098_01); 235 = Medusa's pillar
    purgener_study = true,    -- v1.9.82: log a Purgener's AI decisions (think rows, conditions, routes) - log only    -- v1.9.68: at most this many pulls per minute per monster, then it's left alone a minute
    medusa_battle_pos = true, -- give Medusa battle positions near the player (her AI needs them)
    medusa_fixes = true,      -- grounding / combat-state fixes carried over from v0.20
    medusa_force_battle = true, -- let her main table's "go to combat table" row through
    medusa_trace = false,       -- research: log every think-table row (heavy)
    medusa_force_pass = true,   -- let her "pass" rows (attacks) through the pass-row gate
    medusa_study = false,       -- observe a world Medusa (log only)
    medusa_force_uniq = true,   -- keep her "Ch255EnableChangeMoveAction" flag on (lets attack rows be checked)
    medusa_force_attack = true, -- give her attack permission (EnableAttack) in the Rancor
    medusa_attack_assist = true, -- widen her attack-range check a little (small arena)
    medusa_funnel = false,      -- log each think pass of a Rancor Medusa (research)
    medusa_aggression = 0.5,
    medusa_frost = false,       -- "Norgan frost" look for Rancor Medusas (visual only, experimental)
    medusa_beam_interval = 18.0, -- s: her petrify beam unlocks at least this often (0 = game rule only)
    medusa_petrify_research = false,
    medusa_beam_at_you = true,  -- her petrify beam targets you instead of your pawn
    medusa_pillar_aim = true,
    medusa_pillar_turn = 0,     -- deg/s she is turned around the pillar toward her target while coiled (0 = off; crash suspect)
    medusa_beam_pitch = true,   -- tilt her petrify beam up/down toward the target's height
    medusa_head_aim = 70,       -- turn her neck + head toward her target while she beams (max degrees, 0 = off)
    medusa_light_scale = 1.5,   -- eye light cone size multiplier (match the light circle to the petrify area)
    medusa_arrow_lockon = 180,  -- her snake-bow lock-on cone in degrees (game default 20)
    medusa_arrow_pitch = true,  -- turn freshly shot arrows toward her target (research / fallback)   -- while coiled on the pillar, her bow volley and beam aim at you / the best target
    medusa_petrify_mult = 1.0,
    medusa_beam_turn = 60.0,    -- deg/s extra turning toward you while she fires the beam (0 = off)
    medusa_beam_width = 1.5,    -- beam size multiplier (shell ExpandRate)
    medusa_beam_chase = 3.0,    -- m/s she moves to keep her beam target at 6-12 m while firing (0 = off)
    medusa_beam_smart = true,
    medusa_pillar_use = true,   -- send the Rancor Medusa to the arena pillar (her coil / beam-from-the-pillar attack)
    medusa_pillar_interval = 120, -- seconds between her pillar attempts (the first comes 15 s after the pillar)
    medusa_pillar_lift = 0.0,   -- pillar origin height above the floor (the origin is the pillar's base)
    medusa_pillar = true,       -- spawn a climbable pillar at the Rancor arena center while a Rancor Medusa is alive
    medusa_pillar_scout = false, -- research: log Medusa's lair pillars when they are loaded   -- beam goes to whoever is in beam range (you first)  -- petrify build-up multiplier while a Rancor Medusa is alive -- one-time dump + method counts for beam size / build-up research
    medusa_frost_strength = 0.8,
    medusa_frost_r = 0.80, medusa_frost_g = 0.90, medusa_frost_b = 1.00,
    medusa_frost_glow = 0.4,    -- 0 = her normal attack cooldowns, 0.5 = half as long, 0.9 = 10%
    medusa_arena_radius = 20.0, -- arena radius (used until enough samples, or always when calibrated)
    medusa_radius_calibrated = false, -- true = always use medusa_arena_radius
    cleanup_leftovers = true, -- remove reinforcements still alive when the vortex ends
}
default_config.evil_eye_minions = 3        -- minor slots turned into Evil Eye minions, per Rancor event
default_config.evil_eye_tentacles = 2      -- v1.9.63: minor slots turned into Evil Eye tentacles (ch272002_00), per event
default_config.evil_eye_max_per_event = 1  -- Evil Eyes per Rancor event
default_config.evil_eye_chance = 0.0        -- v1.9.120: the Evil Eye comes through its final-boss slot (eye_final_mode), not per-wave rolls
for _, r in ipairs(REINFORCEMENTS) do
    default_config[r.key .. "_chance"] = r.chance or 0.35
    default_config[r.key .. "_max_per_wave"] = 1
    if r.native_hp then default_config[r.key .. "_use_scaled_hp"] = false end
    if r.max_per_event then default_config[r.key .. "_max_per_event"] = r.max_per_event end
end
default_config.hydra_hp = 192000.0          -- v1.9.157: Hydra HP (Lesser Demon HP, like Medusa)
default_config.hydra_attack = 1.5           -- v1.9.157: Hydra damage multiplier (the global default)
default_config.brine_sphinx_hp = 240000.0     -- v1.9.158: Brine Sphinx HP (a Thimble's; its own is 130,000)
default_config.brine_sphinx_attack = 1.5      -- v1.9.158: Brine Sphinx damage multiplier
-- v1.9.158 (user): the VIRULENT Rancor finale (the Thimble's slot) - five even shares: Evil Eye / Brine Drake /
-- Brine Sphinx / Vermund Purgener / the Thimble stays. The regular Rancor keeps its own three-way roll.
default_config.reg_dullahan_final_share = 0.3333   -- v1.9.183: Brine Dullahan's share of a regular Rancor's Thimble finale
default_config.vir_no_thimble = true                 -- v1.9.183: Virulent finale: the Thimble never stays (one of the four options, when any is available)
default_config.vir_eye_final_share = 0.2
default_config.vir_drake_final_share = 0.2
default_config.vir_sphinx_final_share = 0.2
default_config.vir_vermund_final_share = 0.2
default_config.purgener_hp = 300000.0       -- v1.9.83: Devouring final boss HP (its own is 96,000)
default_config.purgener_attack = 2.5        -- v1.9.143 (user): Purgener damage multiplier, all of its moves
default_config.purgener_pillar_interval = 90 -- v1.9.143: seconds between its pillar attempts
default_config.eye_final_mode = true        -- v1.9.105: Evil Eye only as a regular Rancor's final boss, sharing the ice dragon's (ch257003) slot
default_config.eye_final_share = 0.3333     -- v1.9.144: the Thimble finale is an even three-way roll by default
default_config.drake_final_share = 0.3333   -- v1.9.144 (user): Drake's share of the Thimble finale
default_config.eye_parts_aim = 120.0        -- v1.9.119: Evil Eye ground tentacles turn toward you while casting (deg/s, 0 = off)
default_config.eye_warp_around_you = true   -- v1.9.116: Evil Eye "warp to a dungeon warp point" requests become the game's own "warp around the target"
default_config.eye_lair_rewrite = true      -- v1.9.114: rewrite the Evil Eye's own warp point data (ch270WarpData.user) onto the Rancor arena
default_config.eye_arena_warp = true        -- v1.9.111: Evil Eye warps land on spots around the arena ("virtual lair") instead of its dungeon
default_config.medusa_petrify_len = 0.7     -- v1.9.107: Rancor Medusa petrify beam length (1.0 = normal; user: 30% shorter)
default_config.golem_hp_mult = 3.0          -- v1.9.106: Golem HP = 3x its own (main + medallions), user
default_config.purgener_points_split = true -- v1.9.106: share the Purgener's HP evenly over its weak points (like the Golem's medallions)
default_config.golem_hp = 1000000.0         -- v1.9.99: Golem HP (user: ~1,000,000 total)
default_config.golem_scale = 1.0            -- v1.9.106: Golem at its normal size (user)
default_config.golem_attack = 3.0           -- v1.9.101: Golem damage multiplier (user: +100% on top of the 1.5 it had)
default_config.golem_transform_scale = false -- v1.9.103: also stretch the Golem's model (its spawn ScaleRate alone does nothing visible)
default_config.golem_medal_split = true     -- v1.9.101: share golem_hp evenly over its medallions (it dies when they all break)
default_config.brine_golem_hp_mult = 3.0    -- v1.9.151 (user): Brine Golem HP = 3x its own, spread across the medallions
default_config.brine_golem_attack = 3.0     -- v1.9.151 (user): Brine Golem damage multiplier (3x)
default_config.vermund_hp = 384000.0        -- v1.9.155 (user): Vermund Purgener HP = 2x Lesser Demon, over its weak points
default_config.vermund_attack = 2.5         -- v1.9.155 (user): Vermund Purgener damage multiplier
default_config.dragon_hp = 2000000.0        -- v1.9.97: Dragon final boss HP (its own is 189,000; user: 2,000,000)
default_config.dragon_scale = 0.667         -- v1.9.91: Dragon size (1.0 = normal; set on its spawn record, ScaleRate)
default_config.dragon_breath_aim = 70.0     -- v1.9.92: max degrees the Dragon's head/neck turn toward you during breath (0 = off)
default_config.dragon_breath_turn = 60.0    -- v1.9.92: extra body turning toward you during breath (deg/s)
default_config.dragon_spawner_stats = true  -- v1.9.94: Dragons spawned outside a Rancor (Enemy Spawner) get the boss size/HP/damage too
default_config.dragon_attack = 2.0          -- v1.9.91: Dragon damage multiplier (others use the global one, 1.5 default)
default_config.final_none_share = true      -- v1.9.91: "no final boss" gets an equal share of the final-boss roll
default_config.purgener_min_wave = 2        -- v1.9.123: earliest Devouring LARGE-enemy wave (usually 3 of them, or 2 + Satanica)
default_config.corpse_cleanup = true         -- v1.9.123: remove our bosses' bodies once their wave is over
default_config.per_rancor_regular = 2        -- v1.9.124: reinforcements per regular Rancor (spread over its ~2.6 big-enemy slots)
default_config.per_rancor_virulent = 3       -- v1.9.124: per Virulent Rancor (~4 big-enemy slots)
default_config.per_rancor_devour = 3         -- v1.9.124: per Devouring Rancor (~8 big-enemy slots; the Purgener finale is extra)
default_config.devour_final_share = 0.33     -- v1.9.124: Purgener's share of the Devouring dragon-carcass / Death finales
default_config.purgener_takes_death = true   -- v1.9.124: the Purgener may also take Death's finale (not only the dragon carcass')
default_config.gagana_flight = false         -- v1.9.127: off - IsFlightParam is its "in the air" state, not a permission (the game reset it every second)
default_config.eye_down_speed = 10.0         -- v1.9.133 (user): Evil Eye down time (all tentacles broken) runs 10x faster = 10% as long
default_config.eye_down_anim = 3.0           -- v1.9.135: Evil Eye fall / get-up animations play this much faster while it is down
default_config.only_real_rancors = true      -- v1.9.139: only the game's own Rancor events (not story / quest fights)
default_config.eye_revive_resist = 0.75      -- v1.9.138: Evil Eye takes this much LESS damage while it regrows its tentacles (0.75 = 75% less)
default_config.eye_force_minions = 0   -- v1.9.170 created minions - OFF since v1.9.174 (three crashes); only with eye_force_minions_unsafe
default_config.eye_swarm = true   -- v1.9.177: while our Evil Eye is alive EVERY small Rancor enemy becomes one of its eyeball minions; they die with it
default_config.eye_arrival_minions = 5   -- v1.9.174: extra eyeball minions (wave / nearby takeovers) the moment our Evil Eye arrives
default_config.eye_parts_arena = true   -- v1.9.169: Evil Eye ground tentacles come up on spots inside the arena (off = that move's tentacles are cancelled)
default_config.eye_tele_phase = true         -- v1.9.135: Evil Eye teleport phase: you and each pawn in turn, an attack between teleports, regrow at the end
default_config.gagana_swoops = true          -- v1.9.129: unlock the Gagana's swoop attacks in Rancors (its "行動解禁" AI flag)
default_config.hold_end = true               -- v1.9.127: the Rancor doesn't end (and wipe the field) while our reinforcements are still alive
default_config.hold_end_max = 240            -- v1.9.127: ...for at most this many seconds per Rancor

local config = json.load_file(K.CONFIG_FILE) or {}
if not config.gagana_19127 then config.gagana_flight = false; config.gagana_19127 = true end
if not config.eye_down_19133 then config.eye_down_speed = 10.0; config.eye_down_19133 = true end
if not config.purgener_pillar_reset_1989 then config.purgener_pillar_gid = 235; config.purgener_pillar_reset_1989 = true end
-- v1.9.108: Evil Eye TEST mode (user): spawn like the other reinforcements (per-wave chance) instead of only as the
-- regular Rancor's final boss, so its kit can be refined. Its chance was 0 in the saved settings -> 35%.
-- To go back: tick "Evil Eye only as the regular Rancor final boss" in the menu.
if not config.eye_lair_19114 then config.eye_arena_warp = false; config.eye_lair_19114 = true end   -- v1.9.114: lair rewrite replaces the teleport catch
if not config.eye_test_19108 then
    config.eye_final_mode = false
    if not tonumber(config.evil_eye_chance) or config.evil_eye_chance <= 0 then config.evil_eye_chance = 0.35 end
    config.eye_test_19108 = true
end
if not config.golem_reset_19106 then config.golem_transform_scale = false; config.golem_scale = 1.0; config.golem_reset_19106 = true end
if not config.dragon_hp_2m_1997 then config.dragon_hp = 2000000.0; config.dragon_hp_2m_1997 = true end   -- user: 2,000,000 HP
for k, v in pairs(default_config) do
    if config[k] == nil then config[k] = v end
end
-- drop settings from the Medusa-era builds
for k, _ in pairs(config) do
    if k == "medusa_count" or k == "max_medusa_per_wave" or k == "griffin_count" or k == "wave_cooldown"
        or k == "eye_block_warp" or k == "eye_hide_guest" then config[k] = nil end
end
local function save_config() json.dump_file(K.CONFIG_FILE, config) end
-- v1.9.120 (release prep, user): Evil Eye back to its final-boss slot (50/50 with the regular Rancor's last-wave ice dragon),
-- and one even chance for every regular reinforcement (Griffin, Medusa, Gagana, Nasty Dragon, Golem: 20% each per big-enemy slot)
-- v1.9.123 (user): Devouring waves are counted by large enemies only -> the final boss can come from large wave 2
if not config.devour_waves_19123 then config.purgener_min_wave = 2; config.devour_waves_19123 = true; pcall(function() json.dump_file(K.CONFIG_FILE, config) end) end
-- v1.9.144 (user): the Drake joins the Thimble finale - one even share each (Eye 1/3, Drake 1/3, Thimble stays 1/3)
if not config.drake_19144 then config.eye_final_share = 0.3333; config.drake_final_share = 0.3333; config.drake_19144 = true; pcall(function() json.dump_file(K.CONFIG_FILE, config) end) end
if not config.release_19120 then
    config.eye_final_mode, config.eye_final_share = true, 0.5
    config.evil_eye_chance = 0.0
    for _, k in ipairs({ "griffin", "medusa", "gagana", "nasty_dragon", "golem" }) do config[k .. "_chance"] = 0.2 end
    config.release_19120 = true
    pcall(save_config)
end
if K.RELEASE then
    -- research / logging switches are always off in the release build
    config.purgener_watch, config.purgener_study = false, false
    config.medusa_trace, config.medusa_study, config.medusa_funnel, config.medusa_pillar_scout = false, false, false, false
    config.dragon_spawner_stats, config.eye_arena_warp, config.golem_transform_scale = false, false, false
end
-- v1.9.12: the experimental frost look is switched off once (it can be turned back on in the menu)
-- v1.9.15: petrification research finished - its call counters are switched off once
-- v1.9.23: pillar scout (research) switched off once - its periodic dump was unsafe on spawned pillars
if config.medusa_scout_reset_1923 == nil then
    config.medusa_pillar_scout = false
    config.medusa_scout_reset_1923 = true
    pcall(save_config)
end
if config.medusa_petrify_reset_1960 == nil then
    config.medusa_petrify_mult = 1.0
    config.medusa_petrify_reset_1960 = true
    pcall(save_config)
end
if config.medusa_interval_reset_1956 == nil then
    if (config.medusa_pillar_interval or 60) == 60 then config.medusa_pillar_interval = 120 end
    config.medusa_interval_reset_1956 = true
    pcall(save_config)
end
if config.medusa_turn_reset_1954 == nil then
    config.medusa_pillar_turn = 0
    config.medusa_turn_reset_1954 = true
    pcall(save_config)
end
if config.medusa_lift_reset_1944 == nil then
    config.medusa_pillar_lift = 0.0
    config.medusa_lift_reset_1944 = true
    pcall(save_config)
end
if config.medusa_research_reset_1915 == nil then
    config.medusa_petrify_research = false
    config.medusa_research_reset_1915 = true
    pcall(save_config)
end
if config.medusa_frost_reset_1912 == nil then
    config.medusa_frost = false
    config.medusa_frost_reset_1912 = true
    pcall(save_config)
end

-- Helpers ------------------------------------------------------------------------------
local function safe(fn)
    local ok, r = pcall(fn)
    if ok then return r end
    return nil
end

-- keep the previous session's log (a crash + restart would otherwise overwrite it)
pcall(function()
    local prev = fs.read(K.LOG_FILE)
    if prev and #prev > 0 then fs.write("RancorReinforcements_log_prev.txt", prev) end
end)
local log_lines, file_lines = {}, {}
local log_dirty, last_log_write = true, 0
local function log(msg)
    local line = os.date("%H:%M:%S ") .. msg
    table.insert(log_lines, 1, line)
    if #log_lines > 14 then table.remove(log_lines) end
    table.insert(file_lines, line)
    if #file_lines > 2000 then table.remove(file_lines, 1) end
    log_dirty = true
end
-- write the log file right now (for steps that might crash the game)
local function log_now(msg)
    log(msg)
    pcall(fs.write, K.LOG_FILE, table.concat(file_lines, "\n"))
end

local id_value, id_name = {}, {}
do
    local td = sdk.find_type_definition("app.CharacterID")
    for _, f in ipairs(td and td:get_fields() or {}) do
        if f:is_static() then
            local v = safe(function() return f:get_data(nil) end)
            if v then id_value[f:get_name()] = v; id_name[v] = f:get_name() end
        end
    end
end

local function major_info(id)
    if not id then return nil, false end
    for _, p in ipairs(K.MAJOR_PREFIXES) do
        if string.sub(id, 1, #p[1]) == p[1] then return p[2], p[3] end
    end
    return nil, false
end

local function reinforcement_for(name)
    for _, r in ipairs(REINFORCEMENTS) do
        if name and name:sub(1, #r.id) == r.id then return r end
    end
    return nil
end

-- v1.9.102: cache OFF. A monster list kept for 0.2 s can hold a monster that is being removed; calling
-- get_GameObject on it throws inside the game (16:21:19, as Satanica left) - right after that the Rancor's
-- final wave came in broken (a dead, invisible ch223003) and this script stopped logging. Fresh scans only.
K.FC_CACHE = {}
K.FC_TTL = 0.2
K.FC = {}
local function find_components(type_name)
    local cached = K.FC_CACHE[type_name] and K.FC[type_name]
    if cached and os.clock() - cached.t < K.FC_TTL then return cached.list end
    local scene = safe(function()
        return sdk.call_native_func(sdk.get_native_singleton("via.SceneManager"),
            sdk.find_type_definition("via.SceneManager"), "get_CurrentScene()")
    end)
    if not scene then return {} end
    local arr = safe(function() return scene:call("findComponents(System.Type)", sdk.typeof(type_name)) end)
    local list = (arr and safe(function() return arr:get_elements() end)) or {}
    if K.FC_CACHE[type_name] then K.FC[type_name] = { t = os.clock(), list = list } end
    return list
end

local function set_if_exists(obj, field_names, value)
    local td = obj:get_type_definition()
    while td do
        for _, name in ipairs(field_names) do
            if td:get_field(name) then obj:set_field(name, value); return name end
        end
        td = td:get_parent_type()
    end
    return nil
end

-- Vortex fight detection -----------------------------------------------------------------
local vortex_now, last_vortex_check = false, 0
local vortex_center, vortex_ended_at = nil, nil
local vortex_started_at = -1
local wave_req_last, wave_fight_start = -1000, -1000   -- wave spawn requests (new fight = first after 60 s quiet)
K.POST_WINDOW, K.POST_RADIUS = 600, 400   -- watch for reappearing reinforcements: 10 min, 400 m
local event = { eyes = 0, minions = 0, tentacles = 0, by_key = {} }   -- per Rancor event, reset when a vortex fight starts
-- v1.9.68: the single Devouring Rancor (big arena). Detected from its fingerprint objects
-- (SoundFieldEnv_NRD_Final_BattleArea / 13_env_DarkZone_Area) or its location.
local DEVOUR = { active = false, pos = { x = -2304, y = 648, z = -3802 }, radius = 400 }
-- v1.9.124: which Rancor is running, straight from the game's Rancor manager (app.AppraiseCycleManager
-- ProcessingVoidEventID: 3606 = the Devouring Rancor, xx51-xx55 = Virulent, xx01-xx05 = regular, -1 = none).
-- The location check stays as the fallback for when the game doesn't say.
K.KIND = { t = -10 }
function K.rancor_kind()
    local now = os.clock()
    if now - K.KIND.t < 1 then return K.KIND.kind, K.KIND.id end
    K.KIND.t = now
    local mgr = sdk.get_managed_singleton("app.AppraiseCycleManager")
    local id = mgr and tonumber(safe(function() return mgr:call("get_ProcessingVoidEventID") end))
    local kind = nil
    if id and id >= 0 then
        local high = safe(function() return mgr:call("get_IsProcessingHighLevelVoid") end)
        if id == 3606 or high == true then kind = "devour" elseif id % 100 >= 50 then kind = "virulent" else kind = "regular" end
    end
    K.KIND.kind, K.KIND.id = kind, id
    return kind, id
end
-- v1.9.139 (Nexus bug report, Dragoness573: the mod replaced enemies in the story's Barbatos boss fight): only touch
-- spawns in a real Rancor - one of the game's own Rancor events (ac3101-ac3655: regular xx01-05, Virulent xx51-55,
-- the Devouring 3606). The story's Rancor quest (3001), anything else, or no Rancor at all (-1) is left alone.
function K.real_rancor()
    local _, id = K.rancor_kind()
    if not id or id < 0 then return false, id end
    local r = id % 100
    local ok = id == 3606 or (id >= 3100 and id < 3700 and ((r >= 1 and r <= 5) or (r >= 51 and r <= 55)))
    return ok, id
end
function K.rancor_gate()
    if not config.only_real_rancors then return true end
    local ok, id = K.real_rancor()
    if not ok and (K.GATE_LOG_ID ~= id or os.clock() - (K.GATE_LOG_T or -100) > 30) then
        K.GATE_LOG_ID, K.GATE_LOG_T = id, os.clock()
        log("Spawn request during a vortex, but the game says this is not a regular / Virulent / Devouring Rancor (event ID "
            .. tostring(id) .. ") - left alone")
    end
    return ok
end
-- syncs DEVOUR.active with the game and returns this Rancor's kind and its reinforcement count (event.q)
function K.sync_kind()
    local kind, id = K.rancor_kind()
    if kind then
        local dv = kind == "devour"
        if dv ~= DEVOUR.active then
            log(string.format("Rancor manager: this is %s (ID %s)", dv and "the DEVOURING Rancor" or ("a " .. kind .. " Rancor"), tostring(id)))
            DEVOUR.active = dv
        end
    else
        kind = DEVOUR.active and "devour" or "regular"
    end
    -- v1.9.125: a different Rancor ID = a new Rancor, even when the vortex objects never "ended" in between
    -- (16:37 a regular Rancor right after the Devouring one kept the Devouring arena center, 4,575 m away)
    if id and id >= 0 and id ~= K.KIND.last_id then
        local first = K.KIND.last_id == nil
        K.KIND.last_id = id
        local cm = sdk.get_managed_singleton("app.CharacterManager")
        local p = cm and safe(function() return cm["<ManualPlayer>k__BackingField"]:get_Transform():get_Position() end)
        local far = p and (not vortex_center or (p.x - vortex_center.x) ^ 2 + (p.z - vortex_center.z) ^ 2 > 300 * 300)
        if far then
            vortex_center = { x = p.x, y = p.y, z = p.z }
            log(string.format("New Rancor (ID %d): arena center moved to you (%.0f, %.0f, %.0f)", id, p.x, p.y, p.z))
        end
        if not first and (event.q and event.q.id ~= id) then
            event = { eyes = 0, minions = 0, tentacles = 0, by_key = {} }
            vortex_started_at = os.clock()
        end
    end
    local q = event.q
    if not q or (id and id >= 0 and q.id ~= id) then   -- a new vortex fight or a new Rancor ID starts a new count
        q = { id = id, used = 0, seen = 0 }
        event.q = q
    end
    q.kind = kind
    return kind, q
end
local function rancor_fingerprint()
    -- v1.9.67: log what this Rancor is made of (object names containing these words, with counts) so
    -- different Rancors (e.g. the single Devouring Rancor) can be told apart
    local WORDS = { "vortex", "rancor", "devour", "void", "abyss", "rift", "sp_", "ev_", "area" }
    local hits, n = {}, 0
    for _, t in ipairs(find_components("via.Transform")) do
        local name = safe(function() return t:call("get_GameObject"):call("get_Name") end)
        local low = name and string.lower(name)
        if low then
            for _, w in ipairs(WORDS) do
                if string.find(low, w, 1, true) then
                    if not hits[name] then n = n + 1 end
                    hits[name] = (hits[name] or 0) + 1
                    break
                end
            end
        end
    end
    local list = {}
    for k, c in pairs(hits) do table.insert(list, c > 1 and (k .. " x" .. c) or k) end
    table.sort(list)
    local cm = sdk.get_managed_singleton("app.CharacterManager")
    local tr = cm and safe(function() return cm["<ManualPlayer>k__BackingField"]:get_Transform() end)
    local wp = tr and safe(function()
        local u = tr:call("get_UniversalPosition")
        return string.format("(%.0f, %.0f, %.0f world)", u.x, u.y, u.z)
    end)
    log(string.format("Rancor fingerprint: you at %s; %d named objects: %s",
        wp or "?", n, table.concat(list, ", ", 1, math.min(#list, 80))))
    local by_name = false
    for k in pairs(hits) do
        local low = string.lower(k)
        if low:find("nrd_final_battlearea", 1, true) or low:find("darkzone_area", 1, true) then by_name = true end
    end
    local by_pos = tr and safe(function()
        local u = tr:call("get_UniversalPosition")
        local dx, dz = u.x - DEVOUR.pos.x, u.z - DEVOUR.pos.z
        return dx * dx + dz * dz < DEVOUR.radius * DEVOUR.radius
    end) or false
    -- v1.9.100: location decides. The Devouring area's objects (13_env_DarkZone_Area...) stay loaded for a while
    -- after you leave, so a regular Rancor 1,840 m away was taken for the Devouring one (16:00, no Golem possible).
    DEVOUR.active = by_pos
    DEVOUR.extent = 0
    log(DEVOUR.active and string.format("This is the DEVOURING Rancor (matched by location%s)", by_name and " + objects" or "")
        or ("Normal Rancor (not the Devouring one)" .. (by_name and " - Devouring-area objects are still loaded from earlier, ignored (wrong location)" or "")))
end

-- v1.9.156: Rancor (vortex) detection, cheap. Every Rancor seen so far (regular, Virulent, Devouring) has a
-- "15_CS_Vortexrage" object. 1) the vortex object found last time, if still valid; 2) a direct lookup of the known
-- name(s). No full-scene scan any more.
K.VORTEX_NAMES = { "15_CS_Vortexrage" }
function K.vortex_detect()
    local go = K.vortex_go
    if go then
        local valid = safe(function() return go:call("get_Valid") end)
        local name = valid and safe(function() return go:call("get_Name") end)
        if name and string.find(string.lower(name), "vortex", 1, true) then return true end
        K.vortex_go = nil
    end
    local scene = safe(function()
        return sdk.call_native_func(sdk.get_native_singleton("via.SceneManager"), sdk.find_type_definition("via.SceneManager"), "get_CurrentScene()")
    end)
    if not scene then return false end
    if K.FIND_GO ~= false then
        for _, nm in ipairs(K.VORTEX_NAMES) do
            local ok, g = pcall(function() return scene:call("findGameObject(System.String)", nm) end)
            if not ok then K.FIND_GO = false; break end
            K.FIND_GO = true
            if g then K.vortex_go = g; return true end
        end
        if K.FIND_GO then return false end
    end
    -- (no full-scene fallback scan: the direct lookup was confirmed in-game, ~1 ms vs 19 ms+ for the old scan)
    return false
end

local function refresh_vortex()
    local found = false
    local vgo = nil   -- v1.9.102: no cached vortex object either (always a fresh scan)
    if vgo and safe(function() return vgo:call("get_Valid") end) then
        local name = safe(function() return vgo:call("get_Name") end)
        found = name ~= nil and string.find(string.lower(name), "vortex", 1, true) ~= nil
    end
    if not found then
        -- v1.9.156: no more full-scene scan every 2 s (players: "a stutter every couple of seconds, everywhere, worse after
        -- fast travel" - that scan walked every via.Transform in the loaded world, two game calls each).
        found = K.vortex_detect()
    end
    if found and not vortex_now then
        pcall(rancor_fingerprint)
        -- the vortex objects can flicker for a few seconds; only a real new fight resets the caps
        if not vortex_ended_at or os.clock() - vortex_ended_at > 30 then
            event = { eyes = 0, minions = 0, tentacles = 0, by_key = {} }
            vortex_started_at = os.clock()
            if rr_on_new_vortex then pcall(rr_on_new_vortex) end
        end
        -- the player is at the rift when the fight starts; vortex objects report (0,0,0)
        local cm = sdk.get_managed_singleton("app.CharacterManager")
        local pl = cm and safe(function() return cm["<ManualPlayer>k__BackingField"] end)
        local p = pl and safe(function() return pl:get_Transform():get_Position() end)
        if p then vortex_center = { x = p.x, y = p.y, z = p.z } end
    end
    if found ~= vortex_now then
        log("Vortex fight " .. (found and "started" or "ended") .. (vortex_center and
            string.format(" (center %.0f, %.0f, %.0f)", vortex_center.x, vortex_center.y, vortex_center.z) or ""))
        if not found then vortex_ended_at = os.clock(); DEVOUR.active = false end
    end
    vortex_now = found
end

local function pos_of(go)
    local p = safe(function() return go:call("get_Transform"):call("get_Position") end)
    return p and { x = p.x, y = p.y, z = p.z }
end
local function dist3(a, b)
    if not a or not b then return nil end
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function player_pos()
    local cm = sdk.get_managed_singleton("app.CharacterManager")
    local pl = cm and safe(function() return cm["<ManualPlayer>k__BackingField"] end)
    local p = pl and safe(function() return pl:get_Transform():get_Position() end)
    return p and { x = p.x, y = p.y, z = p.z }
end

-- absolute (universal) world positions - what via.Position fields use
K.HAS_UPOS = (function()
    local td = sdk.find_type_definition("via.Transform")
    return td and td:get_method("get_UniversalPosition") ~= nil
end)()
local function vfield(v, k)
    local x = safe(function() return v[k] end)
    if type(x) ~= "number" then x = safe(function() return v:get_field(k) end) end
    return x
end
local function upos_tr(t)
    if not t then return nil end
    if K.HAS_UPOS then
        local p = safe(function() return t:call("get_UniversalPosition") end)
        local x, y, z = p and vfield(p, "x"), p and vfield(p, "y"), p and vfield(p, "z")
        if type(x) == "number" and type(y) == "number" and type(z) == "number" then return { x = x, y = y, z = z } end
    end
    return nil
end
local function upos_go(go)
    return go and upos_tr(safe(function() return go:call("get_Transform") end))
end
local function player_upos()
    local cm = sdk.get_managed_singleton("app.CharacterManager")
    local pl = cm and safe(function() return cm["<ManualPlayer>k__BackingField"] end)
    return pl and upos_tr(safe(function() return pl:get_Transform() end))
end

-- Move an Evil Eye body back into the arena with the game's own Teleporter
local POS_TD = sdk.find_type_definition("via.Position")
-- v1.9.176 (user 15:34: "what if I'm elevated - recognize the terrain, spawn on the ground around me"): ground height
-- at a world spot. A ray straight down (from 30 m above the reference height to 60 m below) with the player's own
-- CharacterController collision filter - it collides with what you walk on (tested 15:36: under you 83.6 = your feet,
-- 8-13 m out 81.1-84.6). Positions are absolute world (universal); the ray runs in the scene's local coordinates.
-- Returns the ground's absolute y, or nil (no ground found there).
function K.ground_y(ux, uz, ref_y)
    local cm = sdk.get_managed_singleton("app.CharacterManager")
    local pl = cm and safe(function() return cm["<ManualPlayer>k__BackingField"] end)
    local go = pl and safe(function() return pl:call("get_GameObject") end)
    local tr = go and safe(function() return go:call("get_Transform") end)
    local lp = tr and safe(function() return tr:call("get_Position") end)
    local up = tr and upos_tr(tr)
    if not (lp and up) then return nil end
    local ox, oy, oz = up.x - lp.x, up.y - lp.y, up.z - lp.z
    local cc = safe(function() return go:call("getComponent(System.Type)", sdk.typeof("via.physics.CharacterController")) end)
    local fi = cc and safe(function() return cc:call("get_FilterInfo") end)
    if not fi then return nil end
    local ry = (ref_y or up.y) - oy
    local hit = safe(function()
        local q = sdk.create_instance("via.physics.CastRayQuery"):add_ref()
        q:call("setRay(via.vec3, via.vec3)", Vector3f.new(ux - ox, ry + 30, uz - oz), Vector3f.new(ux - ox, ry - 60, uz - oz))
        q:call("set_FilterInfo", fi)
        q:call("enableNearSort")
        local r = sdk.call_native_func(nil, sdk.find_type_definition("via.physics.System"), "castRay(via.physics.CastRayQuery)", q)
        if not r or (r:call("get_NumContactPoints") or 0) < 1 then return nil end
        return r:call("getContactPoint", 0).Position.y
    end)
    return hit and (hit + oy) or nil
end
-- a spot on the ground r_min..r_max around the absolute point c (tries a few directions; nil if none has ground
-- within 25 m up / down of ref_y)
function K.ground_spot(c, r_min, r_max, ref_y)
    for _ = 1, 8 do
        local a = math.random() * 2 * math.pi
        local r = r_min + math.random() * (r_max - r_min)
        local x, z = c.x + math.cos(a) * r, c.z + math.sin(a) * r
        local gy = K.ground_y(x, z, ref_y or c.y)
        if gy and math.abs(gy - (ref_y or c.y)) < 25 then return { x = x, y = gy, z = z } end
    end
    return nil
end
local TELEPORT_M = (function()
    local td = sdk.find_type_definition("app.Teleporter")
    return td and td:get_method("teleport(via.Position)")
end)()
local recalling = false
local recall_method_ok = nil   -- which argument style worked
local function recall_to_arena(teleporter, name, why)
    local pp = player_upos() or player_pos()
    if not pp or not teleporter or not TELEPORT_M then return false end
    local a = math.random() * 2 * math.pi
    local r = 12 + math.random() * 8
    local tx, ty, tz = pp.x + math.cos(a) * r, pp.y + 8, pp.z + math.sin(a) * r
    local styles = {
        function()
            local v = ValueType.new(POS_TD)
            v:set_field("x", tx); v:set_field("y", ty); v:set_field("z", tz)
            return v
        end,
        function() return Vector3f.new(tx, ty, tz) end,
    }
    local err
    recalling = true
    for i, make in ipairs(styles) do
        if not recall_method_ok or recall_method_ok == i then
            local ok, e = pcall(function() TELEPORT_M:call(teleporter, make()) end)
            if ok then
                recalling = false
                recall_method_ok = i
                log(string.format("Recalled %s to the arena (%s), %.0f m from you", name, why, r))
                return true
            end
            err = e
        end
    end
    recalling = false
    log("Recall failed for " .. name .. ": " .. tostring(err))
    return false
end

-- Scaling (HP methods confirmed in-game on TU 4.0) ----------------------------------------
local function call_m(obj, sig, ...)
    local args = { ... }
    return pcall(function() return obj:call(sig, table.unpack(args)) end)
end

-- v1.9.141: the Brine Lich takes the stats of the Rancor's own Norgan Lich (learned from live ones, see K.learn_native)
function K.get_field_any(obj, name)
    local td = obj and obj:get_type_definition()
    while td do
        if td:get_field(name) then return obj:get_field(name) end
        td = td:get_parent_type()
    end
end
function K.native_stats(rf)
    local kind = (K.KIND and K.KIND.kind) or (DEVOUR.active and "devour" or "regular")
    local function get(k)
        local pre = rf.key .. "_native_"
        local hp = tonumber(config[pre .. "hp_" .. k])
        if not hp or hp <= 0 then return nil end
        return { hp = hp, batk = tonumber(config[pre .. "batk_" .. k]), atk = tonumber(config[pre .. "atk_" .. k]),
            guard = tonumber(config[pre .. "guard_" .. k]), bdef = tonumber(config[pre .. "bdef_" .. k]),
            def = tonumber(config[pre .. "def_" .. k]), kind = k, exact = (k == kind) }
    end
    local st = get(kind)
    if not st then for _, k in ipairs({ "regular", "virulent", "devour" }) do st = st or get(k) end end
    st = st or { hp = rf.native_default_hp }
    st.sig = string.format("%s/%s/%s/%s/%s", tostring(st.hp), tostring(st.batk), tostring(st.atk), tostring(st.guard), tostring(st.bdef))
    return st
end
-- t = the tracked monster when its stats are re-matched mid-fight (keeps how hurt it is)
function K.apply_native(hit, rf, t, name)
    local st = K.native_stats(rf)
    local ratio = 1.0
    if t then
        local cur = safe(function() return hit:call("get_Hp") end)
        local mx = safe(function() return hit:call("get_OriginalMaxHp") end)
        if not cur or cur <= 0 then return true, st end
        if mx and mx > 0 then ratio = math.max(0.01, math.min(1.0, cur / mx)) end
    end
    if st.hp and st.hp > 0 then
        local hpv = st.hp + 0.0
        call_m(hit, "setRegionOriginalMaxHp(System.Single, System.Int32, System.Boolean)", hpv, 0, true)
        call_m(hit, "setReducedMaxHpValue(System.Single)", hpv)
        if not t then call_m(hit, "recoverHpAndMaxHpCompletely(System.Boolean)", false) end
        call_m(hit, "setHpValue(System.Single, System.Boolean)", hpv * ratio, false)
    end
    if st.guard and st.guard > 0 then call_m(hit, "set_GuardHp(System.Single)", st.guard + 0.0) end
    if st.batk then set_if_exists(hit, { "_BaseAttackRate" }, st.batk + 0.0) end
    if st.atk then set_if_exists(hit, { "<AttackRate>k__BackingField" }, st.atk + 0.0) end
    if st.bdef then set_if_exists(hit, { "_BaseDefenceRate" }, st.bdef + 0.0) end   -- v1.9.144: damage resistance too
    if st.def then set_if_exists(hit, { "<DefenceRate>k__BackingField" }, st.def + 0.0) end
    log(string.format("%s%s: %s HP%s, damage %s (%s)", t and "Re-matched " or "", name or rf.name, tostring(st.hp),
        st.guard and string.format(", guard %.0f", st.guard) or "", st.batk and string.format("x%.2f / x%.2f", st.batk, st.atk or st.batk) or "its own",
        st.kind and string.format("as a %s Rancor's %s%s", st.kind, rf.variant_label or "native", st.exact and "" or " - none seen in this kind of Rancor yet")
            or (rf.variant_label or "native") .. " not seen yet: default HP, own damage until one shows up"))
    return true, st
end
local function apply_scaling(chara, rf)
    local hit = safe(function() return chara:get_Hit() end)
    if not hit then return false end
    if rf and rf.keep_own_stats then return true end                 -- v1.9.141: Brine Skeleton Lord
    if rf and rf.match_native then return (K.apply_native(hit, rf)) end   -- v1.9.141: Brine Lich
    local scale_hp = not (rf and rf.native_hp) or config[rf.key .. "_use_scaled_hp"]
    local hpv = (rf and rf.hp_key and tonumber(config[rf.hp_key])) or config.hp   -- v1.9.83: own HP (Purgener)
    if rf and rf.hp_mult_key then   -- v1.9.106: a multiple of its own HP (Golem: 3x)
        local base = safe(function() return hit:call("get_OriginalMaxHp") end)
        if type(base) == "number" and base > 0 then hpv = base * (tonumber(config[rf.hp_mult_key]) or 1) end
    end
    if scale_hp then
        call_m(hit, "setRegionOriginalMaxHp(System.Single, System.Int32, System.Boolean)", hpv, 0, true)
        call_m(hit, "setReducedMaxHpValue(System.Single)", hpv)
        call_m(hit, "recoverHpAndMaxHpCompletely(System.Boolean)", false)
        call_m(hit, "setHpValue(System.Single, System.Boolean)", hpv, false)
    end
    call_m(hit, "set_GuardHp(System.Single)", config.guard_hp)
    local atk = (rf and rf.atk_key and tonumber(config[rf.atk_key])) or config.attack_rate   -- v1.9.91
    set_if_exists(hit, { "_BaseAttackRate" }, atk)
    set_if_exists(hit, { "<AttackRate>k__BackingField" }, atk)
    return true
end

local function hp_report(chara)
    local hit = safe(function() return chara:get_Hit() end)
    if not hit then return "?" end
    return string.format("HP %s / max %s", tostring(safe(function() return hit:call("get_Hp") end)),
        tostring(safe(function() return hit:call("get_OriginalMaxHp") end)))
end

-- Spawn-pool injection ------------------------------------------------------------------
-- A "wave" is a burst of spawn requests within 4s of each other.
local wave = { last = -100, counts = {}, slots = 0 }
local stats = { waves = 0, swapped = {} }
local swapped_entries = {}   -- entry address -> true while a swap is live
local pending_reverts = {}   -- { info, addr, original, pick, at, spawned }
local swaps_pending, last_swap_time = 0, -1000
local swaps_by_id, claimed_by_id, last_claim_t = {}, {}, {}   -- only claim monsters we actually swapped in

local function new_wave_if_needed(now)
    if now - wave.last > 4.0 then
        if wave.slots > 0 then
            local parts = {}
            for k, n in pairs(wave.counts) do table.insert(parts, n .. "x " .. k) end
            log(string.format("Wave done: %d major slots, swapped in: %s", wave.slots,
                #parts > 0 and table.concat(parts, ", ") or "none"))
        end
        wave = { last = now, counts = {}, slots = 0, minions = 0, eye_planned = nil }
        stats.waves = stats.waves + 1
    end
    wave.last = now
end

local function rf_by_key(key)
    for _, rf in ipairs(REINFORCEMENTS) do if rf.key == key then return rf end end
end

-- v1.9.69: Satanica (ch261001) - the Rancor end boss cameo. While he is around the mod keeps its
-- hands off every spawn (his summoned Lesser Demons, his teleporter event). He is never swapped.
local SATANICA = { prefix = "ch261001", until_t = -1, seen_t = -1, logged = 0 }
function SATANICA.active(now)
    if now > SATANICA.until_t then return false end
    -- once he has been seen, the event ends 15 s after he leaves the scene
    if SATANICA.seen_t > 0 and now - SATANICA.seen_t > 15 then return false end
    return true
end

-- v1.9.70: test spawn - the next major Rancor slot becomes any chosen monster (to identify monsters
-- by sight, e.g. the Sacred Arbor Purgener). Not scaled or tracked: it keeps its own HP.
local TEST = { armed = nil, here = nil, waiting = nil, idx = 1, list = nil, custom = "" }
function TEST.candidates()
    if TEST.list then return TEST.list end
    local l = {}
    for name in pairs(id_value) do
        -- big-monster families (ch25x / ch26x), variants only (chNNNNNN_NN)
        if name:match("^ch2[56]%d%d%d%d_%d%d$") then table.insert(l, name) end
    end
    table.sort(l)
    TEST.list = l
    return l
end

-- v1.9.69: wave log - every wave of a fight is numbered and its full make-up logged
local WAVES = { n = 0, cur = nil, last_any = -1000 }
function WAVES.flush()
    local w = WAVES.cur
    if not w then return end
    WAVES.cur = nil
    local parts = {}
    for k, c in pairs(w.ids) do table.insert(parts, c .. "x " .. k) end
    table.sort(parts)
    log(string.format("WAVE %d%s%s: %s%s", w.n, (DEVOUR.active and " (Devouring Rancor)" or "") .. (w.large and (" [large wave " .. w.large .. "]") or ""),
        w.satanica and " [Satanica event - left alone]" or "", table.concat(parts, ", "),
        #w.swaps > 0 and (" | mod swaps: " .. table.concat(w.swaps, ", ")) or ""))
end
function WAVES.note(name, now)
    if WAVES.cur and now - WAVES.cur.last > 4 then WAVES.flush() end
    if not WAVES.cur then
        if now - WAVES.last_any > 60 then WAVES.n = 0; WAVES.large_n = 0 end
        WAVES.n = WAVES.n + 1
        WAVES.seq = (WAVES.seq or 0) + 1   -- never reset (corpse cleanup compares it)
        WAVES.cur = { n = WAVES.n, ids = {}, swaps = {}, last = now, seq = WAVES.seq }
    end
    WAVES.last_any = now
    WAVES.cur.last = now
    WAVES.cur.ids[name] = (WAVES.cur.ids[name] or 0) + 1
    -- v1.9.123 (user): only waves with large enemies count as Devouring waves (the small-fodder waves don't)
    if not WAVES.cur.large and name ~= "Invalid" then
        local small = false
        for _, p in ipairs(K.MINOR_PREFIXES) do if name:sub(1, #p) == p then small = true; break end end
        if not small then WAVES.large_n = (WAVES.large_n or 0) + 1; WAVES.cur.large = WAVES.large_n end
    end
    if SATANICA.active(now) then WAVES.cur.satanica = true end
end

-- v1.9.157: the Hydra files are loaded and have ch255000_90 pointed at the Hydra prefab
function K.hydra_ready()
    local H = rawget(_G, "HYDRA_MODE")
    if type(H) ~= "table" or not H.on or type(H.ready) ~= "function" then return false end
    local ok, r = pcall(H.ready)
    return ok and r == true
end

local function pick_reinforcement(flying_slot)
    -- Evil Eye is planned per wave (so its minions can be placed in the same wave)
    local eye = rf_by_key("evil_eye")
    if wave.eye_planned and eye and (wave.counts[eye.name] or 0) < 1
        and event.eyes < config.evil_eye_max_per_event then
        return eye
    end
    -- v1.9.124: one weighted pick among the reinforcements allowed in this slot (their chance settings are the
    -- weights, so equal settings = an even spread). Whether the slot gets a reinforcement at all is decided by
    -- K.quota_pick (the per-Rancor count). Final bosses (Purgener) only come through K.final_pick.
    local pool, total = {}, 0
    for _, rf in ipairs(REINFORCEMENTS) do
        -- v1.9.66: per-event cap and alive cap (alive = tracked with HP > 0, plus swaps not yet spawned)
        local ev_n = event.by_key and event.by_key[rf.key] or 0
        local ev_ok = not rf.max_per_event or ev_n < (config[rf.key .. "_max_per_event"] or rf.max_per_event)
        local pend = (os.clock() - (rf.last_swap_t or -100) < 15) and 1 or 0   -- swapped but maybe not spawned yet
        local alive_ok = not rf.max_alive or (rf.alive_n or 0) + pend < rf.max_alive
        if rf.devour_only and not DEVOUR.active then alive_ok = false end
        if rf.regular_only and DEVOUR.active then alive_ok = false end   -- v1.9.99 (Golem), v1.9.123 (Medusa)
        if rf.final_boss or rf.off or rf.variant_of or rf.finale_only then alive_ok = false end   -- v1.9.141/144: variants and finale monsters have their own roll
        if rf.needs == "hydra" and not K.hydra_ready() then alive_ok = false end   -- v1.9.157: only with the Hydra files loaded
        local w = tonumber(config[rf.key .. "_chance"]) or 0
        if rf.key ~= "evil_eye" and w > 0 and ev_ok and alive_ok and (not flying_slot or rf.can_fly)
            and (wave.counts[rf.name] or 0) < (config[rf.key .. "_max_per_wave"] or 1) then
            pool[#pool + 1] = rf
            total = total + w
        end
    end
    if total <= 0 then return nil end
    -- dev test only: data/rr_dev_prefer.txt naming a reinforcement key makes it the pick whenever it is allowed
    if K.DEV_PREFER then for _, rf in ipairs(pool) do if rf.key == K.DEV_PREFER then return rf end end end
    local r = math.random() * total
    for _, rf in ipairs(pool) do
        r = r - (tonumber(config[rf.key .. "_chance"]) or 0)
        if r < 0 then return rf end
    end
    return pool[#pool]
end

-- v1.9.124 (user: spread the reinforcements evenly across Rancors): every Rancor gets about the same number of
-- reinforcements (one setting per kind of Rancor), spread over its big-enemy slots. Each slot's chance is
-- (reinforcements still to place) / (big-enemy slots still expected), so they neither bunch up in the first
-- waves nor run out: a Rancor with fewer slots than usual fills its last ones, a long one stops at the count.
function K.last_boss_node()
    local mgr = sdk.get_managed_singleton("app.AppraiseCycleManager")
    return mgr ~= nil and safe(function() return mgr:call("get_IsProcessingVoidLastBossNode") end) == true
end
-- v1.9.141 (user): a Rancor's own Skeleton Lord / Norgan Lich slot that did not get a reinforcement becomes its Brine
-- variant at the variant's chance. Same safeguards as the reinforcements: real Rancors only (gate in try_swap), never
-- in Satanica's event, never in the Rancor's last boss wave, and a copied spawn record rolls on its own.
function K.variant_for(cur_name)
    for _, rf in ipairs(REINFORCEMENTS) do
        if rf.variant_of and not rf.off and cur_name:sub(1, #rf.variant_of) == rf.variant_of then return rf end
    end
end
function K.variant_pick(cur_name)
    local rf = K.variant_for(cur_name)
    if not rf or not id_value[rf.id] then return nil end
    local p = tonumber(config[rf.key .. "_chance"]) or 0
    if p <= 0 or K.last_boss_node() then return nil end
    local roll = math.random()
    log(string.format("%s slot: %s (roll %.2f, chance %.0f%%)", cur_name, roll < p and ("becomes a " .. rf.name) or "stays as it is", roll, p * 100))
    if roll < p then return rf end
    return nil
end
function K.quota_pick(flying_slot)
    local kind, q = K.sync_kind()
    -- dev test only: rr_dev_prefer.txt = "evil_eye" puts the Evil Eye (with its minions) in the first big slot of a Rancor
    if K.DEV_PREFER == "evil_eye" then
        local eye = rf_by_key("evil_eye")
        if eye and id_value[eye.id] and event.eyes < (config.evil_eye_max_per_event or 1) then
            wave.eye_planned = true
            log("DEV: Evil Eye test - this big slot becomes the Evil Eye")
            return eye
        end
    end
    -- v1.9.181 dev test: rr_dev_prefer.txt naming a FINALE-ONLY reinforcement (drake / brine_sphinx / vermund) puts it
    -- in the next big slot of any Rancor (normally they only come through the Thimble's finale slot)
    if K.DEV_PREFER then
        local frf = rf_by_key(K.DEV_PREFER)
        if frf and frf.finale_only and not frf.off and id_value[frf.id]
            and ((event.by_key and event.by_key[frf.key]) or 0) < (config[frf.key .. "_max_per_event"] or frf.max_per_event or 1)
            and (frf.alive_n or 0) < (frf.max_alive or 1) then
            log("DEV: " .. frf.name .. " test - this big slot becomes the " .. frf.name .. " (normally a finale-only pick)")
            return frf
        end
    end
    -- v1.9.130 (user: "no final boss wave"): the Rancor's last boss wave stays the game's own. 17:52 a Virulent
    -- Rancor's last boss (a Lich) became our Nasty Dragon, so it looked like there was no final boss at all.
    -- (The ice-dragon / Devouring finale rolls are separate and still apply.)
    local mgr = sdk.get_managed_singleton("app.AppraiseCycleManager")
    if mgr and safe(function() return mgr:call("get_IsProcessingVoidLastBossNode") end) == true then
        log("Big-enemy slot in the Rancor's final boss wave - left to the game")
        return nil
    end
    local want = math.floor(tonumber(config["per_rancor_" .. kind]) or 0)
    local slots_left = math.max(1, (K.SLOTS_EXPECTED[kind] or 3) - q.seen)
    q.seen = q.seen + 1
    local left = want - q.used
    if left <= 0 then return nil end
    local p = math.min(1, left / slots_left)
    local roll = math.random()
    if roll >= p then
        log(string.format("Big-enemy slot %d of this %s Rancor left as it is (roll %.2f, chance %.0f%%; %d of %d reinforcements placed)",
            q.seen, kind, roll, p * 100, q.used, want))
        return nil
    end
    return pick_reinforcement(flying_slot)
end

-- v1.9.124: the Devouring Rancor's finale - the Rancorous Dragon Carcass, or Death - may go to the Purgener
-- (setting: its share of those finales; Satanica's finale is never touched). One roll per Rancor.
function K.final_pick(cur_name)
    if event.final_pick ~= nil then return nil end
    local pool = {}
    for _, rf in ipairs(REINFORCEMENTS) do
        if rf.final_boss and not rf.off and id_value[rf.id] and (config[rf.key .. "_max_per_event"] or 1) > 0 then pool[#pool + 1] = rf end
    end
    local share = tonumber(config.devour_final_share) or 0.33
    local roll = math.random()
    local rf = nil
    if K.DEV_FORCE_FINAL then   -- dev test API only
        rf = rf_by_key(K.DEV_FORCE_FINAL); roll = 0; K.DEV_FORCE_FINAL = nil
    elseif #pool > 0 and roll < share then
        rf = pool[math.random(#pool)]
    end
    if rf and not id_value[rf.id] then rf = nil end
    event.final_pick = rf and rf.key or ("the game's own " .. cur_name)
    log(string.format("Devouring final boss roll: %s -> %s (roll %.2f, Purgener share %.0f%%)", cur_name,
        rf and rf.name or "stays", roll, share * 100))
    return rf
end

local function is_minor(id)
    if not id then return false end
    for _, p in ipairs(K.MINOR_PREFIXES) do
        if id:sub(1, #p) == p then return true end
    end
    return false
end

-- v1.9.167 (user 13:02: "none of his little minions came in"; 13:08: its tentacles never come out in the arena and
-- it teleports without attacking): every Eye-family monster it brings out at runtime - its eyeball minions
-- (ch271000_00), its ground tentacles (ch272000-2_00) and the detached copies of its own tentacles (ch270011-14_00,
-- ch270021-32_00, its "tentacles into the ground" move) - had its prefab UNLOADED in the Rancor area (catalog ref
-- count 0, 13:06). The spawn requests went out (wave 2: 3x ch271000_00 + 1x ch272002_00; the Eye's own summon 5x
-- ch271000_00; 10 tentacle copies) and the game retried them for a few seconds, then gave up - nothing ever appeared.
-- With the tentacles gone, its ground-warp phase had nothing to attack with, so it only teleported. Loading the
-- prefab through the enemy catalog (addEnemyRefCount, ref 0 -> 1, ready at once) made a ch271000_00 request
-- loadable live. So: as soon as an Eye is swapped in (and every 10 s while one is alive), each of these with ref
-- count 0 gets one reference.
-- v1.9.168 (crash 13:17:35): the detached copies of its own tentacles (ch270011-32_00, its "tentacles into the
-- ground" move) crashed the game the moment one could load (ch270011_00 requested + Ch270Parts_WarpIn, then an
-- access violation). They are NOT loaded any more; that move is off for a Rancor Eye and their requests cancelled.
-- v1.9.169 (user 13:28: keep the move, make the tentacles come up inside the arena): loaded again - their warp
-- request is steered onto arena spots first (K.EYEPW below); a request we did not steer is still cancelled.
K.EYE_FAMILY = { "ch271000_00", "ch272000_00", "ch272001_00", "ch272002_00",
    "ch270011_00", "ch270012_00", "ch270013_00", "ch270014_00" }
for i = 21, 32 do K.EYE_FAMILY[#K.EYE_FAMILY + 1] = string.format("ch2700%d_00", i) end
K.EYE_PRE = { t = -100, n = 0 }
function K.eye_preload(why)
    local gen = sdk.get_managed_singleton("app.GenerateManager")
    local cat = gen and safe(function() return gen:get_field("_CatalogCtrl") end)
    local merged = cat and safe(function() return cat:get_field("_EnemyCatalog"):get_field("<MergedCatalog>k__BackingField") end)
    if not merged then return end
    K.EYE_PRE.t = os.clock()
    local added, failed = {}, 0
    for _, id in ipairs(K.EYE_FAMILY) do
        local v = id_value[id]
        if v and safe(function() return merged:call("ContainsKey", v) end) == true then
            local pc = safe(function() return merged:call("get_Item", v):get_field("_Item") end)
            local refn = pc and safe(function() return pc:get_field("_RefCount") end)
            if refn == 0 then
                if pcall(function() cat:call("addEnemyRefCount", v) end) then added[#added + 1] = id else failed = failed + 1 end
            end
        end
    end
    if #added > 0 or failed > 0 then
        K.EYE_PRE.n = K.EYE_PRE.n + 1
        if K.EYE_PRE.n <= 12 then
            log(string.format("Evil Eye summons loaded (%s): %d prefab(s) - %s%s", why, #added, table.concat(added, ", "),
                failed > 0 and string.format(" (%d failed)", failed) or ""))
        end
    end
end
local function plan_wave()
    if wave.eye_planned ~= nil then return end
    local eye = rf_by_key("evil_eye")
    wave.eye_planned = false   -- v1.9.183 (user 16:44): the Evil Eye is a Virulent finale pick only, never a wave slot
    if wave.eye_planned then
        log(string.format("Wave plan: Evil Eye + up to %d minions", config.evil_eye_minions))
    end
end

-- v1.9.175 (user 15:24: its tentacles / eyes were invisible with no collision, one up in the sky): the 40 m pull-in
-- moved them with the Teleporter (15:22:29 / :43 / :51 / 15:23:16) - like the Sphinx's body / model split, the
-- teleport left model + collision behind. Summons are never teleported now; instead the swapped spawn record itself
-- is pointed at a spot near you before the game creates it (eyes 8-16 m around you, 3 m up; ground tentacles
-- 6-14 m on your level), and the record's own position is put back with its enemy ID afterwards.
function K.place_summon(info, pick)
    local pp = player_upos()
    if not pp then return nil end
    local ci = safe(function() return info:get_field("_CommonInfo") end)
    local cur = ci and safe(function() return ci:get_field("_InitialPosition") end)
    local orig = cur and safe(function() return { x = cur:get_field("x"), y = cur:get_field("y"), z = cur:get_field("z") } end)
    if not orig then return nil end
    local flyer = pick == K.MINION_ID
    -- v1.9.176: on the ground around you (flyers 3-5 m above it), not at your height
    local g = flyer and K.ground_spot(pp, 8, 16, pp.y) or K.ground_spot(pp, 6, 14, pp.y)
    if not g then
        local a = math.random() * 2 * math.pi
        local r = flyer and 12 or 10
        g = { x = pp.x + math.cos(a) * r, y = pp.y, z = pp.z + math.sin(a) * r }
    end
    local gy = g.y + (flyer and (3 + math.random() * 2) or 0.2)
    local ok = pcall(function()
        local v = ValueType.new(POS_TD)
        v:set_field("x", g.x); v:set_field("y", gy); v:set_field("z", g.z)
        ci:set_field("_InitialPosition", v)
    end)
    if not ok then return nil end
    return orig, math.sqrt((pp.x - orig.x) ^ 2 + (pp.z - orig.z) ^ 2)
end
local function try_minion(info)
    local addr = info:get_address()
    if swapped_entries[addr] then return end
    if not K.rancor_gate() then return true end   -- v1.9.139
    local id_obj = safe(function() return info._CommonInfo._ObjectID end)
    local cur = id_obj and safe(function() return id_obj._SelectedCharacterID end)
    local cur_name = cur and id_name[cur]
    -- v1.9.135: a copy of a small slot we just turned into a minion / tentacle (19:17: one ghoul slot became NINE
    -- tentacle turrets - the game copies the record for each ghoul of the group). Put copies back to the original.
    -- v1.9.177 (user 15:51): while our Eye is alive every small Rancor enemy becomes one of its eyeball minions
    local swarm = config.eye_swarm and (event.eyes or 0) > 0 and K.eye_alive and K.eye_alive() and id_value[K.MINION_ID] ~= nil
    if swarm and (cur_name == "ch272002_00" or cur_name == K.MINION_ID) and os.clock() - (K.MINOR_SWAP_T or -100) < 5 then
        -- a copy of the slot we just swapped: in a swarm it stays an eyeball (a tentacle copy becomes one too)
        pcall(function() id_obj._SelectedCharacterID = id_value[K.MINION_ID] end)
        local pos_orig = K.place_summon(info, K.MINION_ID)
        swapped_entries[addr] = true
        pcall(function() info:add_ref() end)
        table.insert(pending_reverts, { info = info, addr = addr, original = K.MINOR_SWAP_ORIG or cur, pick = K.MINION_ID, at = os.clock(), pos_orig = pos_orig })
        event.minions = event.minions + 1
        K.SWARM_N = (K.SWARM_N or 0) + 1
        if K.SWARM_N <= 40 then log("Evil Eye swarm: a copy of the slot -> Evil Eye minion too") end
        return true
    end
    if (cur_name == "ch272002_00" or cur_name == K.MINION_ID) and os.clock() - (K.MINOR_SWAP_T or -100) < 5 and K.MINOR_SWAP_ORIG then
        local ok = pcall(function() id_obj._SelectedCharacterID = K.MINOR_SWAP_ORIG end)
        K.MINOR_COPIES = (K.MINOR_COPIES or 0) + 1
        if K.MINOR_COPIES <= 10 then log("Copy of a minion slot set back to " .. tostring(id_name[K.MINOR_SWAP_ORIG]) .. (ok and "" or " (failed)")) end
        return true
    end
    -- v1.9.138 (user: no ground tentacles): while our Evil Eye is up, Norgan soldiers and wisps can become its
    -- minions / tentacles too (in the 19:47 fight its waves had no ghoul or skeleton slots at all)
    local eye_slot = cur_name and (cur_name:sub(1, 9) == "ch230005_" or cur_name:sub(1, 9) == "ch225003_") and (event.eyes or 0) > 0
    if not is_minor(cur_name) and not eye_slot then return false end
    new_wave_if_needed(os.clock())
    plan_wave()
    -- v1.9.133 (user: none of its tentacle turrets came): small-enemy slots in LATER waves can become its minions /
    -- tentacles too while our Evil Eye is alive (before, only small slots in the Eye's own wave could - often none)
    local eye_up = false
    if not wave.eye_planned and (event.eyes or 0) > 0 then
        for _, t in pairs(K.TRACKED or {}) do
            if t.name and t.name:sub(1, #K.EYE_ID) == K.EYE_ID then
                local hp = safe(function() return t.chara:get_Hit():call("get_Hp") end)
                if hp and hp > 0 then eye_up = true; break end
            end
        end
    end
    if not wave.eye_planned and not eye_up and not swarm then return true end
    -- v1.9.63: tentacles (ch272002_00) alternate with the flying eyeball minions
    local TENT = "ch272002_00"
    local want_eye = (swarm or event.minions < config.evil_eye_minions + (event.minion_bonus or 0)) and id_value[K.MINION_ID] ~= nil
    local want_tent = event.tentacles < (config.evil_eye_tentacles or 0) and id_value[TENT] ~= nil
    if not want_eye and not want_tent then return true end
    local tent = want_tent and (not want_eye or event.tentacles <= event.minions)
    local pick = tent and TENT or K.MINION_ID
    local label = tent and "Evil Eye tentacle" or "Evil Eye minion"
    id_obj._SelectedCharacterID = id_value[pick]
    if safe(function() return info._CommonInfo._ObjectID._SelectedCharacterID end) ~= id_value[pick] then
        log(label .. " swap did not stick for " .. cur_name); return true
    end
    if tent then event.tentacles = event.tentacles + 1
    else wave.minions = wave.minions + 1; event.minions = event.minions + 1 end
    stats.swapped[label] = (stats.swapped[label] or 0) + 1
    swapped_entries[addr] = true
    pcall(function() info:add_ref() end)
    local pos_orig, was = K.place_summon(info, pick)   -- v1.9.175
    table.insert(pending_reverts, { info = info, addr = addr, original = cur, pick = pick, at = os.clock(), pos_orig = pos_orig })
    K.MINOR_SWAP_T, K.MINOR_SWAP_ORIG = os.clock(), cur
    log(string.format("Swapped minor %s -> %s%s", cur_name, label, pos_orig and string.format(" (placed near you; its spot was %.0f m away)", was or -1) or ""))
    if WAVES.cur then table.insert(WAVES.cur.swaps, tostring(cur_name) .. " -> " .. label) end
    return true
end

local function try_swap(info)
    local addr = info:get_address()
    if swapped_entries[addr] then
        -- v1.9.128: the same spawn record asked for again while it still holds our pick (17:16 a Lich slot spawned
        -- TWO Nasty Dragons; the second wasn't counted as ours, kept its own HP and its body never left).
        -- Count the extra one as ours so it is scaled, tracked and cleaned up like the first.
        local cur = safe(function() return info._CommonInfo._ObjectID._SelectedCharacterID end)
        for _, pr in ipairs(pending_reverts) do
            if pr.addr == addr and cur == id_value[pr.pick] then
                swaps_by_id[pr.pick] = (swaps_by_id[pr.pick] or 0) + 1
                swaps_pending = swaps_pending + 1
                log("The same slot spawns a second " .. pr.pick .. " - counting it as ours too")
                break
            end
        end
        return
    end
    local id_obj = safe(function() return info._CommonInfo._ObjectID end)
    local cur = id_obj and safe(function() return id_obj._SelectedCharacterID end)
    local cur_name = cur and id_name[cur]
    local major, flying_slot = major_info(cur_name)
    if not cur_name or cur_name == "Invalid" then return end
    if not K.rancor_gate() then return end   -- v1.9.139
    -- v1.9.130: a request already carrying one of our picks, right after we swapped that pick in: the game copied
    -- our swapped spawn record for a second spawn (17:52: a Lich slot made two Nasty Dragons again, the copy had
    -- a new address). Count it as ours, and put the copy back to the original enemy once it has spawned.
    do
        local orf = reinforcement_for(cur_name)
        if orf and os.clock() - (orf.last_swap_t or -100) < 5 then
            -- v1.9.141: a copied Skeleton Lord / Lich record (Liches come in pairs) rolls for the Brine variant on its own
            if orf.variant_of and math.random() < (tonumber(config[orf.key .. "_chance"]) or 0) then
                swaps_by_id[orf.id] = (swaps_by_id[orf.id] or 0) + 1
                swaps_pending = swaps_pending + 1
                orf.last_swap_t = os.clock()
                stats.swapped[orf.name] = (stats.swapped[orf.name] or 0) + 1
                log("A copy of the swapped spawn record (a pair) rolled its own " .. orf.name .. " too - counting it as ours")
                return
            end
            -- v1.9.131: put the copy back to the original enemy before it spawns - one reinforcement per slot
            -- (18:22 a Lich slot spawned TWO Evil Eyes; one ended up as the other's "guest" copy and took no damage)
            local orig
            for i = #pending_reverts, 1, -1 do if pending_reverts[i].pick == orf.id then orig = pending_reverts[i].original; break end end
            local ok = orig and pcall(function() info._CommonInfo._ObjectID._SelectedCharacterID = orig end)
            if ok and safe(function() return info._CommonInfo._ObjectID._SelectedCharacterID end) == orig then
                log("A copy of the swapped spawn record would spawn a second " .. orf.name .. " - set back to " .. tostring(id_name[orig]))
            else
                swaps_by_id[orf.id] = (swaps_by_id[orf.id] or 0) + 1
                swaps_pending = swaps_pending + 1
                log("A copy of the swapped spawn record spawns a second " .. orf.name .. " (could not set it back) - counting it as ours")
            end
            return
        end
    end
    K.sync_kind()   -- v1.9.124: the game's own word on which Rancor this is
    -- v1.9.105: the regular Rancor's final-wave boss, the ice dragon (ch257003_*): 50/50 with the Evil Eye
    local ice = cur_name:sub(1, 9) == "ch257003_"
    if ice then
        if DEVOUR.active then return end
        major, flying_slot = "Thimble (final boss)", true
    end
    -- v1.9.124: the Devouring finale (Rancorous Dragon Carcass / Death) - Death anywhere else is never touched
    local fin = false
    for _, p in ipairs(K.FINALE_PREFIXES) do if not major and cur_name:sub(1, #p) == p then fin = true end end
    if fin then
        if not DEVOUR.active then return end
        if cur_name:sub(1, 9) == "ch227003_" and not config.purgener_takes_death then return end
        major, flying_slot = "Devouring final boss", false
    end
    if not major then return end

    local now = os.clock()
    new_wave_if_needed(now)
    plan_wave()
    wave.slots = wave.slots + 1

    local rf
    if ice then
        -- v1.9.144 (user): the Thimble finale is a three-way roll - Evil Eye / Drake / the Thimble stays (sliders)
        -- v1.9.158 (user): in a VIRULENT Rancor the Brine Sphinx and the Vermund Purgener are finale options too
        local vir = K.KIND.kind == "virulent"
        local eye, drake = rf_by_key("evil_eye"), rf_by_key("drake")
        local sphinx, vermund = rf_by_key("brine_sphinx"), rf_by_key("vermund")
        -- v1.9.182 (user 16:36): the Evil Eye is a VIRULENT finale option only - never in a regular Rancor's finale
        local eshare = (vir and tonumber(config.vir_eye_final_share)) or 0
        local dshare = tonumber(vir and config.vir_drake_final_share or config.drake_final_share) or 0
        local sshare = vir and tonumber(config.vir_sphinx_final_share) or 0
        local vshare = vir and tonumber(config.vir_vermund_final_share) or 0
        -- v1.9.183 (user 16:44): the Brine Dullahan is a REGULAR Rancor finale option
        local dullahan = rf_by_key("brine_dullahan")
        local lshare = (not vir) and tonumber(config.reg_dullahan_final_share) or 0
        local function can(r)
            return r and not r.off and id_value[r.id]
                and ((event.by_key and event.by_key[r.key]) or 0) < (config[r.key .. "_max_per_event"] or r.max_per_event or 1)
                and (r.alive_n or 0) < (r.max_alive or 1)
        end
        local ecan = eye and id_value[eye.id] and event.eyes < config.evil_eye_max_per_event
        if not ecan then eshare = 0 end
        if not can(drake) then dshare = 0 end
        if not can(sphinx) then sshare = 0 end
        if not can(vermund) then vshare = 0 end
        if not can(dullahan) then lshare = 0 end
        local roll = math.random()
        if K.DEV_FORCE_EYE then roll = 0; K.DEV_FORCE_EYE = nil end   -- v1.9.122: dev test API only
        -- v1.9.183 (user 16:44): in a Virulent Rancor the Thimble never stays - the roll is spread over the options that
        -- are available (their shares keep their proportions); only when none is available does the Thimble stay
        local total = eshare + dshare + sshare + vshare + lshare
        if vir and config.vir_no_thimble and total > 0 and total < 1 then roll = roll * total end
        local pick = (roll < eshare and eye) or (roll < eshare + dshare and drake) or (roll < eshare + dshare + sshare and sphinx)
            or (roll < eshare + dshare + sshare + vshare and vermund) or (roll < total and dullahan) or nil
        -- v1.9.180: a forced pick (RR_DEV.force_finale or data/rr_dev_finale.txt) wins outright, whatever the shares
        local forced = K.DEV_FORCE_FINALE or K.DEV_FINALE_FILE
        if forced then
            K.DEV_FORCE_FINALE = nil
            local fr = ({ eye = ecan and eye or nil, drake = can(drake) and drake or nil, sphinx = can(sphinx) and sphinx or nil, vermund = can(vermund) and vermund or nil,
                dullahan = can(dullahan) and dullahan or nil })[forced]
            if fr then pick = fr; log("DEV: Thimble finale forced to " .. fr.name) else log("DEV: forced finale '" .. tostring(forced) .. "' is not available here - normal roll") end
        end
        log(string.format("Final boss roll (%s Rancor): %s -> %s (roll %.2f; %s)", vir and "Virulent" or "regular", cur_name,
            pick and pick.name:upper() or "the Thimble stays", roll,
            vir and string.format("Evil Eye %.0f%%, Drake %.0f%%, Brine Sphinx %.0f%%, Vermund Purgener %.0f%%%s", eshare * 100, dshare * 100, sshare * 100, vshare * 100,
                (config.vir_no_thimble and total > 0) and " - spread so the Thimble never stays" or "")
                or string.format("Drake %.0f%%, Brine Dullahan %.0f%%", dshare * 100, lshare * 100)))
        if not pick then return end
        if pick == eye then wave.eye_planned = true end   -- the Eye's minions can join this wave
        rf = pick
    elseif fin then
        rf = K.final_pick(cur_name)
    else
        rf = K.quota_pick(flying_slot)
        if not rf then rf = K.variant_pick(cur_name) end   -- v1.9.141
    end
    if TEST.armed and id_value[TEST.armed] then
        rf = { id = TEST.armed, key = "test_spawn", name = "TEST " .. TEST.armed }
        log("Test spawn: putting " .. TEST.armed .. " in place of " .. tostring(cur_name))
        TEST.armed = nil
    end
    if not rf or not id_value[rf.id] then return end

    id_obj._SelectedCharacterID = id_value[rf.id]
    if safe(function() return info._CommonInfo._ObjectID._SelectedCharacterID end) ~= id_value[rf.id] then
        log("Swap did not stick for " .. cur_name); return
    end
    if rf.id == K.EYE_ID then
        pcall(K.eye_preload, "Evil Eye swapped in")   -- v1.9.167
        -- v1.9.174 (user 13:41 wanted 5 minions with the Eye; creating them crashed the game 3 times): its first
        -- minions come from the very next small-enemy spawns (its wave and nearby) on top of the usual quota
        event.minion_bonus = (event.minion_bonus or 0) + (tonumber(config.eye_arrival_minions) or 5)
        log(string.format("Evil Eye arriving: the next %d small-enemy spawns near the arena become its minions / tentacles (plus the usual %d)",
            tonumber(config.eye_arrival_minions) or 5, config.evil_eye_minions))
    end
    -- v1.9.147 (user: a Devouring Lich slot spawned FOUR Nasty Dragons, 04:03): some slots are GROUPS - a parent
    -- record with child records that inherit the parent's enemy. Children of the swapped record are pointed back
    -- at the original enemy, so one swap means one reinforcement (the rest of the group stays the game's own).
    do
        local kids = safe(function() return info._Children end)
        local nk = kids and (safe(function() return kids:call("get_Count") end) or 0) or 0
        if nk > 0 then
            local fixed = 0
            for i = 0, nk - 1 do
                local kid = safe(function() return kids:call("get_Item", i) end)
                local kobj = kid and safe(function() return kid._CommonInfo._ObjectID end)
                local kcid = kobj and safe(function() return kobj._SelectedCharacterID end)
                if kobj and (kcid == nil or kcid == id_value[rf.id] or kcid == cur) then
                    if pcall(function() kobj._SelectedCharacterID = cur end) then fixed = fixed + 1 end
                end
            end
            log(string.format("The swapped record is a GROUP (%d children) - %d child slot(s) pointed back at %s", nk, fixed, tostring(cur_name)))
        end
    end
    wave.counts[rf.name] = (wave.counts[rf.name] or 0) + 1
    if rf.key == "evil_eye" then event.eyes = event.eyes + 1 end
    if not ice and not fin and rf.key ~= "test_spawn" and not rf.variant_of and event.q then event.q.used = event.q.used + 1 end   -- v1.9.124 (variants don't count, v1.9.141)
    if fin and cur_name:sub(1, 9) == "ch227003_" then
        event.death_sub = os.clock()
        log("The Purgener takes Death's place - when it falls, the Rancor counts Death as defeated")
    end
    if WAVES.cur then table.insert(WAVES.cur.swaps, tostring(cur_name) .. " -> " .. rf.name) end
    event.by_key = event.by_key or {}
    event.by_key[rf.key] = (event.by_key[rf.key] or 0) + 1
    rf.last_swap_t = os.clock()
    local scale_orig = nil
    if rf.scale_key and tonumber(config[rf.scale_key]) then
        -- v1.9.91: size via the spawn record's ScaleRate (the game's own per-monster size variation)
        scale_orig = safe(function() return info._StatusInfo["<ScaleRate>k__BackingField"] end)
        local oks = pcall(function() info._StatusInfo["<ScaleRate>k__BackingField"] = tonumber(config[rf.scale_key]) end)
        log(string.format("%s size: ScaleRate %s -> %.2f%s", rf.name, tostring(scale_orig), tonumber(config[rf.scale_key]), oks and "" or " (could not set)"))
    end
    stats.swapped[rf.name] = (stats.swapped[rf.name] or 0) + 1
    swapped_entries[addr] = true
    pcall(function() info:add_ref() end)
    table.insert(pending_reverts, { info = info, addr = addr, original = cur, pick = rf.id, at = now, scale_orig = scale_orig })
    swaps_pending = swaps_pending + 1
    swaps_by_id[rf.id] = (swaps_by_id[rf.id] or 0) + 1
    last_swap_time = now
    log(string.format("Swapped major %s (%s) -> %s", major, cur_name, rf.name))
end

-- v1.9.124: in the Devouring Rancor's Death finale the rest of the event waits for "Death defeated"
-- (app.appraiseCycle.condition.DefeatCh227003Condition). When the Purgener took Death's place, that check
-- follows the Purgener: once it has been seen alive and is down (or 90 s passed and it never showed up),
-- the check passes, exactly as if Death had been beaten.
do
    local td = sdk.find_type_definition("app.appraiseCycle.condition.DefeatCh227003Condition")
    local m = td and td:get_method("evaluateImpl")
    if m then
        local ok = pcall(sdk.hook, m, nil, function(retval)
            local t0 = event.death_sub
            if not t0 then return retval end
            if retval ~= nil and (sdk.to_int64(retval) & 0xFF) ~= 0 then return retval end
            local prf = rf_by_key("purgener")
            local alive = prf and (prf.alive_n or 0) > 0
            if alive then event.death_sub_alive = true; return retval end
            local now = os.clock()
            if now - t0 < 20 or (not event.death_sub_alive and now - t0 < 90) then return retval end
            if not event.death_sub_done then
                event.death_sub_done = true
                log("The Purgener in Death's place is down - the Rancor now counts Death as defeated")
            end
            return sdk.to_ptr(1)
        end)
        if not ok then log("Could not hook the Rancor's Death-defeated check") end
    end
end

local function revert_swaps(force_all)
    local now = os.clock()
    for i = #pending_reverts, 1, -1 do
        local r = pending_reverts[i]
        if force_all or r.spawned or now - r.at > (r.hold or 15) then
            local ok = pcall(function() r.info._CommonInfo._ObjectID._SelectedCharacterID = r.original end)
            if r.scale_orig then pcall(function() r.info._StatusInfo["<ScaleRate>k__BackingField"] = r.scale_orig end) end
            if r.pos_orig then pcall(function()   -- v1.9.175
                local v = ValueType.new(POS_TD)
                v:set_field("x", r.pos_orig.x); v:set_field("y", r.pos_orig.y); v:set_field("z", r.pos_orig.z)
                r.info:get_field("_CommonInfo"):set_field("_InitialPosition", v)
            end) end
            log(string.format("Restored spawn entry to %s%s", tostring(id_name[r.original]), ok and "" or " (failed)"))
            swapped_entries[r.addr] = nil
            table.remove(pending_reverts, i)
        end
    end
end

-- v1.9.122: defined before TEST.tick uses it (the harness found it was read as a nil global there)
local function mark_spawned(name)
    for _, r in ipairs(pending_reverts) do
        if not r.spawned and name:sub(1, #r.pick) == r.pick then r.spawned = true; return end
    end
end

-- v1.9.71: "spawn in front of me" - take over the game's next ordinary monster spawn, give it the
-- test ID, then teleport the new monster in front of the player
function TEST.take(info, cname)
    local want = TEST.here
    TEST.here = nil
    info._CommonInfo._ObjectID._SelectedCharacterID = id_value[want]
    if safe(function() return info._CommonInfo._ObjectID._SelectedCharacterID end) ~= id_value[want] then
        log("Test spawn: could not take over the spawn of " .. cname); TEST.here = want; return
    end
    local addr = info:get_address()
    swapped_entries[addr] = true
    pcall(function() info:add_ref() end)
    table.insert(pending_reverts, { info = info, addr = addr, original = id_value[cname], pick = want, at = os.clock(), hold = 90 })
    local known = {}
    for _, m in ipairs(find_components("app.Monster")) do
        local go = safe(function() return m:call("get_GameObject") end)
        if go then known[go:get_address()] = true end
    end
    TEST.waiting = { id = want, t = os.clock(), known = known, last = 0 }
    log("Test spawn: the game's next spawn (" .. cname .. ") becomes " .. want .. " - it will be moved in front of you")
end
function TEST.tick()
    local w = TEST.waiting
    local now = os.clock()
    if not w or now - w.last < 0.5 then return end
    w.last = now
    if now - w.t > 120 then
        log("Test spawn: " .. w.id .. " never appeared within 2 minutes (it may not be able to load here)")
        TEST.waiting = nil
        return
    end
    for _, m in ipairs(find_components("app.Monster")) do
        local go = safe(function() return m:call("get_GameObject") end)
        local name = go and safe(function() return go:call("get_Name") end)
        if name and name:sub(1, #w.id) == w.id and not w.known[go:get_address()] then
            TEST.waiting = nil
            mark_spawned(name)
            local chara = safe(function() return go:call("getComponent(System.Type)", sdk.typeof("app.Character")) end)
            local tp = chara and safe(function() return chara:get_field("Teleporter") end)
            local cm = sdk.get_managed_singleton("app.CharacterManager")
            local ptr = cm and safe(function() return cm["<ManualPlayer>k__BackingField"]:get_Transform() end)
            local pp = player_upos()
            local fw = ptr and safe(function() return ptr:call("get_AxisZ") end)
            local fx, fz = fw and fw.x or 0, fw and fw.z or 1
            local fl = math.sqrt(fx * fx + fz * fz); if fl < 0.01 then fx, fz, fl = 0, 1, 1 end
            local hp = chara and safe(function() return chara:get_Hit():call("get_Hp") end)
            local placed = false
            if TEST.no_move then
                TEST.no_move = nil
                log(string.format("Test spawn: %s appeared (HP %s) - left in place (fragile model)", name, tostring(hp)))
                return
            end
            if tp and pp and TELEPORT_M then
                local tx, ty, tz = pp.x + fx / fl * 12, pp.y + 1, pp.z + fz / fl * 12
                local styles = {
                    function() local v = ValueType.new(POS_TD); v:set_field("x", tx); v:set_field("y", ty); v:set_field("z", tz); return v end,
                    function() return Vector3f.new(tx, ty, tz) end,
                }
                for _, make in ipairs(styles) do
                    if not placed then placed = pcall(function() TELEPORT_M:call(tp, make()) end) end
                end
            end
            log(string.format("Test spawn: %s appeared (HP %s)%s", name, tostring(hp),
                placed and " - moved 12 m in front of you" or " - could not move it (no Teleporter); it is where the game put it"))
            return
        end
    end
end


local tracked_sub = {}      -- sub-object address -> { name = go name, since = clock }
local last_eye_seen = -100   -- clock when a mod-spawned Evil Eye was last seen alive
local hooked = 0
do
    local td = sdk.find_type_definition("app.GenerateManager")
    for _, m in ipairs(td and td:get_methods() or {}) do
        if m:get_name() == "requestGenerate" then
            local nparams = m:get_num_params()
            local ret_void = safe(function() return m:get_return_type():get_full_name() end) == "System.Void"
            -- v1.9.56: only the GenerateInfoContainer argument is read as an object; callback args are
            -- only checked for null (flags / bools / ints must never be turned into objects)
            local info_i, cb_is = nil, {}
            for i, pt in ipairs(safe(function() return m:get_param_types() end) or {}) do
                local ptn = safe(function() return pt:get_full_name() end) or ""
                if ptn:find("GenerateInfoContainer", 1, true) and not info_i then info_i = i
                elseif ptn:find("PrefabInstantiateResults", 1, true) then table.insert(cb_is, i) end
            end
            local ok = pcall(sdk.hook, m, function(args)
                if not config.enabled then return end
                if TEST.here and info_i then
                    local tinfo = safe(function() return sdk.to_managed_object(args[info_i + 2]) end)
                    local tcid = tinfo and safe(function() return tinfo._CommonInfo._ObjectID._SelectedCharacterID end)
                    local tname = tcid and id_name[tcid]
                    if tname and tname:match("^ch2%d%d") and tname:sub(1, #SATANICA.prefix) ~= SATANICA.prefix
                        and not reinforcement_for(tname) and not swapped_entries[tinfo:get_address()] then
                        local okT, errT = pcall(TEST.take, tinfo, tname)
                        if not okT then log("Test spawn error: " .. tostring(errT)) end
                        return
                    end
                end
                if config.require_vortex and not vortex_now then return end
                local info, has_callback = nil, false
                if info_i then info = safe(function() return sdk.to_managed_object(args[info_i + 2]) end) end
                for _, ci in ipairs(cb_is) do
                    local pv = safe(function() return sdk.to_int64(args[ci + 2]) end)
                    if pv and pv ~= 0 then has_callback = true end
                end
                -- wave spawns carry a completion callback; ambient world spawns do not
                if info and has_callback then
                    local tnow = os.clock()
                    local wcid = safe(function() return info._CommonInfo._ObjectID._SelectedCharacterID end)
                    local wname = wcid and id_name[wcid]
                    -- v1.9.146: a dead Eye's queued summons are orphans - cancel them before they pop in
                    local okO, isO = pcall(K.eye_orphan, wname)
                    if wname and okO and isO then
                        local inv = id_value["Invalid"]
                        if inv and pcall(function() info._CommonInfo._ObjectID._SelectedCharacterID = inv end) then
                            K.ORPHANS = (K.ORPHANS or 0) + 1
                            if K.ORPHANS <= 12 then log("Evil Eye is gone - its queued summon (" .. wname .. ") cancelled") end
                            return
                        end
                    end
                    if wname and wname:sub(1, #SATANICA.prefix) == SATANICA.prefix then
                        SATANICA.until_t, SATANICA.seen_t = tnow + 600, -1
                        log("Satanica is coming (" .. wname .. ") - the mod leaves his event and its spawns alone")
                    end
                    if wname and wname ~= "Invalid" and vortex_now then pcall(WAVES.note, wname, tnow) end
                    if SATANICA.active(tnow) then
                        SATANICA.logged = SATANICA.logged + 1
                        if SATANICA.logged <= 30 and not (wname and wname:sub(1, #SATANICA.prefix) == SATANICA.prefix) then
                            log("Satanica event: not touching " .. tostring(wname))
                        end
                        return
                    end
                    if wname and (major_info(wname) or is_minor(wname)) then
                        if tnow - wave_req_last > 60 then wave_fight_start = tnow end
                        wave_req_last = tnow
                    end
                    -- v1.9.179 (user 16:12: "more eye minions without breaking something else"): the Eye's OWN summon move
                    -- asks for 5 eyeballs with a callback (logged as "WAVE: 5x ch271000_00" at 16:04:02 / 16:06:10) - but
                    -- those requests are RequestType Field too, which the Rancor drops (v1.9.178 only fixed the
                    -- no-callback ones). Now they get VoidArea as well and come out on the ground around you.
                    if wname and wname:sub(1, 6) == "ch2710" and (event.eyes or 0) > 0 and K.eye_alive and K.eye_alive()
                        and not swapped_entries[info:get_address()] then
                        local rt = safe(function() return info._CommonInfo._RequestType end)
                        if rt == 1 then
                            pcall(function() info._CommonInfo._RequestType = 64 end)
                            pcall(K.place_summon, info, K.MINION_ID)
                            K.SUMMONFIX = (K.SUMMONFIX or 0) + 1
                            if K.SUMMONFIX <= 40 then log("Evil Eye's own summon (" .. wname .. "): Field -> VoidArea, placed near you") end
                        end
                        return
                    end
                    local ok1, handled = pcall(try_minion, info)
                    if not ok1 then log("Minion swap error: " .. tostring(handled)) end
                    if not (ok1 and handled) then
                        local ok2, err = pcall(try_swap, info)
                        if not ok2 then log("Swap error: " .. tostring(err)) end
                    end
                elseif info and vortex_now then
                    -- no callback during a vortex: Evil Eye re-queued as a world spawn (its "teleport"),
                    -- or its own mid-fight summon requests (which the Rancor area never fulfils)
                    local cid = safe(function() return info._CommonInfo._ObjectID._SelectedCharacterID end)
                    local cname = cid and id_name[cid]
                    -- v1.9.146: orphaned Eye summons (no living Eye any more) are cancelled here too
                    local okO2, isO2 = pcall(K.eye_orphan, cname)
                    if cname and okO2 and isO2 then
                        local inv0 = id_value["Invalid"]
                        if inv0 and pcall(function() info._CommonInfo._ObjectID._SelectedCharacterID = inv0 end) then
                            K.ORPHANS = (K.ORPHANS or 0) + 1
                            if K.ORPHANS <= 12 then log("Evil Eye is gone - its queued summon (" .. cname .. ") cancelled") end
                            return
                        end
                    end
                    -- v1.9.168: a detached copy of the Eye's own tentacles (ch270011_00 .. ch270032_00) crashed the game
                    -- (13:17:35) - while our Eye is in the fight these requests are cancelled
                    if cname and cname:match("^ch2700[1-3]%d_00$") and (event.eyes or 0) > 0
                        and not (config.eye_parts_arena and os.clock() < (K.EYEPW and K.EYEPW.ok_until or -1)) then
                        local inv1 = id_value["Invalid"]
                        if inv1 and pcall(function() info._CommonInfo._ObjectID._SelectedCharacterID = inv1 end) then
                            K.EYE_DETACH = (K.EYE_DETACH or 0) + 1
                            if K.EYE_DETACH <= 10 then log("Evil Eye: detached tentacle request (" .. cname .. ") cancelled - its warp was not steered into the arena") end
                            return
                        end
                    end
                    -- v1.9.167: one ambient fodder record swapped to a tentacle came back as TEN tentacle requests
                    -- (12:59:29, a group of 10) - now that they can load, the copies go back to the original fodder
                    if cname and (cname == "ch272002_00" or cname == K.MINION_ID) and K.AMB_SWAP_T and os.clock() - K.AMB_SWAP_T < 2
                        and K.AMB_SWAP_ORIG and not swapped_entries[info:get_address()] and config.eye_swarm and K.eye_alive and K.eye_alive() then
                        -- v1.9.177 swarm: the copies are eyeballs too, placed near you
                        pcall(function() info._CommonInfo._ObjectID._SelectedCharacterID = id_value[K.MINION_ID] end)
                        local pos_orig = K.place_summon(info, K.MINION_ID)
                        swapped_entries[info:get_address()] = true
                        pcall(function() info:add_ref() end)
                        table.insert(pending_reverts, { info = info, addr = info:get_address(), original = K.AMB_SWAP_ORIG, pick = K.MINION_ID, at = os.clock(), pos_orig = pos_orig })
                        event.minions = event.minions + 1
                        return
                    end
                    if cname and (cname == "ch272002_00" or cname == K.MINION_ID) and K.AMB_SWAP_T and os.clock() - K.AMB_SWAP_T < 2
                        and K.AMB_SWAP_ORIG and not swapped_entries[info:get_address()] then
                        local okb = pcall(function() info._CommonInfo._ObjectID._SelectedCharacterID = K.AMB_SWAP_ORIG end)
                        K.AMB_COPIES = (K.AMB_COPIES or 0) + 1
                        if K.AMB_COPIES <= 10 then log("Copy of an ambient minion request set back to " .. tostring(id_name[K.AMB_SWAP_ORIG]) .. (okb and "" or " (failed)")) end
                        return
                    end
                    -- v1.9.146 (user: the Eye doesn't consistently get its minions): while our Eye is ALIVE, ambient
                    -- fodder spawning near the arena (03:48: 15x ch221006 twice, never used) fills the unfilled
                    -- minion / tentacle quota - same records, same copy-guard, same restore as the wave minors
                    if cname and K.rancor_gate() and (event.eyes or 0) > 0 and K.eye_alive() and not swapped_entries[info:get_address()] then
                        local fod = cname:sub(1, 9) == "ch231000_" or cname:sub(1, 10) == "ch226002_6" or cname:sub(1, 9) == "ch221006_"
                        local want_eye = (config.eye_swarm or event.minions < config.evil_eye_minions + (event.minion_bonus or 0)) and id_value[K.MINION_ID] ~= nil
                        local want_tent = event.tentacles < (config.evil_eye_tentacles or 0) and id_value["ch272002_00"] ~= nil
                        if fod and (want_eye or want_tent) then
                            local ip = safe(function() return info._CommonInfo._InitialPosition end)
                            local ix = ip and (tonumber(safe(function() return ip.x end)) or tonumber(safe(function() return ip:get_field("x") end)))
                            local iz = ip and (tonumber(safe(function() return ip.z end)) or tonumber(safe(function() return ip:get_field("z") end)))
                            local c0 = arena_center or vortex_center
                            -- position unreadable -> treat as near (in-game the container always carries it)
                            local near = (not ix or not iz or not c0) or math.sqrt((ix - c0.x) ^ 2 + (iz - c0.z) ^ 2) < 60
                            if near then
                                local tent = want_tent and (not want_eye or event.tentacles <= event.minions)
                                local pick = tent and "ch272002_00" or K.MINION_ID
                                local okc = pcall(function() info._CommonInfo._ObjectID._SelectedCharacterID = id_value[pick] end)
                                if okc and safe(function() return info._CommonInfo._ObjectID._SelectedCharacterID end) == id_value[pick] then
                                    if tent then event.tentacles = event.tentacles + 1 else event.minions = event.minions + 1 end
                                    local lab = tent and "Evil Eye tentacle" or "Evil Eye minion"
                                    stats.swapped[lab] = (stats.swapped[lab] or 0) + 1
                                    swapped_entries[info:get_address()] = true
                                    pcall(function() info:add_ref() end)
                                    local pos_orig = K.place_summon(info, pick)   -- v1.9.175
                                    table.insert(pending_reverts, { info = info, addr = info:get_address(), original = cid, pick = pick, at = os.clock(), pos_orig = pos_orig })
                                    K.MINOR_SWAP_T, K.MINOR_SWAP_ORIG = os.clock(), cid
                                    K.AMB_SWAP_T, K.AMB_SWAP_ORIG = os.clock(), cid   -- v1.9.167: its copies go back below
                                    log(string.format("Ambient fodder near the arena (%s) -> %s (the Eye is missing its summons)", cname, lab))
                                    if WAVES.cur then table.insert(WAVES.cur.swaps, tostring(cname) .. " -> " .. lab) end
                                end
                            end
                        end
                    end
                    if cname == K.EYE_ID and os.clock() - last_eye_seen < 5 then
                        -- a mod-spawned Evil Eye was just removed at wave end and is being re-queued
                        -- as a normal world monster; point the request at "Invalid" so nothing spawns
                        local inv = id_value["Invalid"]
                        local ok3 = inv and pcall(function() info._CommonInfo._ObjectID._SelectedCharacterID = inv end)
                        log("Evil Eye re-queued as world spawn -> " .. (ok3 and "cancelled" or "could not cancel"))
                    elseif cname and cname:find("^ch27") then
                        -- v1.9.178 (user 15:54, screenshot: its tentacles gone from its body but nowhere in the Rancor): the
                        -- Eye's OWN spawn requests (tentacle copies ch2700xx_00, its summoned ch271000_00, ground tentacles)
                        -- carry RequestType Field (1) - and during a Rancor every generator category has Field DISABLED
                        -- (GenerateExecuteDistributor._DisableReqeustType = {1}, 15:58). They sat in the queue and expired.
                        -- The Rancor's own wave spawns use VoidArea (64): the Eye's requests get that too, so the game
                        -- creates them itself and the Eye links them as usual.
                        if (event.eyes or 0) > 0 and cname:match("^ch27[012]") then
                            local rt = safe(function() return info._CommonInfo._RequestType end)
                            if rt == 1 then
                                local okr = pcall(function() info._CommonInfo._RequestType = 64 end)
                                K.VOIDFIX = (K.VOIDFIX or 0) + 1
                                if K.VOIDFIX <= 40 then log("Evil Eye spawn request " .. cname .. ": Field -> VoidArea (Rancor spawns are VoidArea only)" .. (okr and "" or " - FAILED")) end
                            end
                        end
                        log("ch27 spawn request without wave callback: " .. cname)
                        if K.DEV_GENRES and K.GENRES then pcall(K.GENRES.note, info, cname) end   -- v1.9.171 dev
                    end
                end
            end, nil)
            if ok then hooked = hooked + 1 end
        end
    end
end

-- Evil Eye research hooks + teleport/escape blocking -------------------------------------
-- Every method of these types is hooked (except getters/updates). Calls are only acted on
-- when they belong to a reinforcement this mod spawned (matched by the sub-object address).
K.RESEARCH_TYPES = {
    { "app.Teleporter",                  "Teleporter" },
    { "app.EscapeController",            "EscapeCtrl" },
    { "app.EscapePositionSearchController", "EscapePointSearchCtrl" },
    { "app.SummonController",            "SummonCtrl" },
    { "app.Ch27FlightControl`1<app.Ch270>", "<FlightCtrl>k__BackingField" },
    { "app.AbyssAreaProcessor",          "<AbyssAreaProcessor>k__BackingField" },
    { "app.Ch270000",                    "@component" },
    { "app.Ch270",                       "@ch2" },
}
-- v1.4: only these methods are hooked (log only). Everything else is listed in the dump file.
K.WATCH = {
    ["app.Teleporter"] = { teleport = true },
    ["app.EscapeController"] = { requestEscape = true },
    ["app.Ch270"] = { startWarpAction = true, onFailWarp = true, onWarpAppear = true, onSwitchToGuest = true },
}
local deferred = {}   -- actions to run on the next frame (never inside a game hook)
K.BLOCK_WORDS = { "warp", "telep", "escape", "vanish", "disappear", "flee" }
K.NO_BLOCK_WORDS = { "cancel", "end", "finish", "reset", "clear", "init", "release", "stop", "search" }
local call_counts = {}
local research_hooks = 0
K.METHODS_FILE = "RancorReinforcements_evileye_methods.txt"

local function has_word(s, words)
    for _, w in ipairs(words) do if s:find(w, 1, true) then return true end end
    return false
end

do
    local dump = {}
    for _, entry in ipairs(K.RESEARCH_TYPES) do
        local tn = entry[1]
        local td = sdk.find_type_definition(tn)
        table.insert(dump, "== " .. tn .. (td and "" or "  (type not found)"))
        for _, m in ipairs(td and safe(function() return td:get_methods() end) or {}) do
            local name = m:get_name()
            local ptypes = {}
            for _, p in ipairs(safe(function() return m:get_param_types() end) or {}) do
                table.insert(ptypes, safe(function() return p:get_full_name() end) or "?")
            end
            local ret = safe(function() return m:get_return_type():get_full_name() end) or "?"
            local lower = name:lower()
            local is_static = safe(function() return m:is_static() end)
            local skip = is_static or not (K.WATCH[tn] and K.WATCH[tn][name])
            table.insert(dump, string.format("  %s(%s) -> %s%s", name, table.concat(ptypes, ", "), ret,
                skip and "" or "  [watched]"))
            if not skip then
                local key = tn .. "." .. name
                local ok = pcall(sdk.hook, m, function(args)
                    local this = safe(function() return sdk.to_int64(args[2]) end)
                    local t = this and tracked_sub[this]
                    if not t then return end
                    call_counts[key] = (call_counts[key] or 0) + 1
                    if call_counts[key] <= 10 then log("call " .. key .. " on " .. t.name) end
                    if name == "onWarpAppear" then K.EYE_APPEAR = K.EYE_APPEAR or {}; K.EYE_APPEAR[t.name] = os.clock() end
                    if name == "teleport" and t.type == "app.Teleporter" and not recalling
                        and config.eye_redirect_warp and t.name:sub(1, #K.EYE_ID) == K.EYE_ID then
                        -- the warp destination body was just sent somewhere; check it next frames
                        table.insert(deferred, { kind = "recall", t = t, until_t = os.clock() + 4, t0 = os.clock() })
                    end
                end, nil)
                if ok then research_hooks = research_hooks + 1 end
            end
        end
    end
    -- GenerateManager destroy/cancel signatures (for leftover cleanup)
    local gtd = sdk.find_type_definition("app.GenerateManager")
    table.insert(dump, "== app.GenerateManager (destroy/cancel/die)")
    for _, m in ipairs(gtd and gtd:get_methods() or {}) do
        local lower = m:get_name():lower()
        if lower:find("destroy") or lower:find("cancel") or lower:find("die") or lower:find("delete") then
            local ptypes = {}
            for _, p in ipairs(safe(function() return m:get_param_types() end) or {}) do
                table.insert(ptypes, safe(function() return p:get_full_name() end) or "?")
            end
            table.insert(dump, string.format("  %s(%s)", m:get_name(), table.concat(ptypes, ", ")))
        end
    end
    pcall(fs.write, K.METHODS_FILE, table.concat(dump, "\n"))
end

local function track_subobjects(go, chara, name)
    local now = os.clock()
    for _, entry in ipairs(K.RESEARCH_TYPES) do
        local field, obj = entry[2], nil
        if field == "@component" then
            obj = safe(function() return go:call("getComponent(System.Type)", sdk.typeof(entry[1])) end)
        elseif field == "@ch2" then
            obj = safe(function() return chara.EnemyCtrl.Ch2 end)
        else
            obj = safe(function() return chara:get_field(field) end)
        end
        local addr = obj and safe(function() return obj:get_address() end)
        if addr then tracked_sub[addr] = { name = name, since = now, obj = obj, go = go, type = entry[1] } end
    end
end

-- Leftover cleanup: use the game's own destroy request so it also cancels re-generation.
local destroy_methods = {}
do
    local gtd = sdk.find_type_definition("app.GenerateManager")
    for _, wanted in ipairs({ "requestDestroyAndCancelGenerate", "requestDestroy" }) do
        for _, m in ipairs(gtd and gtd:get_methods() or {}) do
            if m:get_name() == wanted and m:get_num_params() == 1 and not safe(function() return m:is_static() end) then
                local p1 = safe(function() return m:get_param_types()[1]:get_full_name() end)
                if p1 == "via.GameObject" or p1 == "app.Character" then
                    table.insert(destroy_methods, { m = m, name = wanted, p1 = p1 })
                end
            end
        end
    end
end

local function remove_monster(go, chara, name, why)
    local gm = sdk.get_managed_singleton("app.GenerateManager")
    if not gm then log("Cleanup: no GenerateManager"); return false end
    for _, d in ipairs(destroy_methods) do
        local arg = (d.p1 == "via.GameObject") and go or chara
        local ok, err = pcall(function() d.m:call(gm, arg) end)
        log(string.format("Cleanup (%s): %s(%s) on %s -> %s", why, d.name, d.p1, name, ok and "ok" or tostring(err)))
        if ok then return true end
    end
    log("Cleanup: no usable destroy method for " .. name .. " (see " .. K.METHODS_FILE .. ")")
    return false
end

-- Medusa support (v1.8) -----------------------------------------------------------------
-- Root cause (think-table dump 2026-10-12): Medusa's AI (ch255000Think.user) picks every
-- combat move by first asking her waypoint controller for a nearby "battle position" from
-- her lair's waypoint network (battle / magic / petrification spots). Rancor arenas have no
-- such network, so every search fails and her main combat table falls through to "wait".
-- Fix: for Medusas spawned by this mod, a failed search is answered with a spot near the
-- player. The attacks themselves already check range against the player.
-- Also carried over from v0.20 (proven to ground her and get her into combat):
-- startup values of a mobile world Medusa, battle stance without her lair's fixed point,
-- delayed snake-body switch, combat-state push and retarget onto the player.
K.MEDUSA_ID = "ch255000_01"
local medusa = {}              -- go addr -> entry
local medusa_ever = {}         -- go addr -> true for every Medusa this mod has claimed
local medusa_by_beads = {}     -- CharacterBeadsModelCtrl addr -> entry
local medusa_by_ctrl = {}      -- Ch255BattleWayPointCtrl addr -> entry
-- v1.9.107: shorter petrify beams. Her think rows set the beam's irradiation time through
-- EmThkActCh255000PetrificationIrradiationTime (1500 / 360 / 400 in her table). For a Rancor Medusa the value is
-- scaled by medusa_petrify_len for that one call and put back right after (the table is shared with world Medusas).
K.PETRI = { orig = {}, n = 0 }
local medusa_by_module = {}    -- ThinkTableModule addr -> entry
do
    local td = sdk.find_type_definition("app.EmThkActCh255000PetrificationIrradiationTime")
    local m = td and td:get_method("action")
    if m then
        pcall(sdk.hook, m, function(args)
            local st = thread.get_hook_storage()
            st["rr_petri"] = nil
            local mul = tonumber(config.medusa_petrify_len) or 1
            if not config.enabled or math.abs(mul - 1) < 0.01 then return end
            local e = medusa_by_module[sdk.to_int64(args[3])]
            if not e or e.hydra then return end
            local act = safe(function() return sdk.to_managed_object(args[2]) end)
            if not act then return end
            local a = act:get_address()
            local orig = K.PETRI.orig[a]
            if not orig then
                orig = safe(function() return act:get_field("OverwritePetrificationIrradiationTimer") end)
                if type(orig) ~= "number" then return end
                K.PETRI.orig[a] = orig
            end
            if pcall(function() act:set_field("OverwritePetrificationIrradiationTimer", orig * mul) end) then
                st["rr_petri"] = { act = act, orig = orig }
                K.PETRI.n = K.PETRI.n + 1
                if K.PETRI.n <= 20 then log(string.format("Medusa petrify beam: %.0f -> %.0f (x%.2f)", orig, orig * mul, mul)) end
            end
        end, function(retval)
            local st = thread.get_hook_storage()
            local c = st and st["rr_petri"]
            if c then
                st["rr_petri"] = nil
                pcall(function() c.act:set_field("OverwritePetrificationIrradiationTimer", c.orig) end)   -- world Medusas keep theirs
            end
            return retval
        end)
    end
end
K.FIND_OK = { [1] = true, [2] = true, [3] = true, [5] = true, [64] = true, [128] = true }
local PILLAR_AI = { last_try = -1000 }   -- arena pillar for Medusa's AI: pos (world), go, comp, t (spawn clock)

-- v1.9.7 decision funnel (log only): one line per think pass - rows checked, pass/fail, conditions
local frame_no = 0
local fn_lbl, fn_tbl, fn_uq = {}, {}, {}   -- caches by object address
local uq_seen = { Ch255EnableChangeMoveAction = true, Ch255RequestUpperAction = true }  -- + any seen on her rows
local function fn_short(str, n)
    if type(str) ~= "string" then return "?" end
    local ok, len = pcall(utf8.len, str)
    if ok and len and len > n then
        local cut = utf8.offset(str, n + 1)
        if cut then return str:sub(1, cut - 1) .. "~" end
    end
    return str
end
local function funnel_flush(e)
    local b = e.fb
    e.fb, e.f_cur = nil, nil
    if not b or #b.items == 0 then return end
    local line = table.concat(b.items, " | ")
    local sig = line:gsub("[%d%.%-]+", "")
    local now = os.clock()
    if sig == e.f_sig and now - (e.f_sig_t or 0) < 10 then e.f_dupes = (e.f_dupes or 0) + 1; return end
    local rep = (e.f_dupes or 0) > 0 and string.format(" (previous pattern x%d more)", e.f_dupes) or ""
    e.f_sig, e.f_sig_t, e.f_dupes = sig, now, 0
    e.f_lines = (e.f_lines or 0) + 1
    if e.f_lines <= 220 then
        log(string.format("%s pass%s: %s", b.prefix, rep, line))
    elseif e.f_lines == 221 then
        log(b.prefix .. " pass: (funnel log cap reached for this Medusa)")
    end
end
local function funnel_row_begin(e, prefix, tname, label, flags)
    if e.quiet then e.f_cur = nil return end   -- v1.9.143: followed for the pillar fix only, no funnel log
    if e.fb and e.fb.frame ~= frame_no then funnel_flush(e) end
    if not e.fb then
        e.fb = { frame = frame_no, items = {}, prefix = prefix }
        if flags then table.insert(e.fb.items, flags) end
    end
    local b = e.fb
    if #b.items >= 60 then e.f_cur = nil; return end
    local head = ""
    if tname ~= b.tbl then b.tbl = tname; head = "<" .. fn_short(tname, 8) .. "> " end
    table.insert(b.items, head .. label .. "?")
    e.f_cur = { idx = #b.items, head = head, label = label, conds = {} }
end
local function funnel_row_end(e, passed)
    local c = e.f_cur
    e.f_cur = nil
    if not c or not e.fb then return end
    local conds = #c.conds > 0 and ("[" .. table.concat(c.conds, ",") .. "]") or ""
    e.fb.items[c.idx] = c.head .. c.label .. (passed and "+" or "x") .. conds
end
local function funnel_cond(e, token)
    if e and e.f_cur and #e.f_cur.conds < 6 then table.insert(e.f_cur.conds, token) end
end
local function fmt_geo(e)
    local g = e and e.geo
    if not g or os.clock() - g.t > 1.5 then return "" end
    return string.format(" you %.1fm %s", g.d, g.ang and string.format("%+.0fdeg", g.ang) or "?deg")
end

local function m_ch2(chara) return safe(function() return chara.EnemyCtrl.Ch2 end) end
local function m_beads(chara)
    local ch2 = m_ch2(chara)
    return ch2 and safe(function() return ch2["<CharacterBeadsModelCtrl>k__BackingField"] end)
end
local function m_wpctrl(chara)
    local ch2 = m_ch2(chara)
    return ch2 and safe(function() return ch2["<Ch255BattleWayPointCtrl>k__BackingField"] end)
end
local function m_module(chara)
    return safe(function() return chara["<AIDecisionMaker>k__BackingField"]["<DecisionModule>k__BackingField"] end)
end
local function addr_of(o) return o and safe(function() return o:get_address() end) end
local function is_true(ret) return ret ~= nil and (sdk.to_int64(ret) & 0xFF) ~= 0 end

-- 1) startup values of a mobile world Medusa (only while a vortex fight is on)
local function medusa_fix_ch255(obj)
    if not (config.medusa_fixes and vortex_now) then return end
    if safe(function() return obj.MoveType end) == 0 then pcall(function() obj.MoveType = 1 end) end
    if safe(function() return obj._AlwaysCombatModeFlag end) == -1 then pcall(function() obj._AlwaysCombatModeFlag = 0 end) end
end
local function medusa_fix_beads(obj)
    if not (config.medusa_fixes and vortex_now) then return end
    local chara = safe(function() return obj.Ch255000 end) or safe(function() return obj["<Chara>k__BackingField"] end)
    local name = chara and safe(function() return chara:call("get_GameObject"):call("get_Name") end) or ""
    if name:sub(1, 5) ~= "ch255" then return end
    if safe(function() return obj["<InitCircleBufferMode>k__BackingField"] end) == 1 then
        pcall(function() obj["<InitCircleBufferMode>k__BackingField"] = 4 end)
    end
end
local medusa_hooks = 0
local function hook_startup(type_name, fixer)
    local td = sdk.find_type_definition(type_name)
    for _, m in ipairs(td and td:get_methods() or {}) do
        local lower = m:get_name():lower()
        if lower == "start" or lower == "awake" or lower == "onstart" or lower:find("^setup")
            or lower:find("^initiali") or lower == "init" or lower:find("^lateinit") then
            local ok = pcall(sdk.hook, m, function(args)
                if not vortex_now then return end
                local obj = safe(function() return sdk.to_managed_object(args[2]) end)
                thread.get_hook_storage()["rr_m"] = obj
                if obj then pcall(fixer, obj) end
            end, function(retval)
                local st = thread.get_hook_storage()
                local obj = st and st["rr_m"]
                if obj and vortex_now then pcall(fixer, obj); st["rr_m"] = nil end
                return retval
            end)
            if ok then medusa_hooks = medusa_hooks + 1 end
        end
    end
end
hook_startup("app.Ch255000", medusa_fix_ch255)
hook_startup("app.CharacterBeadsModelCtrl", medusa_fix_beads)

-- 2) battle stance without the lair's fixed point (it lifted her into the sky)
do
    local td = sdk.find_type_definition("app.CharacterBeadsModelCtrl")
    local m = td and td:get_method("applySnakeModeTransform")
    if m then
        local ok = pcall(sdk.hook, m, function(args)
            local st = thread.get_hook_storage()
            st["rr_fp"] = nil
            local e = medusa_by_beads[sdk.to_int64(args[2])]
            if not (e and config.medusa_fixes) then return end
            local data = safe(function() return sdk.to_managed_object(args[3]) end)
            if data and safe(function() return data._IsUseFixedPoint end) == true then
                data._IsUseFixedPoint = false
                st["rr_fp"] = data   -- shared game data: restored right after the call
                e.fp_fixes = (e.fp_fixes or 0) + 1
                if e.fp_fixes <= 3 then log("Medusa: battle stance without lair fixed point (#" .. e.fp_fixes .. ")") end
            end
        end, function(retval)
            local st = thread.get_hook_storage()
            local d = st and st["rr_fp"]
            if d then pcall(function() d._IsUseFixedPoint = true end); st["rr_fp"] = nil end
            return retval
        end)
        if ok then medusa_hooks = medusa_hooks + 1 end
    end
end

-- 3) VIRTUAL LAIR (v1.9) ------------------------------------------------------------------
-- In her lair Medusa fights by moving between marked spots (battle / wait / beam spots of her
-- waypoint network) and deciding what to do each time she arrives. A Rancor arena has none, so
-- the mod builds a "virtual lair" around the arena center when she spawns:
--   8 battle spots (ring at 70% of the arena radius), 4 wait spots (40%), 4 beam spots (85%).
-- Her waypoint searches are answered from those spots, and her "am I standing in a wait/battle
-- area?" checks say yes when she is on one. Everything is plain data: the spot goes into her own
-- waypoint controller's fields, and the game's own code moves her there (no game-method calls
-- from the mod inside her AI - the cause of the v1.8.8-v1.8.11 crashes).
K.NULLPOS_TD = sdk.find_type_definition("System.Nullable`1<via.Position>")
local lair = nil   -- { center, radius, battle = {...}, wait = {...}, beam = {...} }  (absolute coords)
local lair_warned = false

local arena_center, arena_center_at = nil, -1   -- your absolute position when the fight started
K.arena_c = function() return arena_center or player_upos() end   -- (for functions defined above this line)

-- walkable samples: places where monsters / you actually stood during this fight (absolute coords)
local walk_samples, walk_grid = {}, {}
local function reset_samples() walk_samples, walk_grid = {}, {} end
local function add_sample(p)
    if not p or not arena_center then return end
    local dx, dz = p.x - arena_center.x, p.z - arena_center.z
    if dx * dx + dz * dz > 60 * 60 or math.abs(p.y - arena_center.y) > 25 then return end
    local key = math.floor(p.x / 2) .. ":" .. math.floor(p.z / 2)
    if walk_grid[key] or #walk_samples >= 800 then return end
    walk_grid[key] = true
    table.insert(walk_samples, { x = p.x, y = p.y, z = p.z })
end
local function sample_walkable()
    if not vortex_now or not arena_center then return end
    add_sample(player_upos())
    for _, m in ipairs(find_components("app.Monster")) do
        local go = safe(function() return m:call("get_GameObject") end)
        local name = go and safe(function() return go:call("get_Name") end) or ""
        if name:sub(1, 5) ~= "ch255" then add_sample(upos_go(go)) end   -- Medusa's own path isn't proof of floor
    end
end
local function estimate_radius()
    if config.medusa_radius_calibrated or #walk_samples < 15 or not arena_center then
        return config.medusa_arena_radius or 20, (config.medusa_radius_calibrated and "calibrated" or "default")
    end
    local d = {}
    for _, p in ipairs(walk_samples) do
        local dx, dz = p.x - arena_center.x, p.z - arena_center.z
        table.insert(d, math.sqrt(dx * dx + dz * dz))
    end
    table.sort(d)
    local r90 = d[math.max(1, math.floor(#d * 0.9))]
    return math.max(10, math.min(45, r90)), string.format("estimated from %d samples", #walk_samples)
end
local function snap_to_floor(p)
    local best, bd = nil, nil
    for _, s in ipairs(walk_samples) do
        local dx, dz = s.x - p.x, s.z - p.z
        local d = dx * dx + dz * dz
        if not bd or d < bd then best, bd = s, d end
    end
    if best and bd <= 6 * 6 then return { x = best.x, y = best.y, z = best.z }, true end
    if best and bd <= 15 * 15 then return { x = p.x, y = best.y, z = p.z }, false end
    return p, false
end

local function build_lair()
    local c = arena_center or player_upos()
    if not c then
        if not lair_warned then lair_warned = true; log("Virtual lair: no absolute position available (get_UniversalPosition missing)") end
        return
    end
    local R, how = estimate_radius()
    local snapped = 0
    local function ring(count, r, phase)
        local out = {}
        for i = 0, count - 1 do
            local a = phase + i * 2 * math.pi / count
            local sp, ok = snap_to_floor({ x = c.x + math.cos(a) * r, y = c.y, z = c.z + math.sin(a) * r })
            if ok then snapped = snapped + 1 end
            table.insert(out, sp)
        end
        return out
    end
    lair = { center = c, radius = R, battle = ring(8, R * 0.7, 0), wait = ring(4, R * 0.4, math.pi / 4),
             beam = ring(4, R * 0.85, math.pi / 8), built = os.clock() }
    lair.how, lair.snapped, lair.samples = how, snapped, #walk_samples
    log(string.format("Virtual lair built around %s: radius %.0f m (%s), %d/16 spots snapped to walked floor",
        arena_center and "where you started the Rancor" or "your current position", R, how, snapped))
end

local function flat_dist(a, b)
    if not a or not b then return nil end
    local dx, dz = a.x - b.x, a.z - b.z
    return math.sqrt(dx * dx + dz * dz)
end

-- pick a spot of the right kind: prefer ones at a fighting distance from the player, nearest to her
local function pick_spot_ring(e, flag)
    if not lair then return nil, "none" end
    local beam = (flag == 64 or flag == 128)
    local kind = beam and "beam" or "battle"
    local lists = beam and { lair.beam, lair.battle } or { lair.battle, lair.wait }
    local pp, here = player_upos(), upos_go(e.go)
    -- ideal point: on the line from her to you, attack distance short of you -> she arrives facing you
    local want = beam and 14 or 8.5
    local ideal = nil
    if pp and here then
        local dx, dz = here.x - pp.x, here.z - pp.z
        local len = math.sqrt(dx * dx + dz * dz)
        if len < 0.5 then dx, dz, len = 1, 0, 1 end
        ideal = { x = pp.x + dx / len * want, y = pp.y, z = pp.z + dz / len * want }
    end
    local best, bestd, first
    for _, list in ipairs(lists) do
        for _, s in ipairs(list) do
            first = first or s
            local bad = e.bad_spots and e.bad_spots[s]
            local score = ideal and (flat_dist(s, ideal) or 0) or (flat_dist(s, here) or 0)
            if s ~= e.bp and not bad and (not bestd or score < bestd) then best, bestd = s, score end
        end
    end
    return best or first, kind
end

local function write_pos_field(obj, field, p)
    return pcall(function()
        local v = ValueType.new(POS_TD)
        v:set_field("x", p.x); v:set_field("y", p.y); v:set_field("z", p.z)
        obj:set_field(field, v)
    end)
end
local function write_nullable_pos_field(obj, field, p)
    if not K.NULLPOS_TD then return false end
    return pcall(function()
        local v = ValueType.new(POS_TD)
        v:set_field("x", p.x); v:set_field("y", p.y); v:set_field("z", p.z)
        local nv = ValueType.new(K.NULLPOS_TD)
        nv:set_field("_Value", v)
        nv:set_field("_HasValue", true)
        obj:set_field(field, nv)
    end)
end

-- v1.9.10: spots made on the fly around you (short runs, attack range, inside the arena)
local function floor_y(p)
    local best, bd = nil, nil
    for _, s in ipairs(walk_samples) do
        local dx, dz = s.x - p.x, s.z - p.z
        local d = dx * dx + dz * dz
        if not bd or d < bd then best, bd = s, d end
    end
    if best and bd <= 15 * 15 then return { x = p.x, y = best.y, z = p.z } end
    return p
end
local function is_bad(e, p)
    for i = #(e.bad_list or {}), 1, -1 do
        local b = e.bad_list[i]
        if os.clock() - b.t > 20 then table.remove(e.bad_list, i)
        elseif (flat_dist(b.p, p) or 99) < 3 then return true end
    end
    return false
end
local function pick_spot(e, flag)
    if not lair then return nil, "none" end
    local beam = (flag == 64 or flag == 128)
    local kind = beam and "beam" or "battle"
    local pp = player_upos()
    local here = (e.geo and os.clock() - e.geo.t < 1 and e.geo.here) or upos_go(e.go)
    if not pp or not here then return pick_spot_ring(e, flag) end
    local c, lim = lair.center, math.max(4, (lair.radius or 14) - 1.5)
    local cur = flat_dist(here, pp) or 0
    -- already at fighting distance and inside the arena: stay put (tiny step) so she acts now
    if not beam and cur >= 5 and cur <= 11 and (flat_dist(here, c) or 0) <= lim and not is_bad(e, here) then
        return floor_y({ x = here.x + (pp.x - here.x) / math.max(cur, 0.1) * 0.8, y = here.y,
                         z = here.z + (pp.z - here.z) / math.max(cur, 0.1) * 0.8 }), kind .. " (in place)"
    end
    local want = beam and 12 or 8
    local base = cur > 0.5 and math.atan(here.z - pp.z, here.x - pp.x) or 0
    local best, bestscore
    for _, off in ipairs({ 0, 0.45, -0.45, 0.9, -0.9, 1.4, -1.4, 2.0, -2.0, 2.6, -2.6, math.pi }) do
        local a = base + off
        local p = { x = pp.x + math.cos(a) * want, y = pp.y, z = pp.z + math.sin(a) * want }
        if (flat_dist(p, c) or 99) <= lim and not is_bad(e, p) then
            local score = (flat_dist(p, here) or 0) + math.abs(off) * 2
            if not bestscore or score < bestscore then best, bestscore = p, score end
        end
    end
    if not best then
        -- you are near the edge: pull the point toward the arena center until it fits
        local a = base
        local p = { x = pp.x + math.cos(a) * want, y = pp.y, z = pp.z + math.sin(a) * want }
        local dc = flat_dist(p, c) or 0
        if dc > lim and dc > 0 then
            p = { x = c.x + (p.x - c.x) * lim / dc, y = p.y, z = c.z + (p.z - c.z) * lim / dc }
        end
        best = p
    end
    return floor_y(best), kind
end

local function give_battle_pos(e, param, cache, why)
    local flag = param and safe(function() return param._RouteFlag end)
    -- v1.9.83: Purgeners use more route kinds (4 pounce, 6 cataclysm, area searches); pillar ones (8)
    -- get a spot next to the pillar from the Purgener module (rr_purg_spot, defined further down)
    if e.purgener and lair then
        local fl = math.tointeger(flag) or 0
        if fl & 8 ~= 0 then
            local ps = rr_purg_spot and rr_purg_spot(e, fl)
            if not ps then return false end
            local ctrl = m_wpctrl(e.chara)
            if ctrl then
                -- v1.9.84: write all four slots (the wait-point move reads NextPatrolPos; a stale one sent
                -- it toward a point 2.3 km away, off the edge of the Devouring stage)
                write_pos_field(ctrl, "<LastFoundedBattlePosition>k__BackingField", ps)
                write_pos_field(ctrl, "<NextPatrolPos>k__BackingField", ps)
                write_nullable_pos_field(ctrl, "<CachedLastFoundedBattlePosition>k__BackingField", ps)
                write_nullable_pos_field(ctrl, "<CachedNextPatrolPos>k__BackingField", ps)
            end
            e.pillar_spots = (e.pillar_spots or 0) + 1
            if e.pillar_spots <= 5 then log(string.format("Purgener -> pillar spot (route %s, %s)", tostring(flag), why)) end
            return true
        end
    end
    if not (K.FIND_OK[flag or -1] or e.purgener) or not lair then return false end
    -- keep the same spot until she gets there (+6 s to act), or 12 s / 20 s pass
    local now = os.clock()
    local p = e.bp
    local here = upos_go(e.go)
    local reached = p and flat_dist(here, p) and flat_dist(here, p) < 4
    if reached and not e.reached_t then e.reached_t = now end
    local stay_over = e.reached_t and now - e.reached_t > 3
    -- you moved away from her spot (not for beam spots): re-pick, at most every 2 s
    local pp0 = player_upos()
    local you_left = p and pp0 and e.bp_kind == "battle" and (flat_dist(p, pp0) or 0) > 13 and now - (e.bp_t or 0) > 2
    if not p or stay_over or you_left or (not e.reached_t and now - (e.bp_t or 0) > 8) or now - (e.bp_t or 0) > 14 then
        e.reached_t = nil
        local kind
        p, kind = pick_spot(e, flag)
        e.bp, e.bp_t, e.bp_kind = p, now, kind
        e.prog_d, e.prog_t = nil, now
        e.spots = (e.spots or 0) + 1
        if e.spots <= 10 or e.spots % 10 == 0 then
            log(string.format("Medusa -> %s spot #%d (%s, route %s), %.0f m from you%s", tostring(kind), e.spots, why,
                tostring(flag), flat_dist(p, player_upos()) or -1, reached and " - reached the last one" or ""))
        end
    end
    local ctrl = m_wpctrl(e.chara)
    if p and ctrl then
        write_pos_field(ctrl, "<LastFoundedBattlePosition>k__BackingField", p)
        write_pos_field(ctrl, "<NextPatrolPos>k__BackingField", p)
        local okc = write_nullable_pos_field(ctrl, "<CachedLastFoundedBattlePosition>k__BackingField", p)
        write_nullable_pos_field(ctrl, "<CachedNextPatrolPos>k__BackingField", p)
        if not okc and not e.null_err then e.null_err = true; log("Medusa: could not write cached spot (Nullable)") end
    end
    e.found = (e.found or 0) + 1
    if not ctrl and not e.noctrl_logged then e.noctrl_logged = true; log("Medusa has no waypoint controller") end
    return true
end

-- is she standing on a virtual-lair spot of this kind?
local function on_spot(e, route_flag)
    if not lair then return false end
    route_flag = math.tointeger(route_flag) or 0
    if e.purgener then
        -- v1.9.83: any non-pillar route (4 pounce, 6 cataclysm, ...) = anywhere inside the spot ring;
        -- pillar routes (8) = within 8 m of the pillar
        local here = upos_go(e.go)
        if route_flag & 8 ~= 0 then return rr_purg_spot and rr_purg_spot(e, route_flag, true) or false end
        return (flat_dist(here, lair.center) or 99) <= (lair.radius or 18) + 6
    end
    local here = upos_go(e.go)
    local function near(list)
        for _, s in ipairs(list) do
            local d = flat_dist(here, s)
            if d and d < 8 then return true end
        end
        return false
    end
    if (route_flag & 5) ~= 0 and (near(lair.wait) or near(lair.battle)) then return true end
    if (route_flag & (64 | 128)) ~= 0 and near(lair.beam) then return true end
    return false
end

-- v1.9.9: a spot her own search found that is far from her / outside the arena
local function spot_is_junk(e, ctrl_ptr)
    if not lair then return false end
    local ctrl = safe(function() return sdk.to_managed_object(ctrl_ptr) end)
    local v = ctrl and safe(function() return ctrl["<LastFoundedBattlePosition>k__BackingField"] end)
    local p = v and { x = vfield(v, "x"), y = vfield(v, "y"), z = vfield(v, "z") }
    if not p or type(p.x) ~= "number" or type(p.z) ~= "number" then return false end
    local here = e.geo and e.geo.here
    local dh = here and flat_dist(p, here)
    local dc = flat_dist(p, lair.center)
    return (dh and dh > 40) or (dc and dc > (lair.radius or 14) + 15)
end

do
    local td = sdk.find_type_definition("app.Ch255BattleWayPointCtrl")
    local m = td and td:get_method("findBattlePosition")
    if m then
        local ok = pcall(sdk.hook, m, function(args)
            local st = thread.get_hook_storage()
            st["rr_fbp"] = nil
            if not config.medusa_battle_pos then return end
            local e = medusa_by_ctrl[sdk.to_int64(args[2])]
            if e then
                st["rr_fbp"] = { e = e, param = safe(function() return sdk.to_managed_object(args[3]) end),
                                 cache = (sdk.to_int64(args[4]) & 0xFF) ~= 0, ctrl = args[2] }
            end
        end, function(retval)
            local st = thread.get_hook_storage()
            local c = st and st["rr_fbp"]
            if c then
                st["rr_fbp"] = nil
                local rf8 = c.param and safe(function() return c.param._RouteFlag end)
                if rf8 == 8 and os.clock() - (c.e.r8_log or -100) > 10 then
                    c.e.r8_log = os.clock()
                    c.e.r8_n = (c.e.r8_n or 0) + 1
                    local tgt = nil
                    for _, mc in ipairs(find_components("app.Ch255000")) do
                        local g = safe(function() return mc["<ClimberTargetGimmick>k__BackingField"] end)
                        if g then tgt = safe(function() return g:call("get_GameObject"):call("get_Name") end) or "?" end
                    end
                    local ctrl = safe(function() return sdk.to_managed_object(c.ctrl) end)
                    local v = ctrl and safe(function() return ctrl["<LastFoundedBattlePosition>k__BackingField"] end)
                    log(string.format("Medusa pillar search (route 8) #%d: %s; spot %s; climb target %s", c.e.r8_n,
                        is_true(retval) and "FOUND" or "nothing", v and string.format("(%.1f, %.1f, %.1f)", vfield(v, "x") or 0, vfield(v, "y") or 0, vfield(v, "z") or 0) or "?",
                        tostring(tgt)))
                end
                if not is_true(retval) then
                    if give_battle_pos(c.e, c.param, c.cache, "waypoint search") then return sdk.to_ptr(1) end
                elseif spot_is_junk(c.e, c.ctrl) then
                    c.e.junk = (c.e.junk or 0) + 1
                    if c.e.junk <= 5 then log("Medusa: her own spot search gave a point far outside the arena - replaced") end
                    c.e.bp = nil
                    give_battle_pos(c.e, c.param, c.cache, "replacing a far spot")
                end
            end
            return retval
        end)
        if ok then medusa_hooks = medusa_hooks + 1 end
    end
    local ctd = sdk.find_type_definition("app.EmThkChkCh255FindBattlePos")
    local cm = ctd and ctd:get_method("evaluate")
    if cm then
        local ok = pcall(sdk.hook, cm, function(args)
            local st = thread.get_hook_storage()
            st["rr_eval"] = nil
            if not config.medusa_battle_pos then return end
            local e = medusa_by_module[sdk.to_int64(args[3])]
            if e then st["rr_eval"] = { e = e, cond = safe(function() return sdk.to_managed_object(args[2]) end) } end
        end, function(retval)
            local st = thread.get_hook_storage()
            local c = st and st["rr_eval"]
            if c then
                st["rr_eval"] = nil
                local param = c.cond and safe(function() return c.cond.PositionParam end)
                local rf = param and safe(function() return param._RouteFlag end)
                if not is_true(retval) then
                    local cache = c.cond and safe(function() return c.cond.CachedFindResult end)
                    if give_battle_pos(c.e, param, cache, "think check") then
                        funnel_cond(c.e, "FindPos" .. tostring(rf) .. "+mod")
                        return sdk.to_ptr(1)
                    end
                    funnel_cond(c.e, "FindPos" .. tostring(rf) .. "x")
                else
                    funnel_cond(c.e, "FindPos" .. tostring(rf) .. "+")
                end
            end
            return retval
        end)
        if ok then medusa_hooks = medusa_hooks + 1 end
    end
    -- "am I standing in a wait / battle / beam area?" (her current waypoint node's route flag)
    local rtd = sdk.find_type_definition("app.EmThkChkCh255CheckNowRouteInfo")
    local rm = rtd and rtd:get_method("evaluate")
    if rm then
        local ok = pcall(sdk.hook, rm, function(args)
            local st = thread.get_hook_storage()
            st["rr_route"] = nil
            if not config.medusa_battle_pos then return end
            local e = medusa_by_module[sdk.to_int64(args[3])]
            if e then st["rr_route"] = { e = e, cond = safe(function() return sdk.to_managed_object(args[2]) end) } end
        end, function(retval)
            local st = thread.get_hook_storage()
            local c = st and st["rr_route"]
            if c then
                st["rr_route"] = nil
                local flag = c.cond and safe(function() return c.cond.RouteFlag end)
                if not is_true(retval) then
                    if type(flag) == "number" and (math.tointeger(flag) or 0) & 8 ~= 0 and PILLAR_AI.at_start and PILLAR_AI.at_start(c.e) then
                        c.e.pillar.at_logged = c.e.pillar.at_logged or (log("Medusa pillar: she reached the pillar start spot (route 8 check passed)") or true)
                        funnel_cond(c.e, "Route8+pillar")
                        return sdk.to_ptr(1)
                    end
                    if type(flag) == "number" and on_spot(c.e, flag) then
                        c.e.route_yes = (c.e.route_yes or 0) + 1
                        if c.e.route_yes <= 3 then log("Medusa: standing on a virtual-lair spot (route " .. flag .. ")") end
                        funnel_cond(c.e, "Route" .. tostring(flag) .. "+mod")
                        return sdk.to_ptr(1)
                    end
                    funnel_cond(c.e, "Route" .. tostring(flag) .. "x")
                else
                    funnel_cond(c.e, "Route" .. tostring(flag) .. "+")
                end
            end
            return retval
        end)
        if ok then medusa_hooks = medusa_hooks + 1 end
    end
end

-- 3a) unstick (v1.9.3): when she is stuck, let her "end of move" timer check pass once
do
    local td = sdk.find_type_definition("app.EmThkChkCheckTimer")
    local m = td and td:get_method("evaluate")
    if m then
        local ok = pcall(sdk.hook, m, function(args)
            local st = thread.get_hook_storage()
            st["rr_tm"] = nil
            local e = medusa_by_module[sdk.to_int64(args[3])]
            if e and e.unstick_until and os.clock() < e.unstick_until then
                st["rr_tm"] = { e = e, cond = safe(function() return sdk.to_managed_object(args[2]) end) }
            end
        end, function(retval)
            local st = thread.get_hook_storage()
            local c = st and st["rr_tm"]
            if c then
                st["rr_tm"] = nil
                local name = c.cond and safe(function() return c.cond.ValueName end)
                if type(name) == "string" and name:find("時間終了", 1, true) and not is_true(retval) then
                    c.e.unstick_until = nil
                    log("Medusa: ended her stuck move (end-of-move timer)")
                    return sdk.to_ptr(1)
                end
            end
            return retval
        end)
        if ok then medusa_hooks = medusa_hooks + 1 end
    end
end

-- 3b) fallback: if her FreePosition01 target still points far away for 5 s, aim her at the
--     party member she's fighting instead (proven stable in v1.8.5)
local medusa_by_tc = {}   -- TargetController addr -> entry
local medusa_by_ch2 = {}  -- app.Ch255000 addr -> entry
do
    local td = sdk.find_type_definition("app.TargetController")
    for _, m in ipairs(td and td:get_methods() or {}) do
        local n = m:get_name()
        local p1 = m:get_num_params() >= 1 and safe(function() return m:get_param_types()[1]:get_full_name() end)
        if (n == "setTarget" or n == "setTypeTarget")
            and (p1 == "app.TargetController.TargetTypeEnum" or p1 == "System.Int32") then
            local ok = pcall(sdk.hook, m, function(args)
                if not config.medusa_battle_pos then return end
                local e = medusa_by_tc[sdk.to_int64(args[2])]
                if not e or not e.fp_bad then return end
                local t = sdk.to_int64(args[3]) & 0xFFFFFFFF
                if t == 25 then
                    args[3] = sdk.to_ptr(4)
                    e.redirects = (e.redirects or 0) + 1
                    if e.redirects <= 3 or e.redirects % 200 == 0 then
                        log("Medusa: target FreePosition01 -> player/party (#" .. e.redirects .. ", " .. n .. ")")
                    end
                end
            end, nil)
            if ok then medusa_hooks = medusa_hooks + 1 end
        end
    end
    -- log (don't block) what the game itself sets FreePosition01 to, to verify it uses our spots
    for _, m in ipairs(td and td:get_methods() or {}) do
        if m:get_name() == "setFreePosition01" then
            local ok = pcall(sdk.hook, m, function(args)
                local e = medusa_by_tc[sdk.to_int64(args[2])]
                if not e then return end
                e.fp_sets = (e.fp_sets or 0) + 1
                if e.fp_sets <= 6 then
                    local v = safe(function() return sdk.to_valuetype(args[3], "via.Position") end)
                    local x, z = v and safe(function() return v.x end), v and safe(function() return v.z end)
                    local d = (type(x) == "number" and type(z) == "number") and flat_dist({ x = x, z = z }, upos_go(e.go))
                    log("Medusa: game set FreePosition01" .. (d and string.format(" to a point %.0f m from her", d) or ""))
                end
            end, nil)
            if ok then medusa_hooks = medusa_hooks + 1 end
        end
    end
end

-- 4) combat state + target (v0.18 / v0.19)
K.AI_COMBAT = 8
local ai_state_methods = {}
do
    local td = sdk.find_type_definition("app.CharacterAIStateController")
    for _, m in ipairs(td and td:get_methods() or {}) do
        local lower = m:get_name():lower()
        local p1 = m:get_num_params() == 1 and safe(function() return m:get_param_types()[1]:get_full_name() end)
        if lower:find("aistate") and (lower:find("^request") or lower:find("^set") or lower:find("^change"))
            and (p1 == "app.AIStateEnum" or p1 == "System.Int32") then
            table.insert(ai_state_methods, m)
        end
    end
end
local TC_td = sdk.find_type_definition("app.TargetController")
local m_setTarget = TC_td and TC_td:get_method("setTarget(app.TargetController.TargetTypeEnum)")
local m_setTypeTarget = TC_td and TC_td:get_method("setTypeTarget(app.TargetController.TargetTypeEnum, via.GameObject, via.vec3)")

local function push_combat(e)
    local ec = safe(function() return e.chara.EnemyCtrl end)
    local ai = safe(function() return e.chara.CharaAIStateCtrl end)
    if not ec or not ai then return end
    if safe(function() return ec.CircleDetectArizenPartyEnemyRecognizeState end) == 0 then
        pcall(function() ec.CircleDetectArizenPartyEnemyRecognizeState = 1 end)
    end
    if safe(function() return ai._AIState end) ~= K.AI_COMBAT then
        for _, m in ipairs(ai_state_methods) do pcall(function() m:call(ai, K.AI_COMBAT) end) end
        pcall(function() ai._FixAIState = K.AI_COMBAT end)
    end
end
local function retarget(e)
    local cm = sdk.get_managed_singleton("app.CharacterManager")
    local player = cm and safe(function() return cm["<ManualPlayer>k__BackingField"] end)
    local tc = safe(function() return m_module(e.chara)._TargetCtrl end)
    if not player or not tc then return end
    if safe(function() return tc._TargetType end) == 25 then return end
    local go = safe(function() return player:get_GameObject() end)
    local pos = safe(function() return player:get_Transform():get_Position() end)
    if m_setTypeTarget and go and pos then pcall(function() m_setTypeTarget:call(tc, 25, go, pos) end) end
    if m_setTarget then pcall(function() m_setTarget:call(tc, 25) end) end
end

local function snake_switch(e)
    local bd = m_beads(e.chara)
    if not bd then return "no body controller" end
    pcall(function() bd["<InitCircleBufferMode>k__BackingField"] = 4 end)
    local ok, err = pcall(function()
        local info = ValueType.new(sdk.find_type_definition("via.Uint2"))
        info.x = 1
        info.y = 0
        bd:requestSwitchRoute(4, info)
        bd:requestSwitchRouteEnd()
    end)
    return ok and "requested" or ("failed: " .. tostring(err))
end


-- 5) decision trace (v1.8.2 research): which think-table rows pass for our Medusa, and how
--    her attack-range checks come out. Log only; changes nothing.
local medusa_by_tctrl = {}   -- ThinkTableController addr -> entry
do
    local td = sdk.find_type_definition("app.ThinkTableController")
    local m = td and td:get_method("isExecuteEmThkGeneralCommand")
    if m then
        local ok = pcall(sdk.hook, m, function(args)
            local st = thread.get_hook_storage()
            st["rr_tr"] = nil
            local e = medusa_by_tctrl[sdk.to_int64(args[2])]
            if e then st["rr_tr"] = { e = e, cmd = args[3], tbl = args[4], tc = args[2] } end
        end, function(retval)
            local st = thread.get_hook_storage()
            local c = st and st["rr_tr"]
            if c then
                st["rr_tr"] = nil
                local e = c.e
                local passed = is_true(retval)
                if not config.medusa_trace then
                    -- light mode: only the v1.8.3 "go to the combat table" fix
                    if not passed and config.medusa_force_battle then
                        local cmd0 = safe(function() return sdk.to_managed_object(c.cmd) end)
                        local jump0 = cmd0 and safe(function() return cmd0.TableName end)
                        if type(jump0) == "string" and jump0:find("本戦闘", 1, true) and jump0:find("メイン", 1, true) then
                            e.forced = (e.forced or 0) + 1
                            if e.forced <= 3 then log("Medusa: sent into her combat table") end
                            return sdk.to_ptr(1)
                        end
                    end
                    return retval
                end
                local this_tc = c.tc
                local cmd = safe(function() return sdk.to_managed_object(c.cmd) end)
                local tbl = safe(function() return sdk.to_managed_object(c.tbl) end)
                local tname = tbl and safe(function() return tbl.TableName end) or "?"
                local act = cmd and safe(function() return cmd._ActInterName end) or "?"
                local jump = cmd and safe(function() return cmd.TableName end) or "?"
                local key = tname .. " | act " .. act .. " | goto " .. jump
                e.rows = e.rows or {}
                local r = e.rows[key] or { pass = 0, fail = 0 }
                e.rows[key] = r
                if passed then r.pass = r.pass + 1 else r.fail = r.fail + 1 end
                if passed and key ~= e.last_pass then
                    e.last_pass = key
                    e.pass_logs = (e.pass_logs or 0) + 1
                    if e.pass_logs <= 40 then log("  think: " .. key) end
                end
                -- log the row's own range limits vs. her current target, once per failing row
                if not passed and not (e.range_logged or {})[key] then
                    e.range_logged = e.range_logged or {}
                    e.range_logged[key] = true
                    local function f2(name)
                        local v = cmd and safe(function() return cmd[name] end)
                        local a, b = v and safe(function() return v.x end), v and safe(function() return v.y end)
                        return (type(a) == "number" and type(b) == "number") and string.format("%.1f..%.1f", a, b) or "?"
                    end
                    local tco = safe(function() return sdk.to_managed_object(this_tc) end)
                    local mod = m_module(e.chara)
                    local function tv(mname)
                        local v = nil   -- v1.8.11: no game-method calls from inside her AI
                        return type(v) == "number" and string.format("%.1f", v) or "?"
                    end
                    if e.range_lines == nil then e.range_lines = 0 end
                    e.range_lines = e.range_lines + 1
                    if e.range_lines <= 30 then
                        log(string.format("  row fails: %s  [row limits Length %s Angle %s Height %s | target now: length %s angle %s height %s, type %s]",
                            key, f2("Length"), f2("Angle"), f2("Height"), tv("getTargetLength"), tv("getTargetAnlge"),
                            tv("getTargetHeight"), tostring(safe(function() return mod._TargetCtrl._TargetType end))))
                    end
                end
                -- v1.8.3: let "go to the main combat table" through for our Medusa
                if not passed and config.medusa_force_battle and type(jump) == "string"
                    and jump:find("本戦闘", 1, true) and jump:find("メイン", 1, true) then
                    e.forced = (e.forced or 0) + 1
                    if e.forced <= 3 then log("Medusa: sent into her combat table (" .. tname .. ")") end
                    return sdk.to_ptr(1)
                end
            end
            return retval
        end)
        if ok then medusa_hooks = medusa_hooks + 1 end
    end
    local atd = sdk.find_type_definition("app.EmThkChkCh255AttackRangeCheck")
    local am = atd and atd:get_method("evaluate")
    if am then
        local ok = pcall(sdk.hook, am, function(args)
            local st = thread.get_hook_storage()
            st["rr_ar"] = nil
            local e = medusa_by_module[sdk.to_int64(args[3])]
            if e and not e.purgener then st["rr_ar"] = { e = e, cond = args[2] } end
        end, function(retval)
            local st = thread.get_hook_storage()
            local c = st and st["rr_ar"]
            if c then
                st["rr_ar"] = nil
                local e = c.e
                e.ar = e.ar or { pass = 0, fail = 0, samples = 0 }
                local passed = is_true(retval)
                if passed then e.ar.pass = e.ar.pass + 1 else e.ar.fail = e.ar.fail + 1 end
                -- v1.9.7: limits of this check (cached per condition object)
                local caddr = sdk.to_int64(c.cond)
                e.ar_lim = e.ar_lim or {}
                local lim = e.ar_lim[caddr]
                if lim == nil then
                    local cond = safe(function() return sdk.to_managed_object(c.cond) end)
                    local L = cond and safe(function() return cond.Length end)
                    local A = cond and safe(function() return cond.Angle end)
                    local lx, ly = L and safe(function() return L.x end), L and safe(function() return L.y end)
                    local ax, ay = A and safe(function() return A.x end), A and safe(function() return A.y end)
                    if type(lx) == "number" and type(ly) == "number" then
                        lim = { lx = lx, ly = ly, a = math.max(math.abs(tonumber(ax) or 30), math.abs(tonumber(ay) or 30)),
                                tt = cond and safe(function() return cond.TargetType end) }
                    else
                        lim = false
                    end
                    e.ar_lim[caddr] = lim
                end
                local tag = lim and string.format("Range%s(%.0f-%.0fm,%.0fdeg)", tostring(lim.tt), lim.lx, lim.ly, lim.a) or "Range"
                local assisted = false
                if not passed and config.medusa_attack_assist and lim and lim.ly <= 20 then
                    local g, now = e.geo, os.clock()
                    if g and now - g.t < 1.5 then
                        local lo, hi = math.max(3.0, lim.lx - 3.0), lim.ly + 2.0
                        local amax = math.max(lim.a, 40)
                        if g.d >= lo and g.d <= hi and (g.ang == nil or math.abs(g.ang) <= amax)
                            and now - (e.last_atk_t or -100) > 3.0 then
                            assisted = true
                            e.ar_assist = (e.ar_assist or 0) + 1
                            if e.ar_assist <= 5 or e.ar_assist % 25 == 0 then
                                log(string.format("Medusa attack-window assist #%d: %s passed (you %.1f m, %s)", e.ar_assist, tag, g.d,
                                    g.ang and string.format("%+.0f deg", g.ang) or "angle ?"))
                            end
                        end
                    end
                end
                funnel_cond(e, tag .. (passed and "+" or (assisted and "+assist" or "x")) .. fmt_geo(e))
                if assisted then return sdk.to_ptr(1) end
                if config.medusa_trace and e.ar.samples < 12 then
                    e.ar.samples = e.ar.samples + 1
                    local cond = safe(function() return sdk.to_managed_object(c.cond) end)
                    local function f2(name)
                        local v = cond and safe(function() return cond[name] end)
                        local a, b = v and safe(function() return v.x end), v and safe(function() return v.y end)
                        return (type(a) == "number" and type(b) == "number") and string.format("%.1f..%.1f", a, b) or "?"
                    end
                    log(string.format("  range check: Length %s Angle %s Height %s target %s lookAt %s -> %s (you are %.1f m away)",
                        f2("Length"), f2("Angle"), f2("Height"),
                        tostring(cond and safe(function() return cond.TargetType end)),
                        tostring(cond and safe(function() return cond.UseLookAtTargetIfHave end)),
                        passed and "IN RANGE" or "out of range", dist3(pos_of(e.go), player_pos()) or -1))
                end
            end
            return retval
        end)
        if ok then medusa_hooks = medusa_hooks + 1 end
    end
end

local function medusa_trace_summary(e)
    local list = {}
    for k, r in pairs(e.rows or {}) do table.insert(list, { k = k, p = r.pass, f = r.fail }) end
    table.sort(list, function(a, b) return (a.p + a.f) > (b.p + b.f) end)
    local out = {}
    for i = 1, math.min(20, #list) do
        table.insert(out, string.format("    %4d pass / %4d fail  %s", list[i].p, list[i].f, list[i].k))
    end
    local ar = e.ar or { pass = 0, fail = 0 }
    return string.format("range checks %d in / %d out; busiest rows:\n%s", ar.pass, ar.fail, table.concat(out, "\n"))
end


-- v1.9.7: where you are relative to her (distance, angle off her nose), refreshed on frame
local function update_geo(e)
    local now = os.clock()
    if e.geo and now - e.geo.t < 0.2 then return end
    local tr = safe(function() return e.go:call("get_Transform") end)
    local here, pp = upos_tr(tr), player_upos()
    if not here or not pp then return end
    local dx, dz = pp.x - here.x, pp.z - here.z
    local d = math.sqrt(dx * dx + dz * dz)
    local ang = nil
    local ax = safe(function() return tr:call("get_AxisZ") end)
    local fx, fz = ax and safe(function() return ax.x end), ax and safe(function() return ax.z end)
    if type(fx) == "number" and type(fz) == "number" and d > 0.05 and (fx * fx + fz * fz) > 0.0001 then
        ang = math.deg(math.atan(dz, dx) - math.atan(fz, fx))
        ang = (ang + 180) % 360 - 180
    end
    e.geo = { d = d, ang = ang, t = now, here = here }
end

-- v1.9.7: extra state (move type, waypoint navigation, unique flags) for the status lines
local function pct(y, n) local t = (y or 0) + (n or 0); return t > 0 and string.format("%.0f%%", 100 * (y or 0) / t) or "-" end
local function medusa_extra_state(e)
    local ch2 = m_ch2(e.chara)
    local wp = m_wpctrl(e.chara)
    local mt = ch2 and safe(function() return ch2.MoveType end)
    local MT = { [0] = "Wait", [1] = "Walk", [2] = "Run", [3] = "Dash", [4] = "Climb" }
    local parts = { "moveType " .. tostring(MT[mt] or mt) }
    if wp then
        table.insert(parts, string.format("waypoint: use %s, naviFailed %s, routeFlag %s, node %s",
            tostring(safe(function() return wp._UseWayPointMove end)), tostring(safe(function() return wp._IsRequestNaviFailed end)),
            tostring(safe(function() return wp._NowRouteFlag end)), tostring(safe(function() return wp["<CurrentNodeId>k__BackingField"] end))))
    end
    table.insert(parts, string.format("nav complete: way %d, surface %d", e.nav_way or 0, e.nav_surf or 0))
    local uq = {}
    for name, r in pairs(e.uq or {}) do
        table.insert(uq, string.format("%s on %s%s", name, pct(r.y, r.n), (r.forced or 0) > 0 and string.format(" (forced %d)", r.forced) or ""))
    end
    table.sort(uq)
    table.insert(parts, "unique flags: " .. (#uq > 0 and table.concat(uq, "; ") or (e.uq_calls and "none resolved" or "no updates seen")))
    if e.cea then
        table.insert(parts, string.format("may-attack check: yes %s of %d%s", pct(e.cea.y, e.cea.n), e.cea.y + e.cea.n,
            e.cea.forced > 0 and string.format(" (granted %d)", e.cea.forced) or ""))
    end
    if e.cfl then
        table.insert(parts, string.format("EnableAttack flag on %s, DisableAttack %s%s", pct(e.cfl.ea, e.cfl.n - e.cfl.ea),
            pct(e.cfl.da, e.cfl.n - e.cfl.da), e.cfl.forced > 0 and string.format(" (forced %d)", e.cfl.forced) or ""))
    end
    if e.ar_assist then table.insert(parts, "attack assists " .. e.ar_assist) end
    if e.cd_cut then table.insert(parts, "cooldowns cut " .. e.cd_cut) end
    if e.geo and os.clock() - e.geo.t < 2 then
        table.insert(parts, string.format("you %.1f m, %s off her nose", e.geo.d, e.geo.ang and string.format("%+.0f deg", e.geo.ang) or "?"))
    end
    return table.concat(parts, " | ")
end

-- 6) STUDY A WORLD MEDUSA (v1.9.5, log only) ---------------------------------------------
-- With "Study world Medusa" on, a normal Medusa in her lair is observed (nothing is changed):
-- which battle spots her real waypoint network gives her (distance / height from her and you),
-- which think-table rows pass when she attacks, pass-row / unique-flag gates, route checks.
local study = {}               -- go addr -> entry
local study_scan_t = 0
local study_by_ctrl, study_by_module, study_by_tctrl, study_by_ch2 = {}, {}, {}, {}
local gate = { pass_row = {}, uniq = {}, common = {} }   -- [who][key] = {t=, f=}
local function gcount(tbl, key, ok)
    local r = tbl[key] or { t = 0, f = 0 }
    tbl[key] = r
    if ok then r.t = r.t + 1 else r.f = r.f + 1 end
end

do
    -- real battle spots
    local td = sdk.find_type_definition("app.Ch255BattleWayPointCtrl")
    local m = td and td:get_method("findBattlePosition")
    if m then
        pcall(sdk.hook, m, function(args)
            local st = thread.get_hook_storage()
            st["rr_sfbp"] = nil
            local e = study_by_ctrl[sdk.to_int64(args[2])]
            if e then st["rr_sfbp"] = { e = e, ctrl = args[2], param = args[3] } end
        end, function(retval)
            local st = thread.get_hook_storage()
            local c = st and st["rr_sfbp"]
            if c then
                st["rr_sfbp"] = nil
                local e = c.e
                local ok = is_true(retval)
                local param = safe(function() return sdk.to_managed_object(c.param) end)
                local flag = param and safe(function() return param._RouteFlag end)
                e.fbp = e.fbp or {}
                gcount(e.fbp, tostring(flag), ok)
                if ok then
                    local ctrl = safe(function() return sdk.to_managed_object(c.ctrl) end)
                    local v = ctrl and safe(function() return ctrl["<LastFoundedBattlePosition>k__BackingField"] end)
                    local p = v and { x = vfield(v, "x"), y = vfield(v, "y"), z = vfield(v, "z") }
                    if p and type(p.x) == "number" then
                        local key = string.format("%d:%d:%d", math.floor(p.x), math.floor(p.y), math.floor(p.z))
                        e.spots_seen = e.spots_seen or {}
                        if not e.spots_seen[key] then
                            e.spots_seen[key] = true
                            e.nspots = (e.nspots or 0) + 1
                            if e.nspots <= 40 then
                                local here, pp = upos_go(e.go), player_upos()
                                log(string.format("STUDY spot route %s: %.1f m from her, %.1f m from you, height %+.1f m vs her",
                                    tostring(flag), flat_dist(p, here) or -1, flat_dist(p, pp) or -1, here and (p.y - here.y) or 0))
                            end
                        end
                    end
                end
            end
            return retval
        end)
    end
    -- passing think-table rows
    local ttd = sdk.find_type_definition("app.ThinkTableController")
    local tm = ttd and ttd:get_method("isExecuteEmThkGeneralCommand")
    if tm then
        pcall(sdk.hook, tm, function(args)
            local st = thread.get_hook_storage()
            st["rr_str"] = nil
            local e = study_by_tctrl[sdk.to_int64(args[2])]
            if e then st["rr_str"] = { e = e, cmd = args[3], tbl = args[4] } end
        end, function(retval)
            local st = thread.get_hook_storage()
            local c = st and st["rr_str"]
            if c then
                st["rr_str"] = nil
                if is_true(retval) then
                    local cmd = safe(function() return sdk.to_managed_object(c.cmd) end)
                    local tbl = safe(function() return sdk.to_managed_object(c.tbl) end)
                    local key = (tbl and safe(function() return tbl.TableName end) or "?") .. " | " ..
                        (cmd and safe(function() return cmd._ActInterName end) or "?") .. " | goto " ..
                        (cmd and safe(function() return cmd.TableName end) or "?")
                    local e = c.e
                    local now = os.clock()
                    e.row_seen = e.row_seen or {}
                    if key ~= e.last_row and now - (e.row_seen[key] or -99) > 3 and not key:find("ACT_INVALID | goto NO_JUMP_TBL", 1, true) then
                        e.last_row = key
                        e.row_seen[key] = now
                        e.rowlogs = (e.rowlogs or 0) + 1
                        if e.rowlogs <= 250 then log("STUDY think: " .. key) end
                    end
                end
            end
            return retval
        end)
    end
    -- gates: pass rows / unique flags / common flags (both study and our Medusas, counted)
    local pr = ttd and ttd:get_method("isEnablePassRow")
    if pr then
        pcall(sdk.hook, pr, function(args)
            local st = thread.get_hook_storage()
            st["rr_pr"] = nil
            local a = sdk.to_int64(args[2])
            local who = study_by_tctrl[a] and "world" or (medusa_by_tctrl[a] and "rancor")
            if who then st["rr_pr"] = { who = who, cmd = args[3], e = medusa_by_tctrl[a] } end
        end, function(retval)
            local st = thread.get_hook_storage()
            local c = st and st["rr_pr"]
            if c then
                st["rr_pr"] = nil
                local cmd = safe(function() return sdk.to_managed_object(c.cmd) end)
                local act = cmd and safe(function() return cmd._ActInterName end) or "?"
                gate.pass_row[c.who] = gate.pass_row[c.who] or {}
                local ok = is_true(retval)
                gcount(gate.pass_row[c.who], act, ok)
                if c.who == "rancor" and not ok and config.medusa_force_pass then return sdk.to_ptr(1) end
            end
            return retval
        end)
    end
    for _, mm in ipairs(ttd and ttd:get_methods() or {}) do
        local n = mm:get_name()
        if n == "checkUniqueFlag" or n == "checkCommonFlag" then
            local p1 = safe(function() return mm:get_param_types()[1]:get_full_name() end)
            pcall(sdk.hook, mm, function(args)
                local st = thread.get_hook_storage()
                st["rr_fl"] = nil
                local a = sdk.to_int64(args[2])
                local who = study_by_tctrl[a] and "world" or (medusa_by_tctrl[a] and "rancor")
                if who then
                    local key = n
                    if p1 == "System.String" then
                        key = n .. " " .. tostring(safe(function() return sdk.to_managed_object(args[3]):ToString() end))
                    else
                        key = n .. " " .. tostring(sdk.to_int64(args[3]))
                    end
                    st["rr_fl"] = { who = who, key = key }
                end
            end, function(retval)
                local st = thread.get_hook_storage()
                local c = st and st["rr_fl"]
                if c then
                    st["rr_fl"] = nil
                    local t = (c.key:find("^checkUnique") and gate.uniq) or gate.common
                    t[c.who] = t[c.who] or {}
                    gcount(t[c.who], c.key, is_true(retval))
                end
                return retval
            end)
        end
    end
end

local function gate_summary(who)
    local out = {}
    for name, t in pairs({ ["pass-row"] = gate.pass_row[who], uniq = gate.uniq[who], common = gate.common[who] }) do
        local parts = {}
        for k, r in pairs(t or {}) do table.insert(parts, string.format("%s %d ok/%d no", k, r.t, r.f)) end
        table.sort(parts)
        if #parts > 0 then table.insert(out, "  " .. name .. ": " .. table.concat(parts, "; ")) end
    end
    return #out > 0 and table.concat(out, "\n") or "  (no gate calls seen)"
end

local function process_study(now)
    if not config.medusa_study and not next(study) then return end   -- v1.9.143: quiet Purgener entries count too
    if config.medusa_study and now - (study_scan_t or 0) >= 2 then
        study_scan_t = now
        if not next(study) then
            for _, m in ipairs(find_components("app.Monster")) do
                local go = safe(function() return m:call("get_GameObject") end)
                local name = go and safe(function() return go:call("get_Name") end) or ""
                if name:sub(1, 11) == "ch255000_01" and not medusa[go:get_address()] and not medusa_ever[go:get_address()] then
                    local chara = safe(function() return go:call("getComponent(System.Type)", sdk.typeof("app.Character")) end)
                    local hp0 = chara and safe(function() return chara:get_Hit():call("get_Hp") end)
                    if chara and type(hp0) == "number" and hp0 > 0 then
                        study[go:get_address()] = { go = go, chara = chara, name = name, started = now, next_log = 0 }
                        log("STUDY: watching world Medusa " .. name .. " (nothing is changed)")
                        break
                    end
                end
            end
        end
    end
    for addr, e in pairs(study) do
        if medusa[addr] then
            for _, k in ipairs(e.keys or {}) do study_by_ctrl[k] = nil; study_by_module[k] = nil; study_by_tctrl[k] = nil; study_by_ch2[k] = nil end
            study[addr] = nil
            log("STUDY: that Medusa belongs to the Rancor fight - not studying it")
            goto continue_study
        end
        do
        pcall(update_geo, e)
        if e.fb and e.fb.frame < frame_no - 2 then funnel_flush(e) end
        local ok = pcall(function()
            local c, m, t = addr_of(m_wpctrl(e.chara)), addr_of(m_module(e.chara)),
                addr_of(safe(function() return m_module(e.chara)._ThinkTableCtrl end))
            if c then study_by_ctrl[c] = e end
            if m then study_by_module[m] = e end
            if t then study_by_tctrl[t] = e end
            local c2 = addr_of(m_ch2(e.chara))
            if c2 then study_by_ch2[c2] = e end
            e.keys = { c, m, t, c2 }
        end)
        -- v1.9.143: a running pillar attempt - did it turn into a climb?
        do
            local pl = e.purg_pillar
            if pl and not pl.done then
                local act = tostring(safe(function() return e.chara["<ActionManager>k__BackingField"].CurrentAction:ToString() end) or "")
                if act:find("imbGimmick", 1, true) or act:find("Climb", 1, true) then
                    pl.done = true
                    log(string.format("Purgener pillar attempt #%d: it is climbing (%s)", pl.n, act))
                elseif now - pl.t > 25 then
                    pl.done = true
                    log(string.format("Purgener pillar attempt #%d ended without a climb (last action %s)", pl.n, act))
                end
            end
        end
        local hp = ok and safe(function() return e.chara:get_Hit():call("get_Hp") end)
        if not ok or hp == nil or hp <= 0 then
            if not e.quiet then log("STUDY: " .. (e.purgener and "Purgener" or "world Medusa") .. " gone. Gates seen:\n" .. gate_summary("world")) end
            if e.purgener then log("STUDY decision summary (Purgener): " .. medusa_trace_summary(e)) end
            funnel_flush(e)
            for _, k in ipairs(e.keys or {}) do study_by_ctrl[k] = nil; study_by_module[k] = nil; study_by_tctrl[k] = nil; study_by_ch2[k] = nil end
            study[addr] = nil
        elseif now >= e.next_log then
            e.next_log = now + 10
            if e.quiet then goto continue_study end
            local act = safe(function() return e.chara["<ActionManager>k__BackingField"].CurrentAction:ToString() end)
            local here, pp = upos_go(e.go), player_upos()
            log(string.format("STUDY +%.0fs: action %s, %.0f m from you, %d distinct spots seen",
                now - e.started, tostring(act), flat_dist(here, pp) or -1, e.nspots or 0))
            if now - (e.last_gate_log or e.started) >= 30 then
                e.last_gate_log = now
                log("STUDY gates (world Medusa):\n" .. gate_summary("world"))
            end
            log("STUDY state: " .. medusa_extra_state(e))
        end
        end
        ::continue_study::
    end
end

-- 7) v1.9.7: unique flags, navigation callbacks, decision funnel ----------------------------
local function who_tctrl(a)
    local e = study_by_tctrl[a]
    if e then return e, "STUDY" end
    if config.medusa_funnel then
        e = medusa_by_tctrl[a]
        if e then return e, "RANCOR" end
    end
    return nil
end
do
    -- (a) every row check: build the funnel line; also log passing rows for the Rancor Medusa
    local ttd = sdk.find_type_definition("app.ThinkTableController")
    local tm = ttd and ttd:get_method("isExecuteEmThkGeneralCommand")
    if tm then
        local ok = pcall(sdk.hook, tm, function(args)
            local st = thread.get_hook_storage()
            st["rr_fn"] = nil
            local e, prefix = who_tctrl(sdk.to_int64(args[2]))
            if not e then return end
            local ca, ta = sdk.to_int64(args[3]), sdk.to_int64(args[4])
            local lbl = fn_lbl[ca]
            if not lbl then
                local cmd = safe(function() return sdk.to_managed_object(args[3]) end)
                local act = cmd and safe(function() return cmd._ActInterName end) or "?"
                local jump = cmd and safe(function() return cmd.TableName end) or "?"
                local uq = cmd and safe(function() return cmd._UniqueFlag end)
                if type(uq) == "string" and uq ~= "" then
                    fn_uq[ca] = uq
                    uq_seen[uq] = true
                end
                if act == "ACT_INVALID" or act == "" then
                    lbl = { short = "->" .. fn_short(jump, 8), act = act, jump = jump }
                else
                    lbl = { short = fn_short(act, 12), act = act, jump = jump }
                end
                fn_lbl[ca] = lbl
            end
            local tname = fn_tbl[ta]
            if not tname then
                local tbl = safe(function() return sdk.to_managed_object(args[4]) end)
                tname = tbl and safe(function() return tbl.TableName end) or "?"
                fn_tbl[ta] = tname
            end
            local flags = nil
            if not e.fb or e.fb.frame ~= frame_no then
                local tco = safe(function() return sdk.to_managed_object(args[2]) end)
                local cf = safe(function() return e.chara.EnemyCtrl.Ch2._CommonFlags end)
                local np = tco and safe(function() return tco["<IsActNoPassFlag>k__BackingField"] end)
                if type(cf) == "number" then
                    flags = string.format("[EA%d DA%d NP%s]", (cf & 536870912) ~= 0 and 1 or 0,
                        (cf & 1073741824) ~= 0 and 1 or 0, np == true and "1" or (np == false and "0" or "?"))
                end
            end
            funnel_row_begin(e, prefix, tname, lbl.short .. (fn_uq[ca] and "{u}" or ""), flags)
            st["rr_fn"] = { e = e, prefix = prefix, lbl = lbl, tname = tname }
        end, function(retval)
            local st = thread.get_hook_storage()
            local c = st and st["rr_fn"]
            if c then
                st["rr_fn"] = nil
                local passed = is_true(retval)
                if not passed and c.prefix == "RANCOR" and c.lbl.jump == "柱に巻き付きに行く" and PILLAR_AI.try_start then
                    local okp, go_ok = pcall(PILLAR_AI.try_start, c.e)
                    if okp and go_ok then
                        funnel_cond(c.e, "Pillar+mod")
                        funnel_row_end(c.e, true)
                        return sdk.to_ptr(1)
                    end
                end
                -- v1.9.143 (user: the Purgener never attached to its pillar - 01:50 Devouring Rancor, its pillar-wrap /
                -- pillar-climb rows failed their unique-flag check all fight): same treatment as Medusa's coil row
                if not passed and c.e.purgener and PILLAR_AI.purg_try then
                    local okp2, go2 = pcall(PILLAR_AI.purg_try, c.e, c.lbl)
                    if okp2 and go2 then
                        funnel_cond(c.e, "Pillar+mod")
                        funnel_row_end(c.e, true)
                        return sdk.to_ptr(1)
                    end
                end
                funnel_row_end(c.e, passed)
                if passed and c.prefix == "RANCOR" then
                    local key = c.tname .. " | " .. tostring(c.lbl.act) .. " | goto " .. tostring(c.lbl.jump)
                    if key ~= c.e.last_row and not key:find("ACT_INVALID | goto NO_JUMP_TBL", 1, true) then
                        c.e.last_row = key
                        c.e.rowlogs = (c.e.rowlogs or 0) + 1
                        if c.e.rowlogs <= 250 then log("RANCOR think: " .. key .. fmt_geo(c.e)) end
                    end
                end
            end
            return retval
        end)
        if ok then medusa_hooks = medusa_hooks + 1 end
    end

    -- (b) conditions (the Rancor Medusa's range / route / find checks are tagged by their own hooks)
    local COND = {
        { "app.EmThkChkCheckTimer", "Timer", "ValueName", true },
        { "app.EmThkChkCheckBool", "Bool", "ValueName", true },
        { "app.EmThkChkCheckInt", "Int", "ValueName", true },
        { "app.EmThkChkCheckActionTimer", "ActTimer", nil, true },
        { "app.EmThkChkCh255MoveType", "MoveType", "CheckMoveType", true },
        { "app.EmThkChkCheckClimbedRegionType", "Climbed", nil, true },
        { "app.EmThkChkCh255000CheckStatus", "Status", "Status", true },
        { "app.EmThkChkCh255AttackRangeCheck", "Range", "TargetType", false },
        { "app.EmThkChkCh255CheckNowRouteInfo", "Route", "RouteFlag", false },
        { "app.EmThkChkCh255FindBattlePos", "FindPos", nil, false },
    }
    local fn_cond = {}
    for i, d in ipairs(COND) do
        local td = sdk.find_type_definition(d[1])
        local m = td and td:get_method("evaluate")
        if m then
            local key = "rr_fc" .. i
            local ok = pcall(sdk.hook, m, function(args)
                local st = thread.get_hook_storage()
                st[key] = nil
                local a = sdk.to_int64(args[3])
                local e = study_by_module[a]
                if not e and d[4] and config.medusa_funnel then e = medusa_by_module[a] end
                if e and e.f_cur then st[key] = { e = e, cond = args[2] } end
            end, function(retval)
                local st = thread.get_hook_storage()
                local c = st and st[key]
                if c then
                    st[key] = nil
                    local ca = sdk.to_int64(c.cond)
                    local tok = fn_cond[ca]
                    if not tok then
                        local cond = safe(function() return sdk.to_managed_object(c.cond) end)
                        local pv = d[3] and cond and safe(function() return cond[d[3]] end)
                        local isnot = cond and safe(function() return cond.IsNot end)
                        tok = (isnot and "NOT " or "") .. d[2] .. (pv ~= nil and (":" .. fn_short(tostring(pv), 8)) or "")
                        fn_cond[ca] = tok
                    end
                    local extra = (d[2] == "Range") and fmt_geo(c.e) or ""
                    funnel_cond(c.e, tok .. (is_true(retval) and "+" or "x") .. extra)
                end
                return retval
            end)
            if ok then medusa_hooks = medusa_hooks + 1 end
        end
    end

    -- (c) navigation finished callbacks of her waypoint controller (count only)
    local wtd = sdk.find_type_definition("app.Ch255BattleWayPointCtrl")
    for _, nm in ipairs({ "onWayNavigationComplete", "onSurfaceNavigationComplete" }) do
        local m = wtd and wtd:get_method(nm)
        if m then
            local ok = pcall(sdk.hook, m, function(args)
                local a = sdk.to_int64(args[2])
                local e = study_by_ctrl[a] or medusa_by_ctrl[a]
                if not e then return end
                local k = (nm == "onWayNavigationComplete") and "nav_way" or "nav_surf"
                e[k] = (e[k] or 0) + 1
                e.nav_logs = (e.nav_logs or 0) + 1
                if e.nav_logs <= 8 then
                    log(string.format("%s nav: %s (spot %s m away)", study_by_ctrl[a] and "STUDY" or "RANCOR", nm,
                        e.geo and e.bp and string.format("%.1f", flat_dist(e.geo.here, e.bp) or -1) or "?"))
                end
            end, function(retval) return retval end)
            if ok then medusa_hooks = medusa_hooks + 1 end
        end
    end

    -- (d) unique flags: after the game updates them, record which of her row flags are on and
    --     keep "...EnableChangeMoveAction" on for the Rancor Medusa (config medusa_force_uniq)
    local uq_hash = {}      -- flag string -> list of hashes
    local uq_retry
    local function resolve(tctrl, name)
        local v = uq_hash[name]
        if v then return v end
        local now = os.clock()
        uq_retry = uq_retry or {}
        if now - (uq_retry[name] or -100) < 2 then return nil end
        uq_retry[name] = now
        local dict = safe(function() return tctrl._CommandUniqueFalgsToHashSet end)
        if not dict then return nil end
        local ms = safe(function() return sdk.create_managed_string(name) end)
        if not ms then return nil end
        local has = safe(function() return dict:call("ContainsKey", ms) end)
        if has ~= true then return nil end
        local list = safe(function() return dict:call("get_Item", ms) end)
        local cnt = list and safe(function() return list:call("get_Count") end)
        local hs = {}
        for i = 0, (tonumber(cnt) or 0) - 1 do
            local h = safe(function() return list:call("get_Item", i) end)
            if h ~= nil then table.insert(hs, h) end
        end
        if #hs == 0 then return nil end
        uq_hash[name] = hs
        log(string.format("Unique flag '%s': %d hash(es) resolved", name, #hs))
        -- "A,B" -> hashes in the same order: learn A and B on their own too
        if name:find(",", 1, true) then
            local i = 0
            for raw in name:gmatch("[^,]+") do
                i = i + 1
                local part = raw:gsub("^%s+", ""):gsub("%s+$", "")
                if hs[i] and not uq_hash[part] then
                    uq_hash[part] = { hs[i] }
                    log(string.format("Unique flag '%s': hash learned from '%s'", part, name))
                end
            end
        end
        return hs
    end
    local function on_update_uq(e, tctrl, is_rancor)
        local set = safe(function() return tctrl._UniqueFlags end)
        if not set then return end
        e.uq_calls = (e.uq_calls or 0) + 1
        local now = os.clock()
        local sample = now - (e.uq_t or 0) >= 0.25
        if sample then e.uq_t = now end
        e.uq = e.uq or {}
        for name, _ in pairs(uq_seen) do
            local force = is_rancor and config.medusa_force_uniq and name == "Ch255EnableChangeMoveAction"
            if sample or force then
                local hs = resolve(tctrl, name)
                if hs then
                    local on = true
                    for _, h in ipairs(hs) do
                        if safe(function() return set:call("Contains", h) end) ~= true then on = false; break end
                    end
                    local r = e.uq[name] or { y = 0, n = 0, forced = 0 }
                    e.uq[name] = r
                    if sample then if on then r.y = r.y + 1 else r.n = r.n + 1 end end
                    if force and not on then
                        for _, h in ipairs(hs) do pcall(function() set:call("Add", h) end) end
                        r.forced = r.forced + 1
                        if r.forced == 1 then log("Medusa: keeping her '" .. name .. "' flag on (it was off)") end
                    end
                end
            end
        end
    end
    for _, tn in ipairs({ "app.Ch255", "app.Ch255000" }) do
        local td = sdk.find_type_definition(tn)
        local m = td and td:get_method("onUpdateUniqueFlag")
        if m then
            local key = "rr_uq" .. tn
            local ok = pcall(sdk.hook, m, function(args)
                local st = thread.get_hook_storage()
                st[key] = nil
                local a = sdk.to_int64(args[2])
                local e, r = study_by_ch2[a], false
                if not e then e, r = medusa_by_ch2[a], true end
                if e then st[key] = { e = e, mod = args[3], r = r } end
            end, function(retval)
                local st = thread.get_hook_storage()
                local c = st and st[key]
                if c then
                    st[key] = nil
                    if c.e.uq_frame ~= frame_no then
                        c.e.uq_frame = frame_no
                        local mod = safe(function() return sdk.to_managed_object(c.mod) end)
                        local tctrl = mod and safe(function() return mod._ThinkTableCtrl end)
                        if tctrl then pcall(on_update_uq, c.e, tctrl, c.r) end
                    end
                end
                return retval
            end)
            if ok then medusa_hooks = medusa_hooks + 1 end
        end
    end
end

-- 9) v1.9.9: aggression - her attack cooldown timers end early ---------------------------------
do
    local COOLDOWN = { ["汎用攻撃リロード"] = 15.0, ["蛇弓発射間隔"] = 9.0, ["石化光線リロード"] = 25.0 }
    local names = {}
    local td = sdk.find_type_definition("app.EmThkChkCheckTimer")
    local m = td and td:get_method("evaluate")
    if m then
        local ok = pcall(sdk.hook, m, function(args)
            local st = thread.get_hook_storage()
            st["rr_agg"] = nil
            if (config.medusa_aggression or 0) <= 0 then return end
            local e = medusa_by_module[sdk.to_int64(args[3])]
            if e and not e.purgener then st["rr_agg"] = { e = e, cond = args[2] } end
        end, function(retval)
            local st = thread.get_hook_storage()
            local c = st and st["rr_agg"]
            if c then
                st["rr_agg"] = nil
                local ca = sdk.to_int64(c.cond)
                local name = names[ca]
                if name == nil then
                    local cond = safe(function() return sdk.to_managed_object(c.cond) end)
                    local vn = cond and safe(function() return cond.ValueName end)
                    local ty = cond and safe(function() return cond.Type end)
                    name = (type(vn) == "string" and COOLDOWN[vn]) and vn or false
                    names[ca] = name
                end
                if name then
                    local e, now = c.e, os.clock()
                    e.cd = e.cd or {}
                    local r = e.cd[name]
                    if not r then r = { open = true }; e.cd[name] = r end
                    if is_true(retval) then
                        r.open = true
                    else
                        if r.open then r.open = false; r.start = now end
                        local need = COOLDOWN[name] * (1 - math.min(0.9, math.max(0, config.medusa_aggression)))
                        if now - (r.start or now) >= need then
                            r.open = true
                            e.cd_cut = (e.cd_cut or 0) + 1
                            if e.cd_cut <= 6 then log(string.format("Medusa aggression: '%s' cooldown cut short after %.1f s", name, now - r.start)) end
                            return sdk.to_ptr(1)
                        end
                    end
                end
            end
            return retval
        end)
        if ok then medusa_hooks = medusa_hooks + 1 end
    end
end

-- 8) v1.9.8: attack permission (EnableAttack) ------------------------------------------------
do
    local EA, DA = 536870912, 1073741824
    local function who_ch2(a)
        local e = study_by_ch2[a]
        if e then return e, false end
        e = medusa_by_ch2[a]
        if e then return e, true end
        return nil
    end
    local td = sdk.find_type_definition("app.Ch200000")
    local m = td and td:get_method("checkEnableAttack")
    if m then
        local ok = pcall(sdk.hook, m, function(args)
            local st = thread.get_hook_storage()
            st["rr_cea"] = nil
            local e, r = who_ch2(sdk.to_int64(args[2]))
            if e then st["rr_cea"] = { e = e, r = r } end
        end, function(retval)
            local st = thread.get_hook_storage()
            local c = st and st["rr_cea"]
            if c then
                st["rr_cea"] = nil
                local yes = is_true(retval)
                local e = c.e
                e.cea = e.cea or { y = 0, n = 0, forced = 0 }
                if yes then e.cea.y = e.cea.y + 1 else e.cea.n = e.cea.n + 1 end
                if not yes and c.r and config.medusa_force_attack then
                    e.cea.forced = e.cea.forced + 1
                    if e.cea.forced == 1 then log("Medusa: game said she may NOT attack (checkEnableAttack) - granting it") end
                    return sdk.to_ptr(1)
                end
            end
            return retval
        end)
        if ok then medusa_hooks = medusa_hooks + 1 end
    else
        log("Medusa: checkEnableAttack not found")
    end
    -- after the game recomputes her common flags, keep EnableAttack on / DisableAttack off
    for _, nm in ipairs({ "updateCommonAttackFlag", "onUpdateCommonFlag" }) do
        local um = td and td:get_method(nm)
        if um then
            local key = "rr_" .. nm
            local ok = pcall(sdk.hook, um, function(args)
                local st = thread.get_hook_storage()
                st[key] = nil
                local e, r = who_ch2(sdk.to_int64(args[2]))
                if e then st[key] = { e = e, r = r, this = args[2] } end
            end, function(retval)
                local st = thread.get_hook_storage()
                local c = st and st[key]
                if c then
                    st[key] = nil
                    local obj = safe(function() return sdk.to_managed_object(c.this) end)
                    local cf = obj and safe(function() return obj._CommonFlags end)
                    if type(cf) == "number" then
                        local e = c.e
                        e.cfl = e.cfl or { ea = 0, da = 0, n = 0, forced = 0 }
                        if nm == "updateCommonAttackFlag" then
                            e.cfl.n = e.cfl.n + 1
                            if (cf & EA) ~= 0 then e.cfl.ea = e.cfl.ea + 1 end
                            if (cf & DA) ~= 0 then e.cfl.da = e.cfl.da + 1 end
                        end
                        if c.r and config.medusa_force_attack and ((cf & EA) == 0 or (cf & DA) ~= 0) then
                            local nv = (cf | EA) & ~DA
                            if pcall(function() obj._CommonFlags = nv end) then
                                e.cfl.forced = e.cfl.forced + 1
                                if e.cfl.forced == 1 then log("Medusa: EnableAttack flag was off - turned it on (" .. nm .. ")") end
                            end
                        end
                    end
                end
                return retval
            end)
            if ok then medusa_hooks = medusa_hooks + 1 end
        end
    end
end

local function medusa_state(e)
    local p = safe(function()
        return m_module(e.chara)._ExecuteActInter["<ActInterPackData>k__BackingField"]:ToString()
    end)
    local pack = p and (string.match(p, "([^/]+)%.user") or p) or "?"
    local am = safe(function() return e.chara["<ActionManager>k__BackingField"] end)
    local act = am and safe(function() return am.CurrentAction:ToString() end)
    local pos = pos_of(e.go)
    local hp = safe(function() return e.chara:get_Hit():call("get_Hp") end)
    local tc = safe(function() return m_module(e.chara)._ThinkTableCtrl end)
    local tbl = tc and safe(function() return tc["<TopSelectThinkTable>k__BackingField"].TableName end)
    local last = tc and safe(function() return tc._ThkEndCommand._ActInterName end)
    local tco = safe(function() return m_module(e.chara)._TargetCtrl end)
    local ttype = tco and safe(function() return tco._TargetType end)
    local tdist = tco and safe(function() return tco._DistanceFromSelf end)
    local tdeg = tco and safe(function() return tco._DegreeToTarget end)
    act = tostring(act) .. string.format(" | target type %s at %s m, %s deg", tostring(ttype),
        type(tdist) == "number" and string.format("%.0f", tdist) or "?", type(tdeg) == "number" and string.format("%.0f", tdeg) or "?")
    act = act .. string.format(" | attack-range checks %d in / %d out", e.ar and e.ar.pass or 0, e.ar and e.ar.fail or 0)
    return string.format("HP %s, y=%s, %.0f m from you (spot %.0f m away), AI %s, pack %s, action %s, table %s, last pick %s, spots %d",
        hp and string.format("%.0f", hp) or "?", pos and string.format("%.1f", pos.y) or "?",
        dist3(pos, player_pos()) or -1, flat_dist(upos_go(e.go), e.bp) or -1,
        tostring(safe(function() return e.chara.CharaAIStateCtrl._AIState end)),
        pack, tostring(act), tostring(tbl), tostring(last), e.spots or 0)
end

local function register_medusa(go, chara, name, hydra)
    local e = { go = go, chara = chara, name = name, started = os.clock(), next_log = 0, hydra = hydra or nil }
    medusa[go:get_address()] = e
    medusa_ever[go:get_address()] = true
    log((hydra and "Hydra" or "Medusa") .. " registered: " .. name .. " (" .. medusa_hooks .. " Medusa hooks active"
        .. (hydra and "; her AI fixes only - no pillar, beam, frost, bow or head aim)" or ")"))
end

-- v1.9.157: a real Medusa (not the Hydra) in the fight - her pillar is only for her
function K.real_medusa()
    for _, e in pairs(medusa) do if not e.hydra then return true end end
    return false
end

local function process_medusa()
    local now = os.clock()
    if config.medusa_battle_pos and (not lair or lair.built < vortex_started_at
        or (now - lair.built > 20 and #walk_samples > (lair.samples or 0) + 10)) then pcall(build_lair) end
    -- stuck detection: no progress toward her spot for 5 s -> drop it
    for _, e in pairs(medusa) do
        local act = safe(function() return e.chara["<ActionManager>k__BackingField"].CurrentAction:ToString() end) or ""
        local moving = act:find("Run", 1, true) or act:find("Walk", 1, true)
        pcall(update_geo, e)
        if act:find("Attack", 1, true) then e.last_atk_t = now end
        if e.fb and e.fb.frame < frame_no - 2 then funnel_flush(e) end
        if not moving then e.prog_d, e.prog_t = nil, now end
        if e.bp and moving and e.reached_t and now - e.reached_t > 4 then
            e.bad_spots = e.bad_spots or {}
            e.bad_spots[e.bp] = true
            log("Medusa still running 4 s after arriving - new spot")
            e.bp, e.reached_t, e.prog_d = nil, nil, nil
            e.unstick_until = now + 3
        end
        if e.bp and moving and e.arrived_spot ~= e.bp then
            local da = flat_dist(upos_go(e.go), e.bp)
            if da and da < 4 then
                e.arrived_spot = e.bp
                e.reached_t = e.reached_t or now
                if e.bp_kind ~= "pillar" then e.unstick_until = now + 2 end
                e.arrivals = (e.arrivals or 0) + 1
                if e.arrivals <= 6 then log(string.format("Medusa arrived at her %s spot (%.1f m) - ending move so she re-decides", tostring(e.bp_kind), da)) end
            end
        end
        if e.bp and not e.reached_t and moving then
            local d = flat_dist(upos_go(e.go), e.bp)
            if d then
                if not e.prog_d or d < e.prog_d - 1 then e.prog_d, e.prog_t = d, now
                elseif now - (e.prog_t or now) > 5 then
                    e.bad_spots = e.bad_spots or {}
                    e.bad_spots[e.bp] = true
                    e.bad_list = e.bad_list or {}
                    table.insert(e.bad_list, { p = e.bp, t = now })
                    e.stuck = (e.stuck or 0) + 1
                    log(string.format("Medusa stuck %.0f m from her %s spot for 5 s - dropping it (#%d)", d, tostring(e.bp_kind), e.stuck))
                    if e.bp_kind == "pillar" and e.pillar then e.pillar.done = true end
                    e.bp, e.prog_d = nil, nil
                    e.unstick_until = now + 3
                end
            end
        end
    end
    for addr, e in pairs(medusa) do
        local ok = pcall(function()
            -- keep the lookup tables current (controllers can be created after spawn)
            local b, c, m = addr_of(m_beads(e.chara)), addr_of(m_wpctrl(e.chara)), addr_of(m_module(e.chara))
            if b then medusa_by_beads[b] = e end
            if c then medusa_by_ctrl[c] = e end
            if m then medusa_by_module[m] = e end
            local t = addr_of(safe(function() return m_module(e.chara)._ThinkTableCtrl end))
            if t then medusa_by_tctrl[t] = e end
            local tg = addr_of(safe(function() return m_module(e.chara)._TargetCtrl end))
            if tg then medusa_by_tc[tg] = e end
            local c2 = addr_of(m_ch2(e.chara))
            if c2 then medusa_by_ch2[c2] = e end
            e.keys = { b, c, m, t, tg, c2 }
            if config.medusa_fixes then
                local ch2 = m_ch2(e.chara)
                if ch2 and safe(function() return ch2._AlwaysCombatModeFlag end) == -1 then ch2._AlwaysCombatModeFlag = 0 end
                if not e.snake_done and now - e.started >= 3.0 then
                    e.snake_done = true
                    log("Medusa snake-body switch: " .. snake_switch(e))
                end
                if config.medusa_battle_pos then
                    -- is FreePosition01 really on her spot now? if not, fall back to the player redirect
                    local tc = safe(function() return m_module(e.chara)._TargetCtrl end)
                    if e.fp_bad and tc then
                        -- while redirected she never aims at 25, so check the slot itself
                        local slot = safe(function() return tc._TargetArray:get_element(25)._Position end)
                        local sp = slot and { x = safe(function() return slot.x end) or 0,
                            y = safe(function() return slot.y end) or 0, z = safe(function() return slot.z end) or 0 }
                        local sd = sp and dist3(sp, upos_go(e.go))
                        if sd and sd < 80 then
                            e.fp_bad = false; e.fp_far = 0
                            log(string.format("Medusa: FreePosition01 slot now %.0f m away - player redirect off", sd))
                        end
                    end
                    if tc and safe(function() return tc._TargetType end) == 25 then
                        local d = safe(function() return tc._DistanceFromSelf end)
                        if type(d) == "number" then
                            if d > 80 then
                                e.fp_far = (e.fp_far or 0) + 1
                                if e.fp_far >= 20 and not e.fp_bad then
                                    e.fp_bad = true
                                    log(string.format("Medusa: FreePosition01 still %.0f m away - using player redirect", d))
                                end
                            else
                                e.fp_far = 0
                                if e.fp_bad then e.fp_bad = false; log("Medusa: spot holds again - player redirect off") end
                                if not e.fp_ok_logged then
                                    e.fp_ok_logged = true
                                    log(string.format("Medusa: FreePosition01 is on her battle spot (%.0f m away)", d))
                                end
                            end
                        end
                    end
                end
                if e.snake_done and now - e.started >= 6.0 and now - (e.last_push or 0) >= 2.0 then
                    e.last_push = now
                    push_combat(e)
                end
            end
        end)
        local hp = ok and safe(function() return e.chara:get_Hit():call("get_Hp") end)
        if ok and hp == nil then e.missing = (e.missing or 0) + 1 else e.missing = 0 end
        if not ok or (hp and hp <= 0) or (e.missing or 0) > 8 then
            log("Medusa gone: " .. e.name .. (ok and " (killed)" or " (despawned)"))
            funnel_flush(e)
            log("Medusa decision summary: " .. medusa_trace_summary(e))
            log("Medusa gates (Rancor Medusa):\n" .. gate_summary("rancor"))
            for _, k in ipairs(e.keys or {}) do
                medusa_by_beads[k] = nil; medusa_by_ctrl[k] = nil; medusa_by_module[k] = nil; medusa_by_tctrl[k] = nil; medusa_by_tc[k] = nil; medusa_by_ch2[k] = nil
            end
            medusa[addr] = nil
        elseif now >= e.next_log then
            log("Medusa +" .. string.format("%.0f", now - e.started) .. "s: " .. medusa_state(e))
            log("  " .. medusa_extra_state(e))
            e.next_log = now + ((now - e.started) < 30 and 5.0 or 15.0)
            if now - (e.last_summary or e.started) >= 20 then
                e.last_summary = now
                log("Medusa decision summary: " .. medusa_trace_summary(e))
                log("Medusa gates (Rancor Medusa):\n" .. gate_summary("rancor"))
            end
        end
    end
end

-- 10) v1.9.11: "Norgan frost" look for Rancor Medusas (visual only) -------------------------
-- Material parameters of her model are changed per instance (via.render.Mesh), so only the
-- Medusas this mod spawns get it. Originals are kept so turning it off restores them.
-- First time a Medusa is seen, every mesh / material / parameter is written to
-- data/RancorReinforcements_medusa_materials.txt so the look can be tuned by name.
local process_frost
do
local MAT_FILE = "RancorReinforcements_medusa_materials.txt"
local MESH_TD = sdk.find_type_definition("via.render.Mesh")
local F4_TD = sdk.find_type_definition("via.Float4")
local mat_scan_done = false
local mesh_api = {}
do
    local names = {}
    for _, m in ipairs(MESH_TD and MESH_TD:get_methods() or {}) do
        local n = m:get_name()
        if n:find("Material", 1, true) then
            local ps = {}
            for _, t in ipairs(safe(function() return m:get_param_types() end) or {}) do table.insert(ps, t:get_full_name()) end
            local rt = safe(function() return m:get_return_type():get_full_name() end) or "?"
            table.insert(names, string.format("%s(%s) -> %s", n, table.concat(ps, ", "), rt))
            mesh_api[n] = mesh_api[n] or m
        end
    end
    mesh_api._list = names
end

local function mesh_components(go)
    local out = {}
    local function visit(tr, depth)
        if not tr or depth > 5 then return end
        local g = safe(function() return tr:call("get_GameObject") end)
        local mesh = g and safe(function() return g:call("getComponent(System.Type)", sdk.typeof("via.render.Mesh")) end)
        if mesh then table.insert(out, { mesh = mesh, name = safe(function() return g:call("get_Name") end) or "?" }) end
        local child = safe(function() return tr:call("get_Child") end)
        local guard = 0
        while child and guard < 64 do
            visit(child, depth + 1)
            child = safe(function() return child:call("get_Next") end)
            guard = guard + 1
        end
    end
    visit(safe(function() return go:call("get_Transform") end), 0)
    return out
end

local function mcall(mesh, name, ...)
    local args = { ... }
    return safe(function() return mesh:call(name, table.unpack(args)) end)
end

-- read every parameter of every material: { [mi] = { name=, vars = { [vi] = {name=, type=, f=, f4=} } } }
local function read_materials(mesh)
    local mats = {}
    local n = tonumber(mcall(mesh, "get_MaterialNum") or mcall(mesh, "getMaterialNum")) or 0
    for mi = 0, n - 1 do
        local mat = { name = tostring(mcall(mesh, "getMaterialName", mi)), vars = {} }
        local vn = tonumber(mcall(mesh, "getMaterialVariableNum", mi)) or 0
        for vi = 0, vn - 1 do
            local v = { name = tostring(mcall(mesh, "getMaterialVariableName", mi, vi)),
                        type = mcall(mesh, "getMaterialVariableType", mi, vi) }
            if v.type == 1 then
                v.f = mcall(mesh, "getMaterialFloat", mi, vi)
            elseif v.type == 4 then
                local f4 = mcall(mesh, "getMaterialFloat4", mi, vi)
                if f4 then v.f4 = { vfield(f4, "x"), vfield(f4, "y"), vfield(f4, "z"), vfield(f4, "w") } end
            end
            mat.vars[vi] = v
        end
        mats[mi] = mat
    end
    return mats
end

local function scan_to_file(e, meshes)
    local lines = { "Rancor Reinforcements - Medusa material scan (" .. os.date() .. ")", "",
                    "via.render.Mesh material methods:" }
    for _, l in ipairs(mesh_api._list or {}) do table.insert(lines, "  " .. l) end
    table.insert(lines, "")
    for _, m in ipairs(meshes) do
        table.insert(lines, "MESH on GameObject " .. m.name)
        for mi, mat in pairs(m.orig or {}) do
            table.insert(lines, string.format("  material %d: %s", mi, mat.name))
            for vi, v in pairs(mat.vars) do
                local val = ""
                if type(v.f) == "number" then val = string.format(" = %.3f", v.f)
                elseif v.f4 then val = string.format(" = (%.3f, %.3f, %.3f, %.3f)", v.f4[1] or 0, v.f4[2] or 0, v.f4[3] or 0, v.f4[4] or 0) end
                table.insert(lines, string.format("    [%d] %s (type %s)%s%s", vi, v.name, tostring(v.type), val,
                    v.role and ("   <- frost: " .. v.role) or ""))
            end
        end
    end
    pcall(fs.write, MAT_FILE, table.concat(lines, "\n"))
end

-- which parameters the frost look changes, by name
local function frost_role(v)
    local n = (v.name or ""):lower()
    if v.type == 4 and v.f4 then
        if n:find("emissive") or n:find("emission") then return "glow" end
        if n:find("subsurface") or n:find("sss") then return "sss" end
        if (n:find("basecolor") or n:find("albedo") or n:find("diffuse") or n:find("_color") or n:find("^color")
            or n:find("tint")) and not (n:find("fresnel") or n:find("rim") or n:find("spec") or n:find("mask")) then
            return "tint"
        end
    elseif v.type == 1 and type(v.f) == "number" then
        if n:find("rough") then return "rough" end
        if n:find("metal") then return "metal" end
        if (n:find("emissive") or n:find("emission")) and (n:find("intensity") or n:find("power") or n:find("scale")) then
            return "glowpow"
        end
    end
    return nil
end

local function set_f4(mesh, mi, vi, x, y, z, w)
    return pcall(function()
        local v = ValueType.new(F4_TD)
        v:set_field("x", x); v:set_field("y", y); v:set_field("z", z); v:set_field("w", w)
        mesh:call("setMaterialFloat4", mi, vi, v)
    end)
end
local function set_f(mesh, mi, vi, x)
    return pcall(function() mesh:call("setMaterialFloat", mi, vi, x) end)
end
local function lerp(a, b, t) return a + (b - a) * t end

local function apply_frost(e, on)
    local meshes = e.frost_meshes
    if not meshes then
        meshes = mesh_components(e.go)
        if #meshes == 0 then
            if not e.frost_nomesh then e.frost_nomesh = true; log("Medusa look: no mesh found on her yet - will retry") end
            return 0
        end
        for _, m in ipairs(meshes) do
            m.orig = read_materials(m.mesh)
            for _, mat in pairs(m.orig) do
                for _, v in pairs(mat.vars) do v.role = frost_role(v) end
            end
        end
        e.frost_meshes = meshes
        local nm, nv = 0, 0
        for _, m in ipairs(meshes) do
            for _, mat in pairs(m.orig) do
                nm = nm + 1
                for _, v in pairs(mat.vars) do if v.role then nv = nv + 1 end end
            end
        end
        log(string.format("Medusa look: %d mesh(es), %d material(s), %d parameter(s) the frost look can change (list: data/%s)",
            #meshes, nm, nv, MAT_FILE))
        if not mat_scan_done then mat_scan_done = true; scan_to_file(e, meshes) end
    end
    local s = math.max(0, math.min(1, config.medusa_frost_strength or 0.8))
    local tr, tg, tb = config.medusa_frost_r or 0.80, config.medusa_frost_g or 0.90, config.medusa_frost_b or 1.0
    local glow = math.max(0, config.medusa_frost_glow or 0.4)
    local changed = 0
    for _, m in ipairs(meshes) do
        for mi, mat in pairs(m.orig) do
            for vi, v in pairs(mat.vars) do
                if v.role then
                    local ok
                    if not on then
                        if v.f4 then ok = set_f4(m.mesh, mi, vi, v.f4[1] or 0, v.f4[2] or 0, v.f4[3] or 0, v.f4[4] or 1)
                        elseif type(v.f) == "number" then ok = set_f(m.mesh, mi, vi, v.f) end
                    elseif v.role == "tint" then
                        local r, g, b, a = v.f4[1] or 1, v.f4[2] or 1, v.f4[3] or 1, v.f4[4] or 1
                        local luma = math.min(1.0, (0.3 * r + 0.59 * g + 0.11 * b) * 1.35 + 0.15)
                        ok = set_f4(m.mesh, mi, vi, lerp(r, luma * tr, s), lerp(g, luma * tg, s), lerp(b, luma * tb, s), a)
                    elseif v.role == "sss" then
                        local r, g, b, a = v.f4[1] or 0, v.f4[2] or 0, v.f4[3] or 0, v.f4[4] or 1
                        ok = set_f4(m.mesh, mi, vi, lerp(r, 0.55, s), lerp(g, 0.75, s), lerp(b, 1.0, s), a)
                    elseif v.role == "glow" then
                        local r, g, b, a = v.f4[1] or 0, v.f4[2] or 0, v.f4[3] or 0, v.f4[4] or 1
                        ok = set_f4(m.mesh, mi, vi, lerp(r, 0.35 * glow, s), lerp(g, 0.75 * glow, s), lerp(b, 1.0 * glow, s), a)
                    elseif v.role == "glowpow" then
                        ok = set_f(m.mesh, mi, vi, v.f + glow * s * 2)
                    elseif v.role == "rough" then
                        ok = set_f(m.mesh, mi, vi, lerp(v.f, 0.85, s * 0.8))
                    elseif v.role == "metal" then
                        ok = set_f(m.mesh, mi, vi, lerp(v.f, 0.0, s))
                    end
                    if ok then changed = changed + 1 end
                end
            end
        end
    end
    if not e.frost_logged then
        e.frost_logged = true
        log(string.format("Medusa look: frost %s - %d parameter(s) set", on and "applied" or "removed", changed))
    end
    return changed
end

local frost_last = 0
process_frost = function()
    local now = os.clock()
    if now - frost_last < 1.0 then return end
    frost_last = now
    for _, e in pairs(medusa) do
        local want = config.medusa_frost and not e.hydra and true or false   -- v1.9.157: never on the Hydra
        -- re-apply every second while on (cheap); restore once when switched off
        if want then
            if now - e.started >= 1.0 then
                local ok, err = pcall(apply_frost, e, true)
                if not ok and not e.frost_err then e.frost_err = true; log("Medusa look error: " .. tostring(err)) end
                e.frost_on = true
            end
        elseif e.frost_on then
            pcall(apply_frost, e, false)
            e.frost_on = false
        end
    end
end

end -- frost module

-- 11) v1.9.12: petrify beam - more often (and research dump for beam size / petrify build-up) --
-- (a) Her beam unlocks after 2 attacks (think value "蛇弓カウント" >= 2). For Rancor Medusas that
--     check also passes once medusa_beam_interval seconds have gone by since her last beam.
-- (b) Research (log only): the first Rancor Medusa writes data/RancorReinforcements_petrify_dump.txt
--     (her petrification control + parameter file, your status-condition controller, the method
--     lists), and counts which petrification / status methods the game calls during the fight.
do
    local names = {}
    local td = sdk.find_type_definition("app.EmThkChkCheckInt")
    local m = td and td:get_method("evaluate")
    if m then
        local ok = pcall(sdk.hook, m, function(args)
            local st = thread.get_hook_storage()
            st["rr_bint"] = nil
            if (config.medusa_beam_interval or 0) <= 0 then return end
            local e = medusa_by_module[sdk.to_int64(args[3])]
            if e and not e.purgener and not e.hydra then st["rr_bint"] = { e = e, cond = args[2] } end
        end, function(retval)
            local st = thread.get_hook_storage()
            local c = st and st["rr_bint"]
            if c then
                st["rr_bint"] = nil
                local ca = sdk.to_int64(c.cond)
                local hit = names[ca]
                if hit == nil then
                    local cond = safe(function() return sdk.to_managed_object(c.cond) end)
                    local vn = cond and safe(function() return cond.ValueName end)
                    local ct = cond and safe(function() return cond.CompareType end)
                    hit = (vn == "蛇弓カウント" and ct == 2) and true or false
                    names[ca] = hit
                end
                if hit and not is_true(retval) then
                    local e, now = c.e, os.clock()
                    if now - (e.last_beam_t or e.started) >= config.medusa_beam_interval then
                        e.beam_unlock = (e.beam_unlock or 0) + 1
                        if e.beam_unlock <= 5 then
                            log(string.format("Medusa: petrify beam unlocked early (%.0f s since her last beam)", now - (e.last_beam_t or e.started)))
                        end
                        return sdk.to_ptr(1)
                    end
                end
            end
            return retval
        end)
        if ok then medusa_hooks = medusa_hooks + 1 end
    end
end

local process_petrify
local process_petrify_extra
local PX = {}   -- pillar research functions

-- v1.9.101: Golem ------------------------------------------------------------------------
-- * size: the spawn record's ScaleRate (2.0) did nothing visible on the Golem, so its Transform scale is set too
-- * HP: it dies when every medallion breaks, whatever its main HP - so golem_hp is shared out over the medallions.
--   Medallions = HitController regions other than 0 that have their own HP (all dumped to a file the first time).
PX.GOLEM_FILE = "RancorReinforcements_golem_regions.txt"
function PX.obj_fields(o, out, prefix, max)
    local td = o and safe(function() return o:get_type_definition() end)
    local n = 0
    while td and n < (max or 80) do
        local tn = td:get_full_name()
        if tn == "System.Object" or tn == "via.Component" or tn == "via.clr.ManagedObject" then break end
        for _, f in ipairs(td:get_fields() or {}) do
            if not f:is_static() then
                n = n + 1
                local v = safe(function() return o:get_field(f:get_name()) end)
                local tv = type(v)
                local sv = (tv == "number" or tv == "boolean" or tv == "string") and tostring(v)
                    or (v ~= nil and safe(function() return v:get_type_definition():get_full_name() end)) or tostring(v)
                table.insert(out, string.format("%s%s : %s = %s", prefix, f:get_name(), f:get_type():get_full_name(), tostring(sv)))
            end
        end
        td = td:get_parent_type()
    end
end
function PX.list_elems(v)
    if not v then return nil end
    local el = safe(function() return v:get_elements() end)
    if el then return el end
    local c = safe(function() return v:call("get_Count") end)
    if type(c) ~= "number" then return nil end
    local t = {}
    for i = 0, c - 1 do t[#t + 1] = safe(function() return v:call("get_Item", i) end) end
    return t
end
-- the region-status list (its length = how many regions the HitController has)
function PX.golem_regions(hit)
    local out = {}
    local ctrl = safe(function() return hit["<RegionStatusCtrl>k__BackingField"] end)
        or safe(function() return hit["<CachedRegionStatusCtrl>k__BackingField"] end)
    local best, best_name
    for _, src in ipairs({ ctrl, hit }) do
        local td = src and safe(function() return src:get_type_definition() end)
        while td and not best do
            for _, f in ipairs(td:get_fields() or {}) do
                local ftn = f:get_type():get_full_name()
                if not f:is_static() and ftn:find("RegionStatus", 1, true) and (ftn:find("[]", 1, true) or ftn:find("List`1", 1, true)) then
                    local el = PX.list_elems(safe(function() return src:get_field(f:get_name()) end))
                    if el and #el > 0 then best, best_name = el, f:get_name() .. " (" .. ftn .. ")"; break end
                end
            end
            td = td:get_parent_type()
            if td and td:get_full_name() == "System.Object" then break end
        end
        if best then break end
    end
    return best, best_name, ctrl
end
function PX.golem_setup(t) return PX.points_setup(t, "golem") end

-- v1.9.119: Evil Eye ground tentacles (its parts ch270011-ch270032, app.Ch272000) cast fire / ice / thunder spells.
-- While one of them is in a casting action it is turned toward you (like Medusa's beam and the Dragon's breath),
-- eye_parts_aim deg/s. Every action they use is logged once (to learn the spell names), plus the aim error at cast start.
PX.PARTS = { list = {}, scan_t = 0, acts = {}, nacts = 0 }
PX.PARTS_QTD = sdk.find_type_definition("via.Quaternion")
PX.SPELL_WORDS = { "fire", "ice", "thunder", "spell", "magic", "shot", "beam", "breath", "cast", "lightning", "flame", "frost", "bullet", "orb", "ball", "laser", "missile", "mine" }
function PX.parts_scan()
    local list = {}
    local eye = false
    for _, t in pairs(K.TRACKED or {}) do if t.name:sub(1, #K.EYE_ID) == K.EYE_ID then eye = true; break end end
    -- v1.9.137 (user): the ground tentacle minions (turrets, ch272001 / ch272002) are aimed at you while they cast too
    local turrets = (event.tentacles or 0) > 0
    if (eye or turrets) and vortex_now then
        for _, m in ipairs(find_components("app.Monster")) do
            local go = safe(function() return m:call("get_GameObject") end)
            local name = go and safe(function() return go:call("get_Name") end)
            if name and (name:match("^ch2700[1-3]%d") or name:match("^ch27200[12]")) then
                local a = go:get_address()
                local old = PX.PARTS.list[a]
                list[a] = old or { go = go, name = name,
                    chara = safe(function() return go:call("getComponent(System.Type)", sdk.typeof("app.Character")) end) }
            end
        end
    end
    PX.PARTS.list = list
end
function PX.parts_late(dt)
    local rate = tonumber(config.eye_parts_aim) or 0
    local now = os.clock()
    if now - PX.PARTS.scan_t > 0.25 then PX.PARTS.scan_t = now; pcall(PX.parts_scan) end
    if not next(PX.PARTS.list) then return end
    -- v1.9.140: tentacles are only turned while an Evil Eye of ours is alive (or for ground tentacles, while they are),
    -- and the list is dropped the moment the Eye is gone, so nothing is ever touched while the game takes them apart
    local eye_alive = false
    for _, t in pairs(K.TRACKED or {}) do
        if t.name and t.name:sub(1, #K.EYE_ID) == K.EYE_ID then
            local hp = safe(function() return t.chara:get_Hit():call("get_Hp") end)
            if hp and hp > 0 then eye_alive = true; break end
        end
    end
    if not eye_alive and (event.tentacles or 0) == 0 then PX.PARTS.list = {}; return end
    local pp = player_upos()
    for _, p in pairs(PX.PARTS.list) do
        local php = p.chara and safe(function() return p.chara:get_Hit():call("get_Hp") end)
        local attached = p.name:match("^ch2700[1-3]%d") ~= nil
        if (attached and not eye_alive) or not php or php <= 0 then goto next_part end
        do
        local act = p.chara and safe(function() return p.chara["<ActionManager>k__BackingField"].CurrentAction:ToString() end) or ""
        if act ~= p.act then
            p.act = act
            if act ~= "" and not PX.PARTS.acts[act] then
                PX.PARTS.acts[act] = true
                PX.PARTS.nacts = PX.PARTS.nacts + 1
                if PX.PARTS.nacts <= 80 then log("Eye tentacle action #" .. PX.PARTS.nacts .. ": " .. act .. " (" .. p.name .. ")") end
            end
            if p.casting and p.cast_err1 then
                PX.PARTS.ends = (PX.PARTS.ends or 0) + 1
                if PX.PARTS.ends <= 25 then log(string.format("Eye tentacle %s cast over: %.0f deg off you at the end", p.name, math.deg(p.cast_err1))) end
            end
            p.cast_err1 = nil
            p.casting, p.cast_logged = false, false
            local low = act:lower()
            for _, w in ipairs(PX.SPELL_WORDS) do if low:find(w, 1, true) then p.casting = true; break end end
        end
        if p.casting and rate > 0 and pp then
            local tr = safe(function() return p.go:call("get_Transform") end)
            local here = tr and upos_tr(tr)
            local qv = tr and safe(function() return tr:call("get_Rotation") end)
            local ax = tr and safe(function() return tr:call("get_AxisZ") end)
            local fx, fz = ax and safe(function() return ax.x end), ax and safe(function() return ax.z end)
            if here and qv and type(fx) == "number" then
                local dx, dz = pp.x - here.x, pp.z - here.z
                local face = math.atan(fx, fz)
                local err = math.atan(dx, dz) - face
                err = (err + math.pi) % (2 * math.pi) - math.pi
                if not p.cast_logged then
                    p.cast_logged = true
                    PX.PARTS.casts = (PX.PARTS.casts or 0) + 1
                    if PX.PARTS.casts <= 25 then
                        log(string.format("Eye tentacle %s casting %s: %.0f deg off you, %.0f m away - turning it toward you", p.name, act,
                            math.deg(err), math.sqrt(dx * dx + dz * dz)))
                    end
                end
                -- v1.9.131: the turn direction is checked right after each turn (same frame, before its animation runs
                -- again) and settled once for good. The old next-frame check measured the animation instead and flipped
                -- the direction 1,754 times in one fight (18:22), so the tentacles jittered instead of turning.
                p.cast_err1 = err
                if math.abs(err) > math.rad(2) then
                    local mx = math.rad(rate) * dt
                    local th = math.max(-mx, math.min(mx, err))
                    p.prev_face, p.prev_th = face, th
                    th = th * (PX.PARTS.sign or 1)
                    local q = { x = vfield(qv, "x"), y = vfield(qv, "y"), z = vfield(qv, "z"), w = vfield(qv, "w") }
                    local sn, cs = math.sin(th / 2), math.cos(th / 2)
                    pcall(function()
                        local v = ValueType.new(PX.PARTS_QTD)
                        v:set_field("x", cs * q.x + sn * q.z); v:set_field("y", cs * q.y + sn * q.w)
                        v:set_field("z", cs * q.z - sn * q.x); v:set_field("w", cs * q.w - sn * q.y)
                        tr:call("set_Rotation", v)
                    end)
                    if not PX.PARTS.sign_locked then
                        local ax2 = safe(function() return tr:call("get_AxisZ") end)
                        local fx2, fz2 = ax2 and safe(function() return ax2.x end), ax2 and safe(function() return ax2.z end)
                        if type(fx2) == "number" then
                            local moved = ((math.atan(fx2, fz2) - face) + math.pi) % (2 * math.pi) - math.pi
                            if math.abs(moved) > 1e-5 then
                                PX.PARTS.sv = (PX.PARTS.sv or 0) + ((moved * p.prev_th > 0) and 1 or -1)
                                if math.abs(PX.PARTS.sv) >= 6 then
                                    if PX.PARTS.sv < 0 then PX.PARTS.sign = -(PX.PARTS.sign or 1) end
                                    PX.PARTS.sign_locked = true
                                    log("Eye tentacle aim: turn direction settled (" .. (PX.PARTS.sv < 0 and "reversed" or "as is") .. ")")
                                end
                            end
                        end
                    end
                else
                    p.prev_face, p.prev_th = nil, nil
                end
            end
        end
        end   -- do (v1.9.140)
        ::next_part::
    end
end
-- v1.9.112: what each mod Evil Eye body looks like to the game (visibility research)
function PX.eye_vis_report(why)
    K.EYE_VIS_N = (K.EYE_VIS_N or 0) + 1
    if K.EYE_VIS_N > 40 then return end
    local parts = {}
    for _, t in pairs(K.TRACKED or {}) do
        if t.name:sub(1, #K.EYE_ID) == K.EYE_ID and t.go then
            local ch = safe(function() return t.go:call("getComponent(System.Type)", sdk.typeof("app.Ch270")) end)
            local draw = safe(function() return t.go:call("get_DrawSelf") end)
            local upd = safe(function() return t.go:call("get_UpdateSelf") end)
            local host = ch and safe(function() return ch:call("get_IsWarpHost") end)
            local guest = ch and safe(function() return ch:call("get_IsGuestOnStart") end)
            local wm = ch and safe(function() return ch:call("get_IsWarpMode") end)
            local ia = ch and safe(function() return ch:call("get_InvisibleAreaCtrl") end)
            local iaf = {}
            if ia then
                local tmp = {}
                PX.obj_fields(ia, tmp, "", 30)
                for _, l in ipairs(tmp) do if l:find("Boolean", 1, true) or l:find("Int32", 1, true) then table.insert(iaf, (l:gsub(" : System%.%w+", ""))) end end
            end
            local hp = safe(function() return t.chara:get_Hit():call("get_Hp") end)
            local d = dist3(pos_of(t.go), player_pos())
            table.insert(parts, string.format("%s: draw %s, update %s, warpHost %s, guestOnStart %s, warpMode %s, HP %s, %.0f m | invisibleArea {%s}",
                t.name, tostring(draw), tostring(upd), tostring(host), tostring(guest), tostring(wm), tostring(hp and math.floor(hp)), d or -1,
                table.concat(iaf, "; ")))
        end
    end
    log("Evil Eye bodies (" .. why .. "):\n    " .. table.concat(parts, "\n    "))
end

-- v1.9.110: Evil Eye warp research (goal: a "virtual lair" - warp spots inside the arena, like Medusa's battle spots).
-- (1) at load: every type reachable from app.Ch27WarpPointRequester / Ch270PartsWarpController whose name mentions Warp
--     -> data/RancorReinforcements_eye_warp_types.txt
-- (2) when a mod Evil Eye spawns: its live WarpPointRequester (fields, lists, positions) -> data/RancorReinforcements_eye_warp_live.txt
-- (3) every WarpPointRequester method call on it is counted and the first 3 of each logged (which ones pick the spot)
PX.EYE_WARP_TYPES = { "app.Ch27WarpPointRequester", "app.Ch270PartsWarpController", "app.Ch27WarpIntensityParameter" }
function PX.type_dump()
    local out, seen, queue = {}, {}, {}
    for _, tn in ipairs(PX.EYE_WARP_TYPES) do table.insert(queue, { tn, 0 }) end
    while #queue > 0 do
        local q = table.remove(queue, 1)
        local tn, depth = q[1], q[2]
        if not seen[tn] then
            seen[tn] = true
            local td = sdk.find_type_definition(tn)
            local par = td and safe(function() return td:get_parent_type():get_full_name() end) or "-"
            table.insert(out, "== " .. tn .. (td and ("  (parent " .. par .. ")") or "  (not found)"))
            local function want(n) return depth < 2 and n and n:find("Warp", 1, true) and not seen[n] end
            for _, f in ipairs(td and (safe(function() return td:get_fields() end) or {}) or {}) do
                local ftn = safe(function() return f:get_type():get_full_name() end) or "?"
                table.insert(out, string.format("  field %s%s : %s", f:is_static() and "static " or "", f:get_name(), ftn))
                local inner = ftn:match("<(app%.[%w%.]+)>") or ftn:match("^(app%.[%w%.]+)%[%]$") or ftn
                if want(inner) then table.insert(queue, { inner, depth + 1 }) end
            end
            for _, m in ipairs(td and (safe(function() return td:get_methods() end) or {}) or {}) do
                local ps = {}
                for _, pt in ipairs(safe(function() return m:get_param_types() end) or {}) do
                    local n = safe(function() return pt:get_full_name() end) or "?"
                    table.insert(ps, n)
                    if want(n) then table.insert(queue, { n, depth + 1 }) end
                end
                local rt = safe(function() return m:get_return_type():get_full_name() end) or "?"
                if want(rt) then table.insert(queue, { rt, depth + 1 }) end
                table.insert(out, string.format("  method %s(%s) -> %s", m:get_name(), table.concat(ps, ", "), rt))
            end
        end
    end
    pcall(fs.write, "RancorReinforcements_eye_warp_types.txt", table.concat(out, "\n"))
    return #out
end
PX.EYE_WARP_CALLS = {}
PX.EYE_WARP_OBJS = {}
do
    local n = (not K.RELEASE) and safe(PX.type_dump)
    local td = (not K.RELEASE) and sdk.find_type_definition("app.Ch27WarpPointRequester")
    local hooked = 0
    for _, m in ipairs(td and td:get_methods() or {}) do
        local mn = m:get_name()
        local low = mn:lower()
        if not m:is_static() and not low:find("update", 1, true) and not low:find("^get_") and not low:find("^set_") then
            local ok = pcall(sdk.hook, m, function(args)
                local a = sdk.to_int64(args[2])
                local owner = PX.EYE_WARP_OBJS[a]
                if not owner then return end
                PX.EYE_WARP_CALLS[mn] = (PX.EYE_WARP_CALLS[mn] or 0) + 1
                if PX.EYE_WARP_CALLS[mn] <= 3 then log("Eye warp research: WarpPointRequester." .. mn .. " called (" .. owner .. ")") end
            end, nil)
            if ok then hooked = hooked + 1 end
        end
    end
    log(string.format("Eye warp research: %s type lines -> data/RancorReinforcements_eye_warp_types.txt, %d WarpPointRequester methods watched", tostring(n), hooked))
end
-- v1.9.114: the Evil Eye's warp points live in AppSystem/ch/ch270/UserData/ch270WarpData.user (one shared copy).
-- Load it, list every position in it, and move them all onto the Rancor arena: the lair's layout is kept, shrunk
-- to fit within ~25 m of the arena center and lifted to the arena's height. The dungeon itself gets the same
-- (moved) points while the game runs - accepted by the user.
PX.LAIR = { pts = nil, applied_at = nil }
PX.LAIR_FILE = "RancorReinforcements_eye_warpdata.txt"
function PX.lair_walk(obj, path, depth, out, pts, seen, owner_list, owner_idx)
    if depth > 7 or not obj then return end
    local td = safe(function() return obj:get_type_definition() end)
    if not td then return end
    local tn = td:get_full_name()
    local is_vt = safe(function() return td:is_value_type() end)
    if not is_vt then
        local a = safe(function() return obj:get_address() end)
        if a then if seen[a] then return end; seen[a] = true end
    end
    local el = (tn:find("[]", 1, true) or tn:find("List`1", 1, true)) and PX.list_elems(obj)
    if el then
        table.insert(out, string.format("%s%s : %s (%d)", string.rep("  ", depth), path, tn, #el))
        for i, e in ipairs(el) do
            if type(e) == "userdata" then PX.lair_walk(e, path .. "[" .. (i - 1) .. "]", depth + 1, out, pts, seen, obj, i - 1) end
        end
        return
    end
    table.insert(out, string.format("%s%s : %s%s", string.rep("  ", depth), path, tn, is_vt and " (struct)" or ""))
    local t2 = td
    while t2 do
        local n2 = t2:get_full_name()
        if n2 == "System.Object" or n2 == "System.ValueType" or n2 == "via.UserData" then break end
        for _, f in ipairs(t2:get_fields() or {}) do
            if not f:is_static() then
                local fname = f:get_name()
                local ftn = safe(function() return f:get_type():get_full_name() end) or "?"
                local v = safe(function() return obj:get_field(fname) end)
                if ftn == "via.vec3" or ftn == "via.Position" or ftn == "via.Float3" then
                    local x, y, z = vfield(v, "x"), vfield(v, "y"), vfield(v, "z")
                    table.insert(out, string.format("%s  .%s = (%.2f, %.2f, %.2f)%s", string.rep("  ", depth), fname, x or 0, y or 0, z or 0, ftn == "via.Position" and " [Position]" or ""))
                    if type(x) == "number" then
                        table.insert(pts, { obj = obj, field = fname, kind = ftn, x = x, y = y, z = z, path = path .. "." .. fname,
                            vt = is_vt, list = owner_list, idx = owner_idx })
                    end
                elseif type(v) == "userdata" then
                    PX.lair_walk(v, path .. "." .. fname, depth + 1, out, pts, seen, nil, nil)
                elseif v ~= nil and depth <= 4 then
                    table.insert(out, string.format("%s  .%s = %s", string.rep("  ", depth), fname, tostring(v)))
                end
            end
        end
        t2 = t2:get_parent_type()
    end
end
function PX.lair_load()
    if PX.LAIR.pts then return PX.LAIR.pts end
    local ud
    for _, p in ipairs({ "AppSystem/ch/ch270/UserData/ch270WarpData.user", "appsystem/ch/ch270/userdata/ch270warpdata.user" }) do
        ud = ud or safe(function() return sdk.create_userdata("via.UserData", p) end)
    end
    local out, pts = { "ch270WarpData.user " .. os.date("%H:%M:%S") .. " - type " .. tostring(ud and safe(function() return ud:get_type_definition():get_full_name() end)) }, {}
    if ud then PX.lair_walk(ud, "WarpData", 0, out, pts, {}, nil, nil) end
    table.insert(out, string.format("== %d positions found", #pts))
    pcall(fs.write, PX.LAIR_FILE, table.concat(out, "\n"))
    log(string.format("Evil Eye lair: warp data %s, %d positions -> data/%s", ud and "loaded" or "NOT loaded", #pts, PX.LAIR_FILE))
    if ud then PX.LAIR.ud = ud; pcall(function() ud:add_ref() end) end
    PX.LAIR.pts = (#pts > 0) and pts or nil   -- nothing yet: try again when an Eye spawns
    for _, q in ipairs(pts) do q.ox, q.oy, q.oz = q.x, q.y, q.z end   -- originals
    return pts
end
if not K.RELEASE then pcall(PX.lair_load) end   -- at load too, so the file can be read before any fight
-- v1.9.145 (user: what are Satanachia's weaknesses / resistances?): load his parameter files straight from the
-- game data - hit params (physical / elemental damage rates per body region), status params and debilitation
-- resistances; the base and _10 variants and their hard-mode versions - and dump them to
-- data/RancorReinforcements_satan_params.txt. Research only, dev build, runs once at script load.
function PX.satan_dump()
    local okr, src = pcall(_G.fs.read, "claude_dumplib.lua")
    if not okr or type(src) ~= "string" or #src < 100 then log("Satanachia params: claude_dumplib.lua not found") return end
    local okl, D = pcall(function() return load(src, "=claude_dumplib", "t")() end)
    if not okl or type(D) ~= "table" then log("Satanachia params: dumplib failed to load") return end
    local files = {
        "appsystem/ch/ch261/001/userdata/ch261001hitparam.user",
        "appsystem/ch/ch261/001/userdata/ch261001_10hitparam.user",
        "appsystem/ch/ch261/001/userdata/ch261001statusparam.user",
        "appsystem/ch/ch261/001/userdata/ch261001_10statusparam.user",
        "appsystem/ch/ch261/001/userdata/ch261001statusconditiondata.user",
        "appsystem/ch/ch261/001/userdata/ch261001dedicatedparam.user",
        "appsystem/ch/ch261/001/userdata/hardmode/ch261001hitparam_hardmode.user",
        "appsystem/ch/ch261/001/userdata/hardmode/ch261001_10hitparam_hardmode.user",
        "appsystem/ch/ch261/001/userdata/hardmode/ch261001_10statusparam_hardmode.user",
        "appsystem/ch/ch261/001/userdata/hardmode/ch261001statusconditiondata_hardmode.user",
    }
    local out, got = {}, 0
    for _, p in ipairs(files) do
        local ud = safe(function() return sdk.create_userdata("via.UserData", p) end)
        if not ud then ud = safe(function() return sdk.create_userdata("via.UserData", "AppSystem/" .. p:sub(11)) end) end
        table.insert(out, "")
        table.insert(out, "===== " .. p .. " -> " .. (ud and tostring(safe(function() return ud:get_type_definition():get_full_name() end)) or "NOT LOADED"))
        if ud then
            got = got + 1
            local okd, txt = pcall(D.dump, ud, p:match("([^/]+)%.user"), 80000, 8)
            table.insert(out, okd and txt or ("dump failed: " .. tostring(txt)))
        end
    end
    pcall(fs.write, "RancorReinforcements_satan_params.txt", table.concat(out, "\n"))
    log(string.format("Satanachia params: %d of %d files dumped -> data/RancorReinforcements_satan_params.txt", got, #files))
end
if not K.RELEASE then pcall(PX.satan_dump) end
-- v1.9.146: the Satanachia weakness oracle (research, dev build): the first time a living ch261001 is seen,
-- ask HIS damage calculator about every damage type (Normal / Weakpoint / Resist) and record his status
-- parameter block -> data/RancorReinforcements_satan_weak.txt. Called from PURG.tick's monster scan.
K.SATAN_TYPES = { [1]="Slash",[2]="Blow",[4]="Shoot",[16]="Fire",[32]="Ice",[64]="Thunder",[128]="Light",[256]="Magic",[512]="Physics" }
function K.satan_oracle(go, name)
    if K.SATAN_DONE then return end
    local ch = safe(function() return go:call("getComponent(System.Type)", sdk.typeof("app.Character")) end)
    local hp = ch and safe(function() return ch:get_Hit():call("get_Hp") end)
    if not hp or hp <= 0 then return end
    local ev = safe(function() return ch:get_field("CheckCharacterWeakpointEvent") end)
    if not ev then return end
    local rnames = { [0] = "Normal", [1] = "WEAKPOINT", [2] = "Resist" }
    local out, got = { "Satanachia damage-type verdicts (" .. tostring(name) .. ") " .. os.date("%H:%M:%S") }, 0
    for bit, nm in pairs(K.SATAN_TYPES) do
        local r = safe(function() return ev:call("Invoke", bit) end)
        local ri = (type(r) == "number" and r) or (r ~= nil and tonumber(safe(function() return sdk.to_int64(r) end)))
        if ri ~= nil then got = got + 1 end
        table.insert(out, string.format("  %-8s -> %s", nm, tostring(rnames[ri] or ri or r)))
    end
    local tgt = safe(function() return ev:get_field("_target") end)
    if tgt then
        table.insert(out, "calculator: " .. tostring(safe(function() return tgt:get_type_definition():get_full_name() end)))
        local t2 = safe(function() return tgt:get_type_definition() end)
        while t2 do
            for _, f in ipairs(t2:get_fields() or {}) do
                if not f:is_static() and (safe(function() return f:get_type():get_full_name() end) == "app.DefaultCharacterStatusParameter") then
                    local v = safe(function() return tgt:get_field(f:get_name()) end)
                    if v then
                        table.insert(out, "  _WeakPointSettings raw = " .. tostring(safe(function() return v:get_field("_WeakPointSettings") end)))
                        table.insert(out, "  _ResistSettings raw = " .. tostring(safe(function() return v:get_field("_ResistSettings") end)))
                        table.insert(out, string.format("  Atk %s  Def %s  MAtk %s  MDef %s",
                            tostring(safe(function() return v:get_field("_Attack") end)), tostring(safe(function() return v:get_field("_Defence") end)),
                            tostring(safe(function() return v:get_field("_MagicAttack") end)), tostring(safe(function() return v:get_field("_MagicDefence") end))))
                    end
                end
            end
            t2 = t2:get_parent_type()
        end
    end
    if got > 0 then
        K.SATAN_DONE = true
        pcall(fs.write, "RancorReinforcements_satan_weak.txt", table.concat(out, "\n"))
        log("Satanachia asked about all 9 damage types -> data/RancorReinforcements_satan_weak.txt")
    end
end
function PX.lair_write(q, x, y, z)
    local nv
    if q.kind == "via.Position" then
        nv = ValueType.new(POS_TD); nv:set_field("x", x); nv:set_field("y", y); nv:set_field("z", z)
    else
        nv = Vector3f.new(x, y, z)
    end
    local ok = pcall(function() q.obj:set_field(q.field, nv) end)
    if ok and q.vt then
        -- a struct inside a list/array: put the changed copy back
        ok = q.list ~= nil and (pcall(function() q.list:call("set_Item", q.idx, q.obj) end)
            or pcall(function() q.list:call("SetValue(System.Object, System.Int32)", q.obj, q.idx) end))
    end
    return ok
end
function PX.lair_apply(c)
    if not (config.eye_lair_rewrite and c) then return end
    local pts = PX.lair_load()
    if not pts or #pts == 0 then return end
    local sx, sy, sz, n = 0, 0, 0, 0
    for _, q in ipairs(pts) do sx, sy, sz, n = sx + q.ox, sy + q.oy, sz + q.oz, n + 1 end
    local cx, cy, cz = sx / n, sy / n, sz / n
    local maxr = 1
    for _, q in ipairs(pts) do maxr = math.max(maxr, math.sqrt((q.ox - cx) ^ 2 + (q.oz - cz) ^ 2)) end
    local k = math.min(1, 25 / maxr)
    local okn = 0
    for _, q in ipairs(pts) do
        local y = c.y + 4 + math.max(-2, math.min(10, (q.oy - cy) * k))
        if PX.lair_write(q, c.x + (q.ox - cx) * k, y, c.z + (q.oz - cz) * k) then okn = okn + 1 end
    end
    PX.LAIR.applied_at = os.clock()
    log(string.format("Evil Eye lair: moved %d of %d warp positions onto the arena (lair spread %.0f m -> x%.2f, center %.0f, %.0f, %.0f)",
        okn, #pts, maxr, k, c.x, c.y, c.z))
end
-- v1.9.115: ch270WarpData.user only comes back as a bare via.UserData (like the Dragon think tables), so look for the
-- live warp manager / warp data the Eye actually uses: probe likely type names, managed singletons and scene components,
-- and dump what is found (fields, methods, every position under it) -> data/RancorReinforcements_eye_warpfind.txt
PX.WARP_NAMES = { "app.Ch270WarpManager", "app.Ch27WarpManager", "app.Ch270WarpData", "app.Ch27WarpData", "app.Ch270WarpPoint",
    "app.Ch27WarpPoint", "app.Ch270WarpPointData", "app.Ch270WarpArea", "app.Ch270WarpAreaData", "app.Ch270WarpData.WarpPoint",
    "app.Ch270WarpData.WarpArea", "app.Ch270WarpData.WarpPointData", "app.Ch270WarpData.WarpGroupData", "app.Ch270WarpData.AreaData",
    "app.Ch270WarpData.PointData", "app.Ch270WarpPointController", "app.Ch270StageManager", "app.Ch270BossStage", "app.Ch270Manager",
    "app.Ch27Manager", "app.Ch270WarpPointManager", "app.Ch270InvisibleArea", "app.InvisibleAreaControl", "app.InvisibleAreaManager",
    "app.Ch270WarpGeneralPoint", "app.Ch270GeneralPoint", "app.Ch270SummonPoint", "app.Ch270SummonPointRequester", "app.Ch27WarpPointRequester" }
function PX.warp_find(where)
    local out = { "Evil Eye warp search (" .. where .. ") " .. os.date("%H:%M:%S") }
    for _, tn in ipairs(PX.WARP_NAMES) do
        local td = sdk.find_type_definition(tn)
        if td then
            local par = safe(function() return td:get_parent_type():get_full_name() end) or "-"
            table.insert(out, "== TYPE " .. tn .. " (parent " .. par .. ")")
            for _, f in ipairs(td:get_fields() or {}) do
                table.insert(out, string.format("  field %s%s : %s", f:is_static() and "static " or "", f:get_name(), safe(function() return f:get_type():get_full_name() end) or "?"))
            end
            for _, m in ipairs(td:get_methods() or {}) do
                local ps = {}
                for _, pt in ipairs(safe(function() return m:get_param_types() end) or {}) do table.insert(ps, safe(function() return pt:get_full_name() end) or "?") end
                table.insert(out, string.format("  method %s(%s) -> %s", m:get_name(), table.concat(ps, ", "), safe(function() return m:get_return_type():get_full_name() end) or "?"))
            end
            local inst = {}
            local sg = safe(function() return sdk.get_managed_singleton(tn) end)
            if sg then table.insert(inst, sg); table.insert(out, "  ** managed singleton exists") end
            local isc = false
            local t2 = td
            for _ = 1, 8 do
                t2 = t2 and safe(function() return t2:get_parent_type() end)
                local n2 = t2 and t2:get_full_name()
                if n2 == "via.Component" or n2 == "via.Behavior" then isc = true; break end
            end
            if isc then
                local list = find_components(tn)
                table.insert(out, "  ** scene components: " .. #list)
                for i = 1, math.min(#list, 4) do table.insert(inst, list[i]) end
            end
            for i, o in ipairs(inst) do
                local w, pts = {}, {}
                PX.lair_walk(o, tn .. "#" .. i, 0, w, pts, {}, nil, nil)
                table.insert(out, string.format("  -- instance %d: %d positions", i, #pts))
                for j = 1, math.min(#w, 400) do table.insert(out, "    " .. w[j]) end
            end
        end
    end
    local old = safe(function() local f = io.open("RancorReinforcements_eye_warpfind.txt", "r"); if f then local x = f:read("a"); f:close(); return x end end) or ""
    pcall(fs.write, "RancorReinforcements_eye_warpfind.txt", old .. "\n" .. table.concat(out, "\n"))
    log("Evil Eye warp search (" .. where .. "): " .. #out .. " lines -> data/RancorReinforcements_eye_warpfind.txt")
end
if not K.RELEASE then pcall(PX.warp_find, "script load") end
-- v1.9.116: app.Ch270WarpManager picks the destination. requestWarpWarpPoint(Ch270, attr, Position, near, far) looks up
-- the dungeon's warp points (none exist in a Rancor); the same manager also has requestWarpAroundTarget(Ch270,
-- Position, vec3, bool) - the Eye's own "appear around its target" warp. For a mod Eye the first is answered with the
-- second, centred on you, so the whole warp (portal, copy, appear) runs natively inside the arena.
PX.WARP_STATS = {}
function PX.is_mod_eye(ch)
    local go = ch and safe(function() return ch:call("get_GameObject") end)
    local a = go and safe(function() return go:get_address() end)
    local t = a and K.TRACKED and K.TRACKED[a]
    return t and t.name:sub(1, #K.EYE_ID) == K.EYE_ID and t or nil
end
do
    local td = sdk.find_type_definition("app.Ch270WarpManager")
    for _, m in ipairs(td and td:get_methods() or {}) do
        local mn = m:get_name()
        if mn == "requestWarpWarpPoint" or mn == "requestWarpAroundTarget" or mn == "requestWarpDQSSearch" or mn == "notifyWarpFail"
            or mn == "requestSwitchWarpHost" or mn == "endWarpRequest" then
            pcall(sdk.hook, m, function(args)
                local st = thread.get_hook_storage()
                st["rr_wm"] = nil
                local ch = safe(function() return sdk.to_managed_object(args[3]) end)
                local t = PX.is_mod_eye(ch)
                if not t then return end
                PX.WARP_STATS[mn] = (PX.WARP_STATS[mn] or 0) + 1
                if PX.WARP_STATS[mn] <= 6 then log(string.format("Evil Eye warp manager: %s (%s, #%d)", mn, t.name, PX.WARP_STATS[mn])) end
                -- v1.9.118: the game's own requestWarpAroundTarget can aim at a far target too (18:18:23: 2,967 m) - re-centre it on you
                if (mn ~= "requestWarpWarpPoint" and mn ~= "requestWarpAroundTarget") or PX.WARP_BUSY
                    or not (config.enabled and config.eye_warp_around_you and vortex_now) then return end
                local flag = false
                if mn == "requestWarpAroundTarget" then flag = ((sdk.to_int64(args[6]) or 0) & 1) == 1 end
                local mgr = safe(function() return sdk.to_managed_object(args[2]) end)
                local pp = player_upos()
                local tp = K.eye_phase_warp_pos and select(2, pcall(K.eye_phase_warp_pos))   -- v1.9.135: teleport phase target
                if type(tp) == "table" and tp.x then pp = tp end
                if not (mgr and pp) then return end
                local pos = ValueType.new(POS_TD)
                pos:set_field("x", pp.x); pos:set_field("y", pp.y); pos:set_field("z", pp.z)
                PX.WARP_BUSY = true
                local ok, r = pcall(function()
                    return mgr:call("requestWarpAroundTarget(app.Ch270, via.Position, via.vec3, System.Boolean)", ch, pos, Vector3f.new(0, 0, 1), flag)
                end)
                PX.WARP_BUSY = false
                PX.WARP_STATS.redirect = (PX.WARP_STATS.redirect or 0) + 1
                if PX.WARP_STATS.redirect <= 12 then
                    log(string.format("Evil Eye warp #%d: %s -> 'around you' instead (%s)", PX.WARP_STATS.redirect,
                        mn == "requestWarpWarpPoint" and "dungeon warp point" or "around its own target", ok and ("game said " .. tostring(r)) or ("failed: " .. tostring(r))))
                end
                if ok then
                    st["rr_wm"] = { r = r and true or false }
                    return sdk.PreHookResult.SKIP_ORIGINAL
                end
            end, function(retval)
                local st = thread.get_hook_storage()
                local c = st and st["rr_wm"]
                if c then st["rr_wm"] = nil; return sdk.to_ptr(c.r and 1 or 0) end
                return retval
            end)
        end
    end
end
function PX.eye_warp_research(t)
    if K.RELEASE then return end
    if not PX.WARP_FOUND_SPAWN then PX.WARP_FOUND_SPAWN = true; pcall(PX.warp_find, "Evil Eye spawned") end
    pcall(function()
        local c = K.arena_c and K.arena_c() or nil
        PX.lair_apply(c)
    end)
    if not t or not t.go then return end
    local ch = safe(function() return t.go:call("getComponent(System.Type)", sdk.typeof("app.Ch270")) end)
    local req = ch and safe(function() return ch:call("get_WarpPointRequester") end)
    local out = { "Evil Eye warp data " .. os.date("%H:%M:%S") .. " - " .. t.name, "Ch270: " .. tostring(ch ~= nil) .. ", WarpPointRequester: " .. tostring(req ~= nil) }
    if req then
        PX.EYE_WARP_OBJS[req:get_address()] = t.name
        table.insert(out, "== WarpPointRequester fields")
        PX.obj_fields(req, out, "    ", 80)
        -- expand list/array fields one level (warp point candidates)
        local td = req:get_type_definition()
        while td and td:get_full_name() ~= "System.Object" do
            for _, f in ipairs(td:get_fields() or {}) do
                if not f:is_static() then
                    local el = PX.list_elems(safe(function() return req:get_field(f:get_name()) end))
                    if el and #el > 0 then
                        table.insert(out, string.format("== list %s (%d)", f:get_name(), #el))
                        for i = 1, math.min(#el, 24) do
                            local e = el[i]
                            if type(e) == "userdata" then
                                local p = safe(function() return e:call("get_Position") end) or safe(function() return e:call("get_GameObject"):call("get_Transform"):call("get_Position") end)
                                table.insert(out, string.format("  [%d] %s%s", i - 1, tostring(safe(function() return e:get_type_definition():get_full_name() end) or e),
                                    p and string.format(" at (%.1f, %.1f, %.1f)", vfield(p, "x") or 0, vfield(p, "y") or 0, vfield(p, "z") or 0) or ""))
                                if i <= 3 then PX.obj_fields(e, out, "      ", 40) end
                            else
                                table.insert(out, string.format("  [%d] %s", i - 1, tostring(e)))
                            end
                        end
                    end
                end
            end
            td = td:get_parent_type()
        end
    end
    if ch then
        table.insert(out, "== Ch270 warp-related fields")
        local tmp = {}
        PX.obj_fields(ch, tmp, "    ", 400)
        for _, l in ipairs(tmp) do if l:find("Warp", 1, true) or l:find("Invisible", 1, true) or l:find("Portal", 1, true) then table.insert(out, l) end end
    end
    local old = safe(function() local f = io.open("RancorReinforcements_eye_warp_live.txt", "r"); if f then local x = f:read("a"); f:close(); return x end end) or ""
    pcall(fs.write, "RancorReinforcements_eye_warp_live.txt", old .. "\n" .. table.concat(out, "\n"))
    log("Eye warp research: " .. t.name .. " warp data -> data/RancorReinforcements_eye_warp_live.txt")
end
-- v1.9.106: weak-point HP for the Golem (medallions: 3x their own, golem_hp_mult) and the Purgener
-- (purgener_hp shared evenly). Weak points = regions > 0 that are live at spawn with >= 1,000 HP.
function PX.points_setup(t, kind)
    if not t or t.golem_done then return end
    t.golem_done = true
    t.kind = kind
    local hit = safe(function() return t.chara:get_Hit() end)
    if not hit then return end
    local regions, rname, ctrl = PX.golem_regions(hit)
    local out = { kind .. " regions " .. os.date("%H:%M:%S") .. " - " .. t.name, "region list: " .. tostring(rname) .. ", count " .. tostring(regions and #regions) }
    local n = regions and #regions or 0
    local medals = {}
    for i = 0, n - 1 do
        local hp = safe(function() return hit:call("getRegionHp(System.Int32)", i) end)
        local mx = safe(function() return hit:call("getRegionOriginalMaxHp(System.Int32)", i) end)
        table.insert(out, string.format("== region %d: HP %s / original max %s", i, tostring(hp), tostring(mx)))
        if regions[i + 1] and i < 3 or (mx and mx > 0) then PX.obj_fields(regions[i + 1], out, "    ", 60) end
        -- v1.9.103: only the medallions this Golem actually has. It spawns with a few live ones (4,400 HP, e.g.
        -- regions 5/6/9/30); the other slots sit at 0 HP (absent) or 80 HP. Filling all 30 (v1.9.101) turned on
        -- absent slots and the Golem came out invisible apart from its weak points.
        if i > 0 and type(mx) == "number" and mx >= 1000 and type(hp) == "number" and hp > 0 then table.insert(medals, { i = i, mx = mx }) end
    end
    if ctrl then table.insert(out, "== RegionStatusCtrl fields"); PX.obj_fields(ctrl, out, "    ", 80) end
    local c252 = safe(function() return t.go:call("getComponent(System.Type)", sdk.typeof("app.Ch252000")) end)
    if c252 then table.insert(out, "== app.Ch252000 fields"); PX.obj_fields(c252, out, "    ", 120) end
    local file = kind == "golem" and PX.GOLEM_FILE or ("RancorReinforcements_" .. kind .. "_regions.txt")
    pcall(fs.write, file, table.concat(out, "\n"))
    local parts, sum = {}, 0
    for _, m in ipairs(medals) do table.insert(parts, string.format("r%d=%.0f", m.i, m.mx)); sum = sum + m.mx end
    log(string.format("%s %s: %d regions, %d live weak points (%s) -> details in data/%s", kind, t.name, n, #medals,
        table.concat(parts, " "), file))
    local on = ((kind == "golem" or kind == "brine_golem") and config.golem_medal_split)
        or ((kind == "purgener" or kind == "vermund") and config.purgener_points_split)
    if on and #medals > 0 then
        local total = (kind == "golem" and sum * (tonumber(config.golem_hp_mult) or 3))
            or (kind == "brine_golem" and sum * (tonumber(config.brine_golem_hp_mult) or 3))
            or (kind == "vermund" and (tonumber(config.vermund_hp) or 384000))
            or (tonumber(config.purgener_hp) or 300000)
        local per = total / #medals
        local okn = 0
        for _, m in ipairs(medals) do
            local ok = pcall(function()
                hit:call("setRegionOriginalMaxHp(System.Single, System.Int32, System.Boolean)", per, m.i, true)
                hit:call("setHp(System.Single, System.Boolean, System.Int32)", per, false, m.i)
            end)
            if ok then okn = okn + 1 end
        end
        local after = {}
        for _, m in ipairs(medals) do
            table.insert(after, string.format("r%d=%s", m.i, tostring(safe(function() return math.floor(hit:call("getRegionHp(System.Int32)", m.i)) end))))
        end
        log(string.format("%s weak points: %.0f HP each on %d of %d (total %.0f; now %s)", kind, per, okn, #medals, total, table.concat(after, " ")))
        t.golem_medals = medals
    end
    t.golem_next = os.clock() + 1
end
function PX.golem_tick(t, now)
    if now < (t.golem_next or 0) then return end
    t.golem_next = now + 1
    local want = tonumber(config.golem_scale) or 1
    if t.kind ~= "golem" or not config.golem_transform_scale or math.abs(want - 1) < 0.01 then want = nil end
    local tr = safe(function() return t.go:call("get_Transform") end)
    local ls = tr and safe(function() return tr:call("get_LocalScale") end)
    local cur = want and ls and vfield(ls, "x")
    if cur and math.abs(cur - want) > 0.02 then
        local ok = pcall(function() tr:call("set_LocalScale", Vector3f.new(want, want, want)) end)
        t.golem_scale_n = (t.golem_scale_n or 0) + 1
        if t.golem_scale_n <= 3 then
            log(string.format("Golem %s size: Transform scale %.2f -> %.2f%s", t.name, cur, want, ok and "" or " (could not set)"))
        end
    end
    if t.golem_medals and now - (t.golem_rlog or 0) >= 15 then
        t.golem_rlog = now
        local hit = safe(function() return t.chara:get_Hit() end)
        local parts = {}
        for _, m in ipairs(t.golem_medals) do
            table.insert(parts, string.format("r%d=%s", m.i, tostring(safe(function() return math.floor(hit:call("getRegionHp(System.Int32)", m.i)) end))))
        end
        log(tostring(t.kind) .. " weak-point HP: " .. table.concat(parts, " "))
    end
end
do
local PETRI_FILE = "RancorReinforcements_petrify_dump.txt"
local petri_dumped = false
local petri_calls = {}     -- "Type.method" -> count
local petri_hooked = 0

local function val_str(v)
    local t = type(v)
    if t == "number" then return (math.type and math.type(v) == "integer") and tostring(v) or string.format("%.4f", v) end
    if t ~= "userdata" then return tostring(v) end
    local td = safe(function() return v:get_type_definition() end)
    local x = safe(function() return v.x end)
    if type(x) == "number" then
        local y, z, w = safe(function() return v.y end), safe(function() return v.z end), safe(function() return v.w end)
        local parts = { string.format("%.3f", x) }
        for _, c in ipairs({ y, z, w }) do if type(c) == "number" then table.insert(parts, string.format("%.3f", c)) end end
        return "(" .. table.concat(parts, ", ") .. ")"
    end
    local s = safe(function() return v:call("ToString") end)
    if type(s) == "string" then return '"' .. s:sub(1, 120) .. '"' end
    return td and ("<" .. td:get_full_name() .. ">") or tostring(v)
end

local function dump_obj(obj, depth, indent, out, seen)
    if #out > 5000 then return end
    local td = safe(function() return obj:get_type_definition() end)
    if not td then return end
    local addr = safe(function() return obj:get_address() end)
    if addr then
        if seen[addr] then table.insert(out, indent .. "(already listed)"); return end
        seen[addr] = true
    end
    local tdi = td
    while tdi do
        local tn = tdi:get_full_name()
        if tn == "System.Object" or tn == "via.Component" or tn == "via.Behavior" or tn == "System.ValueType" then break end
        for _, f in ipairs(tdi:get_fields() or {}) do
            if not f:is_static() then
                local name = f:get_name()
                local ftn = safe(function() return f:get_type():get_full_name() end) or "?"
                local ok, v = pcall(function() return obj:get_field(name) end)
                local line = string.format("%s%s : %s = %s", indent, name, ftn, ok and val_str(v) or "(unreadable)")
                table.insert(out, line)
                if ok and type(v) == "userdata" and depth > 0 then
                    local vtd = safe(function() return v:get_type_definition() end)
                    local vtn = vtd and vtd:get_full_name() or ""
                    local is_seq = vtn:find("List`1", 1, true) or vtn:find("%[%]$")
                    local is_map = vtn:find("Dictionary`", 1, true) or vtn:find("HashSet`", 1, true) or vtn:find("Queue`", 1, true) or vtn:find("Stack`", 1, true)
                    local cnt = is_seq and (safe(function() return v:call("get_Count") end) or safe(function() return v:get_size() end))
                    if is_map then
                        local c2 = safe(function() return v:call("get_Count") end)
                        table.insert(out, indent .. "  (map/set, count " .. tostring(c2) .. ", not walked)")
                    elseif type(cnt) == "number" then
                        table.insert(out, indent .. "  (count " .. cnt .. ")")
                        for i = 0, math.min(cnt, 6) - 1 do
                            local el = safe(function() return v:call("get_Item", i) end) or safe(function() return v:get_element(i) end)
                            table.insert(out, string.format("%s  [%d] = %s", indent, i, val_str(el)))
                            if type(el) == "userdata" and safe(function() return el:get_type_definition() end) and depth > 1 then
                                dump_obj(el, depth - 2, indent .. "      ", out, seen)
                            end
                        end
                    elseif not is_seq and vtd and not vtn:find("^via%.") and not vtn:find("^System%.") and not vtn:find("Action`") then
                        dump_obj(v, depth - 1, indent .. "    ", out, seen)
                    end
                end
            end
        end
        tdi = tdi:get_parent_type()
    end
end

local function list_methods(type_name, out)
    local td = sdk.find_type_definition(type_name)
    table.insert(out, "")
    table.insert(out, "== methods of " .. type_name .. (td and "" or " (type not found)"))
    for _, m in ipairs(td and td:get_methods() or {}) do
        local ps = {}
        for _, t in ipairs(safe(function() return m:get_param_types() end) or {}) do table.insert(ps, t:get_full_name()) end
        table.insert(out, string.format("  %s(%s) -> %s", m:get_name(), table.concat(ps, ", "),
            safe(function() return m:get_return_type():get_full_name() end) or "?"))
    end
end

local function status_ctrl_of(chara)
    if not chara then return nil end
    for _, nm in ipairs({ "<StatusConditionCtrl>k__BackingField", "StatusConditionCtrl", "_StatusConditionCtrl" }) do
        local v = safe(function() return chara[nm] end)
        if v then return v, nm end
    end
    local v = safe(function() return chara:call("get_StatusConditionCtrl") end)
    if v then return v, "get_StatusConditionCtrl()" end
    return nil
end

-- count calls of petrification / status-condition methods (pre-hook only, no changes)
local function hook_counts(type_name, filter)
    local td = sdk.find_type_definition(type_name)
    for _, m in ipairs(td and td:get_methods() or {}) do
        local n = m:get_name()
        local lower = n:lower()
        if (not filter or filter(lower)) and not lower:find("^get_") and not lower:find("^set_") and n ~= ".ctor" and n ~= ".cctor" then
            local key = type_name:gsub("^app%.", "") .. "." .. n
            if pcall(sdk.hook, m, function(args) if next(medusa) then petri_calls[key] = (petri_calls[key] or 0) + 1 end end,
                function(r) return r end) then
                petri_hooked = petri_hooked + 1
            end
        end
    end
end
if config.medusa_petrify_research then
    hook_counts("app.Ch255000PetrificationControl", function(l) return not (l == "update" or l == "lateupdate") end)
    hook_counts("app.StatusConditionCtrl", function(l)
        return l:find("petri") or l:find("accum") or l:find("add") or l:find("damage") or l:find("value") or l:find("request")
    end)
end
local function petri_call_summary()
    local list = {}
    for k, n in pairs(petri_calls) do table.insert(list, { k = k, n = n }) end
    table.sort(list, function(a, b) return a.n > b.n end)
    local out = {}
    for i = 1, math.min(40, #list) do table.insert(out, string.format("    %6d  %s", list[i].n, list[i].k)) end
    return #out > 0 and table.concat(out, "\n") or "    (none)"
end

local function petrify_dump(e)
    local out = { "Rancor Reinforcements - petrification research dump (" .. os.date() .. ")" }
    local ch2 = m_ch2(e.chara)
    local function section(title, obj, depth)
        table.insert(out, "")
        table.insert(out, "=== " .. title .. (obj and "" or " (not found)"))
        if obj then dump_obj(obj, depth, "  ", out, {}) end
    end
    section("Medusa Ch255000PetrificationControl", ch2 and safe(function() return ch2["<Ch255000PetrificationControl>k__BackingField"] end), 3)
    section("Medusa DedicatedParameter (ch255000Parameter.user)", ch2 and safe(function() return ch2.DedicatedParameter end), 4)
    local cm = sdk.get_managed_singleton("app.CharacterManager")
    local pl = cm and safe(function() return cm["<ManualPlayer>k__BackingField"] end)
    local sc, how = status_ctrl_of(pl)
    section("Your status-condition controller (" .. tostring(how) .. ")", sc, 2)
    local msc = status_ctrl_of(e.chara)
    section("Medusa's own status-condition controller", msc, 1)
    for _, tn in ipairs({ "app.Ch255000PetrificationControl", "app.Ch255000PetrificationParameter", "app.StatusConditionCtrl" }) do
        list_methods(tn, out)
    end
    if sc then
        local tn = safe(function() return sc:get_type_definition():get_full_name() end)
        if tn and tn ~= "app.StatusConditionCtrl" then list_methods(tn, out) end
    end
    local etd = sdk.find_type_definition("app.StatusConditionDef.StatusConditionEnum")
    table.insert(out, "")
    table.insert(out, "== app.StatusConditionDef.StatusConditionEnum")
    for _, f in ipairs(etd and etd:get_fields() or {}) do
        if f:is_static() then table.insert(out, "  " .. f:get_name() .. " = " .. tostring(safe(function() return f:get_data(nil) end))) end
    end
    pcall(fs.write, PETRI_FILE, table.concat(out, "\n"))
    log(string.format("Petrify research: dump written (data/%s, %d lines); counting %d petrification/status methods",
        PETRI_FILE, #out, petri_hooked))
end

local beam_dumped = false
local function beam_dump(e)
    local out = { "Rancor Reinforcements - petrify beam dump, taken while she fired (" .. os.date() .. ")" }
    local ch2 = m_ch2(e.chara)
    local mod = m_module(e.chara)
    local function section(title, obj, depth)
        table.insert(out, "")
        table.insert(out, "=== " .. title .. (obj and "" or " (not found)"))
        if obj then dump_obj(obj, depth, "  ", out, {}) end
    end
    section("running action (ThinkTableModule._ExecuteActInter)", mod and safe(function() return mod._ExecuteActInter end), 4)
    section("look-at controller (Ch255._Ch255LookAtCtrl)", ch2 and safe(function() return ch2._Ch255LookAtCtrl end), 2)
    section("move controller (Ch255MoveController)", ch2 and safe(function() return ch2["<Ch255MoveController>k__BackingField"] end), 2)
    section("target controller", mod and safe(function() return mod._TargetCtrl end), 1)
    section("petrification control (during beam)", ch2 and safe(function() return ch2["<Ch255000PetrificationControl>k__BackingField"] end), 1)
    local am = safe(function() return e.chara["<ActionManager>k__BackingField"] end)
    section("current action object", am and safe(function() return am.CurrentAction end), 2)
    for _, tn in ipairs({ "app.Ch255LookAtCtrl", "app.Ch255MoveController" }) do list_methods(tn, out) end
    pcall(fs.write, "RancorReinforcements_petrify_beam_dump.txt", table.concat(out, "\n"))
    log(string.format("Petrify research: beam dump written (data/RancorReinforcements_petrify_beam_dump.txt, %d lines)", #out))
end

process_petrify = function(now)
    for _, e in pairs(medusa) do
        if not e.hydra then   -- v1.9.157: the Hydra has no petrify beam
        local act = safe(function() return e.chara["<ActionManager>k__BackingField"].CurrentAction:ToString() end) or ""
        if act:find("Petrification", 1, true) then
            if not e.in_beam then e.beams = (e.beams or 0) + 1 end
            e.in_beam = true
            e.beam_act = act
            e.last_beam_t = now
            if config.medusa_petrify_research then
                if not beam_dumped and (act:find("Attack", 1, true) or now - (e.beam_start_t or now) > 1.5) then
                    beam_dumped = true
                    local ok, err = pcall(beam_dump, e)
                    if not ok then log("Petrify research beam dump error: " .. tostring(err)) end
                end
                if now - (e.beam_log_t or 0) >= 1.0 and (e.beam_lines or 0) < 25 then
                    e.beam_log_t = now
                    e.beam_lines = (e.beam_lines or 0) + 1
                    local tco = safe(function() return m_module(e.chara)._TargetCtrl end)
                    local tt = tco and safe(function() return tco._TargetType end)
                    local td = tco and safe(function() return tco._DistanceFromSelf end)
                    local tg = tco and safe(function() return tco._DegreeToTarget end)
                    local g = e.geo
                    log(string.format("BEAM #%d %s: you %.1f m, %s off her nose | aiming at target type %s, %s m, %s deg",
                        e.beams or 0, act, g and g.d or -1, g and g.ang and string.format("%+.0f deg", g.ang) or "?",
                        tostring(tt), type(td) == "number" and string.format("%.1f", td) or "?",
                        type(tg) == "number" and string.format("%+.0f", tg) or "?"))
                end
            end
        else
            e.in_beam = false
            e.beam_start_t = nil
            e.beam_lines = 0
        end
        if e.in_beam and not e.beam_start_t then e.beam_start_t = now end
        if config.medusa_petrify_research and not petri_dumped and now - e.started >= 3 then
            petri_dumped = true
            local ok, err = pcall(petrify_dump, e)
            if not ok then log("Petrify research dump error: " .. tostring(err)) end
        end
        if config.medusa_petrify_research and now - (e.petri_log_t or e.started) >= 45 then
            e.petri_log_t = now
            log(string.format("Petrify research: %d beam(s) so far; method calls:\n%s", e.beams or 0, petri_call_summary()))
        end
        end
    end
end
-- 12) v1.9.14: petrify build-up multiplier + beam aimed at you ------------------------------
-- (a) StatusConditionCtrl.applyStatusConditionDamage(status, value, damageInfo): while a Rancor
--     Medusa is alive, the petrification ("Stone" = 12) value is multiplied by medusa_petrify_mult.
-- (b) While a Rancor Medusa fires her beam, her look-at target and attack target answer with YOU
--     (your entry in her target list) instead of whoever she picked (usually your main pawn).
local medusa_by_lookat = {}
local STONE = 12
do
    local td = sdk.find_type_definition("app.StatusConditionCtrl")
    local m = td and td:get_method("applyStatusConditionDamage(app.StatusConditionDef.StatusConditionEnum, System.Single, app.HitController.DamageInfo)")
    if m then
        local n = 0
        local ok = pcall(sdk.hook, m, function(args)
            if not next(medusa) then return end
            local mult = config.medusa_petrify_mult or 1.0
            if mult == 1.0 then return end
            if (sdk.to_int64(args[3]) & 0xFFFFFFFF) ~= STONE then return end
            local v = sdk.to_float(args[4])
            if type(v) ~= "number" or v <= 0 then return end
            args[4] = sdk.float_to_ptr(v * mult)
            n = n + 1
            if n <= 4 then log(string.format("Medusa petrify build-up x%.2f: %.2f -> %.2f", mult, v, v * mult)) end
        end, function(r) return r end)
        if ok then medusa_hooks = medusa_hooks + 1 else log("Medusa: could not hook applyStatusConditionDamage") end
    else
        log("Medusa: applyStatusConditionDamage not found")
    end
end

local function player_aitarget(e)
    local tc = safe(function() return m_module(e.chara)._TargetCtrl end)
    local arr = tc and safe(function() return tc._TargetArray end)
    local t = arr and safe(function() return arr:get_element(12) end)   -- ManualPlayer slot
    if not t then return nil end
    local cm = sdk.get_managed_singleton("app.CharacterManager")
    local pl = cm and safe(function() return cm["<ManualPlayer>k__BackingField"] end)
    local tch = safe(function() return t["<Character>k__BackingField"] end)
    if pl and tch and safe(function() return tch:get_address() end) == safe(function() return pl:get_address() end) then return t end
    return nil
end

do
    local function hook_target(type_name, method_name, lookup, key)
        local td = sdk.find_type_definition(type_name)
        local m = td and td:get_method(method_name)
        if not m then log("Medusa: " .. type_name .. "." .. method_name .. " not found"); return end
        local ok = pcall(sdk.hook, m, function(args)
            local st = thread.get_hook_storage()
            st[key] = nil
            if not (config.medusa_beam_at_you or config.medusa_beam_smart) then return end
            local e = lookup[sdk.to_int64(args[2])]
            if e and (e.in_beam or e.climb_aim or e.walk_beam) then st[key] = e end
        end, function(retval)
            local st = thread.get_hook_storage()
            local e = st and st[key]
            if e then
                st[key] = nil
                local t = (e.beam_target and e.beam_target.t) or e.you_target
                if t then
                    e.aim_swaps = (e.aim_swaps or 0) + 1
                    if e.aim_swaps == 1 then log("Medusa: petrify beam aimed at you (" .. method_name .. ")") end
                    if e.climb_aim and not e.climb_aim_logged then
                        e.climb_aim_logged = true
                        log("Medusa (coiled on the pillar): bow / beam aimed at " .. ((e.beam_target and e.beam_target.name) or "you") .. " (" .. method_name .. ")")
                    end
                    local a = safe(function() return t:get_address() end)
                    if a then return sdk.to_ptr(a) end
                end
            end
            return retval
        end)
        if ok then medusa_hooks = medusa_hooks + 1 end
    end
    hook_target("app.Ch255LookAtCtrl", "getLookAtTarget", medusa_by_lookat, "rr_lat")
    hook_target("app.Ch255", "getAttackTarget", medusa_by_ch2, "rr_gat")
end

-- on frame: keep lookups + your target entry fresh; one dump of her beam shell (radius research)
local shell_dumped = false
-- v1.9.16: who should the beam go to? (party members in her target list)
local BEAM_SLOTS = { 12, 4, 2, 3, 5, 6, 43, 44, 0, 1 }
local function pick_beam_target(e)
    local tc = safe(function() return m_module(e.chara)._TargetCtrl end)
    local arr = tc and safe(function() return tc._TargetArray end)
    if not arr then return end
    local here = e.geo and e.geo.here or upos_go(e.go)
    if not here then return end
    local cm = sdk.get_managed_singleton("app.CharacterManager")
    local pl = cm and safe(function() return cm["<ManualPlayer>k__BackingField"] end)
    local pla = pl and safe(function() return pl:get_address() end)
    local best, bests, seen = nil, nil, {}
    local fallback = nil
    for _, i in ipairs(BEAM_SLOTS) do
        local t = safe(function() return arr:get_element(i) end)
        local ch = t and safe(function() return t["<Character>k__BackingField"] end)
        local a = ch and safe(function() return ch:get_address() end)
        if a and not seen[a] and safe(function() return t["<Disable>k__BackingField"] end) ~= true then
            seen[a] = true
            local hp = safe(function() return ch:get_Hit():call("get_Hp") end)
            local p = upos_tr(safe(function() return ch:get_Transform() end))
            if p and (hp == nil or hp > 0) then
                local d = flat_dist(p, here) or 99
                local climbing = d < 4.5 and (p.y - here.y) > 1.5
                local in_range = d >= 6 and d <= 32 and not climbing
                local is_you = (a == pla)
                local c = { t = t, p = p, d = d, you = is_you, climbing = climbing, ch = ch,
                            name = safe(function() return ch:call("get_GameObject"):call("get_Name") end) or "?" }
                if is_you then fallback = c end
                if in_range then
                    -- you first; otherwise the one closest to where she is looking, then nearest
                    local ang = 0
                    local dx, dz = p.x - here.x, p.z - here.z
                    local tr = safe(function() return e.go:call("get_Transform") end)
                    local ax = tr and safe(function() return tr:call("get_AxisZ") end)
                    local fx, fz = ax and safe(function() return ax.x end), ax and safe(function() return ax.z end)
                    if type(fx) == "number" and type(fz) == "number" then
                        ang = math.abs(math.deg(math.atan(dz, dx) - math.atan(fz, fx)))
                        ang = ang % 360; if ang > 180 then ang = 360 - ang end
                    end
                    local score = (is_you and -1000 or 0) + ang * 0.2 + d * 0.1
                    if not bests or score < bests then best, bests = c, score end
                end
            end
        end
    end
    local pick = best or fallback
    local prev = e.beam_target
    e.beam_target = pick
    if pick and (not prev or prev.ch ~= pick.ch) then
        e.bt_logs = (e.bt_logs or 0) + 1
        if e.bt_logs <= 12 then
            log(string.format("Medusa beam target: %s at %.1f m%s", pick.you and "you" or pick.name, pick.d,
                best and "" or " (nobody in beam range - staying on you)"))
        end
    end
end

local function process_beam2(now)
    for _, e in pairs(medusa) do
        if e.hydra then goto next_beam2 end   -- v1.9.157: no bow / beam aim for the Hydra
        do
        local ap = safe(function() return m_ch2(e.chara).DedicatedParameter._ActionParam end)
        if ap and (config.medusa_arrow_lockon or 20) ~= 20 then
            local cur = safe(function() return ap._ArrowLockOnAngle end)
            if type(cur) == "number" and math.abs(cur - config.medusa_arrow_lockon) > 0.01 then
                if not PILLAR_AI.arrow_ap then PILLAR_AI.arrow_ap, PILLAR_AI.arrow_orig = ap, cur end
                local okw = pcall(function() ap._ArrowLockOnAngle = config.medusa_arrow_lockon + 0.0 end)
                if not e.arrow_logged then
                    e.arrow_logged = true
                    log(string.format("Medusa bow: lock-on cone %.0f -> %.0f deg (%s)", cur, config.medusa_arrow_lockon, okw and "ok" or "failed"))
                end
            end
        end
        local ch2 = m_ch2(e.chara)
        local la = ch2 and addr_of(safe(function() return ch2._Ch255LookAtCtrl end))
        if la then medusa_by_lookat[la] = e; e.lookat_addr = la end
        local pk = safe(function() return m_module(e.chara)._ExecuteActInter["<ActInterPackData>k__BackingField"]:ToString() end)
        e.pack = pk
        local walking_beam = type(pk) == "string" and pk:find("WalkPetrification", 1, true) ~= nil and not pk:find("End", 1, true)
        if walking_beam and not e.walk_beam then
            e.walk_beams = (e.walk_beams or 0) + 1
            if e.walk_beams <= 4 then log("Medusa walking petrify beam: aiming it") end
        end
        e.walk_beam = walking_beam
        local coiled = config.medusa_pillar_aim and type(pk) == "string" and pk:find("Ch255000Climb", 1, true) ~= nil
        if coiled and not e.climb_aim then
            e.coiled_n = (e.coiled_n or 0) + 1
            if e.coiled_n <= 6 then log("Medusa coiled attack: " .. tostring(pk:match("([^/]+)%.user") or pk) .. " - aiming it") end
        end
        e.climb_aim = coiled
        if (e.in_beam or e.climb_aim or e.walk_beam) and config.medusa_beam_at_you then
            local t = player_aitarget(e)
            e.you_target = t
            if not t and not e.no_you_logged then
                e.no_you_logged = true
                log("Medusa: your entry in her target list is empty - beam keeps her own target")
            end
        else
            e.you_target = nil
        end
        if (e.in_beam or e.climb_aim or e.walk_beam) and config.medusa_beam_smart then
            local ok, err = pcall(pick_beam_target, e)
            if not ok and not e.pbt_err then e.pbt_err = true; log("Medusa beam target error: " .. tostring(err)) end
        elseif not (e.in_beam or e.climb_aim or e.walk_beam) then
            e.beam_target = nil
        end
        if config.medusa_petrify_research and not shell_dumped then
            local pc = ch2 and safe(function() return ch2["<Ch255000PetrificationControl>k__BackingField"] end)
            local sh = pc and safe(function() return pc.PetrificationShell end)
            if sh then
                shell_dumped = true
                local out = { "Rancor Reinforcements - petrify beam SHELL dump (" .. os.date() .. ")", "" }
                pcall(dump_obj, sh, 4, "  ", out, {})
                pcall(fs.write, "RancorReinforcements_petrify_shell_dump.txt", table.concat(out, "\n"))
                log(string.format("Petrify research: beam shell dump written (data/RancorReinforcements_petrify_shell_dump.txt, %d lines)", #out))
            end
        end
        end
        ::next_beam2::
    end
end

process_petrify_extra = process_beam2
;(function()   -- own function scope
-- 14) v1.9.18: PILLAR SCOUT (log only) ---------------------------------------------------------
-- Finds Medusa's climbable pillars (app.Gm81_097) in the loaded world and writes everything about
-- them to data/RancorReinforcements_pillar_scout.txt: GameObject, scene folder, parents, children,
-- every component on each, and the Gm81_097 component's own fields. Also what a nearby Medusa holds
-- as her pillar target. Runs every 10 s while medusa_pillar_scout is on, or from the menu button.
local PILLAR_TYPE = "app.Gm81_097"
local SCOUT_FILE = "RancorReinforcements_pillar_scout.txt"
local scout_seen = {}       -- go addr -> true
local scout_count = 0
local scout_last = 0
local function go_components(go)
    local out = {}
    local arr = safe(function() return go:call("get_Components") end)
    local list = arr and (safe(function() return arr:get_elements() end) or {}) or {}
    for _, c in ipairs(list) do
        local tn = safe(function() return c:get_type_definition():get_full_name() end) or "?"
        table.insert(out, tn)
    end
    return out
end
local function folder_path(go)
    local f = safe(function() return go:call("get_Folder") end)
    local p = f and safe(function() return f:call("get_Path") end)
    return p or "?"
end
local function scout_pillars(force)
    local comps = find_components(PILLAR_TYPE)
    local out = { "Rancor Reinforcements - pillar scout (" .. os.date() .. ")",
                  string.format("%d %s component(s) loaded right now", #comps, PILLAR_TYPE) }
    local new = 0
    local pp = player_upos()
    for i, c in ipairs(comps) do
        local go = safe(function() return c:call("get_GameObject") end)
        local addr = go and go:get_address()
        if addr and not scout_seen[addr] then new = new + 1 end
        if addr then scout_seen[addr] = true end
        if go and i <= 12 then
            local tr = safe(function() return go:call("get_Transform") end)
            local p = upos_tr(tr)
            table.insert(out, "")
            table.insert(out, string.format("=== PILLAR %d: %s", i, tostring(safe(function() return go:call("get_Name") end))))
            table.insert(out, "  folder (scene path): " .. tostring(folder_path(go)))
            table.insert(out, string.format("  position: %s | %s from you",
                p and string.format("(%.1f, %.1f, %.1f)", p.x, p.y, p.z) or "?",
                (p and pp) and string.format("%.1f m", flat_dist(p, pp) or -1) or "?"))
            local ls = tr and safe(function() return tr:call("get_LocalScale") end)
            if ls then table.insert(out, "  local scale: " .. val_str(ls)) end
            table.insert(out, "  components: " .. table.concat(go_components(go), ", "))
            -- parent chain
            local par = tr and safe(function() return tr:call("get_Parent") end)
            local depth = 0
            while par and depth < 6 do
                local pg = safe(function() return par:call("get_GameObject") end)
                table.insert(out, string.format("  parent %d: %s  [%s]", depth + 1, tostring(pg and safe(function() return pg:call("get_Name") end)),
                    pg and table.concat(go_components(pg), ", ") or ""))
                par = safe(function() return par:call("get_Parent") end)
                depth = depth + 1
            end
            -- children (2 levels)
            local function kids(t, indent, lvl)
                local ch = t and safe(function() return t:call("get_Child") end)
                local n = 0
                while ch and n < 40 do
                    local cg = safe(function() return ch:call("get_GameObject") end)
                    table.insert(out, string.format("%schild: %s  [%s]", indent, tostring(cg and safe(function() return cg:call("get_Name") end)),
                        cg and table.concat(go_components(cg), ", ") or ""))
                    if lvl < 2 then kids(ch, indent .. "  ", lvl + 1) end
                    ch = safe(function() return ch:call("get_Next") end)
                    n = n + 1
                end
            end
            kids(tr, "  ", 1)
            -- siblings with a mesh within the same parent (the visible column may be a sibling)
            table.insert(out, "  -- Gm81_097 component fields --")
            pcall(dump_obj, c, 2, "    ", out, {})
        end
    end
    -- Medusa's own view (any Medusa nearby, Rancor or world)
    for _, m in ipairs(find_components("app.Ch255000")) do
        local tgt = safe(function() return m["<ClimberTargetGimmick>k__BackingField"] end)
        local mgo = safe(function() return m:call("get_GameObject") end)
        table.insert(out, "")
        table.insert(out, string.format("=== MEDUSA %s: ClimberTargetGimmick = %s", tostring(mgo and safe(function() return mgo:call("get_Name") end)),
            tgt and tostring(safe(function() return tgt:call("get_GameObject"):call("get_Name") end)) or "nil"))
        local cc = safe(function() return m._Ch255ClimbController end)
        if cc then pcall(dump_obj, cc, 1, "    ", out, {}) end
    end
    list_methods(PILLAR_TYPE, out)
    local td = sdk.find_type_definition(PILLAR_TYPE)
    local parent = td and td:get_parent_type()
    if parent then list_methods(parent:get_full_name(), out) end
    if #comps > 0 or force then
        pcall(fs.write, SCOUT_FILE, table.concat(out, "\n"))
    end
    if new > 0 or force then
        scout_count = scout_count + new
        log(string.format("Pillar scout: %d pillar(s) loaded (%d new) - written to data/%s", #comps, new, SCOUT_FILE))
    end
end
PX.scout = function(now, force)
    if not force and not config.medusa_pillar_scout then return end
    if not force and now - scout_last < 10 then return end
    scout_last = now
    local ok, err = pcall(scout_pillars, force)
    if not ok then log("Pillar scout error: " .. tostring(err)) end
end
end)()
;(function()   -- own function scope (Lua's 200-local limit)
-- 15) v1.9.19: pillar prefab hunt + spawn test (menu buttons; research) ------------------------
-- The scout showed each lair pillar (gm81_098_04/05/06, GimmickID 235) is ONE self-contained
-- object: mesh + colliders + the climbable Gm81_097 component (IsGenerate = true), so it comes from
-- a prefab. "Find pillar prefab" walks the game's gimmick/generate managers for anything naming
-- gm81_098 and tries likely prefab paths. "Spawn test pillar" puts one 8 m in front of you.
local pillar_prefab_path = nil
local pillar_spawn = { state = "idle" }
local PILLAR_GUESSES = {
    "AppSystem/Gimmick/gm81_098/gm81_098.pfb",
    "AppSystem/Gimmick/gm81_098/gm81_098_00.pfb",
    "AppSystem/Gimmick/gm81/gm81_098/gm81_098.pfb",
    "AppSystem/Gimmick/gm81/gm81_098.pfb",
    "AppSystem/Prefab/Gimmick/gm81_098.pfb",
    "AppSystem/Prefab/Gimmick/gm81/gm81_098.pfb",
    "GameDesign/Gimmick/gm81_098/gm81_098.pfb",
    "Environment/Gimmick/gm81_098/gm81_098.pfb",
    "AppSystem/Gimmick/gm81_098/gm81_098_04.pfb",
    "AppSystem/Gimmick/gm81_098/Prefab/gm81_098.pfb",
    "AppSystem/Gimmick/Prefab/gm81_098.pfb",
    "AppSystem/Prefab/gm81_098.pfb",
    "Gimmick/gm81_098/gm81_098.pfb",
    "Gimmick/gm81/gm81_098.pfb",
}
local function prefab_probe(path)
    local res = safe(function() return sdk.create_resource("via.PrefabResource", path) end)
    if not res then return nil, "no resource" end
    local pf = safe(function() return res:create_holder("via.Prefab") end)
    if not pf then return nil, "no holder" end
    pf = safe(function() return pf:add_ref() end) or pf
    local exist = safe(function() return pf:call("get_Exist") end)
    return pf, exist
end
local function hunt_prefab()
    local out = { "Rancor Reinforcements - pillar prefab hunt (" .. os.date() .. ")", "" }
    -- 1) singletons that may hold gimmick catalogs
    local hits = {}
    local samples = {}
    local nprefabs = 0
    local t0 = os.clock()
    local function walk(obj, path, depth, seen)
        if #hits > 60 or depth < 0 or not obj or os.clock() - t0 > 10 then return end
        local addr = safe(function() return obj:get_address() end)
        if not addr or seen[addr] then return end
        seen[addr] = true
        local td = safe(function() return obj:get_type_definition() end)
        if not td then return end
        local tn = td:get_full_name()
        if tn == "via.Prefab" then
            local p = safe(function() return obj:call("get_Path") end) or safe(function() return obj:call("get_ResourcePath") end)
            nprefabs = nprefabs + 1
            if type(p) == "string" then
                if p:lower():find("gm81", 1, true) then table.insert(hits, path .. " = via.Prefab " .. p) end
                if #samples < 15 then table.insert(samples, path .. " = " .. p) end
            end
            return
        end
        if tn:find("^via%.") or tn:find("GameObject") then return end
        local cnt = safe(function() return obj:call("get_Count") end) or safe(function() return obj:get_size() end)
        local first_ok = type(cnt) == "number" and cnt > 0 and (safe(function() return obj:call("get_Item", 0) end) ~= nil or safe(function() return obj:get_element(0) end) ~= nil)
        if type(cnt) == "number" and (first_ok or cnt == 0) then
            for i = 0, math.min(cnt, 600) - 1 do
                local el = safe(function() return obj:call("get_Item", i) end) or safe(function() return obj:get_element(i) end)
                if type(el) == "string" then
                    if el:lower():find("gm81_098", 1, true) then table.insert(hits, path .. "[" .. i .. "] = " .. el) end
                elseif type(el) == "userdata" then
                    local s = safe(function() return el:call("ToString") end)
                    if type(s) == "string" and s:lower():find("gm81_098", 1, true) and not s:find("GameObject", 1, true) then
                        table.insert(hits, path .. "[" .. i .. "] = " .. s)
                    end
                    walk(el, path .. "[" .. i .. "]", depth - 1, seen)
                end
            end
            return
        end
        local tdi = td
        while tdi do
            local n = tdi:get_full_name()
            if n == "System.Object" or n == "via.Component" or n == "via.Behavior" then break end
            for _, f in ipairs(tdi:get_fields() or {}) do
                if not f:is_static() then
                    local name = f:get_name()
                    local ok, v = pcall(function() return obj:get_field(name) end)
                    if ok and type(v) == "string" then
                        if v:lower():find("gm81_098", 1, true) then table.insert(hits, path .. "." .. name .. " = " .. v) end
                    elseif ok and type(v) == "userdata" then
                        local s = safe(function() return v:call("ToString") end)
                        if type(s) == "string" and s:lower():find("gm81_098", 1, true) and not s:find("GameObject", 1, true) then
                            table.insert(hits, path .. "." .. name .. " = " .. s)
                        end
                        walk(v, path .. "." .. name, depth - 1, seen)
                    end
                end
            end
            tdi = tdi:get_parent_type()
        end
    end
    for _, sn in ipairs({ "app.GimmickManager", "app.GenerateManager", "app.GimmickGenerateManager", "app.PrefabManager",
                          "app.ResourceManager", "app.EnvironmentManager", "app.StageManager" }) do
        local s = safe(function() return sdk.get_managed_singleton(sn) end)
        table.insert(out, string.format("singleton %s: %s", sn, s and "found" or "not found"))
        if s then
            -- list the manager's own fields first (name : type)
            local td = safe(function() return s:get_type_definition() end)
            for _, f in ipairs(td and td:get_fields() or {}) do
                if not f:is_static() then
                    table.insert(out, string.format("    %s : %s", f:get_name(), safe(function() return f:get_type():get_full_name() end) or "?"))
                end
            end
            walk(s, sn, 5, {})
        end
    end
    -- 2) the loaded pillars themselves: any prefab / generate info naming them
    for i, c in ipairs(find_components("app.Gm81_097")) do
        local go = safe(function() return c:call("get_GameObject") end)
        local gi = go and safe(function() return go:call("getComponent(System.Type)", sdk.typeof("app.GenerateInfo")) end)
        if gi and i <= 2 then walk(gi, "pillar" .. i .. ".GenerateInfo", 4, {}) end
        local gs = go and safe(function() return go:call("getComponent(System.Type)", sdk.typeof("app.GenerateSetting")) end)
        if gs and i <= 2 then walk(gs, "pillar" .. i .. ".GenerateSetting", 4, {}) end
    end
    table.insert(out, "")
    table.insert(out, string.format("== %d prefab references seen in the managers; samples:", nprefabs))
    for _, x in ipairs(samples) do table.insert(out, "  " .. x) end
    table.insert(out, "")
    table.insert(out, "== references naming gm81_098:")
    for _, h in ipairs(hits) do table.insert(out, "  " .. h) end
    if #hits == 0 then table.insert(out, "  (none found)") end
    -- 2b) control test: a prefab the game is known to have
    table.insert(out, "")
    table.insert(out, "== control test (known prefab):")
    for _, cp in ipairs({ "AppSystem/Gimmick/gm_common/Marker.pfb", "AppSystem/Generate/Prefab/GenerateAILocalAreaChecker.pfb" }) do
        local r = safe(function() return sdk.create_resource("via.Prefab", cp) end)
        local h = r and safe(function() return r:create_holder("via.Prefab") end)
        table.insert(out, string.format("  %s -> resource %s, holder %s, Exist %s", cp, tostring(r ~= nil), tostring(h ~= nil),
            tostring(h and safe(function() return h:call("get_Exist") end))))
        local r2 = safe(function() return sdk.create_resource("via.PrefabResource", cp) end)
        table.insert(out, string.format("     (as via.PrefabResource: %s)", tostring(r2 ~= nil)))
    end
    local gm = safe(function() return sdk.get_managed_singleton("app.GimmickManager") end)
    local mp = gm and safe(function() return gm["<MarkerPrefab>k__BackingField"] end)
    if mp then
        table.insert(out, "  GimmickManager.MarkerPrefab: type " .. tostring(safe(function() return mp:get_type_definition():get_full_name() end)) ..
            ", Exist " .. tostring(safe(function() return mp:call("get_Exist") end)) .. ", fields:")
        local mtd = safe(function() return mp:get_type_definition() end)
        for _, f in ipairs(mtd and mtd:get_fields() or {}) do
            table.insert(out, "    " .. f:get_name() .. " : " .. tostring(safe(function() return f:get_type():get_full_name() end)) .. " = " ..
                tostring(safe(function() return val_str(mp:get_field(f:get_name())) end)))
        end
    end
    -- 2c) resource paths used by a loaded pillar (mesh, material, collision)
    table.insert(out, "")
    table.insert(out, "== resources used by a loaded pillar:")
    local folders = {}
    local c1 = find_components("app.Gm81_097")[1]
    local pgo = c1 and safe(function() return c1:call("get_GameObject") end)
    if pgo then
        local mesh = safe(function() return pgo:call("getComponent(System.Type)", sdk.typeof("via.render.Mesh")) end)
        for _, mname in ipairs({ "getMesh", "get_Mesh", "getMaterial", "get_Material" }) do
            local r = mesh and safe(function() return mesh:call(mname) end)
            local rp = r and (safe(function() return r:call("get_ResourcePath") end) or safe(function() return r:call("ToString") end))
            if rp then
                table.insert(out, "  Mesh." .. mname .. " -> " .. tostring(rp))
                local folder = tostring(rp):match("^(.*)/[^/]+$")
                if folder then folders[folder] = true end
            end
        end
        local col = safe(function() return pgo:call("getComponent(System.Type)", sdk.typeof("via.physics.Colliders")) end)
        local cr = col and (safe(function() return col:call("get_CollidersResource") end) or safe(function() return col:call("getCollidersResource") end))
        if cr then table.insert(out, "  Colliders resource -> " .. tostring(safe(function() return cr:call("get_ResourcePath") end) or val_str(cr))) end
        local ctd = col and safe(function() return col:get_type_definition() end)
        for _, m in ipairs(ctd and ctd:get_methods() or {}) do
            local n = m:get_name()
            if n:lower():find("resource") or n:lower():find("path") then table.insert(out, "    Colliders method: " .. n) end
        end
        local mtd2 = mesh and safe(function() return mesh:get_type_definition() end)
        for _, m in ipairs(mtd2 and mtd2:get_methods() or {}) do
            local n = m:get_name()
            if n:lower():find("resource") or n:lower():find("path") or n == "getMesh" or n == "get_Mesh" then table.insert(out, "    Mesh method: " .. n) end
        end
    end
    -- 2d) the game's own create / generate / instantiate entry points
    for _, tn in ipairs({ "app.InstantiateCtrl", "app.GimmickManager", "app.GenerateManager" }) do
        local td = sdk.find_type_definition(tn)
        table.insert(out, "")
        table.insert(out, "== " .. tn .. " create/generate/instantiate methods:")
        for _, m in ipairs(td and td:get_methods() or {}) do
            local n = m:get_name()
            local l = n:lower()
            if l:find("instantiate") or l:find("create") or l:find("generate") or l:find("spawn") or l:find("request") then
                local ps = {}
                for _, t in ipairs(safe(function() return m:get_param_types() end) or {}) do table.insert(ps, t:get_full_name()) end
                table.insert(out, string.format("  %s(%s)", n, table.concat(ps, ", ")))
            end
        end
    end
    -- 3) guessed prefab paths
    table.insert(out, "")
    table.insert(out, "== guessed prefab paths (Exist = does the game have this file):")
    local found = nil
    local cand = {}
    for folder, _ in pairs(folders) do
        table.insert(cand, folder .. "/gm81_098.pfb")
        table.insert(cand, folder .. "/gm81_098_04.pfb")
    end
    for _, h in ipairs(hits) do
        local p = h:match("([%w_/%.]+%.pfb)")
        if p then table.insert(cand, p) end
    end
    for _, p in ipairs(PILLAR_GUESSES) do table.insert(cand, p) end
    for _, p in ipairs(cand) do
        local pf, exist = prefab_probe(p)
        table.insert(out, string.format("  %s -> Exist %s", p, tostring(exist)))
        if exist == true and not found then found = p end
    end
    local ptd = sdk.find_type_definition("via.Prefab")
    table.insert(out, "")
    table.insert(out, "== via.Prefab methods:")
    for _, m in ipairs(ptd and ptd:get_methods() or {}) do
        local ps = {}
        for _, t in ipairs(safe(function() return m:get_param_types() end) or {}) do table.insert(ps, t:get_full_name()) end
        table.insert(out, string.format("  %s(%s)", m:get_name(), table.concat(ps, ", ")))
    end
    pcall(fs.write, "RancorReinforcements_pillar_prefab.txt", table.concat(out, "\n"))
    pillar_prefab_path = found
    log(string.format("Pillar prefab hunt: %d reference(s) naming gm81_098; prefab %s (data/RancorReinforcements_pillar_prefab.txt)",
        #hits, found and ("FOUND: " .. found) or "not found yet"))
end

local PILLAR_GIMMICK_ID = 235
local QUAT_TD4 = sdk.find_type_definition("via.Quaternion")
local spawn_queue = nil     -- runs on the game's update thread
-- object-graph walker: collects managed objects (address -> object), walking fields (no get_Item on
-- maps), list/array elements; root_filter limits which root fields are followed
local function walk_graph(root, max_depth, root_filter, budget, prefabs, time_cap)
    local out, seen, n = {}, {}, 0
    local t0 = os.clock()
    local function visit(obj, depth, is_root)
        if n > (budget or 20000) or os.clock() - t0 > (time_cap or 0.25) then return end
        if type(obj) ~= "userdata" then return end
        local td = safe(function() return obj:get_type_definition() end)
        if not td then return end
        local tn = safe(function() return td:get_full_name() end) or ""
        local is_vt = safe(function() return td:is_value_type() end)
        if not is_vt then
            local addr = safe(function() return obj:get_address() end)
            if not addr or addr == 0 or seen[addr] then return end
            seen[addr] = true
            n = n + 1
            if not tn:find("^via%.") and tn ~= "System.String" then out[addr] = { obj = obj, tn = tn } end
            if prefabs and tn == "via.Prefab" then prefabs[addr] = obj end
        end
        if depth <= 0 then return end
        if tn:find("^via%.") or tn == "System.String" or tn:find("^System%.Type") or tn:find("Action`") or tn:find("^System%.Func") or tn:find("^System%.Action") then return end
        if tn:find("Dictionary`", 1, true) or tn:find("HashSet`", 1, true) or tn:find("Queue`", 1, true)
            or tn:find("Stack`", 1, true) or tn:find("Entry", 1, true) or tn:find("Pool`", 1, true) then return end
        if tn:find("List`1", 1, true) then
            local cnt = safe(function() return obj:call("get_Count") end) or 0
            for i = 0, math.min(cnt, 128) - 1 do
                local el = safe(function() return obj:call("get_Item", i) end)
                if type(el) == "userdata" then visit(el, depth - 1, false) end
            end
            return
        end
        if tn:sub(-2) == "[]" then
            local cnt = safe(function() return obj:get_size() end) or 0
            for i = 0, math.min(cnt, 128) - 1 do
                local el = safe(function() return obj:get_element(i) end)
                if type(el) == "userdata" then visit(el, depth - 1, false) end
            end
            return
        end
        local tdi = td
        while tdi do
            local bn = safe(function() return tdi:get_full_name() end) or ""
            if bn == "System.Object" or bn == "System.ValueType" or bn == "via.Component" or bn == "via.Behavior" then break end
            for _, f in ipairs(safe(function() return tdi:get_fields() end) or {}) do
                if not f:is_static() then
                    local fname = f:get_name()
                    local follow = true
                    if is_root and root_filter then
                        local ftn = safe(function() return f:get_type():get_full_name() end) or ""
                        follow = root_filter(fname, ftn)
                    end
                    if follow then
                        local ok, v = pcall(function() return obj:get_field(fname) end)
                        if ok and type(v) == "userdata" then visit(v, depth - 1, false) end
                    end
                end
            end
            tdi = safe(function() return tdi:get_parent_type() end)
        end
    end
    visit(root, max_depth, true)
    return out, n
end
local function reserve_snapshot()
    local gen = sdk.get_managed_singleton("app.GenerateManager")
    if not gen then return {}, 0 end
    return walk_graph(gen, 7, function(name, tn)
        local s2 = (name .. " " .. tn):lower()
        return s2:find("reserve", 1, true) or s2:find("distributor", 1, true) or s2:find("request", 1, true) or s2:find("unit", 1, true)
    end, 30000)
end
PX.pins = PX.pins or {}
local function pin_obj(o)
    if pcall(function() o:add_ref_permanent() end) then table.insert(PX.pins, o); return true end
    if pcall(function() o:add_ref() end) then table.insert(PX.pins, o); return true end
    return false
end
local function type_hist(list, maxn)
    local h, keys = {}, {}
    for _, e in pairs(list) do
        local t = (e.tn or "?"):gsub("^app%.", "")
        if not h[t] then h[t] = 0; table.insert(keys, t) end
        h[t] = h[t] + 1
    end
    table.sort(keys, function(a, b) return h[a] > h[b] end)
    local parts = {}
    for i = 1, math.min(#keys, maxn or 10) do table.insert(parts, keys[i] .. " x" .. h[keys[i]]) end
    return table.concat(parts, ", ")
end
PX.pin_pillar_graph = function(go)
    local arr = safe(function() return go:call("get_Components") end)
    local all, total = {}, 0
    for _, c in ipairs(arr and (safe(function() return arr:get_elements() end) or {}) or {}) do
        local ctn = safe(function() return c:get_type_definition():get_full_name() end) or ""
        if ctn:find("^app%.") then
            local found = walk_graph(c, 3, nil, 8000)
            for a, e in pairs(found) do
                if not all[a] and not e.tn:find("^app%..*Manager$") then all[a] = e; total = total + 1 end
            end
        end
    end
    local pinned = 0
    for _, e in pairs(all) do if pin_obj(e.obj) then pinned = pinned + 1 end end
    log_now(string.format("Pillar: pinned %d/%d objects reachable from its components [%s]", pinned, total, type_hist(all, 8)))
end

local function prefab_path_of(pf)
    return safe(function() return pf:call("get_Path") end) or safe(function() return pf:call("get_ResourcePath") end)
end
PX.hunt_prefab2 = function(pillar_go)   -- game thread
    local prefabs = {}
    local t0 = os.clock()
    local notes = {}
    if pillar_go then
        local arr = safe(function() return pillar_go:call("get_Components") end)
        for _, c in ipairs(arr and (safe(function() return arr:get_elements() end) or {}) or {}) do
            local ctn = safe(function() return c:get_type_definition():get_full_name() end) or ""
            if ctn == "app.GenerateInfo" or ctn == "app.GenerateSetting" then
                local found, n = walk_graph(c, 5, nil, 4000, prefabs, 0.5)
                table.insert(notes, string.format("%s: %d objects", ctn, n or 0))
            end
        end
    end
    local gen = sdk.get_managed_singleton("app.GenerateManager")
    local cat = gen and safe(function() return gen:get_field("_CatalogCtrl") end)
    if cat then
        local found, n = walk_graph(cat, 5, nil, 8000, prefabs, 1.0)
        table.insert(notes, string.format("catalog: %d objects", n or 0))
        local ctd = safe(function() return cat:get_type_definition() end)
        local ms = {}
        for _, m in ipairs(ctd and ctd:get_methods() or {}) do
            local ps = {}
            for _, t in ipairs(safe(function() return m:get_param_types() end) or {}) do table.insert(ps, (t:get_full_name():gsub("^app%.", ""))) end
            table.insert(ms, m:get_name() .. "(" .. table.concat(ps, ", ") .. ")")
        end
        local fl = {}
        for _, f in ipairs(ctd and ctd:get_fields() or {}) do table.insert(fl, f:get_name() .. ":" .. (safe(function() return f:get_type():get_full_name() end) or "?")) end
        PX.catalog_info = "catalog methods: " .. table.concat(ms, "; ") .. "\ncatalog fields: " .. table.concat(fl, "; ")
    end
    local out, hits, total = { "Rancor Reinforcements - prefab hunt 2 (" .. os.date() .. ")", table.concat(notes, ", "), PX.catalog_info or "", "" }, {}, 0
    local paths = {}
    for _, pf in pairs(prefabs) do
        local path = prefab_path_of(pf)
        total = total + 1
        if type(path) == "string" then
            table.insert(paths, path)
            if path:lower():find("gm81_098", 1, true) then table.insert(hits, { path = path, pf = pf }) end
        end
    end
    table.sort(paths)
    for _, pth in ipairs(paths) do table.insert(out, pth) end
    pcall(fs.write, "RancorReinforcements_prefab_hunt2.txt", table.concat(out, "\n"))
    if #hits > 0 then
        table.sort(hits, function(a, b) return #a.path < #b.path end)
        local h = hits[1]
        PX.pillar_prefab = h.pf
        pcall(function() h.pf:add_ref_permanent() end)
        config.pillar_prefab_path = h.path
        pcall(save_config)
    end
    log_now(string.format("Prefab hunt 2: %d prefabs seen in %.2f s, %d naming gm81_098%s (list: data/RancorReinforcements_prefab_hunt2.txt)",
        total, os.clock() - t0, #hits, #hits > 0 and (" -> PILLAR PREFAB: " .. hits[1].path) or ""))
end
-- prefab-method spawn (plain instantiate, NOT a spawn-system object); runs on the game thread
local VEC3_TDP = sdk.find_type_definition("via.vec3")
-- safe prefab finder: catalog ref-count + lookup, no spawning (game thread)
PX.find_req = nil
local function describe(obj)
    local td = safe(function() return obj:get_type_definition() end)
    local parts = {}
    local tdi = td
    while tdi do
        local bn = tdi:get_full_name()
        if bn == "System.Object" or bn == "System.ValueType" then break end
        for _, f in ipairs(tdi:get_fields() or {}) do
            if not f:is_static() then
                local ftn = safe(function() return f:get_type():get_full_name() end) or "?"
                local ok, v = pcall(function() return obj:get_field(f:get_name()) end)
                local vs = ok and (type(v) == "userdata" and ("<" .. (safe(function() return v:get_type_definition():get_full_name() end) or "?") .. ">") or tostring(v)) or "(unreadable)"
                table.insert(parts, f:get_name() .. ":" .. ftn .. "=" .. vs)
            end
        end
        tdi = tdi:get_parent_type()
    end
    local ms = {}
    for _, m in ipairs(td and td:get_methods() or {}) do
        local ps = {}
        for _, t in ipairs(safe(function() return m:get_param_types() end) or {}) do table.insert(ps, (t:get_full_name():gsub("^app%.", ""))) end
        table.insert(ms, m:get_name() .. "(" .. table.concat(ps, ",") .. ")")
    end
    return (td and td:get_full_name() or "?") .. "\n  fields: " .. table.concat(parts, "; ") .. "\n  methods: " .. table.concat(ms, "; ")
end
local function catalog_lookup(cat, gid)
    local gc = safe(function() return cat:get_field("_GimmickCatalog") end)
    if not gc then return nil, "no _GimmickCatalog" end
    -- the catalog wraps a dictionary; find it and look up the key the safe way (ContainsKey first)
    local td = gc:get_type_definition()
    local tdi = td
    while tdi do
        for _, f in ipairs(tdi:get_fields() or {}) do
            local ftn = safe(function() return f:get_type():get_full_name() end) or ""
            if not f:is_static() and ftn:find("Dictionary`2", 1, true) then
                local d = safe(function() return gc:get_field(f:get_name()) end)
                if d and safe(function() return d:call("ContainsKey", gid) end) == true then
                    return safe(function() return d:call("get_Item", gid) end), f:get_name()
                end
            end
        end
        tdi = tdi:get_parent_type()
    end
    return nil, "key not in catalog yet"
end
PX.catalog_lookup = catalog_lookup   -- v1.9.85: for the gimmick finder
local function prefab_from_controller_1(pc)
    local td = pc:get_type_definition()
    local tdi = td
    while tdi do
        for _, f in ipairs(tdi:get_fields() or {}) do
            local ftn = safe(function() return f:get_type():get_full_name() end) or ""
            if not f:is_static() and ftn == "via.Prefab" then
                local pf = safe(function() return pc:get_field(f:get_name()) end)
                if pf then return pf, f:get_name() end
            end
        end
        tdi = tdi:get_parent_type()
    end
    for _, mname in ipairs({ "get_Prefab", "getPrefab" }) do
        local pf = safe(function() return pc:call(mname) end)
        if pf and safe(function() return pf:get_type_definition():get_full_name() end) == "via.Prefab" then return pf, mname end
    end
    return nil
end
local function prefab_from_controller(pc, notes)
    -- unwrap RefCounter`1<PrefabController> (_Item / get_Item)
    local inner = safe(function() return pc:get_field("_Item") end) or safe(function() return pc:call("get_Item") end)
    local tn = safe(function() return pc:get_type_definition():get_full_name() end) or ""
    if inner and tn:find("RefCounter", 1, true) then
        if notes then table.insert(notes, "PrefabController (unwrapped): " .. describe(inner)) end
        pc = inner
    end
    local pf, how = prefab_from_controller_1(pc)
    if pf then return pf, how end
    -- one level down: any app.* object field of the controller
    local tdi = safe(function() return pc:get_type_definition() end)
    while tdi do
        for _, f in ipairs(tdi:get_fields() or {}) do
            local ftn = safe(function() return f:get_type():get_full_name() end) or ""
            if not f:is_static() and ftn:find("^app%.") then
                local sub = safe(function() return pc:get_field(f:get_name()) end)
                if type(sub) == "userdata" then
                    local pf2, how2 = prefab_from_controller_1(sub)
                    if pf2 then return pf2, f:get_name() .. "." .. tostring(how2) end
                end
            end
        end
        tdi = tdi:get_parent_type()
    end
    return nil
end
PX.prefab_from_controller = prefab_from_controller   -- v1.9.75: reachable from the size check
PX.prefab_path_of = prefab_path_of
PX.find_step = function()
    local r = PX.find_req
    if not r then return end
    local gen = sdk.get_managed_singleton("app.GenerateManager")
    local cat = gen and safe(function() return gen:get_field("_CatalogCtrl") end)
    if not cat then PX.find_req = nil; log_now("Find pillar prefab: no spawn catalog"); return end
    if not r.started then
        r.started = true
        local gc = safe(function() return cat:get_field("_GimmickCatalog") end)
        local out = { "Rancor Reinforcements - pillar prefab (safe finder) " .. os.date(), "", "gimmick catalog: " .. (gc and describe(gc) or "nil") }
        pcall(fs.write, "RancorReinforcements_prefab_find.txt", table.concat(out, "\n"))
        local pc0 = catalog_lookup(cat, PILLAR_GIMMICK_ID)
        if not pc0 then
            local ok, err = pcall(function() cat:call("addGimmickRefCount", PILLAR_GIMMICK_ID) end)
            r.added = ok
            log_now("Find pillar prefab: asked the spawn catalog to load gimmick 235 (" .. (ok and "ok" or tostring(err)) .. ")")
        end
    end
    local pc, where = catalog_lookup(cat, PILLAR_GIMMICK_ID)
    if pc then
        local out = { "Rancor Reinforcements - pillar prefab (safe finder) " .. os.date(), "", "catalog entry: " .. describe(pc) }
        local pf, how = prefab_from_controller(pc, out)
        if pf then
            local path = prefab_path_of(pf)
            pcall(function() pf:add_ref_permanent() end)
            PX.pillar_prefab = pf
            if type(path) == "string" and path ~= "" then config.pillar_prefab_path = path; pcall(save_config) end
            table.insert(out, "prefab (" .. tostring(how) .. "): " .. tostring(path))
            log_now("Find pillar prefab: FOUND " .. tostring(path) .. " (catalog " .. tostring(where) .. ", " .. tostring(how) .. ")")
        else
            log_now("Find pillar prefab: catalog has gimmick 235 but no prefab field found - details in data/RancorReinforcements_prefab_find.txt")
        end
        pcall(fs.write, "RancorReinforcements_prefab_find.txt", table.concat(out, "\n"))
        PX.find_req = nil
        return
    end
    if os.clock() - r.t > 20 then
        PX.find_req = nil
        log_now("Find pillar prefab: gimmick 235 never appeared in the catalog (" .. tostring(where) .. ") - details in data/RancorReinforcements_prefab_find.txt")
    end
end

-- get the pillar prefab from the spawn catalog (game thread); asks the catalog to load it once
PX.prefab_by_gid = {}
-- v1.9.86: any other pillar gimmick (e.g. 408 = gm81_098_01, the Purgener's own bigger pillar)
PX.catalog_prefab_gid = function(r, gid)
    if PX.prefab_by_gid[gid] then return PX.prefab_by_gid[gid] end
    local gen = sdk.get_managed_singleton("app.GenerateManager")
    local cat = gen and safe(function() return gen:get_field("_CatalogCtrl") end)
    if not cat then return nil end
    local pc = catalog_lookup(cat, gid)
    if not pc then
        if not r.added then
            r.added = true
            local ok = pcall(function() cat:call("addGimmickRefCount", gid) end)
            log_now("Pillar (prefab): asked the spawn catalog to load gimmick " .. gid .. " (" .. (ok and "ok" or "failed") .. ")")
        end
        return nil
    end
    local pf = prefab_from_controller(pc)
    if pf then
        pcall(function() pf:add_ref_permanent() end)
        PX.prefab_by_gid[gid] = pf
        log_now("Pillar (prefab): got " .. tostring(prefab_path_of(pf)) .. " from the spawn catalog (gimmick " .. gid .. ")")
    end
    return pf
end
PX.catalog_prefab = function(r)
    if r.gid and r.gid ~= PILLAR_GIMMICK_ID then return PX.catalog_prefab_gid(r, r.gid) end
    local gen = sdk.get_managed_singleton("app.GenerateManager")
    local cat = gen and safe(function() return gen:get_field("_CatalogCtrl") end)
    if not cat then return nil end
    local pc = catalog_lookup(cat, PILLAR_GIMMICK_ID)
    if not pc then
        if not r.added then
            r.added = true
            local ok = pcall(function() cat:call("addGimmickRefCount", PILLAR_GIMMICK_ID) end)
            log_now("Pillar (prefab): asked the spawn catalog to load gimmick 235 (" .. (ok and "ok" or "failed") .. ")")
        end
        return nil
    end
    local pf = prefab_from_controller(pc)
    if pf then
        pcall(function() pf:add_ref_permanent() end)
        PX.pillar_prefab = pf
        log_now("Pillar (prefab): got " .. tostring(prefab_path_of(pf)) .. " from the spawn catalog")
    end
    return pf
end
PX.warm = { t0 = os.clock(), req = nil, done = false }
PX.warm_step = function()
    local w = PX.warm
    if w.done or PX.pillar_prefab or not config.medusa_pillar then w.done = true; return end
    if os.clock() - w.t0 < 10 then return end
    w.req = w.req or { t = os.clock() }
    if PX.catalog_prefab(w.req) then w.done = true; return end
    if os.clock() - w.req.t > 20 then w.done = true; log("Pillar (prefab): warm-up gave up - it will be fetched when Medusa arrives") end
end

-- make sure the pillar reports PreClimbInfoDone (1) + EnableToClimb (2); returns the status after
PX.enable_climb = function(comp, verbose)
    local stf = safe(function() return comp:get_field("Status") end)
    if not stf then return nil, "no Status" end
    local cur = safe(function() return stf:get_field("Data") end)
    if type(cur) == "number" and (math.tointeger(cur) or 0) & 3 == 3 then return cur, "already" end
    local tried = {}
    local td = safe(function() return stf:get_type_definition() end)
    if verbose and not PX.tsf_methods_logged then
        PX.tsf_methods_logged = true
        local ms = {}
        for _, m in ipairs(td and td:get_methods() or {}) do
            local ps = {}
            for _, t in ipairs(safe(function() return m:get_param_types() end) or {}) do table.insert(ps, (t:get_full_name():gsub("^app%.", ""))) end
            table.insert(ms, m:get_name() .. "(" .. table.concat(ps, ",") .. ")")
        end
        log("Pillar status flag methods: " .. table.concat(ms, "; "))
    end
    -- 1) the flag type's own methods
    for _, m in ipairs(td and td:get_methods() or {}) do
        local mn = m:get_name()
        local np = safe(function() return m:get_num_params() end) or -1
        local l = mn:lower()
        if (l == "on" or l == "seton" or l == "add" or l == "addflag" or l == "seton") and np == 1 then
            for _, bit in ipairs({ 1, 2 }) do
                local ok = pcall(function() stf:call(mn, bit) end)
                table.insert(tried, mn .. "(" .. bit .. ")=" .. tostring(ok))
            end
        elseif (l == "set" or l == "setflag") and np == 2 then
            for _, bit in ipairs({ 1, 2 }) do
                local ok = pcall(function() stf:call(mn, bit, true) end)
                table.insert(tried, mn .. "(" .. bit .. ",true)=" .. tostring(ok))
            end
        end
    end
    cur = safe(function() return stf:get_field("Data") end)
    -- 2) the raw field
    if not (type(cur) == "number" and (math.tointeger(cur) or 0) & 3 == 3) then
        local ok, err = pcall(function() stf:set_field("Data", 3) end)
        table.insert(tried, "Data=3 " .. (ok and "ok" or tostring(err)))
        cur = safe(function() return stf:get_field("Data") end)
    end
    return cur, table.concat(tried, ", ")
end

-- is anyone standing where the pillar would go? (player, pawns/party, Rancor Medusas)
local PILLAR_CLEAR = 4.5
PX.spot_blocker = function(x, z)
    local spot = { x = x, z = z }
    local up = player_upos()
    if up and (flat_dist(up, spot) or 99) < PILLAR_CLEAR then return "you" end
    -- party members: the characters in a Rancor Medusa's target list (you + pawns)
    for _, e in pairs(medusa) do
        local arr = safe(function() return m_module(e.chara)._TargetCtrl._TargetArray end)
        for _, i in ipairs({ 12, 4, 2, 3, 5, 6, 43, 44, 0, 1 }) do
            local t = arr and safe(function() return arr:get_element(i) end)
            local ch = t and safe(function() return t["<Character>k__BackingField"] end)
            local go = ch and safe(function() return ch:call("get_GameObject") end)
            local pp = go and upos_go(go)
            if pp and (flat_dist(pp, spot) or 99) < PILLAR_CLEAR and go ~= e.go then return "a party member" end
        end
    end
    for _, e in pairs(medusa) do
        local mp = upos_go(e.go)
        if mp and (flat_dist(mp, spot) or 99) < PILLAR_CLEAR then return "Medusa" end
    end
    return nil
end

PX.prefab_req = nil
PX.prefab_step = function()
    local r = PX.prefab_req
    if not r then return end
    if not r.pf then
        if r.gid and r.gid ~= PILLAR_GIMMICK_ID then
            r.pf = PX.catalog_prefab(r)
        else
            r.pf = PX.pillar_prefab or (PX.catalog_prefab and PX.catalog_prefab(r))
        end
        if not r.pf then
            if os.clock() - r.t > 15 then
                PX.prefab_req = nil
                pillar_spawn = { state = "failed", tag = r.tag }
                log_now("Pillar (prefab): the spawn catalog did not provide gimmick " .. tostring(r.gid or 235) .. " within 15 s")
            end
            return
        end
        pcall(function() r.pf:call("set_Standby", true) end)
    end
    local ready = safe(function() return r.pf:call("get_Ready") end)
    if not ready then
        if os.clock() - r.t > 15 then
            PX.prefab_req = nil
            pillar_spawn = { state = "failed", tag = r.tag }
            log_now("Pillar (prefab): prefab never became ready (15 s)")
        end
        return
    end
    local who = PX.spot_blocker(r.x, r.z)
    if who then
        if not r.block_logged then
            r.block_logged = true
            log(string.format("Pillar (prefab): waiting - %s %s standing on the pillar spot (needs %.1f m clear)", who, who == "you" and "are" or "is", PILLAR_CLEAR))
        end
        return
    end
    if r.block_logged then log("Pillar (prefab): spot is clear now - placing the pillar") end
    PX.prefab_req = nil
    -- world (universal) target -> this engine's local coordinates, via the player's two positions
    local cm = sdk.get_managed_singleton("app.CharacterManager")
    local pl = cm and safe(function() return cm["<ManualPlayer>k__BackingField"] end)
    local tr = pl and safe(function() return pl:get_Transform() end)
    local lp = tr and safe(function() return tr:call("get_Position") end)
    local up = player_upos()
    if not lp or not up then pillar_spawn = { state = "failed", tag = r.tag }; log_now("Pillar (prefab): no player position"); return end
    local lift = tonumber(config.medusa_pillar_lift) or 0.0
    local lx, ly, lz = vfield(lp, "x") + (r.x - up.x), vfield(lp, "y") + (r.y - up.y) + lift, vfield(lp, "z") + (r.z - up.z)
    log_now(string.format("Pillar (prefab): instantiating %s at local (%.1f, %.1f, %.1f)", tostring(prefab_path_of(r.pf)), lx, ly, lz))
    local ok, go = pcall(function()
        local v = ValueType.new(VEC3_TDP)
        v:set_field("x", lx); v:set_field("y", ly); v:set_field("z", lz)
        return r.pf:call("instantiate(via.vec3)", v)
    end)
    if not ok or not go then
        pillar_spawn = { state = "failed", tag = r.tag }
        log_now("Pillar (prefab): instantiate failed: " .. tostring(go))
        return
    end
    pcall(function() go:add_ref() end)
    local comp = nil
    local arr = safe(function() return go:call("get_Components") end)
    local names = {}
    for _, c in ipairs(arr and (safe(function() return arr:get_elements() end) or {}) or {}) do
        local n = safe(function() return c:get_type_definition():get_name() end) or "?"
        table.insert(names, n)
        if n == "Gm81_097" then comp = c end
    end
    pillar_spawn = { state = "spawned", go = go, comp = comp, t_spawned = os.clock(), t = os.clock(), tag = r.tag, method = "prefab", uid_checked = false }
    local p = upos_go(go)
    log_now(string.format("Pillar (prefab): SPAWNED %s at %s (%s from target, origin %.1f m above the floor) [%s]", tostring(safe(function() return go:call("get_Name") end)),
        p and string.format("(%.1f, %.1f, %.1f)", p.x, p.y, p.z) or "?", p and string.format("%.1f m", flat_dist(p, r) or -1) or "?", lift,
        table.concat(names, ", ")))
    PX.climb_check = { comp = comp, go = go, t = os.clock(), floor_y = r.y, gid = r.gid or PILLAR_GIMMICK_ID }
    if comp then PX.repair_uid(pillar_spawn) end
    if r.tag == "arena" then
        PILLAR_AI.go, PILLAR_AI.comp, PILLAR_AI.pos, PILLAR_AI.t, PILLAR_AI.floor_y = go, comp, p, os.clock(), r.y
    end
end
-- Medusa pillar AI helpers (used by the think-row / route / climb-search hooks)
PILLAR_AI.try_start = function(e)
    if e.hydra then return false end   -- v1.9.157
    if not (config.medusa_pillar_use and PILLAR_AI.go and PILLAR_AI.pos) then return false end
    local now = os.clock()
    if now - (PILLAR_AI.t or now) < 15 then return false end
    if now - PILLAR_AI.last_try < (config.medusa_pillar_interval or 60) then return false end
    if e.pillar and not e.pillar.done then return false end
    local here = upos_go(e.go)
    if not here then return false end
    local P = PILLAR_AI.pos
    local dx, dz = here.x - P.x, here.z - P.z
    local d = math.sqrt(dx * dx + dz * dz)
    if d < 0.5 then dx, dz, d = 1, 0, 1 end
    local start = { x = P.x + dx / d * 4.0, y = PILLAR_AI.floor_y or P.y, z = P.z + dz / d * 4.0 }
    PILLAR_AI.last_try = now
    e.pillar = { t = now, start = start, n = ((e.pillar and e.pillar.n) or 0) + 1 }
    e.bp, e.bp_t, e.bp_kind, e.reached_t = start, now, "pillar", nil
    e.unstick_until = nil          -- her pillar table ends on the same timer the unstick pass opens
    local ctrl = m_wpctrl(e.chara)
    if ctrl then
        write_pos_field(ctrl, "<LastFoundedBattlePosition>k__BackingField", start)
        write_pos_field(ctrl, "<NextPatrolPos>k__BackingField", start)
        write_nullable_pos_field(ctrl, "<CachedLastFoundedBattlePosition>k__BackingField", start)
        write_nullable_pos_field(ctrl, "<CachedNextPatrolPos>k__BackingField", start)
    end
    log(string.format("Medusa pillar #%d: her 'coil around the pillar' row passed - sending her to the pillar (start spot %.0f m from her)", e.pillar.n, d - 4))
    return true
end
PILLAR_AI.at_start = function(e)
    local pl = e.pillar
    if not pl or pl.done or os.clock() - pl.t > 25 then return false end
    local here = upos_go(e.go)
    return here ~= nil and (flat_dist(here, pl.start) or 99) < 4.5
end
PILLAR_AI.climb_out = PILLAR_AI.climb_out or {}
local function climb_note(title, obj, depth)
    local out = PILLAR_AI.climb_out
    if #out > 4000 then return end
    table.insert(out, "")
    table.insert(out, "=== " .. os.date("%H:%M:%S ") .. title)
    if obj then pcall(dump_obj, obj, depth or 1, "  ", out, {}) end
    pcall(fs.write, "RancorReinforcements_pillar_climb.txt", table.concat(out, "\n"))
end
PILLAR_AI.tick = function()
    local now = os.clock()
    if not next(medusa) and PILLAR_AI.arrow_ap then
        local okr = pcall(function() PILLAR_AI.arrow_ap._ArrowLockOnAngle = (PILLAR_AI.arrow_orig or 20) + 0.0 end)
        log("Medusa bow: lock-on cone restored to " .. tostring(PILLAR_AI.arrow_orig) .. " deg (" .. (okr and "ok" or "failed") .. ")")
        PILLAR_AI.arrow_ap, PILLAR_AI.arrow_orig = nil, nil
    end
    if false and PILLAR_AI.keep_enabled and PILLAR_AI.comp == PILLAR_AI.keep_enabled and now - (PILLAR_AI.keep_t or 0) > 2 then
        PILLAR_AI.keep_t = now
        local st4, how4 = PX.enable_climb(PILLAR_AI.comp, false)
        if how4 ~= "already" and not PILLAR_AI.keep_logged then
            PILLAR_AI.keep_logged = true
            log("Pillar climb fix: status had dropped - set again -> " .. tostring(st4) .. " [" .. tostring(how4) .. "]")
        end
    end
    if false and PILLAR_AI.comp and PILLAR_AI.dumped ~= PILLAR_AI.go and now - (PILLAR_AI.t or now) > 3 then
        PILLAR_AI.dumped = PILLAR_AI.go
        local P = PILLAR_AI.pos
        climb_note(string.format("ARENA PILLAR at (%.2f, %.2f, %.2f) - Gm81_097 fields", P and P.x or 0, P and P.y or 0, P and P.z or 0), PILLAR_AI.comp, 2)
        log("Pillar climb research: arena pillar climb data written to data/RancorReinforcements_pillar_climb.txt")
    end
    for _, e in pairs(medusa) do
        local act = safe(function() return e.chara["<ActionManager>k__BackingField"].CurrentAction:ToString() end)
        if type(act) == "string" and act:find("CimbGimmick", 1, true) then
            e.climb_since = e.climb_since or now
            local climbable = PILLAR_AI.comp and (math.tointeger(safe(function() return PILLAR_AI.comp:get_field("Status"):get_field("Data") end) or 0) or 0) & 2 ~= 0
            if now - e.climb_since > (climbable and 40 or 12) and now - (e.climb_release_t or 0) > 6 then
                e.climb_release_t = now
                local ch = safe(function() return e.go:call("getComponent(System.Type)", sdk.typeof("app.Ch255000")) end)
                local okr = ch and pcall(function() ch:set_field("<ClimberTargetGimmick>k__BackingField", nil) end)
                e.unstick_until = now + 3          -- let her "end of action" timer checks pass
                pcall(push_combat, e)              -- and push her back into her combat table
                e.climb_releases = (e.climb_releases or 0) + 1
                log(string.format("Medusa pillar: stuck in her climb loop for %.0f s - released her climb target (%s, #%d)",
                    now - e.climb_since, okr and "ok" or "failed", e.climb_releases))
            end
        else
            e.climb_since = nil
        end
    end
    for _, e in pairs(medusa) do
        local pl = e.pillar
        if false and pl and not pl.done and pl.search_ok and now - (pl.cc_t or 0) >= 2 and (pl.cc_n or 0) < 10 then
            pl.cc_t = now
            pl.cc_n = (pl.cc_n or 0) + 1
            local ch = safe(function() return e.go:call("getComponent(System.Type)", sdk.typeof("app.Ch255000")) end)
            local cc = ch and safe(function() return ch._Ch255ClimbController end)
            local here = upos_go(e.go)
            climb_note(string.format("MEDUSA climb #%d.%d at (%.2f, %.2f, %.2f), %.1f m from the pillar", pl.n, pl.cc_n,
                here and here.x or 0, here and here.y or 0, here and here.z or 0,
                (here and PILLAR_AI.pos and flat_dist(here, PILLAR_AI.pos)) or -1), cc, 1)
            if pl.cc_n == 1 and PILLAR_AI.comp then climb_note("ARENA PILLAR during her climb", PILLAR_AI.comp, 2) end
        end
    end
    for _, e in pairs(medusa) do
        local pl = e.pillar
        if pl and not pl.done then
            local climbed = safe(function() return e.go:call("getComponent(System.Type)", sdk.typeof("app.Ch255000"))["<ClimberTargetGimmick>k__BackingField"] end)
            if pl.search_ok and not pl.climb_logged then
                pl.climb_logged = true
            end
            if now - pl.t > 25 then
                pl.done = true
                if e.bp_kind == "pillar" then e.bp = nil end
                log(string.format("Medusa pillar #%d: attempt over after 25 s (climb search %s, climb target %s)", pl.n,
                    tostring(pl.search_ok), climbed and "set" or "none"))
            end
        end
    end
end
do  -- her own "find a climbable gimmick" check: log it, and point it at the arena pillar if it misses
    local td = sdk.find_type_definition("app.EmThkChkCh255FindClimbableGimmick")
    local m = td and td:get_method("evaluate")
    if m then
        pcall(sdk.hook, m, function(args)
            local st = thread.get_hook_storage()
            st["rr_fcg"] = nil
            local e = medusa_by_module[sdk.to_int64(args[3])]
            if e and not e.hydra then st["rr_fcg"] = e end
        end, function(retval)
            local st = thread.get_hook_storage()
            local e = st and st["rr_fcg"]
            if not e then return retval end
            st["rr_fcg"] = nil
            local ok = is_true(retval)
            local pl = e.pillar
            local ch = safe(function() return e.go:call("getComponent(System.Type)", sdk.typeof("app.Ch255000")) end)
            if pl and not pl.done then
                if not pl.search_logged or (ok and not pl.search_ok) then
                    pl.search_logged = true
                    local tgt = ch and safe(function() return ch["<ClimberTargetGimmick>k__BackingField"] end)
                    log(string.format("Medusa pillar #%d: her climbable-pillar search -> %s (climb target: %s)", pl.n, ok and "FOUND" or "nothing",
                        tgt and tostring(safe(function() return tgt:call("get_GameObject"):call("get_Name") end)) or "none"))
                end
                if ok then pl.search_ok = true; return retval end
                local here = upos_go(e.go)
                if PILLAR_AI.comp and ch and here and PILLAR_AI.pos and (flat_dist(here, PILLAR_AI.pos) or 99) < 10 then
                    local set_ok = pcall(function() ch:set_field("<ClimberTargetGimmick>k__BackingField", PILLAR_AI.comp) end)
                    if not pl.force_logged then
                        pl.force_logged = true
                        log("Medusa pillar #" .. pl.n .. ": pointed her climb search at the arena pillar (" .. (set_ok and "target set" or "could not set target") .. ")")
                    end
                    if set_ok then pl.search_ok = "forced"; return sdk.to_ptr(1) end
                end
            end
            return retval
        end)
    end
end
local function spawn_prefab_at(x, y, z, tag, gid)
    PX.prefab_req = { x = x, y = y, z = z, tag = tag, t = os.clock(), gid = gid }
    pillar_spawn = { state = "pf_loading", t = os.clock(), tag = tag }
    log("Pillar spawn (" .. tostring(tag) .. ", prefab method): queued for the game's update thread")
end
PX.spawn_prefab_at = spawn_prefab_at

local function create_gimmick_now(req)
    local gm = sdk.get_managed_singleton("app.GimmickManager")
    local td = sdk.find_type_definition("app.GimmickManager")
    local m = nil
    for _, mm in ipairs(td and td:get_methods() or {}) do
        if mm:get_name() == "createGimmick" and #(safe(function() return mm:get_param_types() end) or {}) == 10 then m = mm end
    end
    if not gm or not m then log("Pillar spawn: createGimmick not available"); return false end
    local pos = ValueType.new(POS_TD)
    pos:set_field("x", req.x); pos:set_field("y", req.y); pos:set_field("z", req.z)
    local q = ValueType.new(QUAT_TD4)
    q:set_field("x", 0.0); q:set_field("y", 0.0); q:set_field("z", 0.0); q:set_field("w", 1.0)
    -- flags 1|2 = DisableRegenerateOnUnload | RemoveContextOnUnload; load area 5 = LoadedArea
    PX.own_create = true
    log_now("Pillar spawn: calling createGimmick (game thread)")
    local ok, err = pcall(function() m:call(gm, PILLAR_GIMMICK_ID, pos, q, 3, nil, nil, nil, 5, false, 0) end)
    PX.own_create = false
    log(string.format("Pillar spawn: createGimmick(%d, flags 3, area LoadedArea) at (%.1f, %.1f, %.1f) -> %s", PILLAR_GIMMICK_ID, req.x, req.y, req.z,
        ok and "requested" or ("error: " .. tostring(err))))
    return ok
end
local remove_queue = nil
-- UniqueID check: returns readable(bool), description
local function uid_report(comp, label)
    if not comp then return false, "no component" end
    local parts = {}
    local readable = true
    for _, fname in ipairs({ "<UniqId>k__BackingField" }) do
        local ok, v = pcall(function() return comp:get_field(fname) end)
        if not ok or v == nil then
            readable = false
            table.insert(parts, fname .. " = (unreadable: " .. tostring(v) .. ")")
        else
            local str = safe(function() return v:call("ToString") end)
            if type(str) ~= "string" then readable = false end
            local fl = {}
            local td = safe(function() return v:get_type_definition() end)
            for _, f in ipairs(td and td:get_fields() or {}) do
                local nm = f:get_name()
                if f:is_static() then
                    table.insert(fl, "static " .. nm .. ":" .. (safe(function() return f:get_type():get_full_name() end) or "?"))
                else
                    local ok2, fv = pcall(function() return v:get_field(nm) end)
                    table.insert(fl, nm .. ":" .. (safe(function() return f:get_type():get_full_name() end) or "?") .. "=" .. (ok2 and val_str(fv) or "(unreadable)"))
                end
            end
            table.insert(parts, string.format('%s = "%s" {%s}', fname, tostring(str), table.concat(fl, ", ")))
        end
    end
    -- the UniqueIDContext inside the ContextHolder path is not walked (unsafe); the backing field is what the game uses
    return readable, (label or "") .. table.concat(parts, "; ")
end
local function hide_pillar(go)
    local done = {}
    if safe(function() go:call("set_DrawSelf", false); return true end) then table.insert(done, "not drawn") end
    local col_t = sdk.typeof("via.physics.Colliders")
    local col = col_t and safe(function() return go:call("getComponent(System.Type)", col_t) end)
    if col and safe(function() col:call("set_Enabled", false); return true end) then table.insert(done, "collision off") end
    local tr = safe(function() return go:call("get_Transform") end)
    local lp = tr and safe(function() return tr:call("get_Position") end)
    if lp and safe(function()
        local v = ValueType.new(sdk.find_type_definition("via.vec3"))
        v:set_field("x", lp.x); v:set_field("y", lp.y - 400); v:set_field("z", lp.z)
        tr:call("set_Position", v); return true end) then table.insert(done, "moved 400 m down") end
    return table.concat(done, ", ")
end
PX.repair_uid = function(ps)
    if not ps.comp or ps.uid_checked then return end
    ps.uid_checked = true
    local ok, txt = uid_report(ps.comp, "Pillar UniqueID right after spawn: ")
    log_now(txt .. (ok and " -> readable" or " -> NOT readable"))
    if ok then
        -- pin the game's own ID object (and the ContextHolder's) so it is never freed
        PX.uid_pins = PX.uid_pins or {}
        local function pin(o)
            if not o then return "nil" end
            local r = pcall(function() o:add_ref_permanent() end) and "permanent"
                or (pcall(function() o:add_ref() end) and "add_ref") or "FAILED"
            table.insert(PX.uid_pins, o)
            return r
        end
        local uid = safe(function() return ps.comp:get_field("<UniqId>k__BackingField") end)
        local ch = safe(function() return ps.comp:get_field("<CompContext>k__BackingField") end)
        local uctx = ch and safe(function() return ch:get_field("UniqueIDContext") end)
        local cu = uctx and safe(function() return uctx:get_field("UniqueID") end)
        local same = uid and cu and safe(function() return uid:get_address() == cu:get_address() end)
        local r1 = pin(uid)
        local r2 = (cu and not same) and pin(cu) or (same and "same object" or "none")
        log_now(string.format("Pillar: ID object pinned (%s); ContextHolder ID: %s", r1, r2))
    end
    if not ok then
        local utd = sdk.find_type_definition("app.UniqueID")
        local gm = utd and utd:get_method("get_Empty")
        local empty = gm and safe(function() return gm:call(nil) end)
        if not empty then
            log_now("Pillar: UniqueID.Empty not available - cannot repair")
        else
            pcall(function() empty:add_ref() end)
            PX.uid_keep = empty
            local r1 = pcall(function() ps.comp:set_field("<UniqId>k__BackingField", empty) end)
            local ch = safe(function() return ps.comp:get_field("<CompContext>k__BackingField") end)
            local uctx = ch and safe(function() return ch:get_field("UniqueIDContext") end)
            local r2 = uctx and pcall(function() uctx:set_field("UniqueID", empty) end)
            log_now(string.format("Pillar: ID repair -> gimmick UniqId set to Empty: %s; ContextHolder UniqueIDContext: %s",
                tostring(r1), uctx and tostring(r2) or "not found"))
            ok, txt = uid_report(ps.comp, "Pillar UniqueID after repair: ")
            log_now(txt .. (ok and " -> readable (repaired)" or " -> STILL NOT readable"))
            local cu = uctx and safe(function() return uctx:get_field("UniqueID") end)
            log("Pillar: ContextHolder UniqueID now " .. tostring(cu and safe(function() return cu:call("ToString") end)))
        end
    end
    ps.uid_ok = ok
end
local function param_list(m)
    local names = safe(function() return m:get_param_names() end) or {}
    local types = safe(function() return m:get_param_types() end) or {}
    local out = {}
    for i, t in ipairs(types) do
        table.insert(out, (safe(function() return t:get_full_name() end) or "?") .. " " .. tostring(names[i] or ("p" .. i)))
    end
    return table.concat(out, ", ")
end
local uid_research_t0 = os.clock()
local uid_research_done = false
local function uid_research()
    local out = {}
    for _, tn in ipairs({ "app.GimmickManager", "app.GimmickBase", "app.UniqueID", "app.UniqueIDContext" }) do
        local td = sdk.find_type_definition(tn)
        for _, m in ipairs(td and td:get_methods() or {}) do
            local n = m:get_name()
            local nl = n:lower()
            if (tn == "app.GimmickManager" and (n == "createGimmick" or n == "deleteCreatedObj" or nl:find("uniq")))
                or (tn == "app.GimmickBase" and nl:find("uniq"))
                or tn == "app.UniqueID" or tn == "app.UniqueIDContext" then
                table.insert(out, string.format("  %s.%s(%s)%s", tn, n, param_list(m), safe(function() return m:is_static() end) and " [static]" or ""))
            end
        end
        if tn == "app.UniqueID" or tn == "app.UniqueIDContext" then
            for _, f in ipairs(td and td:get_fields() or {}) do
                table.insert(out, string.format("  %s field %s%s : %s", tn, f:is_static() and "static " or "", f:get_name(),
                    safe(function() return f:get_type():get_full_name() end) or "?"))
            end
        end
    end
    local n = 0
    for _, tn in ipairs({ "app.GimmickBase" }) do
        for _, c in ipairs(find_components(tn)) do
            if n >= 4 then break end
            local ok, txt = uid_report(c, "  sample gimmick " .. tostring(safe(function() return c:call("get_GameObject"):call("get_Name") end)) .. ": ")
            table.insert(out, txt .. (ok and " -> readable" or " -> NOT readable"))
            n = n + 1
        end
    end
    pcall(fs.write, "RancorReinforcements_uid_research.txt", table.concat(out, "\n"))
    log(string.format("UniqueID research: %d line(s) written to data/RancorReinforcements_uid_research.txt (%d sample gimmicks)", #out, n))
end
PX.game_thread = function()
    if not uid_research_done and os.clock() - uid_research_t0 > 5 then
        uid_research_done = true
        if not K.RELEASE then   -- v1.9.184: research scan, dev build only
            local ok, err = pcall(uid_research)
            if not ok then log("UniqueID research error: " .. tostring(err)) end
        end
    end
    if PX.detect_new_pillar then pcall(PX.detect_new_pillar) end
    if PX.warm_step and not PX.warm.done then pcall(PX.warm_step) end
    if os.clock() - (PX.sweep_t or 0) > 5 then
        PX.sweep_t = os.clock()
        pcall(function()
            local mine = {}
            for _, g in ipairs({ pillar_spawn and pillar_spawn.go, PILLAR_AI.go }) do
                local a = g and safe(function() return g:get_address() end)
                if a then mine[a] = true end
            end
            if PX.prefab_req then return end   -- one is being placed right now
            for _, c in ipairs(find_components("app.Gm81_097")) do
                local go = safe(function() return c:call("get_GameObject") end)
                local nm = go and safe(function() return go:call("get_Name") end)
                local a = go and safe(function() return go:get_address() end)
                if nm == "gm81_098" and a and not mine[a] then
                    local okd = pcall(function() go:call("destroy(via.GameObject)", go) end)
                    if not okd then okd = pcall(function() go:call("destroy", go) end) end
                    log("Pillar cleanup: removed a leftover mod pillar this script was not tracking (" .. (okd and "ok" or "failed") .. ")")
                end
            end
        end)
    end
    if PX.climb_check and os.clock() - PX.climb_check.t > 3 then
        local cc = PX.climb_check
        PX.climb_check = nil
        pcall(function()
            local st = safe(function() return cc.comp:get_field("Status"):get_field("Data") end)
            local lst = safe(function() return cc.comp:get_field("_ClimbPosSet") end)
            local n = lst and safe(function() return lst:call("get_Count") end) or -1
            local parts = {}
            for i = 0, math.min(n, 4) - 1 do
                local e2 = safe(function() return lst:call("get_Item", i) end)
                local rp = e2 and safe(function() return e2:get_field("_RootPos") end)
                local tp = e2 and safe(function() return e2:get_field("_TopPos") end)
                table.insert(parts, string.format("root y %s / top y %s", rp and string.format("%.2f", vfield(rp, "y") or 0) or "?", tp and string.format("%.2f", vfield(tp, "y") or 0) or "?"))
            end
            local mesh = safe(function() return cc.go:call("getComponent(System.Type)", sdk.typeof("via.render.Mesh")) end)
            local aabb = nil
            for _, mn in ipairs({ "get_WorldAABB", "get_BoundingAabb", "get_BoundingAABB", "getWorldAABB" }) do
                aabb = aabb or (mesh and safe(function() return mesh:call(mn) end))
            end
            local amin = aabb and (safe(function() return aabb:get_field("minpos") end) or safe(function() return aabb.minpos end))
            local amax = aabb and (safe(function() return aabb:get_field("maxpos") end) or safe(function() return aabb.maxpos end))
            local up = upos_go(cc.go)
            log_now(string.format("Pillar climb check%s: status %s, %d climb point set(s) %s | floor y %.2f, origin y %s | mesh y %s .. %s",
                cc.second and " (2 s later)" or "", tostring(st), n, table.concat(parts, "; "), cc.floor_y or 0, up and string.format("%.2f", up.y) or "?",
                amin and string.format("%.2f", vfield(amin, "y") or 0) or "?", amax and string.format("%.2f", vfield(amax, "y") or 0) or "?"))
            -- v1.9.88: the Purgener's tall pillar (gimmick 408) finds 2 climb points of its own, but their tops are
            -- only ~3.5 m up (its ray is set up for its home arena) - replace them with the full-height ring
            local hgt0 = (amin and amax) and ((vfield(amax, "y") or 0) - (vfield(amin, "y") or 0)) or 0
            local rebuild = false   -- v1.9.89: off - changing the big pillar's climb list throws inside the game
            if rebuild then
                local okc = pcall(function() lst:call("Clear") end)
                log_now("Pillar climb fix: replacing the pillar's own " .. n .. " climb point(s) (too low for its " ..
                    string.format("%.1f", hgt0) .. " m height)" .. (okc and "" or " - could not clear them"))
                if okc then n = 0 end
            end
            local wx0 = (amin and amax) and math.abs((vfield(amax, "x") or 0) - (vfield(amin, "x") or 0)) or 0
            local wz0 = (amin and amax) and math.abs((vfield(amax, "z") or 0) - (vfield(amin, "z") or 0)) or 0
            -- v1.9.106: decide by gimmick, not by size. The size test (v1.9.89) also flagged Medusa's own pillar (235)
            -- as "big", so her climb points were never filled and she stopped climbing. Only 408 is unsafe.
            local wide = (cc.gid ~= nil and cc.gid ~= PILLAR_GIMMICK_ID) or (cc.gid == nil and (math.max(wx0, wz0) / 2 > 2.5 or hgt0 > 16))
            if n == 0 and up and wide then
                -- v1.9.89: adding climb points to the big pillar (408) throws inside the game; several throws in a
                -- row corrupted the game's script VM and crashed it (13:20:59). Leave its list alone.
                log_now("Pillar climb fix: skipped - this pillar's climb list can't be filled safely (big pillar)")
            end
            if n == 0 and up and not wide and not cc.filled then
                cc.filled = true
                -- the pillar's own ray found nothing (Rancor arena): fill in the climb point set by hand
                local okf, info = pcall(function()
                    local ptd = sdk.find_type_definition("app.Gm81_097.ClimbPosSet")
                    if not ptd then return "no ClimbPosSet type" end
                    local vt = safe(function() return ptd:is_value_type() end)
                    local item, how = nil, nil
                    if vt then item = safe(function() return ValueType.new(ptd) end); how = "ValueType" end
                    if not item then item = safe(function() return ptd:create_instance() end); how = "type:create_instance" end
                    if not item then item = safe(function() return sdk.create_instance("app.Gm81_097.ClimbPosSet", true) end); how = "create_instance(simplify)" end
                    if not item then item = safe(function() return sdk.create_instance("app.Gm81_097.ClimbPosSet") end); how = "create_instance" end
                    if not item then return "could not create ClimbPosSet (value type: " .. tostring(vt) .. ")" end
                    if not vt then pcall(function() item:call(".ctor") end); pcall(function() item:add_ref_permanent() end) end
                    local function mkpos(x, y, z)
                        local v = ValueType.new(POS_TD)
                        v:set_field("x", x); v:set_field("y", y); v:set_field("z", z)
                        return v
                    end
                    -- v1.9.86: top from the mesh height (the Purgener's pillar is taller than Medusa's 15 m)
                    local hgt = (amin and amax) and ((vfield(amax, "y") or 0) - (vfield(amin, "y") or 0)) or 0
                    local top = (hgt and hgt > 16) and (hgt - 1.0) or 14.0
                    -- v1.9.87: a wide pillar (the Purgener's) gets 8 climb points on its surface - a single
                    -- point at the center is buried inside the mesh where it can't be reached
                    local wx = (amin and amax) and math.abs((vfield(amax, "x") or 0) - (vfield(amin, "x") or 0)) or 0
                    local wz = (amin and amax) and math.abs((vfield(amax, "z") or 0) - (vfield(amin, "z") or 0)) or 0
                    local rad = math.max(wx, wz) / 2
                    local pts = {}
                    if false and rad > 2.5 and rad < 15 then   -- v1.9.89: ring off (see above)
                        local r2 = rad + 0.5   -- just outside the surface
                        for i = 0, 7 do
                            local a = i * math.pi / 4
                            table.insert(pts, { up.x + math.cos(a) * r2, up.z + math.sin(a) * r2 })
                        end
                    else
                        pts = { { up.x, up.z } }
                    end
                    local added = 0
                    for idx, xz in ipairs(pts) do
                        local it = item
                        if idx > 1 then
                            it = vt and safe(function() return ValueType.new(ptd) end) or safe(function() return sdk.create_instance("app.Gm81_097.ClimbPosSet", true) end)
                            if it and not vt then pcall(function() it:call(".ctor") end); pcall(function() it:add_ref_permanent() end) end
                        end
                        if it then
                            it:set_field("_RootPos", mkpos(xz[1], up.y + 0.56, xz[2]))
                            it:set_field("_TopPos", mkpos(xz[1], up.y + top, xz[2]))
                            if pcall(function() lst:call("Add", it) end) then added = added + 1 else break end
                        end
                    end
                    log_now(string.format("Pillar climb fix: %d climb point(s), top %.1f m, pillar radius %.1f m", added, top, rad))
                    local n2 = safe(function() return lst:call("get_Count") end)
                    return string.format("climb points now %s (%s via %s)", tostring(n2), vt and "struct" or "object", tostring(how))
                end)
                log_now("Pillar climb fix: its own ray found nothing - filled the climb points in by hand: " .. tostring(info) .. (okf and "" or " (error)"))
            end
            if not cc.second then
                PX.climb_check = { comp = cc.comp, go = cc.go, t = os.clock() - 1, floor_y = cc.floor_y, second = true, gid = cc.gid }
            end
            if lst and (safe(function() return lst:call("get_Count") end) or 0) > 0 then
                local st3, how3 = PX.enable_climb(cc.comp, true)
                if how3 ~= "already" then log_now("Pillar climb fix: status -> " .. tostring(st3) .. " [" .. tostring(how3) .. "]") end
                PILLAR_AI.keep_enabled = cc.comp
            end
            if false and not cc.second then
                -- research: climb offsets + ray cast query/result, then ask the pillar to prepare again
                local out = PILLAR_AI.climb_out or {}
                PILLAR_AI.climb_out = out
                table.insert(out, "")
                table.insert(out, "=== " .. os.date("%H:%M:%S ") .. "PILLAR CLIMB RESEARCH (local origin " .. (function()
                    local lp = safe(function() return cc.go:call("get_Transform"):call("get_Position") end)
                    return lp and string.format("%.2f, %.2f, %.2f", vfield(lp, "x") or 0, vfield(lp, "y") or 0, vfield(lp, "z") or 0) or "?" end)() .. ")")
                local cd = safe(function() return cc.comp:get_field("ClimbData") end)
                local cl = cd and safe(function() return cd:get_field("_ClimbDatas") end)
                local p0 = cl and safe(function() return cl:call("get_Item", 0) end)
                table.insert(out, "ClimbOffsetParam[0]:")
                if p0 then pcall(dump_obj, p0, 1, "  ", out, {}) end
                local rc = safe(function() return cc.comp:get_field("RayCast") end)
                local function getters(obj, label)
                    if not obj then table.insert(out, label .. ": nil"); return end
                    table.insert(out, label .. ": " .. describe(obj))
                    local td = safe(function() return obj:get_type_definition() end)
                    for _, m in ipairs(td and td:get_methods() or {}) do
                        local mn = m:get_name()
                        if mn:find("^get") and (safe(function() return m:get_num_params() end) or 1) == 0 then
                            local v = safe(function() return obj:call(mn) end)
                            table.insert(out, "    " .. mn .. "() = " .. val_str(v))
                        end
                    end
                end
                getters(rc and safe(function() return rc:get_field("Query") end), "RayCast.Query")
                getters(rc and safe(function() return rc:get_field("<SystemResult>k__BackingField") end), "RayCast.SystemResult")
                table.insert(out, "(climb points " .. tostring(n) .. " before any fix)")
                pcall(fs.write, "RancorReinforcements_pillar_climb.txt", table.concat(out, "\n"))
                PX.climb_check = { comp = cc.comp, go = cc.go, t = os.clock() - 1, floor_y = cc.floor_y, second = true, gid = cc.gid }
            end
        end)
    end
    if PX.find_req then
        local okf, errf = pcall(PX.find_step)
        if not okf then PX.find_req = nil; log_now("Find pillar prefab error: " .. tostring(errf)) end
    end
    if PX.prefab_req then
        local okq, errq = pcall(PX.prefab_step)
        if not okq then PX.prefab_req = nil; pillar_spawn = { state = "failed" }; log_now("Pillar (prefab) error: " .. tostring(errq)) end
    end
    local ps = pillar_spawn
    if ps and ps.state == "spawned" and ps.comp and ps.uid_ok and not ps.uid_bad and os.clock() - (ps.last_chk or 0) > 5 then
        ps.last_chk = os.clock()
        local okc = uid_report(ps.comp, "")
        ps.n_chk = (ps.n_chk or 0) + 1
        if not okc then
            ps.uid_bad = true
            log_now(string.format("Pillar: WARNING - its ID went bad after %.0f s despite the pin", os.clock() - (ps.t_spawned or 0)))
        elseif ps.n_chk == 6 then
            log("Pillar: ID still valid after 30 s (pin works)")
        end
    end
    if remove_queue then
        local r = remove_queue
        remove_queue = nil
        local go, comp = r.go, r.comp
        if r.method == "prefab" then
            if PILLAR_AI.go and safe(function() return PILLAR_AI.go:get_address() == go:get_address() end) then
                PILLAR_AI.go, PILLAR_AI.comp, PILLAR_AI.pos = nil, nil, nil
            end
            log_now("Pillar remove (prefab-made): destroying the object (game thread)")
            local okd, errd = pcall(function() go:call("destroy(via.GameObject)", go) end)
            if not okd then okd, errd = pcall(function() go:call("destroy", go) end) end
            log_now("Pillar remove (prefab-made): " .. (okd and "destroyed" or tostring(errd)))
            return
        end
        local ok, txt = uid_report(comp, "Pillar remove: UniqueID before: ")
        log_now(txt .. (ok and " -> readable" or " -> NOT readable"))
        if not ok and comp then
            log_now("Pillar remove: trying the gimmick's own setupUniqId() (game thread)")
            local ok_s, err_s = pcall(function() comp:call("setupUniqId") end)
            ok, txt = uid_report(comp, "Pillar remove: UniqueID after setupUniqId (" .. (ok_s and "ok" or tostring(err_s)) .. "): ")
            log_now(txt .. (ok and " -> readable" or " -> NOT readable"))
        end
        if ok then
            log_now("Pillar remove: ID is clean - calling GimmickManager.deleteCreatedObj (game thread)")
            local gm = sdk.get_managed_singleton("app.GimmickManager")
            local ok_d, err_d = pcall(function() gm:call("deleteCreatedObj(via.GameObject)", go) end)
            log_now("Pillar remove: deleteCreatedObj -> " .. (ok_d and "ok (game finishes the destroy next frame)" or tostring(err_d)))
        else
            local how = hide_pillar(go)
            log_now("Pillar remove: ID could not be repaired - NOT deleting (that crashes). Pillar hidden instead: " .. how)
        end
    end
    local req = spawn_queue
    if not req then return end
    spawn_queue = nil
    if create_gimmick_now(req) then
        pillar_spawn = { state = "waiting", t = os.clock(), x = req.x, y = req.y, z = req.z, known = req.known, tag = req.tag }
        if PX.detect_new_pillar then pcall(PX.detect_new_pillar) end   -- same step, if it already exists
    else
        pillar_spawn = { state = "failed" }
    end
end
do  -- log the game's own createGimmick calls (read-only) to learn its real arguments
    local td = sdk.find_type_definition("app.GimmickManager")
    local n = 0
    for _, mm in ipairs(td and td:get_methods() or {}) do
        if mm:get_name() == "createGimmick" and #(safe(function() return mm:get_param_types() end) or {}) == 10 then
            pcall(sdk.hook, mm, function(args)
                if PX.own_create or n >= 15 then return end
                n = n + 1
                local function i64(a) return safe(function() return sdk.to_int64(a) end) end
                log(string.format("Game createGimmick #%d: id %s, flags %s, lottery %s, parent %s, callback %s, area %s, bool %s, int %s",
                    n, tostring(i64(args[3])), tostring(i64(args[6])), tostring(i64(args[7]) ~= 0), tostring(i64(args[8]) ~= 0),
                    tostring(i64(args[9]) ~= 0), tostring(i64(args[10])), tostring(i64(args[11]) and (i64(args[11]) & 0xFF) ~= 0), tostring(i64(args[12]) and (i64(args[12]) & 0xFFFFFFFF))))
            end, function(r) return r end)
        end
    end
end
local function known_pillars()
    local known = {}
    for _, c in ipairs(find_components("app.Gm81_097")) do
        local go = safe(function() return c:call("get_GameObject") end)
        if go then known[go:get_address()] = true end
    end
    return known
end
local function spawn_at(x, y, z, tag)
    spawn_queue = { x = x, y = y, z = z, known = known_pillars(), tag = tag }
    pillar_spawn = { state = "queued", t = os.clock(), tag = tag }
    log("Pillar spawn (" .. tostring(tag) .. "): queued for the game's update thread")
end
local function spawn_by_id()
    local pp = player_upos()
    local cm = sdk.get_managed_singleton("app.CharacterManager")
    local pl = cm and safe(function() return cm["<ManualPlayer>k__BackingField"] end)
    local tr = pl and safe(function() return pl:get_Transform() end)
    local ax = tr and safe(function() return tr:call("get_AxisZ") end)
    local fx, fz = ax and safe(function() return ax.x end) or 0, ax and safe(function() return ax.z end) or 1
    if not pp then log("Pillar spawn: no player position"); return end
    local known = {}
    for _, c in ipairs(find_components("app.Gm81_097")) do
        local go = safe(function() return c:call("get_GameObject") end)
        if go then known[go:get_address()] = true end
    end
    spawn_queue = { x = pp.x + fx * 8, y = pp.y, z = pp.z + fz * 8, known = known }
    pillar_spawn = { state = "queued", t = os.clock() }
    log("Pillar spawn: queued for the game's update thread")
end
PX.detect_new_pillar = function()   -- game thread
    local s = pillar_spawn
    if s.state ~= "waiting" then return end
    for _, c in ipairs(find_components("app.Gm81_097")) do
        local go = safe(function() return c:call("get_GameObject") end)
        if go and not s.known[go:get_address()] then
            local p = upos_go(go)
            s.state, s.go, s.comp, s.t_spawned = "spawned", go, c, os.clock()
            local comps = {}
            local arr = safe(function() return go:call("get_Components") end)
            for _, cc in ipairs(arr and (safe(function() return arr:get_elements() end) or {}) or {}) do
                table.insert(comps, safe(function() return cc:get_type_definition():get_name() end) or "?")
            end
            log(string.format("Pillar spawn: SPAWNED %s at %s, %.1f m from the requested spot [%s]",
                tostring(safe(function() return go:call("get_Name") end)),
                p and string.format("(%.1f, %.1f, %.1f)", p.x, p.y, p.z) or "?",
                p and (flat_dist(p, s) or -1) or -1, table.concat(comps, ", ")))
            PX.repair_uid(s)
            log_now("Pillar: searching for its prefab (narrow search)")
            local okh, errh = pcall(PX.hunt_prefab2, go)
            if not okh then log_now("Prefab hunt 2 error: " .. tostring(errh)) end
            return
        end
    end
end
local function spawn_wait_tick()
    local s = pillar_spawn
    if s.state ~= "waiting" then return end
    if os.clock() - s.t > 15 then
        s.state = "not seen"
        log("Pillar spawn: no new pillar appeared within 15 s")
    end
end
local function spawn_test_start()
    if true then return spawn_by_id() end
    if not pillar_prefab_path then pcall(hunt_prefab) end
    if not pillar_prefab_path then
        log("Pillar spawn test: no prefab path known - cannot spawn yet")
        return
    end
    local pf = prefab_probe(pillar_prefab_path)
    if not pf then log("Pillar spawn test: could not create prefab object"); return end
    pcall(function() pf:call("set_Standby", true) end)
    pillar_spawn = { state = "loading", pf = pf, t = os.clock() }
    log("Pillar spawn test: loading " .. pillar_prefab_path)
end
local VEC3_TD3 = sdk.find_type_definition("via.vec3")
local function spawn_test_tick()
    local s = pillar_spawn
    if s.state ~= "loading" then return end
    local ready = safe(function() return s.pf:call("get_Ready") end)
    if not ready then
        if os.clock() - s.t > 15 then s.state = "failed"; log("Pillar spawn test: prefab never became ready (15 s)") end
        return
    end
    local cm = sdk.get_managed_singleton("app.CharacterManager")
    local pl = cm and safe(function() return cm["<ManualPlayer>k__BackingField"] end)
    local tr = pl and safe(function() return pl:get_Transform() end)
    local lp = tr and safe(function() return tr:call("get_Position") end)
    local ax = tr and safe(function() return tr:call("get_AxisZ") end)
    local x, y, z = lp and vfield(lp, "x"), lp and vfield(lp, "y"), lp and vfield(lp, "z")
    local fx, fz = ax and safe(function() return ax.x end) or 0, ax and safe(function() return ax.z end) or 1
    if type(x) ~= "number" then s.state = "failed"; log("Pillar spawn test: no player position"); return end
    local ok, go = pcall(function()
        local v = ValueType.new(VEC3_TD3)
        v:set_field("x", x + fx * 8); v:set_field("y", y); v:set_field("z", z + fz * 8)
        return s.pf:call("instantiate(via.vec3)", v)
    end)
    if ok and go then
        s.state = "spawned"; s.go = go
        local comps = {}
        local arr = safe(function() return go:call("get_Components") end)
        for _, c in ipairs(arr and (safe(function() return arr:get_elements() end) or {}) or {}) do
            table.insert(comps, safe(function() return c:get_type_definition():get_name() end) or "?")
        end
        log("Pillar spawn test: SPAWNED " .. tostring(safe(function() return go:call("get_Name") end)) .. " 8 m in front of you [" .. table.concat(comps, ", ") .. "]")
    else
        s.state = "failed"
        log("Pillar spawn test: instantiate failed: " .. tostring(go))
    end
end
local function spawn_test_remove()
    local s = pillar_spawn
    if s.go then
        remove_queue = { go = s.go, comp = s.comp, method = s.method }
        log_now("Pillar spawn test: remove queued for the game's update thread")
    end
    pillar_spawn = { state = "idle" }
end
PX.buttons = function()
    if imgui.button("Find pillar prefab (safe)") then
        PX.find_req = { t = os.clock() }
        log("Find pillar prefab: queued for the game's update thread")
    end
    imgui.same_line()
    if imgui.button("Spawn pillar (prefab method)") then
        do
            local pp = player_upos()
            local cm = sdk.get_managed_singleton("app.CharacterManager")
            local pl = cm and safe(function() return cm["<ManualPlayer>k__BackingField"] end)
            local ax = pl and safe(function() return pl:get_Transform():call("get_AxisZ") end)
            local fx, fz = ax and safe(function() return ax.x end) or 0, ax and safe(function() return ax.z end) or 1
            if pp then pcall(spawn_prefab_at, pp.x + fx * 8, pp.y, pp.z + fz * 8, "test") end
        end
    end
    imgui.same_line()
    if imgui.button("Remove test pillar") then pcall(spawn_test_remove) end
    imgui.text("  pillar prefab: " .. tostring(config.pillar_prefab_path or "unknown") .. " | test: " .. tostring(pillar_spawn.state) .. (pillar_spawn.method and (" (" .. pillar_spawn.method .. ")") or ""))
end
local arena_last, arena_fight, arena_lost_t, arena_far_logged = 0, nil, nil, false
local function arena_tick()
    local now = os.clock()
    if now - arena_last < 1 then return end
    arena_last = now
    local ps = pillar_spawn
    local want = config.enabled and config.medusa_pillar and vortex_now and arena_center ~= nil and K.real_medusa()   -- v1.9.157: not for the Hydra
    if want then
        arena_lost_t = nil
        local pp0 = player_upos()
        local dcen = pp0 and flat_dist(pp0, arena_center)
        if not dcen or dcen > 60 then
            if not arena_far_logged then
                arena_far_logged = true
                log(string.format("Arena pillar: NOT spawned - the arena center is %.0f m from you (must be within 60 m)", dcen or -1))
            end
            return
        end
        arena_far_logged = false
        if arena_fight ~= arena_center_at and (ps.state == "idle" or ps.state == "failed" or ps.state == "not seen" or ps.state == nil) then
            arena_fight = arena_center_at          -- one arena pillar per fight
            local pp = player_upos()
            log(string.format("Arena pillar: Rancor Medusa is here - spawning a pillar at the arena center (%.0f, %.0f, %.0f), %.0f m from you",
                arena_center.x, arena_center.y, arena_center.z, pp and (flat_dist(pp, arena_center) or -1) or -1))
            spawn_prefab_at(arena_center.x, arena_center.y, arena_center.z, "arena")
        end
    elseif ps.tag == "arena" and ps.state == "spawned" then
        arena_lost_t = arena_lost_t or now
        if now - arena_lost_t > 8 then
            log("Arena pillar: " .. (vortex_now and "no Rancor Medusa left" or "the Rancor fight ended") .. " - removing it")
            arena_lost_t = nil
            if vortex_now then arena_fight = nil end   -- a later Medusa in the same fight gets a new pillar
            pcall(spawn_test_remove)
        end
    end
end
PX.tick = function() pcall(spawn_test_tick); pcall(spawn_wait_tick); pcall(arena_tick); pcall(PILLAR_AI.tick) end
PX.pillar_state = function() return pillar_spawn end   -- v1.9.80: for the Purgener watcher
PX.remove_pillar = spawn_test_remove
end)()
end -- petri module

-- 13) v1.9.15: beam tracking (turn assist) + wider beam --------------------------------------
-- While a Rancor Medusa fires (Petrification actions except the end), her body is turned toward
-- you at up to medusa_beam_turn deg/s on top of her own turning. Her beam shell's ExpandRate is
-- scaled by medusa_beam_width (bigger beam). Both run on the game's late-update.
do
    local QUAT_TD = sdk.find_type_definition("via.Quaternion")
    local VEC3_TD = sdk.find_type_definition("via.vec3")
    local last_t = os.clock()
    local function heading(q)
        local fx = 2 * (q.x * q.z + q.w * q.y)
        local fz = 1 - 2 * (q.x * q.x + q.y * q.y)
        return math.atan(fx, fz)
    end
    local function wrap(a)
        while a > math.pi do a = a - 2 * math.pi end
        while a < -math.pi do a = a + 2 * math.pi end
        return a
    end
    local function now_dbg_ok(e)
        local now = os.clock()
        if now - (e.turn_dbg_t or 0) >= 2 and (e.turn_dbg_n or 0) < 40 then
            e.turn_dbg_t = now
            e.turn_dbg_n = (e.turn_dbg_n or 0) + 1
            return true
        end
        return false
    end
    local function turn_step(e, dt)
        local tr = safe(function() return e.go:call("get_Transform") end)
        local qv = tr and safe(function() return tr:call("get_Rotation") end)
        if not qv then return end
        local q = { x = vfield(qv, "x"), y = vfield(qv, "y"), z = vfield(qv, "z"), w = vfield(qv, "w") }
        if type(q.x) ~= "number" or type(q.w) ~= "number" then return end
        local bt = e.beam_target
        local here, pp = upos_tr(tr), (bt and not bt.you and bt.p) or player_upos()
        if not here or not pp then return end
        local dx, dz = pp.x - here.x, pp.z - here.z
        if dx * dx + dz * dz < 4 then return end
        -- did last frame's turn stick? (the game may own her rotation)
        if e.turn_expect and not e.turn_checked then
            local got = heading(q)
            local diff = math.abs(wrap(got - e.turn_expect))
            e.turn_checks = (e.turn_checks or 0) + 1
            if diff < 0.02 then e.turn_kept = (e.turn_kept or 0) + 1 end
            if e.turn_checks == 30 then
                log(string.format("Medusa beam turn assist: %d of 30 turns kept by the game", e.turn_kept or 0))
            end
        end
        -- her real facing: the game's forward axis (not our reading of the rotation value)
        local ax = safe(function() return tr:call("get_AxisZ") end)
        local fx, fz = ax and safe(function() return ax.x end), ax and safe(function() return ax.z end)
        local face = (type(fx) == "number" and type(fz) == "number") and math.atan(fx, fz) or heading(q)
        -- self-check: did last frame's turn move her facing the way we meant?
        if e.turn_prev_face and e.turn_prev_th and math.abs(e.turn_prev_th) > math.rad(0.3) then
            local moved = wrap(face - e.turn_prev_face)
            e.turn_votes = (e.turn_votes or 0) + ((moved * e.turn_prev_th > 0) and 1 or -1)
            e.turn_nvotes = (e.turn_nvotes or 0) + 1
            if e.turn_nvotes >= 12 then
                if e.turn_votes <= -4 then
                    e.turn_sign = -(e.turn_sign or 1)
                    e.turn_flips = (e.turn_flips or 0) + 1
                    log(string.format("Medusa beam turn assist: she was turning the wrong way - direction flipped (%d/%d votes)", e.turn_votes, e.turn_nvotes))
                end
                e.turn_votes, e.turn_nvotes = 0, 0
            end
        end
        local err = wrap(math.atan(dx, dz) - face)
        e.turn_err = err
        if now_dbg_ok(e) then
            log(string.format("Medusa beam turn: target %.0f deg off her nose, %.1f m, direction %s", math.deg(err),
                math.sqrt(dx * dx + dz * dz), (e.turn_sign or 1) > 0 and "normal" or "flipped"))
        end
        if math.abs(err) < math.rad(2) then e.turn_expect = nil; e.turn_prev_face = nil; return end
        local max = math.rad(config.medusa_beam_turn or 50) * dt
        local th = math.max(-max, math.min(max, err))
        e.turn_prev_face, e.turn_prev_th = face, th
        th = th * (e.turn_sign or 1)
        local s, c = math.sin(th / 2), math.cos(th / 2)
        local nq = { w = c * q.w - s * q.y, x = c * q.x + s * q.z, y = c * q.y + s * q.w, z = c * q.z - s * q.x }
        local ok = pcall(function()
            local v = ValueType.new(QUAT_TD)
            v:set_field("x", nq.x); v:set_field("y", nq.y); v:set_field("z", nq.z); v:set_field("w", nq.w)
            tr:call("set_Rotation", v)
        end)
        if ok then
            e.turn_expect = heading(nq)
            e.turns = (e.turns or 0) + 1
            if e.turns == 1 then log(string.format("Medusa beam turn assist: turning her toward you (%.0f deg off)", math.deg(err))) end
        end
    end
    local VEC3_TD2 = sdk.find_type_definition("via.vec3")
    local function chase(e, dt)
        local speed = config.medusa_beam_chase or 0
        if speed <= 0 then return end
        local tr = safe(function() return e.go:call("get_Transform") end)
        local here = upos_tr(tr)
        local bt = e.beam_target
        local tp = (bt and not bt.you and bt.p) or player_upos()
        if not here or not tp then return end
        if bt and bt.climbing then return end
        if e.turn_err and math.abs(e.turn_err) > math.rad(60) then return end
        local dx, dz = tp.x - here.x, tp.z - here.z
        local d = math.sqrt(dx * dx + dz * dz)
        if d < 0.1 then return end
        local step
        if d > 12 then step = math.min(speed * dt, d - 12)
        elseif d < 6 then step = -math.min(speed * 0.6 * dt, 6 - d)
        else return end
        local mx, mz = dx / d * step, dz / d * step
        if lair then
            local nx, nz = here.x + mx, here.z + mz
            local dc = flat_dist({ x = nx, z = nz }, lair.center) or 0
            local lim = (lair.radius or 14) - 1
            if dc > lim and dc > (flat_dist(here, lair.center) or 0) then return end
        end
        local lp = safe(function() return tr:call("get_Position") end)
        local lx, ly, lz = lp and vfield(lp, "x"), lp and vfield(lp, "y"), lp and vfield(lp, "z")
        if type(lx) ~= "number" or type(lz) ~= "number" then return end
        local ok = pcall(function()
            local v = ValueType.new(VEC3_TD2)
            v:set_field("x", lx + mx); v:set_field("y", ly); v:set_field("z", lz + mz)
            tr:call("set_Position", v)
        end)
        if ok then
            e.chased = (e.chased or 0) + math.abs(step)
            if not e.chase_logged then
                e.chase_logged = true
                log(string.format("Medusa beam chase: %s her target (%.1f m away)", step > 0 and "closing in on" or "backing off from", d))
            end
        end
    end
    local function widen(e)
        local w = config.medusa_beam_width or 1.0
        if w == 1.0 then return end
        local ch2 = m_ch2(e.chara)
        local pc = ch2 and safe(function() return ch2["<Ch255000PetrificationControl>k__BackingField"] end)
        local sh = pc and safe(function() return pc.PetrificationShell end)
        if not sh then return end
        local ok = pcall(function()
            local v = ValueType.new(VEC3_TD)
            v:set_field("x", w); v:set_field("y", w); v:set_field("z", w)
            sh:set_field("<ExpandRate>k__BackingField", v)
        end)
        if ok and not e.widen_logged then
            e.widen_logged = true
            log(string.format("Medusa beam widened x%.2f (shell ExpandRate)", w))
        end
    end
    -- (v1.9.51) coiled: orbit her around the pillar axis toward her target
    local function coil_step(e, dt)
        local P = PILLAR_AI.pos
        if not P then return end
        local tr = safe(function() return e.go:call("get_Transform") end)
        local qv = tr and safe(function() return tr:call("get_Rotation") end)
        local here = tr and upos_tr(tr)
        if not qv or not here then return end
        local ox, oz = here.x - P.x, here.z - P.z
        local r = math.sqrt(ox * ox + oz * oz)
        if r > 8 then return end                       -- not on the pillar
        local bt = e.beam_target
        local tp = (bt and not bt.you and bt.p) or player_upos()
        if not tp then return end
        local ax = safe(function() return tr:call("get_AxisZ") end)
        local fx, fz = ax and safe(function() return ax.x end), ax and safe(function() return ax.z end)
        if type(fx) ~= "number" or type(fz) ~= "number" then return end
        local face = math.atan(fx, fz)
        local err = wrap(math.atan(tp.x - here.x, tp.z - here.z) - face)
        if math.abs(err) < math.rad(3) then return end
        local max = math.rad(config.medusa_pillar_turn or 120) * dt
        local th = math.max(-max, math.min(max, err))
        -- facing: same yaw step the beam turn assist uses (its learned direction sign)
        local q = { x = vfield(qv, "x"), y = vfield(qv, "y"), z = vfield(qv, "z"), w = vfield(qv, "w") }
        local ths = th * (e.turn_sign or 1)
        local s, c = math.sin(ths / 2), math.cos(ths / 2)
        local nq = { w = c * q.w - s * q.y, x = c * q.x + s * q.z, y = c * q.y + s * q.w, z = c * q.z - s * q.x }
        -- position: rotate her offset from the pillar axis by the same heading change
        local a = math.atan(ox, oz) + th
        local nox, noz = r * math.sin(a), r * math.cos(a)
        local lp = safe(function() return tr:call("get_Position") end)
        local lx, ly, lz = lp and vfield(lp, "x"), lp and vfield(lp, "y"), lp and vfield(lp, "z")
        if type(lx) ~= "number" then return end
        local ok = pcall(function()
            local v = ValueType.new(QUAT_TD)
            v:set_field("x", nq.x); v:set_field("y", nq.y); v:set_field("z", nq.z); v:set_field("w", nq.w)
            tr:call("set_Rotation", v)
            local p2 = ValueType.new(VEC3_TD)
            p2:set_field("x", lx + (nox - ox)); p2:set_field("y", ly); p2:set_field("z", lz + (noz - oz))
            tr:call("set_Position", p2)
        end)
        if ok then
            e.coil_turns = (e.coil_turns or 0) + 1
            if e.coil_turns == 1 or (e.coil_turns % 300 == 0) then
                log(string.format("Medusa coiled: turning her around the pillar toward %s (%.0f deg off, %.1f m from the pillar axis)",
                    (bt and not bt.you and bt.name) or "you", math.deg(err), r))
            end
        end
    end
    -- (v1.9.51) tilt the petrify beam shell toward the target's chest height
    local function qmul(a, b)
        return { w = a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z,
                 x = a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
                 y = a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
                 z = a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w }
    end
    local dead_shells = {}
    local function beam_pitch(e)
        local beaming = (e.in_beam and not (e.beam_act or ""):find("End", 1, true))
            or (type(e.pack) == "string" and e.pack:find("ClimbPetrification", 1, true) ~= nil) or e.walk_beam
        if not beaming then return end
        local ch2 = m_ch2(e.chara)
        local pc = ch2 and safe(function() return ch2["<Ch255000PetrificationControl>k__BackingField"] end)
        local sh = pc and safe(function() return pc.PetrificationShell end)
        local sha = sh and safe(function() return sh:get_address() end)
        if not sha or dead_shells[sha] then return end
        local sgo = safe(function() return sh:call("get_GameObject") end)
        if not sgo then dead_shells[sha] = true; return end
        local tr = sgo and safe(function() return sgo:call("get_Transform") end)
        if not tr then
            if sh and not e.pitch_noshell then
                e.pitch_noshell = true
                log("Medusa beam aim: beam shell has no transform (" .. tostring(safe(function() return sh:get_type_definition():get_full_name() end)) .. ")")
            end
            return
        end
        local sp = upos_tr(tr)
        local bt = e.beam_target
        local tp = (bt and not bt.you and bt.p) or player_upos()
        if not sp or not tp then return end
        local dx, dy, dz = tp.x - sp.x, (tp.y + 1.3) - sp.y, tp.z - sp.z
        local dl = math.sqrt(dx * dx + dy * dy + dz * dz)
        if dl < 1 then return end
        dx, dy, dz = dx / dl, dy / dl, dz / dl
        local ax = safe(function() return tr:call("get_AxisZ") end)
        local fx, fy, fz = ax and safe(function() return ax.x end), ax and safe(function() return ax.y end), ax and safe(function() return ax.z end)
        local qv = safe(function() return tr:call("get_Rotation") end)
        if type(fx) ~= "number" or not qv then return end
        local dot = math.max(-1, math.min(1, fx * dx + fy * dy + fz * dz))
        local ang = math.acos(dot)
        if not e.pitch_logged or os.clock() - (e.pitch_log_t or 0) > 3 then
            e.pitch_log_t = os.clock()
            e.pitch_logs = (e.pitch_logs or 0) + 1
            if e.pitch_logs <= 12 then
                log(string.format("Medusa beam aim: beam %.0f deg off its target (height diff %+.1f m, %.1f m away) - correcting",
                    math.deg(ang), tp.y + 1.3 - sp.y, dl))
            end
            e.pitch_logged = true
        end
        if ang < math.rad(1) or ang > math.rad(100) then return end   -- tiny, or the beam axis is not Z
        local cx, cy, cz = fy * dz - fz * dy, fz * dx - fx * dz, fx * dy - fy * dx
        local cl = math.sqrt(cx * cx + cy * cy + cz * cz)
        if cl < 1e-6 then return end
        local s = math.sin(ang / 2)
        local qd = { w = math.cos(ang / 2), x = cx / cl * s, y = cy / cl * s, z = cz / cl * s }
        local q = { x = vfield(qv, "x"), y = vfield(qv, "y"), z = vfield(qv, "z"), w = vfield(qv, "w") }
        local nq = qmul(qd, q)
        pcall(function()
            local v = ValueType.new(QUAT_TD)
            v:set_field("x", nq.x); v:set_field("y", nq.y); v:set_field("z", nq.z); v:set_field("w", nq.w)
            tr:call("set_Rotation", v)
        end)
        e.beam_qd = qd   -- the light gets the same tilt
    end
    -- (v1.9.55) her eye light: same tilt as the beam + cone widened like the beam
    local light_methods_logged = false
    local function beam_light(e)
        local beaming = (e.in_beam and not (e.beam_act or ""):find("End", 1, true))
            or (type(e.pack) == "string" and e.pack:find("ClimbPetrification", 1, true) ~= nil) or e.walk_beam
        if not beaming then e.beam_qd = nil; return end
        local ch2 = m_ch2(e.chara)
        local pc = ch2 and safe(function() return ch2["<Ch255000PetrificationControl>k__BackingField"] end)
        local sl = pc and safe(function() return pc.SpotLight end)
        local sla = sl and safe(function() return sl:get_address() end)
        if not sla or dead_shells[sla] then return end
        local lgo = safe(function() return sl:call("get_GameObject") end)
        if not lgo then dead_shells[sla] = true; return end
        if not light_methods_logged then
            light_methods_logged = true
            local td = sl:get_type_definition()
            local ms = {}
            for _, m in ipairs(td and td:get_methods() or {}) do
                local n = m:get_name()
                local l = n:lower()
                if (l:find("cone") or l:find("spread") or l:find("range") or l:find("radius") or l:find("angle")) and n:find("^get_") then
                    local v = safe(function() return sl:call(n) end)
                    table.insert(ms, n .. "=" .. tostring(type(v) == "number" and string.format("%.2f", v) or v))
                end
            end
            log("Medusa eye light (SpotLight): " .. table.concat(ms, ", "))
        end
        -- aim: point the light's own forward axis at the same spot the beam aims at (target chest)
        local ltr = safe(function() return lgo:call("get_Transform") end)
        local lq = ltr and safe(function() return ltr:call("get_Rotation") end)
        local lp = ltr and upos_tr(ltr)
        local bt = e.beam_target
        local tp = (bt and not bt.you and bt.p) or player_upos()
        if lq and lp and tp then
            local lz = safe(function() return ltr:call("get_AxisZ") end)
            local zx, zy, zz = lz and vfield(lz, "x"), lz and vfield(lz, "y"), lz and vfield(lz, "z")
            if type(zx) ~= "number" then return end
            -- learn which way the light shines (+Z or -Z) once, against the beam shell's forward axis
            if not e.light_sign then
                local ch2b = m_ch2(e.chara)
                local pcb = ch2b and safe(function() return ch2b["<Ch255000PetrificationControl>k__BackingField"] end)
                local shb = pcb and safe(function() return pcb.PetrificationShell end)
                local sza = shb and safe(function() return shb:call("get_GameObject"):call("get_Transform"):call("get_AxisZ") end)
                local sx, sy, sz = sza and vfield(sza, "x"), sza and vfield(sza, "y"), sza and vfield(sza, "z")
                if type(sx) == "number" then
                    local d = zx * sx + zy * sy + zz * sz
                    e.light_sign = d >= 0 and 1 or -1
                    log(string.format("Medusa eye light: shines along its %sZ axis (dot with the beam %.2f)", e.light_sign > 0 and "+" or "-", d))
                else
                    return
                end
            end
            local fx, fy, fz = zx * e.light_sign, zy * e.light_sign, zz * e.light_sign
            local dx, dy, dz = tp.x - lp.x, (tp.y + 1.3) - lp.y, tp.z - lp.z
            local dl = math.sqrt(dx * dx + dy * dy + dz * dz)
            if dl > 1 then
                dx, dy, dz = dx / dl, dy / dl, dz / dl
                local ang = math.acos(math.max(-1, math.min(1, fx * dx + fy * dy + fz * dz)))
                if ang > math.rad(0.5) and ang < math.rad(120) then
                    local cx, cy, cz = fy * dz - fz * dy, fz * dx - fx * dz, fx * dy - fy * dx
                    local cl = math.sqrt(cx * cx + cy * cy + cz * cz)
                    if cl > 1e-6 then
                        local sn = math.sin(ang / 2)
                        local qd = { w = math.cos(ang / 2), x = cx / cl * sn, y = cy / cl * sn, z = cz / cl * sn }
                        local q = { x = vfield(lq, "x"), y = vfield(lq, "y"), z = vfield(lq, "z"), w = vfield(lq, "w") }
                        local nq = qmul(qd, q)
                        local okr = pcall(function()
                            local v = ValueType.new(QUAT_TD)
                            v:set_field("x", nq.x); v:set_field("y", nq.y); v:set_field("z", nq.z); v:set_field("w", nq.w)
                            ltr:call("set_Rotation", v)
                        end)
                        if okr and not e.light_tilt_logged then
                            e.light_tilt_logged = true
                            log(string.format("Medusa eye light: aimed at the beam's target (was %.0f deg off)", math.deg(ang)))
                        end
                    end
                end
            end
        end
        -- width: widen the cone (and spread) like the beam's hit area
        local w = config.medusa_light_scale or config.medusa_beam_width or 1.0
        if w ~= 1.0 then
            for _, nm in ipairs({ "Cone", "Spread" }) do
                local cur = safe(function() return sl:call("get_" .. nm) end)
                if type(cur) == "number" and cur > 0 then
                    local base = (e.light_base and e.light_base[nm]) or nil
                    -- the game may reset it every frame; only widen from a value we did not set ourselves
                    if not e.light_set or math.abs(cur - (e.light_set[nm] or -1)) > 0.01 then
                        base = cur
                        e.light_base = e.light_base or {}
                        e.light_base[nm] = cur
                    end
                    local half = math.rad(math.min(base, 170) / 2)
                    local nv = math.deg(2 * math.atan(math.tan(half) * w))
                    if math.abs(nv - cur) > 0.01 and pcall(function() sl:call("set_" .. nm, nv + 0.0) end) then
                        e.light_set = e.light_set or {}
                        e.light_set[nm] = nv
                        if not e.light_w_logged then
                            e.light_w_logged = true
                            log(string.format("Medusa eye light: %s %.1f -> %.1f deg (x%.2f, eye light size slider)", nm, base, nv, w))
                        end
                    end
                end
            end
        end
    end
    -- (v1.9.52) her snake-bow arrows: point new arrow shells at her target (+ specified homing target)
    local function target_go_and_pos(e)
        local bt = e.beam_target
        if bt and not bt.you and bt.t then
            local ch = safe(function() return bt.t["<Character>k__BackingField"] end)
            local go = ch and safe(function() return ch:call("get_GameObject") end)
            if go then return go, bt.p or upos_go(go) end
        end
        local cm = sdk.get_managed_singleton("app.CharacterManager")
        local pl = cm and safe(function() return cm["<ManualPlayer>k__BackingField"] end)
        local go = pl and safe(function() return pl:call("get_GameObject") end)
        return go, player_upos()
    end
    local function arrows(e)
        local pk = e.pack
        if type(pk) ~= "string" or not pk:find("SnakeArrow", 1, true) then return end
        e.arrow_seen = e.arrow_seen or {}
        local tgo, tp = target_go_and_pos(e)
        if not tp then return end
        local myaddr = safe(function() return e.go:get_address() end)
        local shells = find_components("app.Shell")
        local volley = math.floor(os.clock() / 4)
        if e.arrow_research ~= volley and (e.arrow_research_n or 0) < 6 then
            e.arrow_research = volley
            e.arrow_research_n = (e.arrow_research_n or 0) + 1
            local parts = {}
            for i, shc in ipairs(shells) do
                if i > 6 then break end
                local nm = safe(function() return shc:call("get_GameObject"):call("get_Name") end)
                local o1 = safe(function() return shc:get_field("CachedTopOwner"):call("get_GameObject"):call("get_Name") end)
                local o2 = safe(function() return shc:get_field("<OwnerHitCtrl>k__BackingField"):call("get_GameObject"):call("get_Name") end)
                table.insert(parts, string.format("%s (top owner %s, owner %s)", tostring(nm), tostring(o1), tostring(o2)))
            end
            log(string.format("Medusa bow research (%s): %d shell(s) in the scene: %s", tostring(pk:match("([^/]+)%.user") or pk), #shells, table.concat(parts, "; ")))
        end
        for _, shc in ipairs(shells) do
            local a = safe(function() return shc:get_address() end)
            if a and not e.arrow_seen[a] then
                local owner = safe(function() return shc:get_field("CachedTopOwner"):call("get_GameObject") end)
                    or safe(function() return shc:get_field("<OwnerHitCtrl>k__BackingField"):call("get_GameObject") end)
                local is_beam = safe(function() return m_ch2(e.chara)["<Ch255000PetrificationControl>k__BackingField"].PetrificationShell:get_address() end) == a
                local mine = owner and safe(function() return owner:get_address() end) == myaddr
                if not mine and not owner and not is_beam then
                    -- no owner recorded: a shell that just appeared close to her during her bow action is hers
                    local str = safe(function() return shc:get_field("<Transform>k__BackingField") end)
                        or safe(function() return shc:call("get_GameObject"):call("get_Transform") end)
                    local spp = str and upos_tr(str)
                    local mp = upos_go(e.go)
                    if spp and mp then
                        local dxm, dym, dzm = spp.x - mp.x, spp.y - mp.y, spp.z - mp.z
                        mine = (dxm * dxm + dzm * dzm) < 64 and math.abs(dym) < 14
                    end
                    if not mine then e.arrow_seen[a] = os.clock() end   -- old / far shell: ignore from now on
                end
                if mine and not is_beam then
                    e.arrow_seen[a] = os.clock()
                    local tr = safe(function() return shc:get_field("<Transform>k__BackingField") end)
                        or safe(function() return shc:call("get_GameObject"):call("get_Transform") end)
                    local okS = tgo and pcall(function() shc:set_field("<SpecifiedTarget>k__BackingField", tgo) end)
                    local turned = nil
                    local sp = tr and upos_tr(tr)
                    if sp then
                        local dx, dy, dz = tp.x - sp.x, (tp.y + 1.3) - sp.y, tp.z - sp.z
                        local dl = math.sqrt(dx * dx + dy * dy + dz * dz)
                        local ax = safe(function() return tr:call("get_AxisZ") end)
                        local qv = safe(function() return tr:call("get_Rotation") end)
                        local fx, fy, fz = ax and safe(function() return ax.x end), ax and safe(function() return ax.y end), ax and safe(function() return ax.z end)
                        if dl > 1 and type(fx) == "number" and qv then
                            dx, dy, dz = dx / dl, dy / dl, dz / dl
                            local ang = math.acos(math.max(-1, math.min(1, fx * dx + fy * dy + fz * dz)))
                            turned = math.deg(ang)
                            if config.medusa_arrow_pitch and ang > math.rad(1) and ang < math.rad(120) then
                                local cx, cy, cz = fy * dz - fz * dy, fz * dx - fx * dz, fx * dy - fy * dx
                                local cl = math.sqrt(cx * cx + cy * cy + cz * cz)
                                if cl > 1e-6 then
                                    local sn = math.sin(ang / 2)
                                    local qd = { w = math.cos(ang / 2), x = cx / cl * sn, y = cy / cl * sn, z = cz / cl * sn }
                                    local q = { x = vfield(qv, "x"), y = vfield(qv, "y"), z = vfield(qv, "z"), w = vfield(qv, "w") }
                                    local nq = qmul(qd, q)
                                    pcall(function()
                                        local v = ValueType.new(QUAT_TD)
                                        v:set_field("x", nq.x); v:set_field("y", nq.y); v:set_field("z", nq.z); v:set_field("w", nq.w)
                                        tr:call("set_Rotation", v)
                                    end)
                                end
                            end
                        end
                    end
                    e.arrow_n = (e.arrow_n or 0) + 1
                    if e.arrow_n <= 8 then
                        log(string.format("Medusa arrow #%d: %s, homing target %s, was %s deg off its target (height diff %s)",
                            e.arrow_n, tostring(safe(function() return shc:call("get_GameObject"):call("get_Name") end)),
                            okS and "set" or "not set", turned and string.format("%.0f", turned) or "?",
                            sp and string.format("%+.1f m", tp.y + 1.3 - sp.y) or "?"))
                    end
                end
            end
        end
        -- forget old entries
        local now = os.clock()
        for a, t in pairs(e.arrow_seen) do if now - t > 20 then e.arrow_seen[a] = nil end end
    end
    -- (v1.9.57) turn her neck + head toward her target (after her animation, every frame)
    local HEAD_CHAIN = { { "Neck_0", 0.25 }, { "Neck_1", 0.33 }, { "Head_0", 1.0 } }
    local function joint_of(e, nm)
        e.joints = e.joints or {}
        local j = e.joints[nm]
        if j == nil then
            local tr = safe(function() return e.go:call("get_Transform") end)
            j = tr and safe(function() return tr:call("getJointByName", nm) end) or false
            e.joints[nm] = j
        end
        return j or nil
    end
    local function rot_toward(j, tx, ty, tz, frac, max_rad)
        local ax = safe(function() return j:call("get_AxisZ") end)
        local jp = safe(function() return j:call("get_Position") end)
        local qv = safe(function() return j:call("get_Rotation") end)
        if not ax or not jp or not qv then return nil end
        local fx, fy, fz = vfield(ax, "x"), vfield(ax, "y"), vfield(ax, "z")
        local dx, dy, dz = tx - vfield(jp, "x"), ty - vfield(jp, "y"), tz - vfield(jp, "z")
        local dl = math.sqrt(dx * dx + dy * dy + dz * dz)
        if dl < 1 or type(fx) ~= "number" then return nil end
        dx, dy, dz = dx / dl, dy / dl, dz / dl
        local ang = math.acos(math.max(-1, math.min(1, fx * dx + fy * dy + fz * dz)))
        if ang < math.rad(0.5) then return 0 end
        local use = math.min(ang * frac, max_rad)
        local cx, cy, cz = fy * dz - fz * dy, fz * dx - fx * dz, fx * dy - fy * dx
        local cl = math.sqrt(cx * cx + cy * cy + cz * cz)
        if cl < 1e-6 then return nil end
        local sn = math.sin(use / 2)
        local qd = { w = math.cos(use / 2), x = cx / cl * sn, y = cy / cl * sn, z = cz / cl * sn }
        local q = { x = vfield(qv, "x"), y = vfield(qv, "y"), z = vfield(qv, "z"), w = vfield(qv, "w") }
        local nq = qmul(qd, q)
        local ok = pcall(function()
            local v = ValueType.new(QUAT_TD)
            v:set_field("x", nq.x); v:set_field("y", nq.y); v:set_field("z", nq.z); v:set_field("w", nq.w)
            j:call("set_Rotation", v)
        end)
        return ok and use or nil, ang
    end
    local function head_aim(e)
        local lim = math.rad(config.medusa_head_aim or 0)
        if lim <= 0 then return end
        local pk = type(e.pack) == "string" and e.pack or ""
        local active = (e.in_beam and not (e.beam_act or ""):find("End", 1, true)) or pk:find("Ch255000Climb", 1, true) or e.walk_beam
        if not active then return end
        -- target point in this engine's local coordinates (joint positions are local)
        local bt = e.beam_target
        local tup = (bt and not bt.you and bt.p) or player_upos()
        local cm = sdk.get_managed_singleton("app.CharacterManager")
        local pl = cm and safe(function() return cm["<ManualPlayer>k__BackingField"] end)
        local plp = pl and safe(function() return pl:get_Transform():call("get_Position") end)
        local pup = player_upos()
        if not tup or not plp or not pup then return end
        local tx = vfield(plp, "x") + (tup.x - pup.x)
        local ty = vfield(plp, "y") + (tup.y - pup.y) + 1.3
        local tz = vfield(plp, "z") + (tup.z - pup.z)
        local used, first_ang = 0, nil
        for _, jf in ipairs(HEAD_CHAIN) do
            local j = joint_of(e, jf[1])
            if j then
                local u, a = rot_toward(j, tx, ty, tz, jf[2], math.max(0, lim - used))
                if a and not first_ang then first_ang = a end
                if u then used = used + u end
            end
        end
        e.head_turns = (e.head_turns or 0) + 1
        local now_h = os.clock()
        if e.head_turns == 1 or (math.deg(used) > 5 and now_h - (e.head_log_t or 0) > 20) then
            e.head_log_t = now_h
            log(string.format("Medusa head aim: turned neck + head %.0f deg toward %s (was %.0f deg off; joints %s/%s/%s)",
                math.deg(used), (bt and not bt.you and bt.name) or "you", math.deg(first_ang or 0),
                joint_of(e, "Neck_0") and "ok" or "-", joint_of(e, "Neck_1") and "ok" or "-", joint_of(e, "Head_0") and "ok" or "-"))
        end
    end
    -- (v1.9.56 research) her head / neck joints, listed once while she aims
    local function head_research(e)
        if e.head_logged then return end
        e.head_logged = true
        local tr = safe(function() return e.go:call("get_Transform") end)
        local arr = tr and safe(function() return tr:call("get_Joints") end)
        local els = arr and safe(function() return arr:get_elements() end) or {}
        local bt = e.beam_target
        local tp = (bt and not bt.you and bt.p) or player_upos()
        local parts = {}
        for _, j in ipairs(els) do
            local nm = safe(function() return j:call("get_Name") end)
            local l = type(nm) == "string" and nm:lower() or ""
            if l:find("head") or l:find("neck") or l:find("face") or l:find("eye") or l:find("jaw") then
                local ax = {}
                for _, an in ipairs({ "AxisX", "AxisY", "AxisZ" }) do
                    local v = safe(function() return j:call("get_" .. an) end)
                    if v then table.insert(ax, string.format("%s(%.2f,%.2f,%.2f)", an, vfield(v, "x") or 0, vfield(v, "y") or 0, vfield(v, "z") or 0)) end
                end
                table.insert(parts, nm .. (#ax > 0 and (" " .. table.concat(ax, " ")) or ""))
                if #parts >= 12 then break end
            end
        end
        local here = upos_go(e.go)
        log(string.format("Medusa head research: %d joints, head/neck: %s | target dir from her (%.1f, %.1f, %.1f)", #els, table.concat(parts, "; "),
            (tp and here) and (tp.x - here.x) or 0, (tp and here) and (tp.y - here.y) or 0, (tp and here) and (tp.z - here.z) or 0))
    end
    -- v1.9.92: Dragon breath aim (like Medusa's gaze): while a Dragon's action is a breath
    -- (e.g. Ch258_Breath_F_LookAt) its upper neck + head are turned toward the target's chest (up to
    -- dragon_breath_aim deg) and its body is turned toward the target (Medusa's beam turn assist).
    PX.DRAGON_CHAIN = { { "Neck_6", 0.15 }, { "Neck_7", 0.2 }, { "Neck_8", 0.3 }, { "Head_0", 1.0 } }
    PX.dragon_late = function(dt)   -- (table field, not a local: the main chunk is at Lua's 200-local limit)
        local lim = math.rad(config.dragon_breath_aim or 0)
        if lim <= 0 then return end
        local drg = rr_dragons and rr_dragons() or {}
        for _, d in pairs(drg) do
            local act = d.last_act or ""
            if act:find("Breath", 1, true) and not act:find("End", 1, true) then
                local cm = sdk.get_managed_singleton("app.CharacterManager")
                local pl = cm and safe(function() return cm["<ManualPlayer>k__BackingField"] end)
                local plp = pl and safe(function() return pl:get_Transform():call("get_Position") end)
                if plp then
                    local tx, ty, tz = vfield(plp, "x"), vfield(plp, "y") + 1.3, vfield(plp, "z")
                    local used, first_ang = 0, nil
                    for _, jf in ipairs(PX.DRAGON_CHAIN) do
                        local j = joint_of(d, jf[1])
                        if j then
                            local u, a = rot_toward(j, tx, ty, tz, jf[2], math.max(0, lim - used))
                            if a and not first_ang then first_ang = a end
                            if u then used = used + u end
                        end
                    end
                    if (config.dragon_breath_turn or 0) > 0 then
                        local saved = config.medusa_beam_turn
                        config.medusa_beam_turn = config.dragon_breath_turn
                        pcall(turn_step, d, dt)
                        config.medusa_beam_turn = saved
                    end
                    d.aims = (d.aims or 0) + 1
                    if d.aims == 1 or (d.aims % 600 == 0) then
                        log(string.format("Dragon breath aim (%s): head/neck turned %.0f deg toward you (was %.0f deg off; joints %s)", act,
                            math.deg(used), math.deg(first_ang or 0), joint_of(d, "Head_0") and "ok" or "missing"))
                    end
                end
            end
        end
    end
    local function late()
        if not config.enabled then return end
        local now = os.clock()
        local dt = math.min(0.1, math.max(0.0, now - last_t))
        last_t = now
        local okp, errp = pcall(PX.parts_late, dt)
        if not okp and not PX.parts_err then PX.parts_err = true; log("Eye tentacle aim error: " .. tostring(errp)) end
        local okd, errd = pcall(PX.dragon_late, dt)
        if not okd and not K.dragon_err_logged then K.dragon_err_logged = true; log("Dragon breath aim error: " .. tostring(errd)) end
        if not next(medusa) then return end
        for _, e in pairs(medusa) do
            if e.hydra then goto next_late end   -- v1.9.157: the Hydra files aim its necks and breath
            do
            if e.climb_aim and (config.medusa_pillar_turn or 0) > 0 then
                local okc2, errc2 = pcall(coil_step, e, dt)
                if not okc2 and not e.coil_err then e.coil_err = true; log("Medusa coiled turn error: " .. tostring(errc2)) end
            end
            if (config.medusa_arrow_pitch or (config.medusa_arrow_lockon or 20) ~= 20) then
                local oka, erra = pcall(arrows, e)
                if not oka and not e.arrow_err then e.arrow_err = true; log("Medusa arrow aim error: " .. tostring(erra)) end
            end
            local okh, errh = pcall(head_aim, e)
            if not okh and not e.head_err then e.head_err = true; log("Medusa head aim error: " .. tostring(errh)) end
            if type(e.pack) == "string" and e.pack:find("ClimbPetrification", 1, true) then pcall(widen, e) end
            if (e.in_beam or e.climb_aim or e.walk_beam) and not e.head_logged then pcall(head_research, e) end
            if e.walk_beam then pcall(widen, e) end
            if config.medusa_beam_pitch and (e.in_beam or e.climb_aim or e.walk_beam) then
                e.beam_qd = nil
                local okp2, errp2 = pcall(beam_pitch, e)
                if not okp2 and not e.pitch_err then e.pitch_err = true; log("Medusa beam aim error: " .. tostring(errp2)) end
                local okl, errl = pcall(beam_light, e)
                if not okl and not e.light_err then e.light_err = true; log("Medusa eye light error: " .. tostring(errl)) end
            end
            if e.in_beam then
                local act = e.beam_act or ""
                if (config.medusa_beam_turn or 0) > 0 and not act:find("End", 1, true) then
                    local ok, err = pcall(turn_step, e, dt)
                    if not ok and not e.turn_err then e.turn_err = true; log("Medusa beam turn error: " .. tostring(err)) end
                end
                pcall(widen, e)
                if not act:find("End", 1, true) and not act:find("Start", 1, true) then
                    local okc, errc = pcall(chase, e, dt)
                    if not okc and not e.chase_err then e.chase_err = true; log("Medusa beam chase error: " .. tostring(errc)) end
                end
            else
                e.turn_expect = nil
                e.turn_prev_face, e.turn_prev_th, e.turn_err = nil, nil, nil
            end
            end
            ::next_late::
        end
    end
    if re.on_application_entry then
        local ok = pcall(re.on_application_entry, "LateUpdateBehavior", function()
            local ok2, err = pcall(late)
            if not ok2 then log("Medusa beam late-update error: " .. tostring(err)) end
        end)
        if not ok then log("Medusa: LateUpdateBehavior callback not available - beam turn assist off") end
    end
end


-- pillar spawn requests run on the game's update thread
if re.on_application_entry then
    pcall(re.on_application_entry, "UpdateBehavior", function()
        if PX.game_thread then
            local ok, err = pcall(PX.game_thread)
            if not ok then log("Pillar spawn error: " .. tostring(err)) end
        end
    end)
end

-- material changes are made on the game's update thread when REFramework offers it
local frost_on_game_thread = false
if re.on_application_entry then
    frost_on_game_thread = pcall(re.on_application_entry, "UpdateBehavior", function()
        if not config.enabled or not next(medusa) then return end
        local okF, errF = pcall(process_frost)
        if not okF then log("Medusa look error: " .. tostring(errF)) end
    end)
end

-- Find swapped-in monsters after they spawn and scale them ---------------------------
local scaled = {}
local ignored_logged = {}
local tracked = {}   -- go address -> { go, chara, name, last_pos, last_report }
K.TRACKED = tracked  -- (for functions defined above this line)
-- v1.9.123 (user): the bodies of the mod's bosses are removed once their wave is over (the next wave has
-- started, or the Rancor ended) instead of lying around until the event ends. Destroyed on the game thread.
PX.corpse_q = {}
-- v1.9.142: three identical crashes (Oct 15 23:17, Oct 16 01:21 and 01:26 - all DD2.exe+0x4e58072, a null read in
-- the game's destroy processing, 2-3 s after a body despawn) shared one pattern: the old "remove after its wave"
-- trigger fired on the NEXT wave's first spawn request, so the despawn always landed in the middle of the game's
-- spawn burst (01:21: 9 ghouls spawning; 01:26: 10). It hit the Eye, the Gagana and the Griffin alike, so the
-- v1.9.140 Eye exclusion treated a symptom. Bodies are now only removed in a quiet moment.
-- v1.9.148: the 04:30 crash (same DD2.exe+0x4e58072, 2 s after TWO bodies were despawned at once) slipped the
-- 5 s gate: wave 3's soldiers were requested 4 s before and still materializing. The window is 12 s now, a
-- freshly spawned reinforcement also counts as noise, and corpse_exec removes ONE body per pass, 3 s apart.
function PX.quiet(now)
    if not vortex_now then return true end
    if swaps_pending > 0 then return false end   -- one of our reinforcements is mid-spawn
    if now - (wave_req_last or -1000) < 12 then return false end          -- wave spawn requests still coming
    if now - ((WAVES and WAVES.last_any) or -1000) < 12 then return false end
    for _, t in pairs(K.TRACKED or {}) do
        if t.spawned_at and now - t.spawned_at < 12 then return false end -- one of ours is still settling in
    end
    return true
end
function PX.corpse_tick(now)
    if not config.corpse_cleanup then return end
    for addr, t in pairs(tracked) do
        if not t.corpse_done then
            local hp = safe(function() return t.chara:get_Hit():call("get_Hp") end)
            if hp and hp <= 0 and not t.died_at then t.died_at, t.died_seq = now, WAVES.seq or 0 end
            if t.died_at and now - t.died_at > 6 and ((WAVES.seq or 0) > t.died_seq or not vortex_now) and PX.quiet(now) then   -- v1.9.142
                t.corpse_done = true
                -- v1.9.140: never the Evil Eye - its two bodies and its tentacle parts take themselves apart; the game
                -- crashed 3 s after its body was despawned (23:17:55 -> 23:17:58)
                if not (t.name and t.name:sub(1, #K.EYE_ID) == K.EYE_ID) then
                    table.insert(PX.corpse_q, { go = t.go, name = t.name })
                end
            end
        end
    end
end
-- v1.9.125 (user: the Gagana doesn't use its whole moveset in Rancors). Recorded 16:39: in a whole fight its AI
-- checked "go to hover" 632 times and never took off - no flight moves at all, while Griffins fly normally.
-- app.Ch253012 has IsFlightParam / setFlightParam(bool) and a home-area check (isCheckAILocalAreaNRD06), so its
-- flight looks tied to its home area. The mod switches flight on for its own Gagana (setting), and logs it.
function K.gagana_tick(now)
    if now - (K.gag_t or 0) < 1 then return end
    K.gag_t = now
    for _, t in pairs(tracked) do
        if t.name and t.name:sub(1, 8) == "ch253012" and t.go then
            t.gag = t.gag or { t0 = now, n = 0 }
            local g = t.gag
            local ch2 = g.ch2 or safe(function() return t.go:call("getComponent(System.Type)", sdk.typeof("app.Ch253012")) end)
            g.ch2 = ch2
            local hp = safe(function() return t.chara:get_Hit():call("get_Hp") end)
            if ch2 and hp and hp > 0 then
                local fl = safe(function() return ch2.IsFlightParam end)
                if not g.logged then
                    g.logged = true
                    local area = safe(function() return ch2.InitAILocalAreaDefinition end)
                    local nrd = area ~= nil and safe(function() return ch2:call("isCheckAILocalAreaNRD06(app.AILocalAreaDefinition)", area) end)
                    log(string.format("GAGANA %s: flight %s, escape %s, CC height %s, home area %s (NRD06 check %s)", t.name, tostring(fl),
                        tostring(safe(function() return ch2.IsSetEscape end)), tostring(safe(function() return ch2.OriginalCCHeight end)),
                        tostring(area), tostring(nrd)))
                    -- (v1.9.134: no live dumps)
                end
                if g.last_fl ~= fl then
                    if g.last_fl ~= nil then log(string.format("GAGANA %s: flight %s -> %s (%.0f s in)", t.name, tostring(g.last_fl), tostring(fl), now - g.t0)) end
                    g.last_fl = fl
                end
                -- v1.9.129: its swoop attacks (急襲) need the AI flag "行動解禁" (moves unlocked), which its lair sets and
                -- a Rancor never does (17:41 fight: 140 swoop checks, 0 passed). Its other flight moves are tied to its
                -- nest areas (【巣】 tables, area checks) or to a target it can't walk to / 6-30 m above it - left alone.
                if config.gagana_swoops and now - g.t0 > 5 then
                    if g.unlock == nil then
                        g.unlock = false
                        local vc = safe(function() return m_module(t.chara)._ThinkTableCtrl["<ValueController>k__BackingField"] end)
                        local dict = vc and safe(function() return vc.BoolValueDictionary end)
                        local ents = dict and safe(function() return dict._entries end)
                        for _, e in ipairs(ents and (safe(function() return ents:get_elements() end) or {}) or {}) do
                            local bv = safe(function() return e.value end)
                            if bv and safe(function() return bv.ValueName end) == "行動解禁" then g.unlock = bv; break end
                        end
                        log("GAGANA " .. t.name .. ": swoop-unlock flag " .. (g.unlock and "found" or "NOT found"))
                    end
                    if g.unlock and safe(function() return g.unlock.Value end) == false then
                        g.unlock_n = (g.unlock_n or 0) + 1
                        local okb = pcall(function() g.unlock:set_field("Value", true) end)
                        if g.unlock_n == 1 or g.unlock_n % 20 == 0 then
                            log(string.format("GAGANA %s: swoop attacks unlocked (#%d)%s", t.name, g.unlock_n, okb and "" or " - failed"))
                        end
                    end
                end
                if config.gagana_flight and fl == false and now - g.t0 > 10 and g.n < 30 and now - (g.set_t or -100) > 5 then
                    g.n, g.set_t = g.n + 1, now
                    local ok, err = pcall(function() ch2:call("setFlightParam(System.Boolean)", true) end)
                    local fl2 = safe(function() return ch2.IsFlightParam end)
                    g.last_fl = fl2
                    log(string.format("GAGANA %s: flight switched on (#%d): %s -> flight %s", t.name, g.n, ok and "ok" or ("failed " .. tostring(err)), tostring(fl2)))
                end
            end
        end
    end
end
-- v1.9.127 (user: the final wave ended while our Nasty Dragon was still up, and everything vanished): the Rancor
-- ends when all of ITS bosses are down (AllBossDefeatCondition) and then clears the field within 3 s - our
-- reinforcements included. While one of ours is still alive near you, that check is held at "not yet"
-- (at most hold_end_max seconds per Rancor), so the fight ends when you have beaten them too.
K.HOLD = { alive = {}, t = 0 }
function K.hold_tick(now)
    if now - K.HOLD.t < 0.5 then return end
    K.HOLD.t = now
    local alive = {}
    if vortex_now then
        local pp = player_upos()
        for _, t in pairs(tracked) do
            local hp = safe(function() return t.chara:get_Hit():call("get_Hp") end)
            if hp and hp > 0 and t.go then
                local up = upos_go(t.go)
                local d = up and pp and flat_dist(up, pp)
                if not d or d < 250 then alive[#alive + 1] = t.name end
            end
        end
    end
    K.HOLD.alive = alive
    if K.HOLD.since and #alive == 0 then
        log(string.format("Your reinforcements are down - the Rancor may end now (held it %.0f s)", now - K.HOLD.since))
        K.HOLD.since, K.HOLD.done = nil, true
    end
    if K.HOLD.fight ~= vortex_started_at then K.HOLD.fight, K.HOLD.since, K.HOLD.done, K.HOLD.timed_out = vortex_started_at, nil, nil, nil end
end
do
    local td = sdk.find_type_definition("app.appraiseCycle.condition.AllBossDefeatCondition")
    local m = td and td:get_method("evaluateImpl")
    if m then
        local ok = pcall(sdk.hook, m, nil, function(retval)
            if not config.hold_end or #K.HOLD.alive == 0 then return retval end
            if retval == nil or (sdk.to_int64(retval) & 0xFF) == 0 then return retval end
            local now = os.clock()
            if not K.HOLD.since then
                K.HOLD.since = now
                log(string.format("The Rancor's own bosses are down, but yours are still up (%s) - holding the end until they fall (max %d s)",
                    table.concat(K.HOLD.alive, ", "), math.floor(tonumber(config.hold_end_max) or 240)))
            end
            if now - K.HOLD.since > (tonumber(config.hold_end_max) or 240) then
                if not K.HOLD.timed_out then K.HOLD.timed_out = true; log("Holding the Rancor's end timed out - letting it end") end
                return retval
            end
            return sdk.to_ptr(0)
        end)
        if not ok then log("Could not hook the Rancor's all-bosses-defeated check") end
    end
end
-- v1.9.130 (user: the Evil Eye goes down far too easily - its vulnerable time on the floor after all its tentacles
-- are broken should be 1/3). app.Ch270 keeps that state's clock in _DownTimer. While that clock moves, the mod moves
-- it (eye_down_speed - 1) times as far again each frame, in the same direction, so the down state ends sooner.
-- Every down is logged (start value, direction, length) - not yet seen live, so this is checked on the first one.
K.EYEDOWN = {}
K.EYE_TCTRL = {}
function K.eye_down_tick(now)
    local mult = tonumber(config.eye_down_speed) or 1
    for addr, t in pairs(tracked) do
        if t.name and t.name:sub(1, #K.EYE_ID) == K.EYE_ID and t.go then
            local e = K.EYEDOWN[addr]
            if not e then
                e = { ch = safe(function() return t.go:call("getComponent(System.Type)", sdk.typeof("app.Ch270")) end) }
                K.EYEDOWN[addr] = e
            end
            -- v1.9.135: its think-table controller (for the teleport phase) and its animation speed while down
            if not e.tctrl and t.chara then
                e.tctrl = addr_of(safe(function() return m_module(t.chara)._ThinkTableCtrl end))
                if e.tctrl then K.EYE_TCTRL[e.tctrl] = t end
            end
            local act = safe(function() return t.chara["<ActionManager>k__BackingField"].CurrentAction:ToString() end) or ""
            local downish = act == "DmgFallCrashL" or act == "DmgFallCrash" or act == "DmgDownLoop" or act:find("StandupSign", 1, true)
                or act:find("Standup", 1, true) or act:find("DownLoop", 1, true)
            -- v1.9.136: ONLY while it is down, and always as a float. v1.9.135 set "1" at spawn as a Lua integer, which
            -- the game read as a float of ~0 - the Eye stood frozen (19:36, "speed now 0.0") and the game crashed in its
            -- parts / warp code 37 s later.
            local want = downish and (tonumber(config.eye_down_anim) or 1.0) * 1.0 or 1.0
            if want < 0.5 then want = 1.0 end
            if e.anim_speed == nil and not downish then e.anim_speed = 1.0 end   -- never touched it: leave it alone
            if e.anim_speed ~= want then
                e.motion = e.motion or safe(function() return t.go:call("getComponent(System.Type)", sdk.typeof("via.motion.Motion")) end)
                local ok = e.motion and pcall(function() e.motion:call("set_PlaySpeed(System.Single)", want + 0.0) end)
                local now_sp = ok and safe(function() return e.motion:call("get_PlaySpeed") end)
                if ok and type(now_sp) == "number" and math.abs(now_sp - want) > 0.05 then
                    -- did not take as meant: put 1.0 back and stop using this
                    pcall(function() e.motion:call("set_PlaySpeed(System.Single)", 1.0) end)
                    config.eye_down_anim = 1.0
                    log(string.format("EVIL EYE: animation speed came out as %s instead of %.1f - reset to normal, feature off", tostring(now_sp), want))
                    ok = false
                end
                if ok then
                    e.anim_speed = want
                    if not K.EYE_ANIM_LOGGED or want ~= 1 then
                        K.EYE_ANIM_LOGGED = true
                        log(string.format("EVIL EYE %s: animation speed x%.1f (%s, speed now %s)", t.name, want, act,
                            tostring(safe(function() return e.motion:call("get_PlaySpeed") end))))
                    end
                else
                    e.anim_speed = want   -- don't retry every frame
                    if not K.EYE_ANIM_FAIL then K.EYE_ANIM_FAIL = true; log("EVIL EYE: could not set its animation speed") end
                end
            end
            local v = e.ch and safe(function() return e.ch:get_field("_DownTimer") end)
            if type(v) == "number" then
                local prev = e.v
                e.v = v
                if prev and v ~= prev then
                    local d = v - prev
                    if not e.down then
                        e.down, e.t0, e.v0, e.dir = true, now, prev, d > 0 and "up" or "down"
                        local act = safe(function() return t.chara["<ActionManager>k__BackingField"].CurrentAction:ToString() end)
                        log(string.format("EVIL EYE down state: timer %.2f counting %s (action %s) - speeding it up x%.1f", prev, e.dir, tostring(act), mult))
                    end
                    e.moved_t = now
                    if mult > 1.01 and math.abs(d) < 5 then
                        local nv = v + d * (mult - 1)
                        if e.dir == "down" and nv < 0 then nv = 0 end
                        if pcall(function() e.ch:set_field("_DownTimer", nv) end) then e.v = nv end
                    end
                elseif e.down and now - (e.moved_t or now) > 1.0 then
                    local act = safe(function() return t.chara["<ActionManager>k__BackingField"].CurrentAction:ToString() end)
                    log(string.format("EVIL EYE down state over after %.1f s (timer %.2f -> %.2f, now action %s)", now - e.t0, e.v0 or -1, v, tostring(act)))
                    e.down = false
                end
            end
        end
    end
end
-- v1.9.135 (user): the Evil Eye's teleport phase. Its AI enters it when its think value "ワープ回数" (teleports left)
-- is 1+: main table -> "≪本体≫ワープチェック" -> instant-death gravity orb -> "warp move" (seen 19:18: 3 teleports).
-- In that phase:
--   * each teleport lands next to the next party member in turn: you, then each pawn (via the warp redirect below)
--   * after every teleport it must attack before it may teleport again: a tentacle swipe, and every 2nd time its
--     grab-bite ("Ch270:通常掴み(噛みつき)"). Done by holding its "go to warp check" row at "no" and steering its
--     attack table (other branches held at "no") until the attack has started
--   * when the teleports run out (ワープ回数 back to 0), it does its rapid tentacle regrowth ("Ch270:触手高速復活",
--     normally only when every tentacle is gone) - that row is let through once.
-- Row decisions are only answered (passed / held), never changed from inside the hook otherwise.
K.EYEPH = { active = false, need_attack = false, warps = 0, attacks = 0, t0 = 0, names = {} }
function K.eye_phase_targets()
    local list = {}
    local pp = player_upos()
    if pp then list[#list + 1] = { pos = pp, who = "you" } end
    local pm = sdk.get_managed_singleton("app.PawnManager")
    local l = pm and safe(function() return pm:call("get_AlivePawnCharacterList") end)
    local n = l and safe(function() return l:call("get_Count") end) or 0
    for i = 0, n - 1 do
        local c = safe(function() return l:call("get_Item", i) end)
        local tr = c and safe(function() return c:get_Transform() end)
        local up = tr and upos_tr(tr)
        if up then list[#list + 1] = { pos = up, who = "pawn " .. (#list) } end
    end
    return list
end
-- called by the warp redirect: where this teleport should land (nil = around you, as before)
function K.eye_phase_warp_pos()
    local P = K.EYEPH
    if not (config.eye_tele_phase and P.active) then return nil end
    local list = K.eye_phase_targets()
    if #list == 0 then return nil end
    local pick = list[(P.warps % #list) + 1]
    P.warps = P.warps + 1
    P.need_attack, P.need_t = true, os.clock()
    log(string.format("EVIL EYE teleport phase: teleport #%d -> next to %s; it attacks before the next one", P.warps, pick.who))
    return pick.pos
end
function K.eye_row_names(cmd_p, tbl_p)
    local ca = sdk.to_int64(cmd_p)
    local n = K.EYEPH.names[ca]
    if n == nil then
        local cmd = safe(function() return sdk.to_managed_object(cmd_p) end)
        local tbl = safe(function() return sdk.to_managed_object(tbl_p) end)
        n = { t = tbl and safe(function() return tbl.TableName end) or "?", a = cmd and safe(function() return cmd._ActInterName end) or "?",
              j = cmd and safe(function() return cmd.TableName end) or "?" }
        K.EYEPH.names[ca] = n
    end
    return n
end
-- the decision for one row: true / false to override, nil to leave the game's answer
function K.eye_row_gate(n, passed)
    local P = K.EYEPH
    local t, a, j = n.t, n.a, n.j
    -- phase start: its main table chooses the warp check
    if t == "メインテーブル" and j == "≪本体≫ワープチェック" then
        if P.need_attack and passed then return false end
        if passed and not P.active then
            P.active, P.t0, P.warps, P.attacks, P.need_attack, P.end_req = true, os.clock(), 0, 0, false, false
            log("EVIL EYE teleport phase started")
        end
        return nil
    end
    -- the regrowth at the end
    if P.end_req and t == "フェーズチェック" and a == "Ch270:触手高速復活" and j == "NO_JUMP_TBL" then
        P.end_req = false
        log("EVIL EYE teleport phase over: rapid tentacle regrowth")
        return true
    end
    if not P.need_attack then return nil end
    local grab_turn = (P.attacks % 2) == 1
    -- v1.9.138: its main table goes straight to its attack table (2 of 3 waits timed out at 19:51-19:54)
    if t == "メインテーブル" then
        if j == "【通常】攻撃メインテーブル" then return true end
        if j == "移動メインテーブル" then return false end
        return nil
    end
    if t == "【通常】攻撃メインテーブル" then
        if j == "≪触手≫物理攻撃" or j == "≪本体≫物理攻撃" then return true end
        if j == "≪触手≫魔法攻撃" or j == "≪触手≫地面ワープテーブル" or j == "≪本体≫魔法攻撃テーブル" or j == "≪本体≫視線攻撃"
            or (a == "ACT_INVALID" and j == "NO_JUMP_TBL") or a:find("ホバリング", 1, true) then return false end
    elseif t == "≪本体≫物理攻撃" and a == "Ch270:通常掴み(噛みつき)" then
        if grab_turn then
            P.need_attack, P.attacks = false, P.attacks + 1
            log("EVIL EYE teleport phase: grab-bite before the next teleport")
            return true
        end
    elseif t:find("≪触手≫", 1, true) and t:find("：物理攻撃", 1, true) and not grab_turn then
        -- v1.9.138: the first swipe row it checks is let through (they rarely pass on their own: 1 in ~400)
        P.need_attack, P.attacks = false, P.attacks + 1
        log("EVIL EYE teleport phase: tentacle swipe before the next teleport" .. (passed and "" or " (let through)"))
        return true
    end
    return nil
end
-- v1.9.138 (user): more damage resistance while it regrows its tentacles (its actions "Ch270RevivePartsQuick" and
-- the other "RevivePart" ones). Its two bodies share one HP; each frame, the part of any HP loss that the resistance
-- covers is given back (setHpValue on every body, same value, so it doesn't matter which body the game reads).
K.EYEREV = { last = nil, on = false }
function K.eye_revive_tick(now)
    local resist = tonumber(config.eye_revive_resist) or 0
    local bodies, reviving, hp = {}, false, nil
    for _, t in pairs(tracked) do
        if t.name and t.name:sub(1, #K.EYE_ID) == K.EYE_ID and t.chara then
            local hit = safe(function() return t.chara:get_Hit() end)
            local h = hit and safe(function() return hit:call("get_Hp") end)
            if hit and type(h) == "number" and h > 0 then
                bodies[#bodies + 1] = hit
                hp = hp and math.min(hp, h) or h
                local act = safe(function() return t.chara["<ActionManager>k__BackingField"].CurrentAction:ToString() end) or ""
                if act:find("Revive", 1, true) then reviving = true end
            end
        end
    end
    local R = K.EYEREV
    if not reviving or resist <= 0 or #bodies == 0 then
        if R.on then log(string.format("EVIL EYE regrowth over - normal damage again (%.0f damage taken back during it)", R.saved or 0)) end
        R.on, R.last = false, nil
        return
    end
    if not R.on then
        R.on, R.saved, R.last = true, 0, hp
        log(string.format("EVIL EYE regrowing its tentacles - %.0f%% less damage until it's done", resist * 100))
        return
    end
    if R.last and hp < R.last then
        local back = (R.last - hp) * resist
        local nv = hp + back
        for _, hit in ipairs(bodies) do pcall(function() hit:call("setHpValue(System.Single, System.Boolean)", nv + 0.0, false) end) end
        R.saved = (R.saved or 0) + back
        hp = nv
    end
    R.last = hp
end
-- v1.9.168 (user 13:18: "no minions spawned in"): every 2 s while our Eye is up, report each of its minions / ground
-- tentacles that exists (where, how far from you) and pull any that came out more than 40 m from you into the arena
K.EYEMIN = { seen = {}, t = 0, n = 0 }
function K.eye_minion_tick(now)
    local M = K.EYEMIN
    if now - M.t < 2 then return end
    M.t = now
    if not ((event.eyes or 0) > 0 and (vortex_now or (M.dead_t and now - M.dead_t < 30))) then
        if next(M.seen) then M.seen = {} end
        if not vortex_now then M.was_alive, M.dead_t = false, nil end
        return
    end
    local pp = player_upos()
    if not pp then return end
    -- v1.9.177 (user: "they die when the Evil Eye dies"): once our Eye has been alive and is now dead, every one of its
    -- eyeballs / ground tentacles still standing dies too (for 30 s, so late arrivals go as well)
    local alive = K.eye_alive and K.eye_alive()
    if alive then M.was_alive, M.dead_t = true, nil
    elseif M.was_alive and not M.dead_t then M.dead_t = now; M.killed = 0 end
    local killing = M.dead_t and now - M.dead_t < 30
    for _, c in ipairs(find_components("app.Character")) do
        local go = safe(function() return c:call("get_GameObject") end)
        local nm = go and safe(function() return go:call("get_Name") end) or ""
        if killing and (nm:sub(1, 9) == "ch271000_" or nm:sub(1, 6) == "ch2720") and nm:find("_00_", 1, true) then
            local hp = safe(function() return c:get_Hit():call("get_Hp") end)
            if hp and hp > 0 then
                local ok = pcall(function() c:call("requestFallDead") end)
                M.killed = (M.killed or 0) + 1
                if M.killed <= 30 then log(string.format("Evil Eye is dead - its %s dies with it%s", nm, ok and "" or " (could not)")) end
            end
        end
        if nm:sub(1, 9) == "ch271000_" or nm:sub(1, 6) == "ch2720" then
            local a = safe(function() return go:get_address() end)
            local up = upos_go(go)
            local d = up and flat_dist(pp, up)
            local e = a and M.seen[a]
            if a and not e then
                e = { name = nm, t = now }
                M.seen[a] = e
                M.n = M.n + 1
                if M.n <= 30 then log(string.format("Evil Eye summon appeared: %s, %s m from you", nm, d and string.format("%.0f", d) or "?")) end
            end
            -- (v1.9.175: no pull-in teleport any more - it split them from their model and collision)
        end
    end
end
-- v1.9.169 (user 13:28): its "tentacles into the ground" move, kept and steered into the arena. The move asks
-- app.Ch270PartsWarpController.requestWarp(WarpRequest) for N tentacle copies (ch2700xx_00). Request types:
-- AroundTarget 0 / AroundEachPartyMember 1 (a navigation query around you / each party member), AroundCenterOfBossStage
-- 2, SwingAppearAroundTarget 3, Ch270WarpRequester 4 / Area20 5 (its dungeon's warp data - the Rancor area has none,
-- 0 positions: the likely 13:17:35 crash), SubspaceContinuousBite 6. For a Rancor Eye: types 2 / 4 / 5 become
-- AroundTarget (state back to the query around its target), the dungeon warp-manager path is never entered, and any
-- found position more than 40 m from you is moved onto a spot 5-14 m around you before the tentacles are generated.
-- Only then are its tentacle spawn requests let through (15 s); every step is written to the log at once.
K.EYEPW = { ctrls = {}, n = 0, ok_until = -100 }
K.EYEPW.TYPE = { [0] = "AroundTarget", [1] = "AroundEachPartyMember", [2] = "AroundCenterOfBossStage", [3] = "SwingAppearAroundTarget",
    [4] = "Ch270WarpRequester", [5] = "Ch270WarpRequesterArea20", [6] = "SubspaceContinuousBite", [7] = "None" }
function K.EYEPW.ours(ctrl)
    local c = safe(function() return ctrl:get_field("_Ch270") end)
    local go = c and safe(function() return c:call("get_GameObject") end)
    local a = go and safe(function() return go:get_address() end)
    return a and tracked[a]
end
function K.EYEPW.say(msg)
    K.EYEPW.n = K.EYEPW.n + 1
    if K.EYEPW.n <= 80 then log_now("Eye tentacle warp: " .. msg) end
end
function K.EYEPW.spot()
    local pp = player_upos()
    if not pp then return nil end
    return K.ground_spot(pp, 5, 14, pp.y) or { x = pp.x + 8, y = pp.y, z = pp.z }   -- v1.9.176: on the ground
end
function K.EYEPW.clamp(ctrl, e)
    local pp = player_upos()
    local outer = pp and safe(function() return ctrl:get_field("_RequestPositions") end)
    local no = outer and safe(function() return outer:call("get_Count") end) or 0
    local total, moved, far = 0, 0, 0
    for i = 0, no - 1 do
        local inner = safe(function() return outer:call("get_Item", i) end)
        local ni = inner and safe(function() return inner:call("get_Count") end) or 0
        for j = 0, ni - 1 do
            local v = safe(function() return inner:call("get_Item", j) end)
            local p = v and safe(function() return { x = v:get_field("x"), y = v:get_field("y"), z = v:get_field("z") } end)
            total = total + 1
            local d = p and flat_dist(pp, p) or 999
            if d > 40 then
                far = math.max(far, d)
                local q = K.EYEPW.spot()
                if q and pcall(function()
                    local nv = ValueType.new(POS_TD)
                    nv:set_field("x", q.x); nv:set_field("y", q.y); nv:set_field("z", q.z)
                    inner:call("set_Item", j, nv)
                end) then moved = moved + 1 end
            end
        end
    end
    return total, moved, far
end
do
    local td = sdk.find_type_definition("app.Ch270PartsWarpController")
    local function m_of(sig, name, np)
        local m = td and safe(function() return td:get_method(sig) end)
        if td and not m then for _, mm in ipairs(td:get_methods()) do if mm:get_name() == name and mm:get_num_params() == np then m = mm; break end end end
        return m
    end
    local mreq = m_of("requestWarp(app.Ch270PartsWarpController.WarpRequest)", "requestWarp", 1)
    if mreq then pcall(sdk.hook, mreq, function(args)
        local st = thread.get_hook_storage(); st.rr_pw = nil
        if not (config.enabled and vortex_now) then return end
        local ctrl = sdk.to_managed_object(args[2])
        local t = ctrl and K.EYEPW.ours(ctrl)
        if t then st.rr_pw = { ctrl = ctrl, t = t } end
    end, function(retval)
        local st = thread.get_hook_storage(); local c = st and st.rr_pw
        if not c then return retval end
        st.rr_pw = nil
        local ctrl = c.ctrl
        local req = safe(function() return ctrl:get_field("_CurrentRequest") end)
        local ty = req and safe(function() return req:get_field("_WarpRequestType") end)
        local cnt = req and safe(function() local u = req:get_field("_WarpCount"); return string.format("%s-%s", tostring(u:get_field("x")), tostring(u:get_field("y"))) end) or "?"
        local stt = safe(function() return ctrl:get_field("_RequestState") end)
        local e = K.EYEPW.ctrls[ctrl:get_address()] or {}
        K.EYEPW.ctrls[ctrl:get_address()] = e
        e.ctrl, e.t, e.state, e.clamped = ctrl, c.t, stt, false
        local msg = string.format("%s asks for tentacles: type %s, count %s, state %s", c.t.name, tostring(K.EYEPW.TYPE[ty or -1] or ty), cnt, tostring(stt))
        if config.eye_parts_arena and (ty == 2 or ty == 4 or ty == 5) then
            local ok = pcall(function() req:set_field("_WarpRequestType", 0); ctrl:set_field("_RequestState", 0) end)
            msg = msg .. (ok and " -> AroundTarget (a query around its target)" or " -> could NOT change it")
        end
        K.EYEPW.ok_until = config.eye_parts_arena and (os.clock() + 15) or -100
        K.EYEPW.say(msg)
        return retval
    end) end
    -- its dungeon warp-manager path: never for a Rancor Eye
    local mwm = m_of("requestCh270WarpManager(app.Ch270WarpData.WarpGroup)", "requestCh270WarpManager", 1)
    if mwm then pcall(sdk.hook, mwm, function(args)
        local st = thread.get_hook_storage(); st.rr_pwm = nil
        if not (config.enabled and vortex_now and config.eye_parts_arena) then return end
        local ctrl = sdk.to_managed_object(args[2])
        local t = ctrl and K.EYEPW.ours(ctrl)
        if not t then return end
        pcall(function()
            local req = ctrl:get_field("_CurrentRequest")
            if req then req:set_field("_WarpRequestType", 0) end
            ctrl:set_field("_RequestState", 0)
        end)
        K.EYEPW.say(t.name .. ": its dungeon warp-point path was asked for - sent to the query around its target instead")
        st.rr_pwm = true
        return sdk.PreHookResult.SKIP_ORIGINAL
    end, function(retval)
        local st = thread.get_hook_storage()
        if st and st.rr_pwm then st.rr_pwm = nil; return sdk.to_ptr(0) end
        return retval
    end) end
    -- state watch + position clamp, only for controllers that asked this fight
    local mup = m_of("update()", "update", 0)
    if mup then pcall(sdk.hook, mup, function(args)
        if not next(K.EYEPW.ctrls) then return end
        local e = K.EYEPW.ctrls[sdk.to_int64(args[2])]
        if not e then return end
        local stt = safe(function() return e.ctrl:get_field("_RequestState") end)
        if stt ~= e.state then
            e.state = stt
            if stt == 16 or stt == 18 then
                pcall(function() e.ctrl:set_field("_RequestState", 0) end)
                K.EYEPW.say(e.t.name .. string.format(": state %d (dungeon warp points) -> back to the query around its target", stt))
                return
            end
            if stt == 10 or stt == 14 or stt == 20 then
                local total, moved, far = K.EYEPW.clamp(e.ctrl, e)
                K.EYEPW.say(string.format("%s: generating at %d spot(s)%s", e.t.name, total,
                    moved > 0 and string.format(", %d moved into the arena (were up to %.0f m away)", moved, far) or ", all inside 40 m of you"))
                K.EYEPW.ok_until = os.clock() + 15
            elseif stt == 22 or stt == 23 then
                K.EYEPW.say(e.t.name .. ": tentacle warp finished (state " .. tostring(stt) .. ")")
                K.EYEPW.ctrls[sdk.to_int64(args[2])] = nil
            end
        end
    end, nil) end
    local mwi = m_of("requestWarpInAction(app.Ch272)", "requestWarpInAction", 1)
    if mwi then pcall(sdk.hook, mwi, function(args)
        if not (config.enabled and vortex_now) then return end
        local ctrl = sdk.to_managed_object(args[2])
        local t = ctrl and K.EYEPW.ours(ctrl)
        if not t then return end
        local c272 = sdk.to_managed_object(args[3])
        local go = c272 and safe(function() return c272:call("get_GameObject") end)
        local up, pp = go and upos_go(go), player_upos()
        K.EYEPW.say(string.format("%s: tentacle %s comes up %s m from you", t.name, go and tostring(safe(function() return go:call("get_Name") end)) or "?",
            (up and pp) and string.format("%.0f", flat_dist(pp, up) or -1) or "?"))
    end, nil) end
end
-- v1.9.170 (user 13:41): its first eyeball minions are CREATED, not taken over. Tested live 13:42: a copy of the
-- Eye's own GenerateInfoContainer (container, CommonInfo and ObjectID cloned; CharacterID -> ch271000_00; a NEW
-- RequestID from app.RequestID.makeNewRequestID - with the Eye's own one the create returned -1) handed to
-- GenerateManager.forceRequestCreateInstance made ch271000_00_113 appear 7 m from the player with 6,400 HP. The
-- same done with a detached tentacle copy (ch270026_00) CRASHED the game (13:42:57) - tentacles are never created.
-- These n minions are on top of the takeover quota (evil_eye_minions), which still fills from later waves.
K.EYEF = { keep = {} }
function K.eye_force_minions(t, i, n)
    if not (t and t.go and vortex_now and config.enabled) then return end
    if not K.eye_alive() then return end
    local gm = sdk.get_managed_singleton("app.GenerateManager")
    local gi = safe(function() return t.go:call("getComponent(System.Type)", sdk.typeof("app.GenerateInfo")) end)
    local src = gi and safe(function() return gi:get_field("_Container") end)
    local mid = id_value[K.MINION_ID]
    local rtd = sdk.find_type_definition("app.RequestID")
    local mk = rtd and rtd:get_method("makeNewRequestID")
    if not (gm and src and mid and mk) then if i == 1 then log("Evil Eye minions: could not create them (no spawn data to copy)") end; return end
    if i == 1 then pcall(K.eye_preload, "minions created") end
    local pp = player_upos()
    local c0 = arena_center
    if not c0 or (pp and flat_dist(pp, c0) > 80) then c0 = pp end
    if not c0 then return end
    local function clone(o)
        local c = o:call("MemberwiseClone")
        c = (type(c) == "userdata" and c.get_type_definition) and c or sdk.to_managed_object(c)
        pcall(function() c:add_ref() end)
        K.EYEF.keep[#K.EYEF.keep + 1] = c
        return c
    end
    K.EYEF.a0 = (i == 1 or not K.EYEF.a0) and math.random() * 2 * math.pi or K.EYEF.a0
    local ok, r = pcall(function()
        local c = clone(src)
        -- v1.9.172: nothing of the copy is shared with the Eye's own spawn data (every GenerateInfo sub-record is copied)
        local td = c:get_type_definition()
        while td and td:get_full_name() ~= "System.Object" do
            for _, f in ipairs(td:get_fields()) do
                local ft = f:get_type()
                if not f:is_static() and not ft:is_value_type() and ft:get_full_name():find("^app%.GenerateInfo") then
                    local v = c:get_field(f:get_name())
                    if v and ft:get_full_name() ~= "app.GenerateInfo.GenerateInfoContainer" then c:set_field(f:get_name(), clone(v)) end
                end
            end
            td = td:get_parent_type()
        end
        local ci = c:get_field("_CommonInfo")
        local oid = clone(ci:get_field("_ObjectID"))
        ci:set_field("_ObjectID", oid)
        oid:set_field("_SelectedCharacterID", mid)
        local rid = mk:call(nil)
        pcall(function() rid:add_ref() end)
        K.EYEF.keep[#K.EYEF.keep + 1] = rid
        -- v1.9.173 (crash 15:07:35 in BattleManager.registerDetectArizenPartyAndInCameraEnemy ->
        -- Dictionary<UniqueID, EnemyController>.TryInsert, 1 s after the 3rd created minion): every created minion
        -- carried the same / an empty UniqueID. Each one now gets its own new UniqueID, checked before it is created.
        local utd = sdk.find_type_definition("app.UniqueID")
        local mku = utd and utd:get_method("makeNewUniqueID")
        local uid = mku and mku:call(nil)
        if not uid then error("no new UniqueID") end
        pcall(function() uid:add_ref() end)
        K.EYEF.keep[#K.EYEF.keep + 1] = uid
        rid:call("setUniqueID(app.UniqueID)", uid)
        ci:call("setRequestID(app.RequestID)", rid)
        local got = ci:call("get_UniqID")
        local src_u = safe(function() return src:get_field("_CommonInfo"):call("get_UniqID") end)
        if not got or (src_u and got:get_address() == src_u:get_address()) or tostring(got:call("ToString")) == tostring(src_u and src_u:call("ToString")) then
            error("its UniqueID would match the Eye's")
        end
        K.EYEF.uids = K.EYEF.uids or {}
        local us = tostring(got:call("ToString"))
        if K.EYEF.uids[us] then error("UniqueID " .. us .. " already used") end
        K.EYEF.uids[us] = true
        local a = K.EYEF.a0 + (i - 1) * (2 * math.pi / n)
        local rr = 8 + math.random() * 8
        local v = ValueType.new(POS_TD)
        v:set_field("x", c0.x + math.cos(a) * rr); v:set_field("y", (pp and pp.y or c0.y) + 4 + math.random() * 3); v:set_field("z", c0.z + math.sin(a) * rr)
        ci:set_field("_InitialPosition", v)
        log_now(string.format("Evil Eye minion %d/%d: creating", i, n))
        return gm:call("forceRequestCreateInstance(app.GenerateInfo.GenerateInfoContainer, System.Action`2<app.PrefabInstantiateResults,app.DummyArg_2_0_0_13>, System.Action`2<app.PrefabInstantiateResults,app.DummyArg_2_0_0_14>)", c, nil, nil)
    end)
    log(string.format("Evil Eye minion %d/%d: %s", i, n, (ok and type(r) == "number" and r >= 0) and "created" or ("failed (" .. tostring(r) .. ")")))
end
-- v1.9.171 dev research (user 13:47: "investigate, we need those tentacles"): the Eye's own spawn requests (its
-- detached tentacles ch2700xx_00, its summoned ch271000_00) are queued by the GenerateManager in a Rancor but never
-- instantiated - isDisableGenerateRequest says "not disabled" every frame and then they expire. This finds the
-- GenerateManager collection / controller holding such a request and dumps it right away and 4 s later (its state
-- while stuck), plus one wave request for comparison. Output: data/RancorReinforcements_genres.txt
K.GENRES = { n = 0, mgr_done = false, out = {}, keep = {} }
function K.GENRES.w(line) K.GENRES.out[#K.GENRES.out + 1] = line end
function K.GENRES.flush() pcall(fs.write, "RancorReinforcements_genres.txt", table.concat(K.GENRES.out, "\n")) end
function K.GENRES.dumpobj(obj, pre, depth, budget)
    budget = budget or { n = 0 }
    local td = safe(function() return obj:get_type_definition() end)
    while td and td:get_full_name() ~= "System.Object" and budget.n < 400 do
        for _, f in ipairs(td:get_fields()) do
            if not f:is_static() and budget.n < 400 then
                budget.n = budget.n + 1
                local okf, x = pcall(function() return obj:get_field(f:get_name()) end)
                local ft = f:get_type()
                local s = tostring(x)
                if okf and type(x) == "userdata" and ft:is_value_type() then
                    local okx, xs = pcall(function() return string.format("(%.2f, %.2f, %.2f)", x.x, x.y, x.z) end)
                    if okx then s = xs end
                end
                if okf and type(x) == "userdata" and not ft:is_value_type() then
                    local cnt = safe(function() return x:call("get_Count") end) or safe(function() return x:call("get_Length") end)
                    if cnt then s = s .. " [count " .. tostring(cnt) .. "]" end
                end
                K.GENRES.w(pre .. f:get_name() .. " : " .. ft:get_full_name() .. " = " .. s:sub(1, 120))
                if depth > 0 and okf and type(x) == "userdata" and not ft:is_value_type() and x.get_type_definition
                    and not ft:get_full_name():find("System.Collections", 1, true) then
                    K.GENRES.dumpobj(x, pre .. "    ", depth - 1, budget)
                end
            end
        end
        td = td:get_parent_type()
    end
end
-- every element of a managed collection (List / array / Dictionary values)
function K.GENRES.elements(x)
    local out = {}
    local tn = safe(function() return x:get_type_definition():get_full_name() end) or ""
    if tn:find("Dictionary`2", 1, true) then
        local ents = safe(function() return x:get_field("_entries") end)
        for _, e in ipairs(ents and (safe(function() return ents:get_elements() end) or {}) or {}) do
            local v = safe(function() return e:get_field("value") end)
            if v then out[#out + 1] = v end
        end
    else
        local n = safe(function() return x:call("get_Count") end)
        if n then for i = 0, math.min(n, 3000) - 1 do local v = safe(function() return x:call("get_Item", i) end); if v then out[#out + 1] = v end end
        else for _, v in ipairs(safe(function() return x:get_elements() end) or {}) do out[#out + 1] = v end end
    end
    return out
end
-- does obj (one level of fields) point at the container?
function K.GENRES.refers(obj, caddr)
    if type(obj) ~= "userdata" or not obj.get_type_definition then return nil end
    if safe(function() return obj:get_address() end) == caddr then return "itself" end
    local td = safe(function() return obj:get_type_definition() end)
    while td and td:get_full_name() ~= "System.Object" do
        for _, f in ipairs(td:get_fields()) do
            if not f:is_static() and not f:get_type():is_value_type() then
                local v = safe(function() return obj:get_field(f:get_name()) end)
                if type(v) == "userdata" and v.get_address and safe(function() return v:get_address() end) == caddr then return f:get_name() end
            end
        end
        td = td:get_parent_type()
    end
    return nil
end
function K.GENRES.note(info, cname)
    local G = K.GENRES
    G.n = G.n + 1
    if G.n > 3 then return end
    pcall(function() info:add_ref() end)
    G.keep[#G.keep + 1] = info
    local now = os.clock()
    table.insert(deferred, { kind = "genres", info = info, cname = cname, at = now + 0.5, tag = "0.5 s after its request" })
    table.insert(deferred, { kind = "genres", info = info, cname = cname, at = now + 4.0, tag = "4 s after its request" })
end
function K.GENRES.dump(d)
    local G = K.GENRES
    local gm = sdk.get_managed_singleton("app.GenerateManager")
    if not gm then return end
    local caddr = safe(function() return d.info:get_address() end)
    G.w("")
    G.w(string.format("===== %s %s (%s), container %s =====", os.date("%H:%M:%S"), d.cname, d.tag, tostring(caddr)))
    if not G.mgr_done then
        G.mgr_done = true
        G.w("-- GenerateManager collections:")
        local td = gm:get_type_definition()
        while td and td:get_full_name() ~= "System.Object" do
            for _, f in ipairs(td:get_fields()) do
                if not f:is_static() and not f:get_type():is_value_type() then
                    local v = safe(function() return gm:get_field(f:get_name()) end)
                    local cnt = v and (safe(function() return v:call("get_Count") end) or safe(function() return v:call("get_Length") end))
                    if cnt then G.w(string.format("  %s : %s [%s]", f:get_name(), f:get_type():get_full_name(), tostring(cnt))) end
                end
            end
            td = td:get_parent_type()
        end
    end
    -- where is it held?
    local found = 0
    local td = gm:get_type_definition()
    while td and td:get_full_name() ~= "System.Object" do
        for _, f in ipairs(td:get_fields()) do
            if not f:is_static() and not f:get_type():is_value_type() then
                local v = safe(function() return gm:get_field(f:get_name()) end)
                local isc = v and (safe(function() return v:call("get_Count") end) or safe(function() return v:call("get_Length") end))
                if isc and isc > 0 then
                    for i, el in ipairs(G.elements(v)) do
                        local how = G.refers(el, caddr)
                        if not how then
                            -- one more level: an element that is itself a collection or holds a list
                            local tn = safe(function() return el:get_type_definition():get_full_name() end) or ""
                            if tn:find("List`1", 1, true) or tn:find("[]", 1, true) then
                                for _, el2 in ipairs(G.elements(el)) do
                                    local how2 = G.refers(el2, caddr)
                                    if how2 then
                                        found = found + 1
                                        G.w(string.format("-- held in GenerateManager.%s[%d] -> inner element (%s) via %s", f:get_name(), i - 1,
                                            safe(function() return el2:get_type_definition():get_full_name() end) or "?", how2))
                                        if found <= 2 then G.dumpobj(el2, "    ", 1) end
                                        break
                                    end
                                end
                            end
                        else
                            found = found + 1
                            G.w(string.format("-- held in GenerateManager.%s[%d] (%s) via %s", f:get_name(), i - 1,
                                safe(function() return el:get_type_definition():get_full_name() end) or "?", how))
                            if found <= 2 and how ~= "itself" then G.dumpobj(el, "    ", 1) end
                        end
                    end
                end
            end
        end
        td = td:get_parent_type()
    end
    if found == 0 then G.w("-- not found in any GenerateManager collection (dropped from the queue?)") end
    G.w("-- the request (CommonInfo):")
    G.dumpobj(safe(function() return d.info:get_field("_CommonInfo") end), "    ", 1)
    G.flush()
    log(string.format("DEV genres: %s (%s) - %d holder(s) -> data/RancorReinforcements_genres.txt", d.cname, d.tag, found))
end
-- frame side: teleports left (its think value), phase timeouts
function K.eye_phase_tick(now)
    local P = K.EYEPH
    -- v1.9.140: no Evil Eye of ours alive -> no phase, and forget its AI controller
    if P.active or P.end_req or next(K.EYE_TCTRL) then
        local any = false
        for _, t in pairs(tracked) do
            if t.name and t.name:sub(1, #K.EYE_ID) == K.EYE_ID then
                local hp = safe(function() return t.chara:get_Hit():call("get_Hp") end)
                if hp and hp > 0 then any = true; break end
            end
        end
        if not any then
            if P.active then log("EVIL EYE teleport phase: the Eye is gone - phase off") end
            P.active, P.end_req, P.need_attack = false, false, false
            K.EYE_TCTRL = {}
            K.EYEDOWN = {}
            return
        end
    end
    if not P.active then return end
    if now - (P.chk or 0) < 0.5 then return end
    P.chk = now
    local left
    for _, t in pairs(tracked) do
        if t.name and t.name:sub(1, #K.EYE_ID) == K.EYE_ID and t.chara then
            local vc = safe(function() return m_module(t.chara)._ThinkTableCtrl["<ValueController>k__BackingField"] end)
            local dict = vc and safe(function() return vc.IntValueDictionary end)
            local ents = dict and safe(function() return dict._entries end)
            for _, e in ipairs(ents and (safe(function() return ents:get_elements() end) or {}) or {}) do
                local iv = safe(function() return e.value end)
                if iv and safe(function() return iv.ValueName end) == "ワープ回数" then
                    local v = safe(function() return iv.Value end)
                    if type(v) == "number" then left = math.max(left or 0, v) end
                end
            end
        end
    end
    if left ~= P.left then P.left = left; log("EVIL EYE teleport phase: teleports left " .. tostring(left)) end
    -- an attack that never comes (out of range, busy) is not waited for forever
    if P.need_attack and now - (P.need_t or now) > 12 then
        P.need_attack = false
        log("EVIL EYE teleport phase: no attack within 12 s - letting it teleport on")
    end
    if (left == 0 and P.warps > 0 and not P.need_attack) or now - P.t0 > 90 then
        P.active, P.end_req = false, true
        P.end_t = now
    end
    if P.end_req and now - (P.end_t or now) > 15 then P.end_req = false; log("EVIL EYE teleport phase: regrowth row never came up") end
end
do
    local ttd = sdk.find_type_definition("app.ThinkTableController")
    local tm = ttd and ttd:get_method("isExecuteEmThkGeneralCommand")
    if tm then
        pcall(sdk.hook, tm, function(args)
            if not next(K.EYE_TCTRL) then return end
            local st = thread.get_hook_storage()
            st["rr_eyeph"] = nil
            if not (config.enabled and config.eye_tele_phase) then return end
            if K.EYE_TCTRL[sdk.to_int64(args[2])] then st["rr_eyeph"] = { cmd = args[3], tbl = args[4] } end
        end, function(retval)
            local st = thread.get_hook_storage()
            local c = st and st["rr_eyeph"]
            if not c then return retval end
            st["rr_eyeph"] = nil
            local ok, r = pcall(function() return K.eye_row_gate(K.eye_row_names(c.cmd, c.tbl), is_true(retval)) end)
            if ok and r ~= nil then return sdk.to_ptr(r and 1 or 0) end
            return retval
        end)
    end
end
-- dev: its flight / waypoint settings and area checker, once per session
function K.gagana_dump(t, ch2)
    if K.gag_dumped then return end
    K.gag_dumped = true
    local okr, src = pcall(_G.fs.read, "claude_dumplib.lua")
    if not okr or type(src) ~= "string" or #src < 100 then return end
    local okl, D = pcall(function() return load(src, "=claude_dumplib", "t")() end)
    if not okl or type(D) ~= "table" then return end
    local txt = D.dump(safe(function() return ch2.DedicatedParameter end), "Ch253012 DedicatedParameter of " .. t.name, 20000, 8) .. "\n\n" ..
        D.dump(safe(function() return ch2["<AILocalAreaChecker>k__BackingField"] end), "AILocalAreaChecker", 5000, 4) .. "\n\n" ..
        D.dump(safe(function() return ch2["<FlightControl>k__BackingField"] end), "FlightControl", 8000, 4)
    pcall(fs.write, "RancorReinforcements_gagana_flight.txt", txt)
end
function PX.corpse_exec()
    if #PX.corpse_q == 0 then return end
    local nowq = os.clock()
    if not PX.quiet(nowq) then return end   -- v1.9.142: wait out the spawn burst, keep the queue
    if nowq - (PX.corpse_last or -1000) < 3 then return end   -- v1.9.148: one body at a time
    PX.corpse_last = nowq
    local q = { table.remove(PX.corpse_q, 1) }
    for _, c in ipairs(q) do
        -- v1.9.128: through the game's own despawn (GenerateManager.requestDestroy(container, true, false x4) - the
        -- same call and arguments the game uses), so the spawner forgets the monster. A raw GameObject.destroy may
        -- have left it counted: after the Gagana's body went (17:16:31) the next two big spawns - a Griffin and the
        -- Rancor's own final boss - never appeared, and the Rancor gave up waiting and ended.
        local how, ok, err = "game despawn", false, nil
        local gm = sdk.get_managed_singleton("app.GenerateManager")
        local gi = safe(function() return c.go:call("getComponent(System.Type)", sdk.typeof("app.GenerateInfo")) end)
        local cont = gi and safe(function() return gi:get_field("_Container") end)
        if K.RD_M == nil then
            K.RD_M = false
            local gtd = sdk.find_type_definition("app.GenerateManager")
            for _, m in ipairs(gtd and gtd:get_methods() or {}) do
                if m:get_name() == "requestDestroy" and m:get_num_params() == 6 then K.RD_M = m end
            end
        end
        if gm and cont and K.RD_M then
            ok, err = pcall(function() return K.RD_M:call(gm, cont, true, false, false, false, false) end)
        end
        if not ok then
            how = "destroy (fallback: " .. tostring(err or "no spawn record") .. ")"
            ok, err = pcall(function() c.go:call("destroy(via.GameObject)", c.go) end)
        end
        log(string.format("Body removed after its wave: %s via %s%s", c.name, how, ok and "" or (" - failed: " .. tostring(err))))
    end
end
re.on_application_entry("UpdateBehavior", function() pcall(PX.corpse_exec) end)
local removed = {}   -- go address -> true
local function in_post_window()
    return vortex_ended_at and os.clock() - vortex_ended_at < K.POST_WINDOW and vortex_center
end

-- v1.9.141: learn the stats of the Rancor's own Norgan Liches (HP, guard, damage), per kind of Rancor, for the Brine
-- Lich that takes their place. Read once per monster, in real Rancors only; kept in the settings file. Brine Liches
-- already out in the same fight are re-matched when the numbers change (keeping how hurt they are).
K.NATIVE_SEEN, K.NATIVE_N = {}, 0
function K.learn_native(go, name, now)
    local a = go:get_address()
    if K.NATIVE_SEEN[a] then return end
    local rf
    for _, r in ipairs(REINFORCEMENTS) do
        local src = r.variant_of or r.native_of   -- v1.9.144: the Drake matches the Thimble without being its variant
        if r.match_native and not r.off and src and name:sub(1, #src) == src then rf = r end
    end
    if K.NATIVE_N > 4000 then K.NATIVE_SEEN, K.NATIVE_N = {}, 0 end
    if not rf or not K.real_rancor() then K.NATIVE_SEEN[a] = true; K.NATIVE_N = K.NATIVE_N + 1; return end
    local chara = safe(function() return go:call("getComponent(System.Type)", sdk.typeof("app.Character")) end)
    local hit = chara and safe(function() return chara:get_Hit() end)
    local hp = hit and safe(function() return hit:call("get_Hp") end)
    if not hp or hp <= 0 then return end   -- not set up yet: try again next scan
    K.NATIVE_SEEN[a] = true; K.NATIVE_N = K.NATIVE_N + 1
    local mx = safe(function() return hit:call("get_OriginalMaxHp") end)
    local maxhp = (type(mx) == "number" and mx > 0) and mx or hp
    local batk = tonumber(safe(function() return K.get_field_any(hit, "_BaseAttackRate") end))
    local atk = tonumber(safe(function() return K.get_field_any(hit, "<AttackRate>k__BackingField") end))
    local bdef = tonumber(safe(function() return K.get_field_any(hit, "_BaseDefenceRate") end))
    local def = tonumber(safe(function() return K.get_field_any(hit, "<DefenceRate>k__BackingField") end))
    local guard = tonumber(safe(function() return hit:call("get_GuardHp") end))
    local kind = (K.KIND and K.KIND.kind) or "regular"
    local pre = rf.key .. "_native_"
    local before = K.native_stats(rf).sig
    config[pre .. "hp_" .. kind], config[pre .. "batk_" .. kind] = maxhp, batk
    config[pre .. "atk_" .. kind], config[pre .. "guard_" .. kind] = atk, guard
    config[pre .. "bdef_" .. kind], config[pre .. "def_" .. kind] = bdef, def   -- v1.9.144: defence too
    local st = K.native_stats(rf)
    log(string.format("%s %s in this %s Rancor: %.0f HP (now %.0f), guard %s, damage %s / %s%s", rf.variant_label or "Native", name, kind,
        maxhp, hp, tostring(guard), tostring(batk), tostring(atk), st.sig ~= before and " - new numbers for the " .. rf.name or ""))
    if st.sig == before then return end
    pcall(save_config)
    for _, t in pairs(K.TRACKED or {}) do
        if t.name and t.name:sub(1, #rf.id) == rf.id and t.native_sig ~= st.sig then
            local th = safe(function() return t.chara:get_Hit() end)
            if th then pcall(K.apply_native, th, rf, t, t.name); t.native_sig = st.sig end
        end
    end
end

local function find_and_scale_new()
    local now = os.clock()
    local swapping = swaps_pending > 0 and now - last_swap_time <= 60
    if not swapping then swaps_pending = 0 end
    if not vortex_now and not swapping and not next(tracked) and not in_post_window() then return end
    local present = {}
    for _, m in ipairs(find_components("app.Monster")) do
        local go = safe(function() return m:call("get_GameObject") end)
        local name = go and safe(function() return go:call("get_Name") end)
        local rf = reinforcement_for(name)
        if name and name:sub(1, #SATANICA.prefix) == SATANICA.prefix then
            if SATANICA.seen_t < 0 then log("Satanica is here (" .. name .. ")") end
            SATANICA.seen_t = now
            if SATANICA.until_t < now + 60 then SATANICA.until_t = now + 60 end
        end
        if not rf and name and vortex_now and name:sub(1, 3) == "ch2" then pcall(K.learn_native, go, name, now) end   -- v1.9.141
        if not rf and name and vortex_now and arena_center and name:match("^ch2%d%d") then
            -- v1.9.68: how far out this Rancor's own enemies appear = how big the arena is
            local a = go:get_address()
            event.nat_seen = event.nat_seen or {}
            if not event.nat_seen[a] then
                event.nat_seen[a] = true
                local up = upos_go(go)
                local fd = up and flat_dist(up, arena_center)
                if fd and fd < 140 and fd > (DEVOUR.extent or 0) then DEVOUR.extent = fd end
            end
        end
        if name and vortex_now and name:sub(1, 5) == "ch272" then
            -- v1.9.63: watch Evil Eye tentacles (log only) - HP, distance, so a stuck one shows up
            local a = go:get_address()
            event.tent_seen = event.tent_seen or {}
            local ts = event.tent_seen[a]
            if not ts or now - ts.t >= 15 then
                local ch = ts and ts.chara or safe(function() return go:call("getComponent(System.Type)", sdk.typeof("app.Character")) end)
                local up = upos_go(go)
                local c = arena_center or player_upos()
                log(string.format("Tentacle %s %s: %s, %.0f m from arena center", name, ts and "status" or "appeared",
                    ch and hp_report(ch) or "no Character", (up and c and flat_dist(up, c)) or -1))
                event.tent_seen[a] = { t = now, chara = ch }
            end
        end
        if rf then
            local addr = go:get_address()
            present[addr] = true
            local chara = scaled[addr] or tracked[addr] and tracked[addr].chara
                or safe(function() return go:call("getComponent(System.Type)", sdk.typeof("app.Character")) end)
            local pos = pos_of(go)
            if not scaled[addr] and not removed[addr] then
                local claimable = (swaps_by_id[rf.id] or 0) > (claimed_by_id[rf.id] or 0)
                    or (rf.key == "evil_eye" and now - (last_claim_t[rf.id] or -100) < 5)
                if (vortex_now or swapping) and not claimable then
                    -- v1.9.147: a fresh same-ID body right after our swap with no claim left = an extra from a
                    -- swapped GROUP record (04:03: 3 unscaled Nasty Dragons next to the real one). Despawned in
                    -- a quiet moment through the game's own despawn, like a body after its wave.
                    if rf.max_alive and K.real_rancor() and now - (rf.last_swap_t or -1000) < 30 and not removed[addr] then
                        removed[addr] = true
                        pcall(function() go:add_ref() end)
                        table.insert(PX.corpse_q, { go = go, name = name })
                        log("Extra " .. name .. " from a swapped group slot - despawning it once the spawning settles")
                    elseif not ignored_logged[addr] then
                        ignored_logged[addr] = true
                        log("Ignoring " .. name .. " - not spawned by this mod (world monster)")
                    end
                elseif (vortex_now or swapping) and (name == rf.id or not ((safe(function() return chara:get_Hit():call("get_Hp") end) or 0) > 0)) then
                    -- v1.9.104: never claim an object without an instance number ("ch252000_00" - a leftover/standby copy
                    -- that sits far outside the map with 0 HP) or one with no HP yet. At 16:36 that copy was claimed instead
                    -- of the real Golem, pulled into the arena by the leash, and the real Golem never showed up.
                    K.NOCLAIM = K.NOCLAIM or {}
                    if not K.NOCLAIM[addr] then
                        K.NOCLAIM[addr] = true
                        log(string.format("Not claiming %s (%s) - waiting for the real spawn", name,
                            name == rf.id and "no instance number: a leftover/standby copy" or "no HP yet"))
                    end
                elseif vortex_now or swapping then
                    local pre_hp = chara and hp_report(chara)
                    if chara and apply_scaling(chara, rf) then
                        log(string.format("%s spawned with its own HP: %s", name, tostring(pre_hp)))
                        claimed_by_id[rf.id] = (claimed_by_id[rf.id] or 0) + 1
                        last_claim_t[rf.id] = now
                        scaled[addr] = chara
                        swaps_pending = math.max(0, swaps_pending - 1)
                        mark_spawned(name)
                        tracked[addr] = { go = go, chara = chara, name = name, last_pos = pos, last_report = now, spawned_at = now }
                        if rf.match_native then tracked[addr].native_sig = K.native_stats(rf).sig end   -- v1.9.141
                        pcall(function() go:add_ref() end)
                        track_subobjects(go, chara, name)
                        if rf.key == "medusa" then register_medusa(go, chara, name) end
                        if rf.key == "hydra" then register_medusa(go, chara, name, true) end   -- v1.9.157
                        if rf.key == "golem" then pcall(PX.golem_setup, tracked[addr]) end
                        if rf.key == "brine_golem" then pcall(PX.points_setup, tracked[addr], "brine_golem") end   -- v1.9.151
                        if rf.key == "evil_eye" then pcall(PX.eye_warp_research, tracked[addr]) end
                        if rf.key == "purgener" then pcall(PX.points_setup, tracked[addr], "purgener") end
                        if rf.key == "vermund" then pcall(PX.points_setup, tracked[addr], "vermund") end   -- v1.9.155
                        if rf.no_teleport then   -- v1.9.161: spawned at its lair (far away) -> onto an arena spot
                            local pp = player_upos()
                            local up = upos_go(go)
                            local far = (pp and up and flat_dist(pp, up)) or 999
                            local tp = safe(function() return chara:get_field("Teleporter") end)
                            log(string.format("%s spawned %.0f m from you%s", name, far, far > 300 and " - bringing it to the arena" or ""))
                            if far > 300 and tp then table.insert(deferred, { kind = "arena_dest", obj = tp, name = name, why = "spawned at its lair", at = os.clock() + 1.0 }) end
                        end
                        local d = dist3(pos, vortex_center)
                        log(string.format("Scaled %s (%s)%s", name, hp_report(chara),
                            d and string.format(", %.0f m from vortex center", d) or ""))
                    end
                elseif in_post_window() then
                    -- a reinforcement turning up near the finished vortex = an escaped one coming back
                    local d = dist3(pos, vortex_center)
                    if d and d <= K.POST_RADIUS then
                        removed[addr] = true
                        log(string.format("REAPPEARED after vortex: %s, %.0f m from vortex center (%s)", name, d,
                            chara and hp_report(chara) or "?"))
                        if config.cleanup_leftovers then remove_monster(go, chara, name, "reappeared") end
                    end
                end
            end
            local t = tracked[addr]
            if t and (rf.key == "golem" or rf.key == "purgener") then pcall(PX.golem_tick, t, now) end
            if t and rf.sphinx_warp and not t.spx and (t.spx_try or 0) < 40 then   -- v1.9.164
                t.spx_try = (t.spx_try or 0) + 1
                if K.SPX.claim(t, name) then t.spx = true end
            end
            if t and rf.block_acts and not t.rowblock then   -- v1.9.163
                local tc = safe(function() return t.chara["<AIDecisionMaker>k__BackingField"]["<DecisionModule>k__BackingField"]._ThinkTableCtrl end)
                local a = tc and safe(function() return tc:get_address() end)
                if a then K.ROWBLOCK[a] = { acts = rf.block_acts, name = name }; t.rowblock = a; log(name .. ": its AI rows " .. table.concat((function() local o = {} for k in pairs(rf.block_acts) do o[#o+1] = k end return o end)(), ", ") .. " are off") end
            end
            if t and name:sub(1, #K.EYE_ID) == K.EYE_ID then
                last_eye_seen = now
                -- v1.9.170 (user 13:41: "force in 5 minions with the Evil Eye, later ones takeovers")
                if not event.eye_forced and config.eye_force_minions_unsafe == true and (tonumber(config.eye_force_minions) or 0) > 0 and vortex_now then
                    event.eye_forced = true
                    -- v1.9.172: 8 s after it arrives (15:02:34 the game crashed 2 s after the Eye spawned, while its
                    -- second body was being set up and all 5 were created in one frame), then one every 1.5 s
                    local nmin = math.min(8, tonumber(config.eye_force_minions) or 5)
                    for i = 1, nmin do
                        table.insert(deferred, { kind = "eye_force", t = t, at = now + 8.0 + (i - 1) * 1.5, i = i, n = nmin })
                    end
                end
                if now - K.EYE_PRE.t > 10 then pcall(K.eye_preload, "Evil Eye alive") end   -- v1.9.167
                local far = dist3(pos, player_pos())
                -- v1.9.64: never recall a dead Eye body (its mirror copy sits at 1 HP after death)
                local ehp = safe(function() return t.chara:get_Hit():call("get_Hp") end)
                -- v1.9.109: only after it has been away for 3 s (the warp's own recall waits for it to reappear first)
                if far and far > 300 then t.far_since = t.far_since or now else t.far_since = nil end
                if vortex_now and config.eye_redirect_warp and far and far > 300 and ehp and ehp > 1.5
                    and now - (t.far_since or now) >= 3 and now - (t.last_recall or -100) > 3 then
                    t.last_recall = now
                    local tp = safe(function() return t.chara:get_field("Teleporter") end)
                    recall_to_arena(tp, name, string.format("%.0f m away", far))
                end
            end
            -- v1.9.62 arena leash: a reinforcement that spawned or flew outside the arena can't be
            -- reached and the Rancor never completes. Pull living Griffins (etc.) back next to you.
            if t and vortex_now and config.leash and rf.key ~= "medusa" and rf.key ~= "evil_eye" and not rf.no_leash then
                local up = upos_go(go)
                local c = arena_center or player_upos()
                local hp = safe(function() return t.chara:get_Hit():call("get_Hp") end)
                local fd = up and c and flat_dist(up, c)
                local hgt = up and c and (up.y - c.y)
                -- v1.9.68: the leash scales with the arena (Devouring Rancor / how far its own enemies spawn),
                -- only counts as outside when far from BOTH the center and you, and is rate-limited
                local lim = DEVOUR.active and config.leash_dist_devour or config.leash_dist
                lim = math.max(lim, (DEVOUR.extent or 0) + 15)
                local pd = up and safe(function() local pp = player_upos(); return pp and flat_dist(up, pp) end)
                local outside = fd and ((fd > lim and (not pd or pd > lim)) or (hgt and hgt > config.leash_height))
                t.recalls = t.recalls or {}
                while #t.recalls > 0 and now - t.recalls[1] > 60 do table.remove(t.recalls, 1) end
                local throttled = #t.recalls >= config.leash_max_recalls
                if throttled and not t.throttle_logged then
                    t.throttle_logged = true
                    log(string.format("Leash: %s pulled back %d times this minute - leaving it alone for now (limit %.0f m)",
                        name, #t.recalls, lim))
                elseif not throttled then
                    t.throttle_logged = nil
                end
                if outside and hp and hp > 0 and not throttled then
                    t.out_since = t.out_since or now
                    if now - t.out_since >= config.leash_secs and now - (t.last_recall or -100) > 5 then
                        t.last_recall = now
                        table.insert(t.recalls, now)
                        t.leash_n = (t.leash_n or 0) + 1
                        local tp = safe(function() return t.chara:get_field("Teleporter") end)
                        local why = string.format("outside the arena: %.0f m out (limit %.0f), %.0f m up, for %.0f s", fd, lim, hgt or 0, now - t.out_since)
                        if tp then
                            if recall_to_arena(tp, name, why) then t.out_since = nil end
                        elseif t.leash_n <= 3 then
                            log("Leash: " .. name .. " is " .. why .. " but has no Teleporter")
                        end
                    end
                else
                    t.out_since = nil
                end
            end
            if t and pos then
                local jump = dist3(pos, t.last_pos)
                if jump and jump > 25 then
                    local d = dist3(pos, vortex_center)
                    log(string.format("JUMP %s moved %.0f m in 1 s (now %.0f m from vortex center)", name, jump, d or -1))
                elseif now - t.last_report >= 15 then
                    local d = dist3(pos, vortex_center)
                    log(string.format("Track %s: %s, %.0f m from vortex center", name, hp_report(t.chara), d or -1))
                    t.last_report = now
                end
                t.last_pos = pos
            end
        end
    end
    do  -- v1.9.66: living count per reinforcement type (for max_alive)
        local n = {}
        for _, t in pairs(tracked) do
            local r = reinforcement_for(t.name)
            if r and r.max_alive then
                local hp = safe(function() return t.chara:get_Hit():call("get_Hp") end)
                if hp and hp > 0 then n[r.key] = (n[r.key] or 0) + 1 end
            end
        end
        for _, r in ipairs(REINFORCEMENTS) do if r.max_alive then r.alive_n = n[r.key] or 0 end end
    end
    for addr, t in pairs(tracked) do
        if not present[addr] then
            log(string.format("LEFT SCENE: %s (last seen %.0f m from vortex center, vortex %s)", t.name,
                dist3(t.last_pos, vortex_center) or -1, vortex_now and "active" or "over"))
            tracked[addr] = nil; scaled[addr] = nil
        elseif not vortex_now and vortex_ended_at and t.spawned_at < vortex_ended_at and not removed[addr] then
            removed[addr] = true
            log(string.format("Leftover after vortex: %s (%s)", t.name, hp_report(t.chara)))
            if config.cleanup_leftovers then remove_monster(t.go, t.chara, t.name, "leftover") end
        end
    end
end

local function keep_attack_rate()
    for addr, chara in pairs(scaled) do
        local ok = pcall(function()
            local hit = chara:get_Hit()
            local t = tracked[addr]
            local rf = t and reinforcement_for(t.name)
            if rf and rf.keep_own_stats then return end   -- v1.9.141: Brine Skeleton Lord keeps its own damage
            if rf and rf.match_native then                -- v1.9.141: Brine Lich keeps the Norgan Lich's damage
                local st = K.native_stats(rf)
                if st.batk then set_if_exists(hit, { "_BaseAttackRate" }, st.batk + 0.0) end
                if st.atk then set_if_exists(hit, { "<AttackRate>k__BackingField" }, st.atk + 0.0) end
                return
            end
            local atk = (rf and rf.atk_key and tonumber(config[rf.atk_key])) or config.attack_rate   -- v1.9.91
            set_if_exists(hit, { "_BaseAttackRate" }, atk)
            set_if_exists(hit, { "<AttackRate>k__BackingField" }, atk)
        end)
        if not ok then scaled[addr] = nil end
    end
end

-- v1.9.146 (user: after the Eye fight its tentacles pop in and instantly vanish): the moment the Eye died
-- (03:51:02) the game flushed its queued summons - two 37,500 HP tentacles spawned at the arena center one
-- second later, found their parent dead and took themselves apart. Any Eye-family spawn (ch271000 minions,
-- ch272000/272002 tentacles) requested in our Rancor while no mod Evil Eye is alive is an orphan: cancelled.
function K.eye_orphan(cname)
    if not cname then return false end
    local fam6 = cname:sub(1, 6)
    if fam6 ~= "ch2710" and fam6 ~= "ch2720" then return false end
    if cname:sub(1, #K.EYE_ID) == K.EYE_ID then return false end   -- the Eye body has its own handling
    if (event.eyes or 0) == 0 then return false end                -- this fight never had our Eye
    if not vortex_now and not (vortex_ended_at and os.clock() - vortex_ended_at < 60) then return false end
    if K.eye_alive and K.eye_alive() then return false end         -- alive: its summons are the real mechanic
    return true
end
-- Keep a living Evil Eye from being deleted at wave end ---------------------------------
-- v1.9.61: the Eye runs as two mirrored bodies (host + guest). On death one drops to 0 HP and
-- the other can sit at 1 HP forever, so: any body at 0 = the Eye is dead; 1 HP or less is not alive.
local eye_dead_logged = false
local function eye_alive()
    local any_alive, any_dead = false, false
    for _, t in pairs(tracked) do
        if t.name:sub(1, #K.EYE_ID) == K.EYE_ID then
            local hp = safe(function() return t.chara:get_Hit():call("get_Hp") end)
            if hp then
                if hp <= 0 then any_dead = true elseif hp > 1.5 then any_alive = true end
            end
        end
    end
    if any_dead and not eye_dead_logged then
        eye_dead_logged = true
        log("Evil Eye is dead (a body hit 0 HP) - letting the Rancor clean up its remaining body")
    end
    return any_alive and not any_dead
end
K.eye_alive = eye_alive   -- v1.9.146: for the orphan-summon and fodder checks in the spawn hooks
rr_on_new_vortex = function() eye_dead_logged = false end

local keep_hooks, keep_count = 0, 0
do
    local SAFE_RET = { ["System.Void"] = true, ["System.Boolean"] = true, ["System.Int32"] = true, ["System.UInt32"] = true }
    local td = sdk.find_type_definition("app.GenerateManager")
    for _, m in ipairs(td and td:get_methods() or {}) do
        local p1 = m:get_num_params() == 6 and safe(function() return m:get_param_types()[1]:get_full_name() end) or ""
        if m:get_name() == "requestDestroy" and p1:find("GenerateInfoContainer", 1, true) then
            local ret = safe(function() return m:get_return_type():get_full_name() end) or "?"
            local idx = safe(function() return m:is_static() end) and 2 or 3
            if SAFE_RET[ret] then
                local ok = pcall(sdk.hook, m, function(args)
                    if not (config.enabled and config.eye_keep_alive and vortex_now) then return end
                    local info = safe(function() return sdk.to_managed_object(args[idx]) end)
                    local cid = info and safe(function() return info._CommonInfo._ObjectID._SelectedCharacterID end)
                    if cid ~= id_value[K.EYE_ID] or not eye_alive() then return end
                    keep_count = keep_count + 1
                    if keep_count <= 20 then log("Kept the Evil Eye: blocked its wave-end removal") end
                    thread.get_hook_storage()["rr_skip"] = true
                    return sdk.PreHookResult.SKIP_ORIGINAL
                end, function(retval)
                    local st = thread.get_hook_storage()
                    if st and st["rr_skip"] then
                        st["rr_skip"] = nil
                        if ret ~= "System.Void" then return sdk.to_ptr(0) end
                    end
                    return retval
                end)
                if ok then keep_hooks = keep_hooks + 1 end
            end
            log("requestDestroy(container) returns " .. ret .. (SAFE_RET[ret] and " - hooked" or " - not hooked (unsafe to skip)"))
        end
    end
end
do
    local names = {}
    for _, f in ipairs(POS_TD and safe(function() return POS_TD:get_fields() end) or {}) do
        table.insert(names, f:get_name() .. ":" .. (safe(function() return f:get_type():get_full_name() end) or "?"))
    end
    log("via.Position fields: " .. table.concat(names, ", "))
end

-- Main loop ---------------------------------------------------------------------------
local last_tick = 0
local function capture_arena_center()
    local function retake(p, why)
        arena_center, arena_center_at = p, os.clock()
        lair = nil
        reset_samples()
        log(string.format("Rancor arena center = your position (%.0f, %.0f, %.0f world)%s", p.x, p.y, p.z, why or ""))
        if why and why:find("new fight", 1, true) then pcall(rancor_fingerprint) end
        if why and why:find("new fight", 1, true) then
            -- v1.9.66: a new Rancor while the vortex never "ended" - restart the per-event caps,
            -- keeping anything already swapped in on this fight's first wave
            local keep = {}
            for _, r in ipairs(REINFORCEMENTS) do
                if (r.last_swap_t or -100) >= wave_fight_start - 1 and event.by_key then keep[r.key] = event.by_key[r.key] end
            end
            event.by_key = keep
            -- v1.9.117: the Evil Eye / minion / tentacle counters restart too (one Eye at 18:05 used up the cap for every later
            -- Rancor because the vortex never "ended" in between); keep an Eye swapped in on this first wave
            local eye_now = keep.evil_eye or 0
            event.eyes, event.minions, event.tentacles = eye_now, (eye_now > 0) and event.minions or 0, (eye_now > 0) and event.tentacles or 0
        end
    end
    if vortex_now and arena_center_at < vortex_started_at then
        local p = player_upos()
        if p then retake(p) end
    end
    if not vortex_now then return end
    local p = player_upos()
    if not p then return end
    local d = arena_center and flat_dist(p, arena_center)
    -- first wave of a new fight: you just touched the rift
    if wave_fight_start > arena_center_at and os.clock() - wave_fight_start < 5 then
        if not arena_center or (d and d > 150) then
            retake(p, string.format(" - new fight's first wave (old center was %.0f m away)", d or -1))
        else
            arena_center_at = os.clock()   -- confirmed, keep the calibrated center
        end
        return
    end
    -- a Rancor Medusa is fighting but you are far from the center: it is stale
    if next(medusa) and d and d > 80 then
        retake(p, string.format(" - the old center was %.0f m away (stale)", d))
    end
end
-- v1.9.111: Evil Eye "virtual lair". Its warp picks a point from its dungeon's warp data (Ch270WarpData areas) and the
-- game then moves the body there with Teleporter.teleport. For a mod Eye during a Rancor that teleport is cancelled and
-- the body is put on a spot around the arena instead (ring 14-30 m from the center, 5-10 m up, never right next to
-- the last spot), so it never leaves and never needs pulling back.
K.EYE_SPOTS = { last = nil, n = 0 }
function K.eye_spot()
    local pp = player_upos()
    local c = arena_center
    if not c or (pp and flat_dist(pp, c) > 80) then c = pp end
    if not c then return nil end
    local best
    for _ = 1, 8 do
        local a = math.random() * 2 * math.pi
        local r = 14 + math.random() * 16
        local p = { x = c.x + math.cos(a) * r, y = (pp and pp.y or c.y) + 5 + math.random() * 5, z = c.z + math.sin(a) * r }
        best = p
        if not K.EYE_SPOTS.last or flat_dist(p, K.EYE_SPOTS.last) > 12 then break end
    end
    K.EYE_SPOTS.last = best
    return best
end
do
    local td = sdk.find_type_definition("app.Teleporter")
    for _, sig in ipairs({ "teleport(via.Position)", "teleport(via.Position, via.Quaternion)" }) do
        local m = td and td:get_method(sig)
        if m then
            pcall(sdk.hook, m, function(args)
                if recalling or not (config.enabled and config.eye_arena_warp and vortex_now) then return end
                local t = tracked_sub[sdk.to_int64(args[2])]
                if not (t and t.type == "app.Teleporter" and t.name:sub(1, #K.EYE_ID) == K.EYE_ID) then return end
                table.insert(deferred, { kind = "eye_dest", t = t })
                K.EYE_SPOTS.n = K.EYE_SPOTS.n + 1
                return sdk.PreHookResult.SKIP_ORIGINAL
            end, nil)
        end
    end
end
-- v1.9.163: think-table rows that never pass for a reinforcement (rf.block_acts, by the row's action name)
K.ROWBLOCK = {}   -- ThinkTableController address -> { acts = set, name = go name }
K.ROWBLOCK_CMD = {}   -- command address -> action name (cache)
do
    local td = sdk.find_type_definition("app.ThinkTableController")
    local m = td and td:get_method("isExecuteEmThkGeneralCommand")
    if m then
        pcall(sdk.hook, m, function(args)
            local st = thread.get_hook_storage(); st.rr_rb = nil
            local e = K.ROWBLOCK[sdk.to_int64(args[2])]
            if e then st.rr_rb = { e = e, cmd = args[3] } end
        end, function(retval)
            local st = thread.get_hook_storage(); local c = st and st.rr_rb
            if not c then return retval end
            st.rr_rb = nil
            if (sdk.to_int64(retval) & 0xFF) == 0 then return retval end
            local ca = sdk.to_int64(c.cmd)
            local act = K.ROWBLOCK_CMD[ca]
            if act == nil then
                local cmd = safe(function() return sdk.to_managed_object(c.cmd) end)
                act = cmd and safe(function() return cmd._ActInterName end) or ""
                -- v1.9.164: also "act > jump table" so one row of an act can be off and the others stay
                local jump = cmd and safe(function() return cmd.TableName end) or ""
                act = { act, act .. " > " .. tostring(jump) }
                K.ROWBLOCK_CMD[ca] = act
            end
            local hit = c.e.acts[act[1]] and act[1] or (c.e.acts[act[2]] and act[2])
            if hit then act = hit end
            if hit then
                c.e.n = (c.e.n or 0) + 1
                if c.e.n <= 5 then table.insert(deferred, { kind = "log", msg = string.format("%s: AI row '%s' blocked (#%d)", c.e.name, act, c.e.n) }) end
                return sdk.to_ptr(0)
            end
            return retval
        end)
    end
end
-- v1.9.159: reinforcements that teleport themselves home (Brine Sphinx -> its lair) stay in the Rancor
do
    local td = sdk.find_type_definition("app.Teleporter")
    for _, sig in ipairs({ "teleport(via.Position)", "teleport(via.Position, via.Quaternion)" }) do
        local m = td and td:get_method(sig)
        if m then
            pcall(sdk.hook, m, function(args)
                if recalling or not (config.enabled and vortex_now) then return end
                local t = tracked_sub[sdk.to_int64(args[2])]
                if not (t and t.type == "app.Teleporter") then return end
                local rf = reinforcement_for(t.name)
                if not (rf and rf.no_teleport) then return end
                K.TP_BLOCK = (K.TP_BLOCK or 0) + 1
                -- v1.9.162: rewrite where her own teleport goes (the game's warp keeps model + body together)
                local now = os.clock()
                local p
                -- v1.9.163: a warp that stays near you (her warp attacks) keeps the game's own destination
                local dest = safe(function() local v = sdk.to_valuetype(args[3], "via.Position"); return { x = v:get_field("x"), y = v:get_field("y"), z = v:get_field("z") } end)
                local ppn = player_upos()
                if dest and ppn and now - (t.since or -100) >= 4 and (flat_dist(ppn, dest) or 999) < 45 then
                    K.TP_NEAR = (K.TP_NEAR or 0) + 1
                    if K.TP_NEAR <= 10 then log(string.format("%s warp attack / near warp: kept (%.0f m from you)", t.name, flat_dist(ppn, dest) or -1)) end
                    return nil
                end
                if now - (t.since or -100) < 4 then
                    p = upos_go(t.go)   -- the spawn teleport: stay where she appeared
                    if p then p = { x = p.x, y = p.y, z = p.z } end
                elseif t.lair_p and now - (t.lair_t or -10) < 1.5 then
                    p = t.lair_p        -- the same warp calls teleport twice: same spot
                else
                    p = K.lair_spot(1.5)
                end
                if not p then return sdk.PreHookResult.SKIP_ORIGINAL end
                t.lair_p, t.lair_t = p, now
                local ok = pcall(function()
                    local v = sdk.to_valuetype(args[3], "via.Position")
                    v:set_field("x", p.x); v:set_field("y", p.y); v:set_field("z", p.z)
                end)
                if not ok then return sdk.PreHookResult.SKIP_ORIGINAL end
                K.LAIR_SPOTS.n = K.LAIR_SPOTS.n + 1
                if K.LAIR_SPOTS.n <= 40 then
                    local pp = player_upos()
                    log(string.format("%s teleport #%d (the game aimed it %s m away) -> %s, %.0f m from you", t.name, K.LAIR_SPOTS.n,
                        dest and ppn and string.format("%.0f", flat_dist(ppn, dest) or -1) or "?",
                        now - (t.since or -100) < 4 and "stays where it spawned" or "arena spot", (pp and flat_dist(pp, p)) or -1))
                end
                -- her warp may reset her HP to her own: check it a moment later
                table.insert(deferred, { kind = "tp_check", go = t.go, name = t.name, p = p, at = now + 1.2 })
                table.insert(deferred, { kind = "keep_hp", go = t.go, name = t.name, at = now + 1.5 })
                table.insert(deferred, { kind = "keep_hp", go = t.go, name = t.name, at = now + 4.0 })
                return nil
            end, nil)
        end
    end
end
-- v1.9.164 (user 12:30: "she just teleported away ... whatever arena based teleports she has spread those around
-- Rancors, Rancor Sphinx only"): her own warp system, app.Ch253001WarpController. 12:24:48 she teleported, and one
-- second later she was gone from the scene - a warp with WarpDestroy set deletes her at its end. Her warp
-- situations: BattleWarp 0 (warp blast / warp orb / out-of-range warp), SubdueSucceed 1, DestroyWarp 2,
-- WarpToTreasureBox 3, OutOfStage 4 (back into her sanctuary), AvoidPetrificationIrradiation 5 (gaze dodge).
-- For a Rancor Sphinx only: 1-4 never run, WarpDestroy is kept off, her quest routine changes are ignored, and any
-- warp point more than 45 m from you (her sanctuary points, the out-of-range warp) is moved onto a spot around the
-- arena (the same ring as the teleport rewrite above), so the game's own warp - model and body together - lands there.
K.SPX = { wc = {}, log_n = 0 }
K.SPX.SIT = { [0] = "BattleWarp", [1] = "SubdueSucceed", [2] = "DestroyWarp", [3] = "WarpToTreasureBox", [4] = "OutOfStage", [5] = "AvoidPetrificationIrradiation" }
K.SPX.CAT = { [0] = "FirstSanctuary", [1] = "SecondSanctuary", [2] = "Field", [3] = "NRD" }
K.SPX.TGT = { [0] = "Position", [1] = "TargetDistance", [2] = "WarpSelf", [3] = "Destroy" }
K.SPX.BLOCK = { [1] = true, [2] = true, [3] = true, [4] = true, [5] = true }   -- v1.9.165: 5 = gaze dodge, off
K.SPX.NEAR = 45
function K.SPX.dlog(msg)
    K.SPX.log_n = K.SPX.log_n + 1
    if K.SPX.log_n <= 120 then table.insert(deferred, { kind = "log", msg = msg }) end
end
function K.SPX.read_pos(obj, fname)
    local v = safe(function() return obj:get_field(fname) end)
    if not v then return nil end
    return safe(function() return { x = v:get_field("x"), y = v:get_field("y"), z = v:get_field("z") } end)
end
-- write a via.Position field of a managed object (set_field first, raw memory if that does not stick)
function K.SPX.write_pos(obj, fname, p)
    local function same()
        local q = K.SPX.read_pos(obj, fname)
        return q and math.abs(q.x - p.x) < 0.01 and math.abs(q.z - p.z) < 0.01
    end
    pcall(function()
        local v = ValueType.new(POS_TD)
        v:set_field("x", p.x); v:set_field("y", p.y); v:set_field("z", p.z)
        obj:set_field(fname, v)
    end)
    if same() then return "set" end
    local ok = pcall(function()
        local td = obj:get_type_definition()
        local f
        while td and not f do f = td:get_field(fname); td = td:get_parent_type() end
        local base = f:get_offset_from_base()
        for _, c in ipairs({ "x", "y", "z" }) do
            local pf = POS_TD:get_field(c)
            local off = base + pf:get_offset_from_fieldptr()
            if pf:get_type():get_full_name() == "System.Double" then obj:write_double(off, p[c]) else obj:write_float(off, p[c]) end
        end
    end)
    if ok and same() then return "raw" end
    return nil
end
function K.SPX.entry(args)
    return K.SPX.wc[sdk.to_int64(args[2])]
end
-- the arena spot for this warp (one warp asks more than once: keep the same spot for 3 s)
function K.SPX.spot(e)
    local now = os.clock()
    if e.spot and now - (e.spot_t or -10) < 3 then return e.spot end
    e.spot, e.spot_t = K.lair_spot(1.5), now
    return e.spot
end
-- move her chosen warp point (and the candidate points) into the arena when it is far from you
function K.SPX.fix(e, why)
    if not (config.enabled and vortex_now) then return end
    local wc = e.wc
    local pp = player_upos()
    local p = K.SPX.read_pos(wc, "WarpPosition")
    if not (pp and p) then return end
    local d = flat_dist(pp, p) or 999
    if d < K.SPX.NEAR then
        if why == "warpStart" then K.SPX.dlog(string.format("%s warp (%s): the game's point %.0f m from you - kept", e.name, e.sit_name or "?", d)) end
        return
    end
    local q = K.SPX.spot(e)
    if not q then return end
    local how = K.SPX.write_pos(wc, "WarpPosition", q)
    e.fixed = (e.fixed or 0) + 1
    K.SPX.dlog(string.format("%s warp (%s, %s): the game's point was %.0f m from you -> arena spot %.0f m from you%s", e.name,
        e.sit_name or "?", why, d, flat_dist(pp, q) or -1, how and "" or " - WRITE FAILED (the teleport rewrite still applies)"))
end
function K.SPX.fix_candidates(e)
    if not (config.enabled and vortex_now) then return end
    local pp = player_upos()
    local list = pp and safe(function() return e.wc:get_field("CandidateWarpPositionList") end)
    local n = list and safe(function() return list:call("get_Count") end) or 0
    local moved = 0
    for i = 0, n - 1 do
        local c = safe(function() return list:call("get_Item", i) end)
        local p = c and K.SPX.read_pos(c, "Position")
        if p and (flat_dist(pp, p) or 999) >= K.SPX.NEAR then
            local q = K.lair_spot(1.5)
            if q and K.SPX.write_pos(c, "Position", q) then moved = moved + 1 end
        end
    end
    if moved > 0 then
        e.cand = (e.cand or 0) + 1
        if e.cand <= 5 then K.SPX.dlog(string.format("%s: %d of her %d warp candidate points were far from you -> arena spots", e.name, moved, n)) end
    end
end
-- claimed from the tracked loop for a Rancor Brine Sphinx
function K.SPX.claim(t, name)
    local c = safe(function() return t.go:call("getComponent(System.Type)", sdk.typeof("app.Ch253001")) end)
    local wc = c and safe(function() return c:get_field("<Ch253001WarpController>k__BackingField") end)
    local a = wc and safe(function() return wc:get_address() end)
    if not a then return false end
    local e = { t = t, name = name, wc = wc, comp = c, blocked = {}, req = {} }
    K.SPX.wc[a] = e
    local cat = safe(function() return wc:get_field("WarpBattleCategory") end)
    e.cat = cat
    log(string.format("%s: warp controller claimed (her warp category %s) - her warps stay in the arena", name, tostring(K.SPX.CAT[cat or -1] or cat)))
    -- her warp table (Ch253001Parameter._WarpParamList), for the record
    local par
    local td = safe(function() return c:get_type_definition() end)
    while td and not par do
        for _, f in ipairs(td:get_fields()) do
            if not f:is_static() and f:get_type():get_full_name():find("Ch253001Parameter", 1, true) then
                par = safe(function() return c:get_field(f:get_name()) end)
                if par then break end
            end
        end
        td = td:get_parent_type()
    end
    if K.DEV_SPX_TEST then   -- every warp situation, one at a time (blocked ones must log "cancelled")
        local now = os.clock()
        for i, sit in ipairs({ 5, 0, 4, 2, 3, 1, 5, 0 }) do
            table.insert(deferred, { kind = "spx_test", e = e, sit = sit, at = now + 15 + i * 9 })
        end
        table.insert(deferred, { kind = "spx_test", e = e, at = now + 15 + 9 * 9 + 4 })
        log(name .. ": DEV warp test armed (8 warps, 9 s apart, from 24 s)")
    end
    if not par then par = safe(function() return c:call("get_Ch253001Parameter") end) end
    local wl = par and safe(function() return par:get_field("_WarpParamList") end)
    local items = wl and safe(function() return wl:get_elements() end) or {}
    local pp = player_upos()
    log(string.format("%s: her warp table has %d entries (min warp distance %s)", name, #items, tostring(par and safe(function() return par:get_field("_MinWarpDistance") end))))
    for i, w in ipairs(items) do
        local p = K.SPX.read_pos(w, "_Position")
        local dd = safe(function() local v = w:get_field("_Distance"); return string.format("%.0f-%.0f", v.x, v.y) end) or "?"
        local wcat, ws, wt = safe(function() return w:get_field("_WarpCategory") end), safe(function() return w:get_field("_WarpSituation") end), safe(function() return w:get_field("_WarpTargetType") end)
        log(string.format("  warp %d: %s / %s / %s, distance %s, point %s%s", i, tostring(K.SPX.CAT[wcat or -1] or wcat), tostring(K.SPX.SIT[ws or -1] or ws),
            tostring(K.SPX.TGT[wt or -1] or wt), dd, p and string.format("(%.0f, %.0f, %.0f)", p.x, p.y, p.z) or "?",
            (p and pp) and string.format(" = %.0f m from you", flat_dist(pp, p) or -1) or ""))
    end
    return true
end
do
    local td = sdk.find_type_definition("app.Ch253001WarpController")
    local function hk(sig, pre, post)
        local m = td and safe(function() return td:get_method(sig) end)
        if td and not m then   -- by name + parameter count
            local nm, ps = sig:match("^([^(]+)%((.*)%)$")
            local np = (ps == "" and 0) or select(2, ps:gsub(",", ",")) + 1
            for _, mm in ipairs(td:get_methods()) do
                if mm:get_name() == nm and mm:get_num_params() == np then m = mm; break end
            end
        end
        if m then
            local ok = pcall(sdk.hook, m, pre, post)
            K.SPX.hooks = (K.SPX.hooks or 0) + (ok and 1 or 0)
        else log("Sphinx warp hook missing: " .. sig) end
    end
    hk("requestWarp(app.Ch253001WarpController.WarpSituationEnum)", function(args)
        local st = thread.get_hook_storage(); st.rr_spx = nil
        local e = K.SPX.entry(args)
        if not (e and config.enabled and vortex_now) then return end
        local sit = sdk.to_int64(args[3]) & 0xFFFFFFFF
        local act = safe(function() return e.t.chara["<ActionManager>k__BackingField"].CurrentAction:ToString() end) or "?"
        if K.SPX.BLOCK[sit] then
            e.blocked[sit] = (e.blocked[sit] or 0) + 1
            local n = e.blocked[sit]
            if n <= 3 or n % 200 == 0 then K.SPX.dlog(string.format("%s: warp '%s' cancelled (#%d, during %s)", e.name, K.SPX.SIT[sit] or tostring(sit), n, act)) end
            st.rr_spx = true
            return sdk.PreHookResult.SKIP_ORIGINAL
        end
        e.sit, e.sit_name = sit, K.SPX.SIT[sit] or tostring(sit)
        e.req[sit] = (e.req[sit] or 0) + 1
        if e.req[sit] <= 6 then K.SPX.dlog(string.format("%s: warp '%s' #%d (during %s)", e.name, e.sit_name, e.req[sit], act)) end
    end, function(retval)
        local st = thread.get_hook_storage()
        if st and st.rr_spx then st.rr_spx = nil; return sdk.to_ptr(0) end
        return retval
    end)
    local function fix_post(why)
        return function(args)
            local st = thread.get_hook_storage(); st.rr_spxf = K.SPX.entry(args)
        end, function(retval)
            local st = thread.get_hook_storage(); local e = st and st.rr_spxf
            if e then st.rr_spxf = nil; pcall(K.SPX.fix, e, why) end
            return retval
        end
    end
    hk("findWarpPosition()", fix_post("findWarpPosition"))
    hk("findWarpPosition(app.Ch253001WarpController.WarpSituationEnum, via.vec3, via.Quaternion)", fix_post("findWarpPosition"))
    hk("updateCandidateWarpPosition()", function(args)
        local st = thread.get_hook_storage(); st.rr_spxc = K.SPX.entry(args)
    end, function(retval)
        local st = thread.get_hook_storage(); local e = st and st.rr_spxc
        if e then st.rr_spxc = nil; pcall(K.SPX.fix_candidates, e); pcall(K.SPX.fix, e, "candidates") end
        return retval
    end)
    local function no_destroy(e, where)
        if not (config.enabled and vortex_now) then return end
        if safe(function() return e.wc:get_field("WarpDestroy") end) == true then
            pcall(function() e.wc:set_field("WarpDestroy", false) end)
            e.nd = (e.nd or 0) + 1
            if e.nd <= 5 then K.SPX.dlog(string.format("%s: her warp was set to delete her (%s) - kept off", e.name, where)) end
        end
    end
    hk("warpStart()", function(args)
        local e = K.SPX.entry(args)
        if e then no_destroy(e, "warp start"); pcall(K.SPX.fix, e, "warpStart") end
    end, nil)
    hk("updateWarp()", function(args)
        local e = K.SPX.entry(args)
        if e then no_destroy(e, "mid-warp") end
    end, nil)
    hk("warpEnd()", function(args)
        local e = K.SPX.entry(args)
        if e then
            no_destroy(e, "warp end")
            e.warps = (e.warps or 0) + 1
            if e.warps <= 30 then
                local pp, up = player_upos(), upos_go(e.t.go)
                K.SPX.dlog(string.format("%s: warp #%d (%s) ended%s", e.name, e.warps, e.sit_name or "?",
                    (pp and up) and string.format(", %.0f m from you", flat_dist(pp, up) or -1) or ""))
            end
            if e.t.go then
                table.insert(deferred, { kind = "keep_hp", go = e.t.go, name = e.name, at = os.clock() + 0.5 })
            end
        end
    end, nil)
    hk("Ch253001QuestController_ChangeQuestRoutineHandler(app.QuestRoutineEnum)", function(args)
        local e = K.SPX.entry(args)
        if not (e and config.enabled and vortex_now) then return end
        e.qr = (e.qr or 0) + 1
        if e.qr <= 5 then K.SPX.dlog(string.format("%s: quest routine change (%d) ignored", e.name, sdk.to_int64(args[3]) & 0xFFFFFFFF)) end
        return sdk.PreHookResult.SKIP_ORIGINAL
    end, nil)
    log(string.format("Sphinx warp controller: %d hooks", K.SPX.hooks or 0))
end
-- v1.9.161: a spot around the arena for a "virtual lair" teleport (Brine Sphinx)
K.LAIR_SPOTS = { last = nil, n = 0 }
function K.lair_spot(h)
    local pp = player_upos()
    local c = arena_center
    if not c or (pp and flat_dist(pp, c) > 80) then c = pp end
    if not c then return nil end
    local best
    for _ = 1, 8 do
        local a = math.random() * 2 * math.pi
        local r = 10 + math.random() * 16
        local ref = pp and pp.y or c.y
        local gx, gz = c.x + math.cos(a) * r, c.z + math.sin(a) * r
        local gy = K.ground_y(gx, gz, ref)   -- v1.9.176: the ground there, not your height
        if not gy or math.abs(gy - ref) > 25 then gy = ref end
        local p = { x = gx, y = gy + (h or 1.5), z = gz }
        best = p
        if not K.LAIR_SPOTS.last or flat_dist(p, K.LAIR_SPOTS.last) > 10 then break end
    end
    K.LAIR_SPOTS.last = best
    return best
end
local last_medusa_tick = 0
local last_petri_tick = 0
local function run_deferred()
    local list = deferred
    deferred = {}
    for _, d in ipairs(list) do
        if d.kind == "recall" then
            local d_far = dist3(pos_of(d.t.go), player_pos())
            local tt = d.t.go and tracked[safe(function() return d.t.go:get_address() end) or 0]
            local ehp = tt and safe(function() return tt.chara:get_Hit():call("get_Hp") end)
            if ehp and ehp <= 1.5 then
                -- v1.9.64: dead Eye body warping off - let it go
            elseif d_far and d_far > 60 then
                -- v1.9.109: the Eye's warp ends with onWarpAppear (it fades back in). Pulling it back before that
                -- left it invisible and warping every ~6 s (17:19-17:22). Give it 1.5 s to appear on its own, then
                -- recall it, and if it still hasn't appeared, run its appear step half a second later.
                local appeared = (K.EYE_APPEAR or {})[d.t.name] or -1
                if appeared < (d.t0 or 0) and os.clock() - (d.t0 or 0) < 1.5 then
                    table.insert(deferred, d)
                else
                    recall_to_arena(d.t.obj, d.t.name, string.format("warp sent it %.0f m away", d_far))
                    if appeared < (d.t0 or 0) and not config.eye_warp_around_you then   -- v1.9.118: forcing froze both bodies
                        table.insert(deferred, { kind = "eye_appear", t = d.t, at = os.clock() + 0.5, t0 = d.t0 or 0 })
                    end
                end
            elseif os.clock() < d.until_t then
                table.insert(deferred, d)   -- teleport not applied yet; check again next frame
            end
        elseif d.kind == "eye_dest" then
            -- v1.9.113: one warp moves the arriving body more than once (17:46:00 and :02); keep it on the same spot
            local p = (K.EYE_SPOTS.last and os.clock() - (K.EYE_SPOTS.last_t or -100) < 6) and K.EYE_SPOTS.last or K.eye_spot()
            K.EYE_SPOTS.last_t = os.clock()
            local ok = false
            if p and TELEPORT_M then
                recalling = true
                ok = pcall(function()
                    local v = ValueType.new(POS_TD)
                    v:set_field("x", p.x); v:set_field("y", p.y); v:set_field("z", p.z)
                    TELEPORT_M:call(d.t.obj, v)
                end)
                recalling = false
            end
            if K.EYE_SPOTS.n <= 30 then
                local pp = player_upos()
                log(string.format("Evil Eye warp #%d (%s): landed on an arena spot%s", K.EYE_SPOTS.n, d.t.name,
                    ok and string.format(", %.0f m from you", (pp and flat_dist(pp, p)) or -1) or " - FAILED (the old pull-back still applies)"))
            end
            pcall(PX.eye_vis_report, "just landed")
            if not ok then
                table.insert(deferred, { kind = "recall", t = d.t, until_t = os.clock() + 4, t0 = os.clock() })
            else
                -- v1.9.113: forcing the appear/end-warp here (v1.9.112) left BOTH bodies visible and frozen - the host was
                -- still mid-warp. Let the game finish the warp itself now that the destination is inside the arena; just report.
                table.insert(deferred, { kind = "eye_watch", at = os.clock() + 3, why = "3 s after landing" })
                table.insert(deferred, { kind = "eye_watch", at = os.clock() + 7, why = "7 s after landing" })
            end
        elseif d.kind == "log" then
            log(d.msg)
        elseif d.kind == "eye_force" then   -- v1.9.170
            if d.at and os.clock() < d.at then table.insert(deferred, d)
            else pcall(K.eye_force_minions, d.t, d.i or 1, d.n or 1) end
        elseif d.kind == "genres" then   -- v1.9.171 dev
            if d.at and os.clock() < d.at then table.insert(deferred, d) else pcall(K.GENRES.dump, d) end
        elseif d.kind == "spx_test" then   -- v1.9.164 dev
            if d.at and os.clock() < d.at then table.insert(deferred, d)
            elseif d.e and d.e.t.go and safe(function() return d.e.t.go:call("get_Valid") end) ~= false then
                local e = d.e
                local pp, up = player_upos(), upos_go(e.t.go)
                local where = (pp and up) and string.format("%.0f m from you", flat_dist(pp, up) or -1) or "?"
                if d.sit then
                    local ok, r = pcall(function() return e.wc:call("requestWarp(app.Ch253001WarpController.WarpSituationEnum)", d.sit) end)
                    log(string.format("DEV TEST %s: requestWarp(%s) -> %s (she is %s, HP %s)", e.name, K.SPX.SIT[d.sit] or tostring(d.sit),
                        ok and tostring(r) or ("error " .. tostring(r)), where, tostring(safe(function() return math.floor(e.t.chara:get_Hit():call("get_Hp")) end))))
                else
                    log(string.format("DEV TEST %s: done - she is %s, warps ended %d, points moved %d, phase %s", e.name, where, e.warps or 0, e.fixed or 0,
                        tostring(safe(function() return e.wc:get_field("WarpPhase") end))))
                end
            end
        elseif d.kind == "tp_check" then
            if d.at and os.clock() < d.at then table.insert(deferred, d)
            else
                local up = d.go and upos_go(d.go)
                K.TP_CHECK = (K.TP_CHECK or 0) + 1
                if K.TP_CHECK <= 20 and up then log(string.format("%s after its warp: %.1f m from the chosen spot", d.name or "?", flat_dist(up, d.p) or -1)) end
            end
        elseif d.kind == "keep_hp" then
            -- v1.9.162: a warp reset her max HP to her own - put the scaled HP back (same fraction left)
            if d.at and os.clock() < d.at then table.insert(deferred, d)
            else
                local tt = d.go and tracked[safe(function() return d.go:get_address() end) or 0]
                local rf = tt and reinforcement_for(tt.name)
                local want = rf and rf.hp_key and tonumber(config[rf.hp_key])
                local hit = tt and safe(function() return tt.chara:get_Hit() end)
                local mx = hit and safe(function() return hit:call("get_OriginalMaxHp") end)
                local hp = hit and safe(function() return hit:call("get_Hp") end)
                if want and mx and hp and hp > 0 and mx < want * 0.9 then
                    local frac = math.max(0.01, math.min(1, hp / mx))
                    pcall(function()
                        hit:call("setRegionOriginalMaxHp(System.Single, System.Int32, System.Boolean)", want, 0, true)
                        hit:call("setReducedMaxHpValue(System.Single)", want)
                        hit:call("setHpValue(System.Single, System.Boolean)", want * frac, false)
                    end)
                    log(string.format("%s: its warp reset its HP to its own (%.0f / %.0f) - back to %.0f / %.0f", d.name or "?", hp, mx, want * frac, want))
                end
            end
        elseif d.kind == "arena_dest" then
            -- v1.9.161: put a no_teleport reinforcement (Brine Sphinx) on an arena spot with its own Teleporter
            if d.at and os.clock() < d.at then table.insert(deferred, d)
            elseif d.obj and TELEPORT_M then
                local p = K.lair_spot(1.5)
                local ok = p and pcall(function()
                    recalling = true
                    local v = ValueType.new(POS_TD)
                    v:set_field("x", p.x); v:set_field("y", p.y); v:set_field("z", p.z)
                    TELEPORT_M:call(d.obj, v)
                end)
                recalling = false
                K.LAIR_SPOTS.n = K.LAIR_SPOTS.n + 1
                if K.LAIR_SPOTS.n <= 40 then
                    local pp = player_upos()
                    log(string.format("%s %s -> arena spot #%d%s", d.name or "?", d.why or "teleport", K.LAIR_SPOTS.n,
                        ok and string.format(", %.0f m from you", (pp and p and flat_dist(pp, p)) or -1) or " - FAILED"))
                end
            end
        elseif d.kind == "eye_watch" then
            if os.clock() < d.at then table.insert(deferred, d) else pcall(PX.eye_vis_report, d.why) end
        elseif d.kind == "eye_appear" then
            if os.clock() < d.at then
                table.insert(deferred, d)
            elseif ((K.EYE_APPEAR or {})[d.t.name] or -1) < d.t0 then
                local ch = d.t.go and safe(function() return d.t.go:call("getComponent(System.Type)", sdk.typeof("app.Ch270")) end)
                local wm = ch and safe(function() return ch:call("get_IsWarpMode") end)
                local ok = ch and pcall(function() ch:call("onWarpAppear") end)
                -- v1.9.112: v1.9.110 showed warp mode still true after the appear step (and the Eye stayed invisible):
                -- finish the warp too, and report what the game thinks of both bodies
                local wm2 = ch and safe(function() return ch:call("get_IsWarpMode") end)
                local ok2 = nil
                if wm2 then ok2 = pcall(function() ch:call("endWarpAction(System.Boolean)", false) end) end
                local wm3 = ch and safe(function() return ch:call("get_IsWarpMode") end)
                K.EYE_FORCED = (K.EYE_FORCED or 0) + 1
                if K.EYE_FORCED <= 20 then
                    log(string.format("Evil Eye %s: had not reappeared after its warp - appear step %s, warp mode %s -> %s%s -> %s",
                        d.t.name, ok and "ok" or "failed", tostring(wm), tostring(wm2),
                        ok2 == nil and "" or (ok2 and ", ended the warp" or ", end-warp failed"), tostring(wm3)))
                end
                pcall(PX.eye_vis_report, "after appear step")
            end
        end
    end
end

-- v1.9.73: raw model spawn for size checks - load the monster's own prefab file
-- (AppSystem/ch/chNNN/Prefab/<id>.pfb) and instantiate it 15 m in front of the player, outside the
-- game's spawn system. It may not move or fight; it is for seeing the monster. Game thread only.
TEST.placed = {}
-- v1.9.78: load a monster's prefab through the game's enemy catalog; returns the via.Prefab once it is
-- ready, nil while loading; r.fail is set on failure. r = { id, t, ... }
function TEST.catalog_ready(r, tag)
    local now = os.clock()
    if not r.pf then
        local gen = sdk.get_managed_singleton("app.GenerateManager")
        local cat = gen and safe(function() return gen:get_field("_CatalogCtrl") end)
        local cid = id_value[r.id]
        local ec = cat and safe(function() return cat:get_field("_EnemyCatalog") end)
        local pc = nil
        if ec then
            local tdi = ec:get_type_definition()
            while tdi and not pc do
                for _, f in ipairs(tdi:get_fields() or {}) do
                    local ftn = safe(function() return f:get_type():get_full_name() end) or ""
                    if not f:is_static() and ftn:find("Dictionary`2", 1, true) then
                        local d = safe(function() return ec:get_field(f:get_name()) end)
                        if d and safe(function() return d:call("ContainsKey", cid) end) == true then
                            pc = safe(function() return d:call("get_Item", cid) end)
                            if pc then break end
                        end
                    end
                end
                tdi = tdi:get_parent_type()
            end
        end
        if pc then
            r.pf = PX.prefab_from_controller(pc)
            if r.pf then
                pcall(function() r.pf:add_ref() end)
                pcall(function() r.pf:call("set_Standby", true) end)
                log_now(tag .. ": " .. r.id .. " found in the enemy catalog (" .. tostring(PX.prefab_path_of(r.pf)) .. ")")
            end
        elseif cat and not r.added then
            r.added = true
            local ok, err = pcall(function() cat:call("addEnemyRefCount", cid) end)
            log_now(tag .. ": asked the enemy catalog to load " .. r.id .. (ok and "" or (" (failed: " .. tostring(err) .. ")")))
            if not ok then r.fail = true end
            return nil
        end
        if not r.pf then
            if now - r.t > 30 then r.fail = true; log_now(tag .. ": the enemy catalog never provided " .. r.id .. " (30 s)") end
            return nil
        end
    end
    if not safe(function() return r.pf:call("get_Ready") end) then
        if now - r.t > 30 then r.fail = true; log_now(tag .. ": " .. r.id .. " never finished loading (30 s)") end
        return nil
    end
    return r.pf
end
function TEST.raw_step()
    local r = TEST.raw
    if not r then return end
    local now = os.clock()
    if not r.pf then
        -- v1.9.74: ask the game's enemy catalog to load the monster (like the pillar's gimmick catalog):
        -- GenerateManager._CatalogCtrl.addEnemyRefCount(id) -> _EnemyCatalog[id] -> PrefabController -> via.Prefab
        local gen = sdk.get_managed_singleton("app.GenerateManager")
        local cat = gen and safe(function() return gen:get_field("_CatalogCtrl") end)
        local cid = id_value[r.id]
        local ec = cat and safe(function() return cat:get_field("_EnemyCatalog") end)
        local pc = nil
        if ec then
            local tdi = ec:get_type_definition()
            while tdi and not pc do
                for _, f in ipairs(tdi:get_fields() or {}) do
                    local ftn = safe(function() return f:get_type():get_full_name() end) or ""
                    if not f:is_static() and ftn:find("Dictionary`2", 1, true) then
                        local d = safe(function() return ec:get_field(f:get_name()) end)
                        if d and safe(function() return d:call("ContainsKey", cid) end) == true then
                            pc = safe(function() return d:call("get_Item", cid) end)
                            if pc then break end
                        end
                    end
                end
                tdi = tdi:get_parent_type()
            end
        end
        if pc then
            r.pf = PX.prefab_from_controller(pc)
            if r.pf then
                pcall(function() r.pf:add_ref() end)
                pcall(function() r.pf:call("set_Standby", true) end)
                log_now("Size check: got " .. tostring(PX.prefab_path_of(r.pf)) .. " from the enemy catalog")
            end
        elseif cat and not r.added then
            r.added = true
            local ok, err = pcall(function() cat:call("addEnemyRefCount", cid) end)
            log_now("Size check: asked the enemy catalog to load " .. r.id .. (ok and "" or (" (failed: " .. tostring(err) .. ")")))
            if not ok then TEST.raw = nil end
            return
        end
        if not r.pf then
            if now - r.t > 30 then
                TEST.raw = nil
                log_now("Size check: the enemy catalog never provided " .. r.id .. " (30 s) - it may only load in its own area")
            end
            return
        end
    end
    if not safe(function() return r.pf:call("get_Ready") end) then
        if now - r.t > 30 then
            TEST.raw = nil
            log_now("Size check: " .. r.id .. " never finished loading (30 s) - it may only load in its own area")
        end
        return
    end
    TEST.raw = nil
    local cm = sdk.get_managed_singleton("app.CharacterManager")
    local tr = cm and safe(function() return cm["<ManualPlayer>k__BackingField"]:get_Transform() end)
    local lp = tr and safe(function() return tr:call("get_Position") end)
    local fw = tr and safe(function() return tr:call("get_AxisZ") end)
    if not lp then log_now("Size check: no player position"); return end
    local fx, fz = fw and fw.x or 0, fw and fw.z or 1
    local fl = math.sqrt(fx * fx + fz * fz); if fl < 0.01 then fx, fz, fl = 0, 1, 1 end
    local lx, ly, lz = vfield(lp, "x") + fx / fl * 15, vfield(lp, "y"), vfield(lp, "z") + fz / fl * 15
    local ok, go = pcall(function()
        local v = ValueType.new(sdk.find_type_definition("via.vec3"))
        v:set_field("x", lx); v:set_field("y", ly); v:set_field("z", lz)
        return r.pf:call("instantiate(via.vec3)", v)
    end)
    if not ok or not go then log_now("Size check: placing " .. r.id .. " failed: " .. tostring(go)); return end
    pcall(function() go:add_ref() end)
    table.insert(TEST.placed, { go = go, id = r.id })
    local n = safe(function() return go:call("get_Name") end)
    log_now(string.format("Size check: placed %s (%s) 15 m in front of you", r.id, tostring(n)))
end
function TEST.remove_step()
    if not TEST.remove_req then return end
    TEST.remove_req = nil
    for _, p in ipairs(TEST.placed) do
        local ok = pcall(function() p.go:call("destroy(via.GameObject)", p.go) end)
        log_now("Size check: removed " .. p.id .. (ok and "" or " (failed)"))
    end
    TEST.placed = {}
end
-- v1.9.77: "Evil Eye method" - the Evil Eye makes its second body with
-- GenerateManager.forceRequestCreateInstance(GenerateInfoContainer, cb, cb). We borrow the spawn record
-- (GenerateInfoContainer) of a real monster near the player, point it at the chosen ID, ask the game to
-- create one more instance from it, and put the record back once the new monster has appeared.
TEST.RESEARCH_FILE = "RancorReinforcements_spawn_research.txt"
function TEST.find_container(obj, depth, seen)
    if not obj or depth > 2 then return nil end
    seen = seen or {}
    local a = safe(function() return obj:get_address() end)
    if not a or seen[a] then return nil end
    seen[a] = true
    local tdi = safe(function() return obj:get_type_definition() end)
    while tdi do
        for _, f in ipairs(tdi:get_fields() or {}) do
            local ftn = safe(function() return f:get_type():get_full_name() end) or ""
            if not f:is_static() and ftn:find("GenerateInfoContainer", 1, true) and not ftn:find("[]", 1, true)
                and not ftn:find("List", 1, true) and not ftn:find("Dictionary", 1, true) then
                local v = safe(function() return obj:get_field(f:get_name()) end)
                if v then return v, f:get_name() end
            end
        end
        tdi = tdi:get_parent_type()
    end
    return nil
end
function TEST.dump(obj, label, out, depth)
    depth = depth or 0
    if not obj or depth > 2 then return end
    local tdi = safe(function() return obj:get_type_definition() end)
    table.insert(out, string.rep("  ", depth) .. label .. " : " .. tostring(tdi and tdi:get_full_name()))
    while tdi do
        for _, f in ipairs(tdi:get_fields() or {}) do
            if not f:is_static() then
                local ftn = safe(function() return f:get_type():get_full_name() end) or "?"
                local v = safe(function() return obj:get_field(f:get_name()) end)
                local vs
                if type(v) == "number" or type(v) == "boolean" or type(v) == "string" then vs = tostring(v)
                elseif v == nil then vs = "nil" else vs = "<" .. ftn .. ">" end
                table.insert(out, string.rep("  ", depth + 1) .. f:get_name() .. " : " .. ftn .. " = " .. vs)
                if type(v) == "userdata" and depth < 2 and not ftn:find("[]", 1, true) and not ftn:find("Dictionary", 1, true)
                    and not ftn:find("List", 1, true) and (ftn:find("^app%.") or ftn:find("Info")) then
                    TEST.dump(v, f:get_name(), out, depth + 2)
                end
            end
        end
        tdi = tdi:get_parent_type()
    end
end
function TEST.evil_step()
    local r = TEST.evil
    if not r then return end
    -- v1.9.78: the monster's model must be loaded first (the Evil Eye only ever re-creates itself,
    -- whose model is already loaded; a not-loaded Griffin returned -1)
    if not TEST.catalog_ready(r, "Evil Eye method") then
        if r.fail then TEST.evil = nil end
        return
    end
    TEST.evil = nil
    local pp = player_upos()
    local best, bestd, bname
    for _, m in ipairs(find_components("app.Monster")) do
        local go = safe(function() return m:call("get_GameObject") end)
        local name = go and safe(function() return go:call("get_Name") end)
        if name and name:match("^ch2%d%d") and not reinforcement_for(name)
            and name:sub(1, #SATANICA.prefix) ~= SATANICA.prefix and name:sub(1, #r.id) ~= r.id then
            local up = upos_go(go)
            local d = up and pp and flat_dist(up, pp)
            if d and (not bestd or d < bestd) then best, bestd, bname = go, d, name end
        end
    end
    if not best then log_now("Evil Eye method: no monster near you to borrow a spawn record from - go where monsters are"); return end
    local gi = safe(function() return best:call("getComponent(System.Type)", sdk.typeof("app.GenerateInfo")) end)
    local cont, fname = TEST.find_container(gi, 0)
    if not cont then
        local chara = safe(function() return best:call("getComponent(System.Type)", sdk.typeof("app.Character")) end)
        cont, fname = TEST.find_container(chara, 0)
    end
    local out = { "Spawn research " .. os.date("%H:%M:%S") .. ": donor " .. bname .. string.format(" (%.0f m away)", bestd or -1) ..
        ", GenerateInfo component " .. tostring(gi ~= nil) .. ", container field " .. tostring(fname) }
    if gi then TEST.dump(gi, "app.GenerateInfo", out) end
    if cont then TEST.dump(cont, "container", out) end
    pcall(fs.write, TEST.RESEARCH_FILE, table.concat(out, "\n"))
    if not cont then log_now("Evil Eye method: " .. bname .. " has no spawn record I can find (written to data/" .. TEST.RESEARCH_FILE .. ")"); return end
    local orig = safe(function() return cont._CommonInfo._ObjectID._SelectedCharacterID end)
    -- v1.9.79: restore to the donor's real ID (from its object name) - a script reset mid-attempt
    -- once left a lizard's record pointing at the Griffin, and the record itself was then "restored" to that
    local real = bname:match("^(ch%d%d%d%d%d%d_%d%d)")
    if real and id_value[real] then orig = id_value[real] end
    if not orig then log_now("Evil Eye method: the spawn record has no character ID field (see data/" .. TEST.RESEARCH_FILE .. ")"); return end
    local gm = sdk.get_managed_singleton("app.GenerateManager")
    local fm = nil
    for _, m in ipairs(sdk.find_type_definition("app.GenerateManager"):get_methods()) do
        if m:get_name() == "forceRequestCreateInstance" and m:get_num_params() == 3 then fm = m end
    end
    if not gm or not fm then log_now("Evil Eye method: forceRequestCreateInstance not found"); return end
    local known = {}
    for _, m in ipairs(find_components("app.Monster")) do
        local go = safe(function() return m:call("get_GameObject") end)
        if go then known[go:get_address()] = true end
    end
    pcall(function() cont:add_ref() end)
    local okset = pcall(function() cont._CommonInfo._ObjectID._SelectedCharacterID = id_value[r.id] end)
    log_now(string.format("Evil Eye method: borrowing %s's spawn record (field %s), set to %s: %s", bname, tostring(fname), r.id, okset and "ok" or "failed"))
    if not okset then return end
    TEST.own_call = true
    local ok, ret = pcall(function() return fm:call(gm, cont, nil, nil) end)
    TEST.own_call = false
    log_now("Evil Eye method: forceRequestCreateInstance -> " .. (ok and ("ok, returned " .. tostring(ret)) or ("error " .. tostring(ret))) ..
        ((ok and ret == -1) and " (-1 = the game refused)" or ""))
    table.insert(pending_reverts, { info = cont, addr = cont:get_address(), original = orig, pick = r.id, at = os.clock(), hold = 45 })
    if ok then TEST.waiting = { id = r.id, t = os.clock(), known = known, last = 0 } end
end

-- v1.9.79: repair spawn records left pointing at a test ID (records whose ID does not match the
-- monster that owns them, for monsters this mod did not spawn); runs once after load and on demand
function TEST.repair_records()
    local fixed = 0
    for _, m in ipairs(find_components("app.Monster")) do
        local go = safe(function() return m:call("get_GameObject") end)
        local name = go and safe(function() return go:call("get_Name") end)
        local real = name and name:match("^(ch%d%d%d%d%d%d_%d%d)")
        if real and id_value[real] and not reinforcement_for(name) and not name:find("^ch27") then
            local gi = safe(function() return go:call("getComponent(System.Type)", sdk.typeof("app.GenerateInfo")) end)
            local cont = gi and safe(function() return gi:get_field("_Container") end)
            local cur = cont and safe(function() return cont._CommonInfo._ObjectID._SelectedCharacterID end)
            local cur_name = cur and id_name[cur]
            if cur_name and cur_name ~= real and cur_name:match("^ch2[56]") then
                local ok = pcall(function() cont._CommonInfo._ObjectID._SelectedCharacterID = id_value[real] end)
                fixed = fixed + 1
                log_now(string.format("Repair: %s's spawn record said %s - set back to %s%s", name, cur_name, real, ok and "" or " (failed)"))
            end
        end
    end
    log_now("Repair: checked spawn records near you, fixed " .. fixed)
end
TEST.repair_at = os.clock() + 15
TEST.own_call = false

if re.on_application_entry then
    pcall(re.on_application_entry, "UpdateBehavior", function()
        if TEST.repair_at and os.clock() > TEST.repair_at then TEST.repair_at = nil; pcall(TEST.repair_records) end
        if TEST.evil then local ok, err = pcall(TEST.evil_step); if not ok then TEST.evil = nil; log_now("Evil Eye method error: " .. tostring(err)) end end
        if TEST.raw then local ok, err = pcall(TEST.raw_step); if not ok then TEST.raw = nil; log_now("Size check error: " .. tostring(err)) end end
        if TEST.remove_req then pcall(TEST.remove_step) end
    end)
end

-- v1.9.85: Gimmick finder - list every GimmickID (name = number) to a file, and place any gimmick
-- in front of the player through the game's gimmick catalog (the same way the Medusa pillar, gimmick
-- 235 / gm81_098, is placed). Used to look for the Purgener's own, bigger pillar.
local GF = { id_text = "", placed = {}, req = nil, remove_req = false, names = nil }
GF.FILE = "RancorReinforcements_gimmick_ids.txt"
function GF.dump()
    local td = sdk.find_type_definition("app.GimmickID")
    if not td then log("Gimmick finder: app.GimmickID not found"); return end
    local rows, n81 = {}, 0
    GF.names = {}
    for _, f in ipairs(td:get_fields() or {}) do
        if f:is_static() then
            local v = safe(function() return f:get_data(nil) end)
            if type(v) == "number" then
                local nm = f:get_name()
                GF.names[nm] = v
                table.insert(rows, { v = v, n = nm })
                if nm:lower():find("gm81") then n81 = n81 + 1 end
            end
        end
    end
    table.sort(rows, function(a, b) return a.v < b.v end)
    local out = { "app.GimmickID - " .. #rows .. " entries (" .. os.date("%H:%M:%S") .. ")" }
    for _, r in ipairs(rows) do table.insert(out, string.format("%6d  %s", r.v, r.n)) end
    pcall(fs.write, GF.FILE, table.concat(out, "\n"))
    log(string.format("Gimmick finder: %d gimmick IDs written to data/%s (%d mention gm81)", #rows, GF.FILE, n81))
end
function GF.step()   -- game thread
    if GF.remove_req then
        GF.remove_req = false
        for _, p in ipairs(GF.placed) do
            local ok = pcall(function() p.go:call("destroy(via.GameObject)", p.go) end)
            log_now("Gimmick finder: removed gimmick " .. p.id .. (ok and "" or " (failed)"))
        end
        GF.placed = {}
    end
    local r = GF.req
    if not r then return end
    local now = os.clock()
    local gen = sdk.get_managed_singleton("app.GenerateManager")
    local cat = gen and safe(function() return gen:get_field("_CatalogCtrl") end)
    if not cat then GF.req = nil; log_now("Gimmick finder: no spawn catalog"); return end
    if not r.pf then
        local pc = PX.catalog_lookup(cat, r.id)
        if not pc then
            if not r.added then
                r.added = true
                local ok, err = pcall(function() cat:call("addGimmickRefCount", r.id) end)
                log_now("Gimmick finder: asked the catalog to load gimmick " .. r.id .. (ok and "" or (" (failed: " .. tostring(err) .. ")")))
                if not ok then GF.req = nil end
            elseif now - r.t > 30 then
                GF.req = nil
                log_now("Gimmick finder: gimmick " .. r.id .. " never showed up in the catalog (30 s) - it may only load in its own area")
            end
            return
        end
        r.pf = PX.prefab_from_controller(pc)
        if not r.pf then GF.req = nil; log_now("Gimmick finder: gimmick " .. r.id .. " has no prefab"); return end
        pcall(function() r.pf:add_ref() end)
        pcall(function() r.pf:call("set_Standby", true) end)
        log_now("Gimmick finder: gimmick " .. r.id .. " = " .. tostring(PX.prefab_path_of(r.pf)))
    end
    if not safe(function() return r.pf:call("get_Ready") end) then
        if now - r.t > 30 then GF.req = nil; log_now("Gimmick finder: gimmick " .. r.id .. " never finished loading") end
        return
    end
    GF.req = nil
    local cm = sdk.get_managed_singleton("app.CharacterManager")
    local tr = cm and safe(function() return cm["<ManualPlayer>k__BackingField"]:get_Transform() end)
    local lp = tr and safe(function() return tr:call("get_Position") end)
    local fw = tr and safe(function() return tr:call("get_AxisZ") end)
    if not lp then log_now("Gimmick finder: no player position"); return end
    local fx, fz = fw and fw.x or 0, fw and fw.z or 1
    local fl = math.sqrt(fx * fx + fz * fz); if fl < 0.01 then fx, fz, fl = 0, 1, 1 end
    local dist = r.dist or 15
    local ok, go = pcall(function()
        local v = ValueType.new(sdk.find_type_definition("via.vec3"))
        v:set_field("x", vfield(lp, "x") + fx / fl * dist); v:set_field("y", vfield(lp, "y")); v:set_field("z", vfield(lp, "z") + fz / fl * dist)
        return r.pf:call("instantiate(via.vec3)", v)
    end)
    if not ok or not go then log_now("Gimmick finder: placing gimmick " .. r.id .. " failed: " .. tostring(go)); return end
    pcall(function() go:add_ref() end)
    table.insert(GF.placed, { go = go, id = r.id })
    local names = {}
    local arr = safe(function() return go:call("get_Components") end)
    for _, c in ipairs(arr and (safe(function() return arr:get_elements() end) or {}) or {}) do
        table.insert(names, safe(function() return c:get_type_definition():get_name() end) or "?")
    end
    local climb = table.concat(names, ","):find("Gm81_097", 1, true) and " - CLIMBABLE (has the pillar climb component)" or ""
    log_now(string.format("Gimmick finder: placed gimmick %s (%s) %d m in front of you%s [%s]", r.id,
        tostring(safe(function() return go:call("get_Name") end)), dist, climb, table.concat(names, ", ")))
end
if re.on_application_entry then
    pcall(re.on_application_entry, "UpdateBehavior", function()
        if GF.req or GF.remove_req then
            local ok, err = pcall(GF.step)
            if not ok then GF.req = nil; log_now("Gimmick finder error: " .. tostring(err)) end
        end
    end)
end
if not K.RELEASE then pcall(GF.dump) end   -- once at load, so the list is on disk right away (v1.9.184: dev build only)
function GF.ui()
    if K.RELEASE then return end
    if not imgui.tree_node("Gimmick finder (look for the Purgener's pillar)") then return end
    if imgui.button("List every gimmick ID to a file") then pcall(GF.dump) end
    local ch
    ch, GF.id_text = imgui.input_text("Gimmick ID (number or name)", GF.id_text)
    local t = (GF.id_text or ""):gsub("%s", "")
    local id = tonumber(t)
    if not id and t ~= "" then
        if not GF.names then pcall(GF.dump) end
        id = GF.names and (GF.names[t] or GF.names[t:upper()] or GF.names[t:lower()])
    end
    if imgui.button("Place gimmick " .. tostring(id or "?") .. " 15 m in front of me") then
        if id then GF.req = { id = id, t = os.clock(), dist = 15 }; log("Gimmick finder: requested gimmick " .. id)
        else log("Gimmick finder: unknown gimmick '" .. t .. "'") end
    end
    if #GF.placed > 0 then
        imgui.same_line()
        if imgui.button("Remove placed gimmicks (" .. #GF.placed .. ")") then GF.remove_req = true end
    end
    imgui.text("  The Medusa pillar is gimmick 235 (gm81_098). Save first: an unknown gimmick may crash the game.")
    imgui.tree_pop()
end

-- v1.9.80: Purgener watcher. Purgeners are Medusa / Griffin-family bosses (Sacred Arbor ch255010,
-- Volcanic Island ch255011, Vermund ch253010, Island Encampment ch253011, Battahl ch240000). Any one
-- that appears (e.g. from Enemy Spawner) is logged: AI table, action pack, action, target, HP, big
-- jumps, its climbable-gimmick searches and escape/teleport calls. The Medusa-family ones also get
-- the climbable pillar placed next to them, and a failed climb search is pointed at that pillar.
local PURG = { list = {}, by_module = {}, last = 0, lines = 0,
    names = { ch255010 = "Sacred Arbor Purgener", ch255011 = "Volcanic Island Purgener", ch253010 = "Vermund Purgener",
              ch253011 = "Island Encampment Purgener", ch240000 = "Battahl Purgener" } }
function PURG.log(msg)
    PURG.lines = PURG.lines + 1
    if PURG.lines <= 600 then log(msg) elseif PURG.lines == 601 then log("Purgener watch: log cap reached") end
end
function PURG.pillar()
    local ps = PX.pillar_state and PX.pillar_state()
    return ps
end
-- v1.9.83: battle spots around the Purgener's pillar (the Medusa spot system answers its searches
-- from these): 8 battle spots at 12 m, 4 wait spots at 7 m, 4 far spots at 16 m
function PURG.build_spots(c)
    local function ring(count, r, phase)
        local out = {}
        for i = 0, count - 1 do
            local a = phase + i * 2 * math.pi / count
            table.insert(out, { x = c.x + math.cos(a) * r, y = c.y, z = c.z + math.sin(a) * r })
        end
        return out
    end
    lair = { center = { x = c.x, y = c.y, z = c.z }, radius = 18, battle = ring(8, 12, 0), wait = ring(4, 7, math.pi / 4),
             beam = ring(4, 16, math.pi / 8), built = os.clock(), how = "Purgener pillar", snapped = 0, samples = 0, purgener = true }
    PURG.log(string.format("Purgener: 16 battle spots placed around the pillar (7-16 m out), center (%.0f, %.0f, %.0f)", c.x, c.y, c.z))
end
-- v1.9.143: the Purgener's pillar attempt. Its main table checks pillar-wrap / pillar-climb rows all fight and
-- their unique-flag condition never passes in the Rancor arena (01:50 fight: ~200 failed checks, 0 pillar actions).
-- Like Medusa's coil row: on an interval one attempt is started - the failing pillar row is passed by the mod and
-- its next battle position is set beside the pillar; while the attempt runs (25 s) every pillar row may pass, so
-- the wrap chain can continue. The attempt's outcome is logged (process_study watches for a climb action).
PILLAR_AI.purg_try = function(e, lbl)
    if not config.purgener_pillar then return false end
    local j = tostring(lbl and lbl.jump or "")
    if not (j:find("柱", 1, true) and (j:find("巻", 1, true) or j:find("登", 1, true))) then return false end
    local ps = PURG.pillar()
    local pgo = ps and ps.state == "spawned" and ps.go
    local pp = pgo and upos_go(pgo)
    if not pp then return false end
    local now = os.clock()
    local pl = e.purg_pillar
    if pl and not pl.done and now - pl.t <= 25 then return true end   -- attempt running: let the pillar rows pass
    if now - (ps.t or now) < 12 then return false end                 -- let the climb-point fix settle first
    if now - (PILLAR_AI.purg_last or -1000) < (tonumber(config.purgener_pillar_interval) or 90) then return false end
    local here = upos_go(e.go)
    if not here then return false end
    local dx, dz = here.x - pp.x, here.z - pp.z
    local d = math.sqrt(dx * dx + dz * dz)
    if d < 0.5 then dx, dz, d = 1, 0, 1 end
    local start = { x = pp.x + dx / d * 4.0, y = pp.y, z = pp.z + dz / d * 4.0 }
    PILLAR_AI.purg_last = now
    e.purg_pillar = { t = now, n = ((pl and pl.n) or 0) + 1 }
    local ctrl = m_wpctrl(e.chara)
    if ctrl then
        write_pos_field(ctrl, "<LastFoundedBattlePosition>k__BackingField", start)
        write_pos_field(ctrl, "<NextPatrolPos>k__BackingField", start)
        write_nullable_pos_field(ctrl, "<CachedLastFoundedBattlePosition>k__BackingField", start)
        write_nullable_pos_field(ctrl, "<CachedNextPatrolPos>k__BackingField", start)
    end
    log(string.format("Purgener pillar attempt #%d: its pillar row passed by the mod (%.0f m from the pillar)", e.purg_pillar.n, d))
    return true
end
-- pillar spot for route-8 searches / checks; check_only = "is it standing there?"
rr_purg_spot = function(e, flag, check_only)
    local ps = PURG.pillar()
    local pp = ps and ps.state == "spawned" and ps.go and upos_go(ps.go)
    if not pp then return check_only and false or nil end
    local here = upos_go(e.go)
    if check_only then return (here and flat_dist(here, pp) or 99) < 8 end
    local dx, dz = (here and here.x or pp.x + 1) - pp.x, (here and here.z or pp.z) - pp.z
    local d = math.sqrt(dx * dx + dz * dz)
    if d < 0.5 then dx, dz, d = 1, 0, 1 end
    return { x = pp.x + dx / d * 4.5, y = pp.y, z = pp.z + dz / d * 4.5 }
end
function PURG.tick()
    local now = os.clock()
    if now - PURG.last < 1.0 then return end
    PURG.last = now
    -- v1.9.156: release build only looks after its own Purgeners: no Rancor and none tracked -> no monster scan
    if K.RELEASE and not vortex_now and not next(PURG.list) and not (K.TRACKED and next(K.TRACKED)) then return end
    local present = {}
    for _, m in ipairs(find_components("app.Monster")) do
        local go = safe(function() return m:call("get_GameObject") end)
        local name = go and safe(function() return go:call("get_Name") end)
        local fam = name and name:match("^(ch%d%d%d%d%d%d)_")
        -- v1.9.81: only living Purgeners near you (corpses / parked ones are left alone)
        -- v1.9.120 release: only the mod's own Purgeners (world ones are left completely alone)
        if not K.RELEASE and name and name:sub(1, 8) == "ch261001" and not K.SATAN_DONE then pcall(K.satan_oracle, go, name) end   -- v1.9.146
        if fam and K.RELEASE and not PURG.list[go:get_address()] and not (K.TRACKED and K.TRACKED[go:get_address()]) then fam = nil end
        if fam and PURG.names[fam] and not PURG.list[go:get_address()] then
            local chara0 = safe(function() return go:call("getComponent(System.Type)", sdk.typeof("app.Character")) end)
            local hp0 = chara0 and safe(function() return chara0:get_Hit():call("get_Hp") end)
            local d0 = dist3(pos_of(go), player_pos())
            if not (type(hp0) == "number" and hp0 > 0 and d0 and d0 < 300) then fam = nil end
        end
        if fam and PURG.names[fam] then
            local addr = go:get_address()
            present[addr] = true
            local e = PURG.list[addr]
            if not e then
                local chara = safe(function() return go:call("getComponent(System.Type)", sdk.typeof("app.Character")) end)
                e = { go = go, chara = chara, name = name, label = PURG.names[fam], fam = fam, started = now, next_log = 0, purgener = true }
                PURG.list[addr] = e
                pcall(function() go:add_ref() end)
                pcall(track_subobjects, go, chara, name)
                local mod = addr_of(m_module(chara))
                if mod then PURG.by_module[mod] = e end
                local hp = safe(function() return chara:get_Hit():call("get_Hp") end)
                -- its Medusa-family component, found once here (not inside a game hook)
                local arr = safe(function() return go:call("get_Components") end)
                for _, c in ipairs(arr and (safe(function() return arr:get_elements() end) or {}) or {}) do
                    local tn = safe(function() return c:get_type_definition():get_full_name() end) or ""
                    if tn:match("^app%.Ch2%d%d0%d%d$") then e.comp = c end
                end
                PURG.log(string.format("PURGENER seen: %s (%s), HP %s, %.0f m from you", e.label, name, tostring(hp), dist3(pos_of(go), player_pos()) or -1))
                if config.purgener_study and chara and not study[addr] then
                    -- v1.9.82: the world-Medusa study (log only) also follows Purgeners: every think-row
                    -- check, its conditions, route / battle-spot searches and unique flags
                    study[addr] = { go = go, chara = chara, name = name, started = now, next_log = 0, purgener = true }
                    PURG.log("STUDY: following the " .. e.label .. "'s AI decisions (log only, changes nothing)")
                elseif config.purgener_pillar and chara and not study[addr] and K.TRACKED and K.TRACKED[addr] then
                    -- v1.9.143: the pillar fix needs its think rows followed even with the study logging off
                    -- (the release build): a quiet entry - no funnel log, no STUDY lines, just the pillar rows
                    study[addr] = { go = go, chara = chara, name = name, started = now, next_log = 0, purgener = true, quiet = true }
                end
                local ps = PURG.pillar()
                if config.purgener_pillar and fam:find("^ch255") and ps and ps.state ~= "spawned" and ps.state ~= "pf_loading" then
                    local up, pp = upos_go(go), player_upos()
                    if DEVOUR.active and vortex_now and arena_center then
                        -- v1.9.83: Devouring final boss - its pillar goes at the arena center
                        PX.spawn_prefab_at(arena_center.x, arena_center.y, arena_center.z, "purgener", tonumber(config.purgener_pillar_gid) or 408)
                        PURG.log("Purgener pillar: Devouring Rancor - placing the climbable pillar at the arena center")
                        up = nil
                    end
                    if up and pp then
                        local dx, dz = pp.x - up.x, pp.z - up.z
                        local d = math.sqrt(dx * dx + dz * dz)
                        if d < 0.5 then dx, dz, d = 1, 0, 1 end
                        local k = math.min(12, d * 0.5) / d
                        PURG.pillar_for = addr
                        PX.spawn_prefab_at(up.x + dx * k, pp.y, up.z + dz * k, "purgener", tonumber(config.purgener_pillar_gid) or 408)
                        PURG.log(string.format("Purgener pillar: placing the climbable pillar %.0f m from the %s (toward you)", math.min(12, d * 0.5), e.label))
                    end
                end
            end
            -- v1.9.83: Medusa spot system answers its searches (keys refreshed each second)
            local kc, km = addr_of(m_wpctrl(e.chara)), addr_of(m_module(e.chara))
            local tco = safe(function() return m_module(e.chara)._TargetCtrl end)
            local kt = addr_of(tco)
            if kc then medusa_by_ctrl[kc] = e end
            if km then medusa_by_module[km] = e end
            if kt then medusa_by_tc[kt] = e end
            e.mkeys = { kc, km, kt }
            -- v1.9.84: far-target guard - a "move to point" target (type 25) more than 60 m away is junk;
            -- the next time the game picks it, it is redirected to the player/party (Medusa's guard)
            local tt = tco and safe(function() return tco._TargetType end)
            local td0 = tco and safe(function() return tco._DistanceFromSelf end)
            local far = tt == 25 and type(td0) == "number" and td0 > 60
            if far and not e.fp_bad then
                e.fp_bad = true
                PURG.log(string.format("Purgener: its move-to-point target is %.0f m away (off the stage) - sending it at the party instead", td0))
            elseif not far and e.fp_bad and tt == 25 then
                e.fp_bad = false
            end
            local ps0 = PURG.pillar()
            local pp0 = ps0 and ps0.tag == "purgener" and ps0.state == "spawned" and ps0.go and upos_go(ps0.go)
            if pp0 and not (lair and lair.purgener and flat_dist(lair.center, pp0) < 1) then PURG.build_spots(pp0) end
            local pos = pos_of(go)
            if e.last_pos and pos then
                local j = dist3(pos, e.last_pos)
                if j and j > 20 then PURG.log(string.format("Purgener JUMP: %s moved %.0f m in 1 s (now %.0f m from you)", e.name, j, dist3(pos, player_pos()) or -1)) end
            end
            e.last_pos = pos
            local act = safe(function() return e.chara["<ActionManager>k__BackingField"].CurrentAction:ToString() end)
            if act and act ~= e.last_act then
                e.last_act = act
                local hp = safe(function() return e.chara:get_Hit():call("get_Hp") end)
                PURG.log(string.format("Purgener action: %s (HP %s)", act, hp and string.format("%.0f", hp) or "?"))
            end
            local hpn = safe(function() return e.chara:get_Hit():call("get_Hp") end)
            if not hpn or hpn <= 0 then present[addr] = nil end   -- dead: stop watching it
            if hpn and hpn > 0 and now >= e.next_log then
                e.next_log = now + ((now - e.started) < 30 and 5 or 15)
                local ok, st = pcall(medusa_state, e)
                local ps = PURG.pillar()
                local pd = ps and ps.go and upos_go(ps.go) and flat_dist(upos_go(go), upos_go(ps.go))
                PURG.log(string.format("Purgener +%.0fs: %s%s", now - e.started, ok and st or ("state error " .. tostring(st)),
                    pd and string.format(" | pillar %.0f m away", pd) or ""))
            end
        end
    end
    for addr, e in pairs(PURG.list) do
        if not present[addr] then
            PURG.log("PURGENER gone: " .. e.name .. " (last action " .. tostring(e.last_act) .. ")")
            for _, k in ipairs(e.mkeys or {}) do medusa_by_ctrl[k] = nil; medusa_by_module[k] = nil; medusa_by_tc[k] = nil end
            if lair and lair.purgener then lair = nil end
            for k, v in pairs(PURG.by_module) do if v == e then PURG.by_module[k] = nil end end
            PURG.list[addr] = nil
            local ps = PURG.pillar()
            if ps and ps.tag == "purgener" and ps.state == "spawned" and not next(PURG.list) then
                PURG.log("Purgener pillar: no Purgener left - removing it")
                pcall(PX.remove_pillar)
            end
        end
    end
end
-- v1.9.91: Dragon research (for breath head-tracking like Medusa's gaze): any ch258000 monster -> its size,
-- head/neck/jaw joints once, every action change (breath actions), HP + target every 10 s. Log only.
PURG.drg = {}
rr_dragons = function() return PURG.drg end
-- v1.9.94: Enemy Spawner spawns go through GenerateManager.requestCreateInstance(PrefabController, container, ...).
-- Put the Dragon boss size on that record (same field the Rancor swap uses), before the prefab is created.
PURG.drg_rf = function()
    for _, r in ipairs(REINFORCEMENTS) do if r.key == "dragon" then return r end end
end
do
    local td = sdk.find_type_definition("app.GenerateManager")
    for _, m in ipairs(td and td:get_methods() or {}) do
        local pt = m:get_name() == "requestCreateInstance" and m:get_num_params() == 6 and safe(function() return m:get_param_types() end)
        if pt and pt[1]:get_full_name() == "app.PrefabController" and not pt[2]:is_value_type() then
            pcall(sdk.hook, m, function(args)
                if not (config.enabled and config.dragon_spawner_stats) then return end
                local cont = safe(function() return sdk.to_managed_object(args[4]) end)
                local cid = cont and safe(function() return cont._CommonInfo._ObjectID._SelectedCharacterID end)
                local cname = cid and id_name[cid]
                if not (cname and cname:sub(1, 8) == "ch258000") then return end   -- v1.9.97: all Dragon variants
                local sc = tonumber(config.dragon_scale) or 1.0
                local old = safe(function() return cont._StatusInfo["<ScaleRate>k__BackingField"] end)
                local ok = pcall(function() cont._StatusInfo["<ScaleRate>k__BackingField"] = sc end)
                log(string.format("Spawner Dragon %s: size ScaleRate %s -> %.2f%s", cname, tostring(old), sc, ok and "" or " (could not set)"))
            end, function(retval) return retval end)
            -- v1.9.146: the dead Eye's summon flush goes through this method - skip orphan Eye-family spawns
            pcall(sdk.hook, m, function(args)
                if not config.enabled then return end
                local cont = safe(function() return sdk.to_managed_object(args[4]) end)
                local cid = cont and safe(function() return cont._CommonInfo._ObjectID._SelectedCharacterID end)
                local cname = cid and id_name[cid]
                local okO3, isO3 = pcall(K.eye_orphan, cname)
                if cname and okO3 and isO3 then
                    K.ORPHANS = (K.ORPHANS or 0) + 1
                    if K.ORPHANS <= 12 then log("Evil Eye is gone - its summon's spawn (" .. cname .. ") skipped") end
                    return sdk.PreHookResult.SKIP_ORIGINAL
                end
            end, function(retval) return retval end)
            log("Spawner Dragon hook on " .. m:get_name() .. " (" .. pt[1]:get_full_name() .. ", ...)")
        end
    end
end
-- v1.9.97: Dragon variant move catalog (actions + passing AI think rows per variant)
-- -> data/RancorReinforcements_dragon_moves.txt, so the variants' movesets can be compared.
PURG.drg_tctrl = {}
PURG.moves = {}
PURG.MOVES_FILE = "RancorReinforcements_moves.txt"   -- v1.9.124: Dragons, Gaganas and Griffins
function PURG.moves_seen(d)
    local adm = d.chara and safe(function() return d.chara["<AIDecisionMaker>k__BackingField"] end)
    local init = adm and safe(function() return adm._ThinkTableInitSetting end)
    local td = init and safe(function() return init._InitThinkTableData end)
    d.think_path = td and safe(function() return td:call("ToString()") end)
    local v = PURG.moves[d.variant] or { acts = {}, rows = {}, n_acts = 0, n_rows = 0, fights = 0 }
    PURG.moves[d.variant] = v
    v.fights = v.fights + 1
    v.think = d.think_path or v.think
    PURG.moves_dirty = true
end
function PURG.moves_add(d, kind, key)
    local v = PURG.moves[d.variant]
    if not v then return end
    local t = v[kind]
    if not t[key] then
        t[key] = 0
        if kind == "acts" then v.n_acts = v.n_acts + 1 else v.n_rows = v.n_rows + 1 end
        log(string.format("MOVES %s NEW %s #%d: %s", d.variant, kind == "acts" and "move" or "AI row",
            kind == "acts" and v.n_acts or v.n_rows, key))
    end
    t[key] = t[key] + 1
    PURG.moves_dirty = true
end
function PURG.moves_write()
    local out = { "Recorded monster moves (" .. os.date("%Y-%m-%d %H:%M:%S") .. ")", "" }
    local vs = {}
    for k in pairs(PURG.moves) do table.insert(vs, k) end
    table.sort(vs)
    local all = {}
    for _, k in ipairs(vs) do for a in pairs(PURG.moves[k].acts) do all[a] = all[a] or {}; all[a][k] = true end end
    for _, k in ipairs(vs) do
        local v = PURG.moves[k]
        table.insert(out, string.format("===== %s  (spawned %d time(s), AI %s) =====", k, v.fights, tostring(v.think)))
        table.insert(out, string.format("-- %d different moves:", v.n_acts))
        local acts = {}
        for a, n in pairs(v.acts) do table.insert(acts, { a, n }) end
        table.sort(acts, function(x, y) return x[1] < y[1] end)
        for _, a in ipairs(acts) do
            local others = {}
            for _, k2 in ipairs(vs) do if k2 ~= k and all[a[1]][k2] then table.insert(others, k2:sub(10)) end end
            table.insert(out, string.format("  %-40s x%-4d %s", a[1], a[2], #others > 0 and ("(also " .. table.concat(others, ",") .. ")") or "(ONLY this variant so far)"))
        end
        table.insert(out, string.format("-- %d AI think rows that fired:", v.n_rows))
        local rows = {}
        for r, n in pairs(v.rows) do table.insert(rows, { r, n }) end
        table.sort(rows, function(x, y) return x[1] < y[1] end)
        for _, r in ipairs(rows) do table.insert(out, string.format("  x%-4d %s", r[2], r[1])) end
        table.insert(out, "")
    end
    pcall(fs.write, PURG.MOVES_FILE, table.concat(out, "\n"))
end
do
    local ttd = sdk.find_type_definition("app.ThinkTableController")
    local tm = (not K.RELEASE) and ttd and ttd:get_method("isExecuteEmThkGeneralCommand")
    if tm then
        pcall(sdk.hook, tm, function(args)
            if not next(PURG.drg_tctrl) then return end
            local st = thread.get_hook_storage()
            st["rr_dtr"] = nil
            local d = PURG.drg_tctrl[sdk.to_int64(args[2])]
            if d then st["rr_dtr"] = { d = d, cmd = args[3], tbl = args[4] } end
        end, function(retval)
            local st = thread.get_hook_storage()
            local c = st and st["rr_dtr"]
            if c then
                st["rr_dtr"] = nil
                if c.d.rowset then pcall(K.gag_row, c.cmd, c.tbl, is_true(retval), c.d.rowset) end
                if is_true(retval) then
                    local cmd = safe(function() return sdk.to_managed_object(c.cmd) end)
                    local tbl = safe(function() return sdk.to_managed_object(c.tbl) end)
                    local key = (tbl and safe(function() return tbl.TableName end) or "?") .. " | " ..
                        (cmd and safe(function() return cmd._ActInterName end) or "?") .. " | goto " ..
                        (cmd and safe(function() return cmd.TableName end) or "?")
                    if not key:find("ACT_INVALID | goto NO_JUMP_TBL", 1, true) then pcall(PURG.moves_add, c.d, "rows", key) end
                end
            end
            return retval
        end)
        log("Dragon AI row study hook on ThinkTableController.isExecuteEmThkGeneralCommand")
    end
end

-- v1.9.96: Dragon damage study - what each hit on a Dragon does (weak points / resistances).
-- HitController.updateDamageHp(DamageInfo, Single, Boolean); only Dragons' HitControllers are looked at.
PURG.dmg = { hits = 0, dumped = 0, sum = 0, max = 0, win_t = 0 }
PURG.DMG_FILE = "RancorReinforcements_dragon_damage.txt"
function PURG.dmg_dump(di, dmg)
    local out = { string.format("== hit %d, damage arg %.1f ==", PURG.dmg.hits, dmg or -1) }
    local td = di:get_type_definition()
    while td do
        for _, f in ipairs(td:get_fields()) do
            if not f:is_static() then
                local v = safe(function() return di:get_field(f:get_name()) end)
                local tv = type(v)
                local sv = (tv == "number" or tv == "boolean" or tv == "string") and tostring(v)
                    or (v ~= nil and safe(function() return v:get_type_definition():get_full_name() end)) or tostring(v)
                table.insert(out, string.format("  %s : %s = %s", f:get_name(), f:get_type():get_full_name(), tostring(sv)))
            end
        end
        td = td:get_parent_type()
        if td and td:get_full_name() == "System.Object" then break end
    end
    local old = safe(function() local fh = io.open(PURG.DMG_FILE, "r"); if fh then local x = fh:read("a"); fh:close(); return x end end) or ""
    pcall(fs.write, PURG.DMG_FILE, old .. table.concat(out, "\n") .. "\n")
end
do
    local td = sdk.find_type_definition("app.HitController")
    for _, m in ipairs(td and td:get_methods() or {}) do
        local pt = (not K.RELEASE) and m:get_name() == "updateDamageHp" and m:get_num_params() == 3 and safe(function() return m:get_param_types() end)
        if pt and not pt[1]:is_value_type() and pt[2]:get_full_name() == "System.Single" then
            pcall(sdk.hook, m, function(args)
                if not next(PURG.drg) then return end
                local ha = sdk.to_int64(args[2])
                local d
                for _, x in pairs(PURG.drg) do
                    if not x.hit_addr and x.chara then x.hit_addr = safe(function() return x.chara:get_Hit():get_address() end) end
                    if x.hit_addr == ha then d = x; break end
                end
                if not d then return end
                local dmg = safe(function() return sdk.to_float(args[4]) end)
                local P = PURG.dmg
                P.hits = P.hits + 1
                d.hits = (d.hits or 0) + 1
                if dmg then d.sum = (d.sum or 0) + dmg; if dmg > (d.max or 0) then d.max = dmg end end
                local di = safe(function() return sdk.to_managed_object(args[3]) end)
                if di and (P.dumped < 4 or (dmg and dmg >= 5000 and P.dumped < 12)) then
                    P.dumped = P.dumped + 1
                    pcall(PURG.dmg_dump, di, dmg)
                end
                if P.hits <= 30 or (dmg and dmg >= 15000) then
                    local di2 = di
                    local reg = di2 and safe(function() return di2.RegionStatusNo end)
                    local weak = di2 and safe(function() return di2.IsWeakDamage end)
                    log(string.format("DRAGON hit #%d: %.0f damage (body part %s%s)%s", P.hits, dmg or -1, tostring(reg), weak and ", WEAK SPOT" or "",
                        (dmg and dmg >= 15000) and "  <-- BIG" or ""))
                end
            end, function(retval) return retval end)
            log("Dragon damage study hook on HitController." .. m:get_name())
        end
    end
end   -- v1.9.92: for the breath aim (late-update block above)
-- v1.9.124 (user: the Gagana doesn't seem to use its whole moveset in Rancors): move recorder for Gaganas, and
-- Griffins to compare - every action and AI think row they use, Rancor ones and world ones apart, into
-- data/RancorReinforcements_moves.txt, plus a one-time dump of their AI controller. Dev build only.
-- v1.9.147 (user: give the Brine Lich the Norgan Lich's teleport): both Liches are recorded now - every move
-- and think row, and the lich rowset dumps the teleport rows WITH their conditions, so the next fight shows
-- whether the Brine Lich checks the shared teleport rows and what blocks them (a forceable gate vs missing packs).
K.MOVE_WATCH = { ch253012 = "Gagana", ch253000 = "Griffin", ch270000 = "Evil Eye", ch227000 = "Brine Lich", ch227002 = "Norgan Lich" }
PURG.watch, PURG.watch_wait, PURG.watch_present = {}, {}, {}
function PURG.watch_seen(m, go, name, now, mine)
    local addr = go:get_address()
    PURG.watch_present[addr] = true
    if PURG.watch[addr] then return end
    -- wait 3 s so the mod's own tracking has claimed its reinforcements first (Rancor vs world label)
    PURG.watch_wait[addr] = PURG.watch_wait[addr] or now
    if now - PURG.watch_wait[addr] < 3 then return end
    PURG.watch_wait[addr] = nil
    local chara = safe(function() return go:call("getComponent(System.Type)", sdk.typeof("app.Character")) end)
    if not chara then return end
    local d = { go = go, chara = chara, name = name, t = now, lines = 0, gagana = name:sub(1, 8) == "ch253012",
        rowset = (name:sub(1, 8) == "ch253012" and "gagana") or (name:sub(1, 8) == "ch270000" and "eye")
            or (name:sub(1, 7) == "ch22700" and "lich") or nil,
        variant = K.MOVE_WATCH[name:sub(1, 8)] .. " " .. name:sub(1, 11) .. (mine and " (Rancor)" or " (world)") }
    PURG.watch[addr] = d
    pcall(PURG.moves_seen, d)
    d.tctrl = addr_of(safe(function() return m_module(chara)._ThinkTableCtrl end))
    if d.tctrl then PURG.drg_tctrl[d.tctrl] = d end
    log(string.format("MOVES: recording %s as '%s' (AI %s)", name, d.variant, tostring(d.think_path)))
    pcall(PURG.ai_dump, d)
end
-- v1.9.127: Gagana think rows - every row it checks, passed or not, counted; the rows of its flight tables
-- (hover / swoop / take-off / landing) dumped once with their conditions, to see what blocks its take-off.
-- Called from the AI hook: only counts and keeps the pointers; the dump happens in the frame callback.
-- v1.9.133: the same study for the Evil Eye (its teleport phase, swipes / grabs, tentacle regrowth), each kind to
-- its own file: data/RancorReinforcements_rows_<kind>.txt
K.ROWSETS = {
    gagana = { rows = {}, q = {}, title = "Gagana", file = "RancorReinforcements_gagana_rows.txt",
        kw = { "ホバー", "急襲", "離陸", "着陸", "飛", "空中" } },
    eye = { rows = {}, q = {}, title = "Evil Eye", file = "RancorReinforcements_rows_evil_eye.txt",
        kw = { "ワープ", "転移", "瞬間", "テレポ", "移動", "再生", "復活", "掴", "捕", "触手", "パーツ", "スイング", "薙", "払",
               "Warp", "Revive", "Parts", "Swing", "Hold", "Catch", "Bite", "Tentacle" } },
    -- v1.9.147: both Liches' teleport / vanish / appear rows, with conditions (which gate blocks the Brine Lich?)
    lich = { rows = {}, q = {}, title = "Lich", file = "RancorReinforcements_lich_rows.txt",
        kw = { "テレポ", "ワープ", "転移", "瞬間", "消", "出現", "Teleport", "Warp", "Appear", "Vanish" } },
}
function K.gag_row(cmd_p, tbl_p, passed, set)
    local S = K.ROWSETS[set or "gagana"]
    local ca = sdk.to_int64(cmd_p)
    local r = S.rows[ca]
    if not r then
        r = { cmd = cmd_p, tbl = tbl_p, ok = 0, no = 0, seq = (S.n or 0) + 1 }
        S.n = r.seq
        S.rows[ca] = r
        S.q[#S.q + 1] = r
    end
    if passed then r.ok = r.ok + 1; r.last_ok = os.clock() else r.no = r.no + 1 end
end
function K.rows_set_frame(S, now)
    local q = S.q
    if #q > 0 then
        S.q = {}
        for _, r in ipairs(q) do
            local cmd = safe(function() return sdk.to_managed_object(r.cmd) end)
            local tbl = safe(function() return sdk.to_managed_object(r.tbl) end)
            r.tname = tbl and safe(function() return tbl.TableName end) or "?"
            r.act = cmd and safe(function() return cmd._ActInterName end) or "?"
            r.jump = cmd and safe(function() return cmd.TableName end) or "?"
            local nm = r.tname .. " " .. r.act .. " " .. r.jump
            for _, w in ipairs(S.kw) do if nm:find(w, 1, true) then r.flight = true; r.obj = cmd; break end end
        end
    end
    if now - (S.wt or 0) < 5 then return end
    S.wt = now
    local list = {}
    for _, r in pairs(S.rows) do if r.tname then list[#list + 1] = r end end
    if #list == 0 then return end
    table.sort(list, function(a, b) if a.tname ~= b.tname then return a.tname < b.tname end return a.seq < b.seq end)
    local out = { S.title .. " think rows checked (" .. os.date("%H:%M:%S") .. "): passed / failed, in table order", "" }
    for _, r in ipairs(list) do
        out[#out + 1] = string.format("%6d ok %6d no  %s | %s | goto %s%s", r.ok, r.no, r.tname, r.act, r.jump, r.flight and "   <- dumped below" or "")
    end
    local okr, src = pcall(_G.fs.read, "claude_dumplib.lua")
    local D = okr and type(src) == "string" and #src > 100 and select(2, pcall(function() return load(src, "=claude_dumplib", "t")() end))
    if type(D) == "table" then
        local nd = 0
        for _, r in ipairs(list) do
            if r.flight and r.obj and not r.dumped and nd < 80 then
                nd = nd + 1
                r.dumped = D.dump(r.obj, "ROW " .. r.tname .. " | " .. r.act .. " | goto " .. r.jump, 1500, 6)
            end
            if r.dumped then out[#out + 1] = "\n" .. r.dumped end
        end
    end
    pcall(fs.write, S.file, table.concat(out, "\n"))
end
function K.gag_rows_frame(now)
    if now - (K.ROWS_T or 0) < 1 then return end
    K.ROWS_T = now
    for _, S in pairs(K.ROWSETS) do pcall(K.rows_set_frame, S, now) end
end
-- every frame: the action each watched monster is in (short moves are missed at 0.5 s sampling)
function PURG.watch_frame()
    for _, d in pairs(PURG.watch) do
        local act = safe(function() return d.chara["<ActionManager>k__BackingField"].CurrentAction:ToString() end)
        if act and act ~= d.cur_act then d.cur_act = act; pcall(PURG.moves_add, d, "acts", act) end
    end
end
function PURG.watch_cleanup()
    for addr, d in pairs(PURG.watch) do
        if not PURG.watch_present[addr] then
            log("MOVES: " .. d.name .. " gone (last action " .. tostring(d.cur_act) .. ")")
            if d.tctrl then PURG.drg_tctrl[d.tctrl] = nil end
            PURG.watch[addr] = nil
        end
    end
    for addr in pairs(PURG.watch_wait) do if not PURG.watch_present[addr] then PURG.watch_wait[addr] = nil end end
    PURG.watch_present = {}
end
-- one dump per kind of its AI controller (think tables, rows, conditions) with the bridge's dump library
function PURG.ai_dump(d)
    -- v1.9.134: OFF. Dumping a live monster's AI controller calls ToString on its live targets; on the Evil Eye
    -- (19:04:26) that faulted inside the game (AITargetGameObject.ToString), and the game crashed 80 s later in
    -- the Eye's own parts/warp code. Only static data (think rows) is dumped now.
    if true then return end
    PURG.ai_dumped = PURG.ai_dumped or {}
    if PURG.ai_dumped[d.variant] then return end
    PURG.ai_dumped[d.variant] = true
    local okr, src = pcall(_G.fs.read, "claude_dumplib.lua")
    if not okr or type(src) ~= "string" or #src < 100 then return end
    local okl, D = pcall(function() return load(src, "=claude_dumplib", "t")() end)
    if not okl or type(D) ~= "table" then return end
    local ctrl = safe(function() return m_module(d.chara)._ThinkTableCtrl end)
    local adm = safe(function() return d.chara["<AIDecisionMaker>k__BackingField"] end)
    local txt = D.dump(ctrl, "ThinkTableCtrl of " .. d.name .. " (" .. d.variant .. ")", 40000, 7) .. "\n\n" ..
        D.dump(adm, "AIDecisionMaker of " .. d.name, 20000, 4)
    local file = "RancorReinforcements_ai_" .. d.variant:gsub("[^%w]+", "_"):gsub("_$", "") .. ".txt"
    pcall(fs.write, file, txt)
    log("MOVES: AI controller of " .. d.name .. " written to " .. file)
end
function PURG.dragon_tick()
    local now = os.clock()
    if now - (PURG.drg_last or 0) < 0.5 then return end
    PURG.drg_last = now
    -- v1.9.156: same for Dragons (unless the Enemy Spawner Dragon option is on)
    if K.RELEASE and not config.dragon_spawner_stats and not vortex_now and not next(PURG.drg) and not (K.TRACKED and next(K.TRACKED)) then return end
    local present = {}
    for _, m in ipairs(find_components("app.Monster")) do
        local go = safe(function() return m:call("get_GameObject") end)
        local name = go and safe(function() return go:call("get_Name") end)
        -- v1.9.120: world Dragons are only touched by the Enemy Spawner option or the dev build's watcher
        local mine = name and K.TRACKED and K.TRACKED[go:get_address()]
        if not K.RELEASE and name and K.MOVE_WATCH[name:sub(1, 8)] then pcall(PURG.watch_seen, m, go, name, now, mine) end
        if name and name:sub(1, 8) == "ch258000" and not mine and not config.dragon_spawner_stats and (K.RELEASE or not config.purgener_watch) then name = nil end
        if name and name:sub(1, 8) == "ch258000" then
            local addr = go:get_address()
            present[addr] = true
            local d = PURG.drg[addr]
            if not d then
                local chara = safe(function() return go:call("getComponent(System.Type)", sdk.typeof("app.Character")) end)
                d = { go = go, chara = chara, name = name, t = now, next_log = now + 10, lines = 0 }
                PURG.drg[addr] = d
                d.variant = name:sub(1, 11)
                local rf = PURG.drg_rf()
                if config.dragon_spawner_stats and rf then d.boost_at = now + 3.0; d.boost_until = now + 12; d.rf = rf end   -- v1.9.98: later, after its entrance
                d.hits, d.sum, d.max = 0, 0, 0
                pcall(PURG.moves_seen, d)
                local tr = safe(function() return go:call("get_Transform") end)
                local ls = tr and safe(function() return tr:call("get_LocalScale") end)
                local gi = safe(function() return go:call("getComponent(System.Type)", sdk.typeof("app.GenerateInfo")) end)
                local sr = gi and safe(function() return gi:get_field("_Container")._StatusInfo["<ScaleRate>k__BackingField"] end)
                local joints = {}
                local arr = tr and safe(function() return tr:call("get_Joints") end)
                for _, j in ipairs(arr and (safe(function() return arr:get_elements() end) or {}) or {}) do
                    local jn = safe(function() return j:call("get_Name") end) or ""
                    local low = jn:lower()
                    if low:find("head") or low:find("neck") or low:find("jaw") or low:find("mouth") or low:find("tongue") then
                        table.insert(joints, jn)
                    end
                end
                log(string.format("DRAGON seen: %s, HP %s, local scale %s, spawn ScaleRate %s, %d head/neck joints, AI %s", name,
                    tostring(chara and safe(function() return chara:get_Hit():call("get_Hp") end)),
                    ls and string.format("%.2f", vfield(ls, "x") or 0) or "?", tostring(sr), #joints, tostring(d.think_path)))
            end
            -- v1.9.98: never touch its HP during its spawn entrance (crash 15:20 right after Dragon A's FrontFallLanding)
            local entering = d.cur_act == nil or d.cur_act == "Invalid" or tostring(d.cur_act):find("Landing", 1, true)
            if d.boost_at and now >= d.boost_at and (not entering or now >= d.boost_until) then
                d.boost_at = nil
                d.chara = d.chara or safe(function() return go:call("getComponent(System.Type)", sdk.typeof("app.Character")) end)
                local hp0 = d.chara and safe(function() return d.chara:get_Hit():call("get_Hp") end)
                if hp0 and hp0 <= 0 then
                    log("Spawner Dragon " .. name .. " is already dead - not boosting it")
                elseif not scaled[addr] and d.chara and config.dragon_spawner_stats then
                    local pre = hp_report(d.chara)
                    if apply_scaling(d.chara, d.rf) then
                        d.boosted = true
                        log(string.format("Spawner Dragon %s boosted: %s -> %s, damage x%.1f", name, pre, hp_report(d.chara), tonumber(config.dragon_attack) or 1))
                    end
                end
            end
            if d.boosted and not scaled[addr] then   -- keep the damage multiplier (the game resets it)
                pcall(function()
                    local hit = d.chara:get_Hit()
                    set_if_exists(hit, { "_BaseAttackRate" }, tonumber(config.dragon_attack) or 1)
                    set_if_exists(hit, { "<AttackRate>k__BackingField" }, tonumber(config.dragon_attack) or 1)
                end)
            end
            if not d.think_path and d.chara and now - d.t > 2 and now - (d.think_try or 0) > 2 then
                d.think_try = now
                local adm = safe(function() return d.chara["<AIDecisionMaker>k__BackingField"] end)
                local init = adm and safe(function() return adm._ThinkTableInitSetting end)
                local tdat = init and safe(function() return init._InitThinkTableData end)
                d.think_path = tdat and (safe(function() return tdat:call("ToString()") end) or safe(function() return tdat:get_type_definition():get_full_name() end))
                if d.think_path then
                    log("DRAGON " .. tostring(d.variant) .. " AI table: " .. d.think_path)
                    if PURG.moves[d.variant] then PURG.moves[d.variant].think = d.think_path; PURG.moves_dirty = true end
                end
            end
            if not d.tctrl and d.chara then
                d.tctrl = addr_of(safe(function() return m_module(d.chara)._ThinkTableCtrl end))
                if d.tctrl then PURG.drg_tctrl[d.tctrl] = d end
            end
            local act = d.chara and safe(function() return d.chara["<ActionManager>k__BackingField"].CurrentAction:ToString() end)
            if act and act ~= d.cur_act then d.cur_act = act; pcall(PURG.moves_add, d, "acts", act) end
            if not config.purgener_watch then act = nil end
            if act and act ~= d.last_act and d.lines < 300 then
                d.last_act, d.lines = act, d.lines + 1
                log("DRAGON action: " .. act)
            end
            if now >= d.next_log then
                d.next_log = now + 10
                local hp = d.chara and safe(function() return d.chara:get_Hit():call("get_Hp") end)
                if hp and hp > 0 or (d.hits or 0) > 0 then
                    log(string.format("DRAGON %s +%.0fs: HP %s, %.0f m from you | last 10 s: %d hits, %.0f damage, biggest %.0f", d.variant or name, now - d.t, tostring(hp),
                        dist3(pos_of(go), player_pos()) or -1, d.hits or 0, d.sum or 0, d.max or 0))
                end
                d.hits, d.sum, d.max = 0, 0, 0
            end
        end
    end
    if not K.RELEASE then pcall(PURG.watch_cleanup) end
    if PURG.moves_dirty and now - (PURG.moves_wt or 0) >= 2 then
        PURG.moves_dirty, PURG.moves_wt = false, now
        pcall(PURG.moves_write)
    end
    for addr, d in pairs(PURG.drg) do
        if not present[addr] then
            log("DRAGON gone: " .. d.name .. " (last action " .. tostring(d.last_act) .. ")"); PURG.drg[addr] = nil
            if d.tctrl then PURG.drg_tctrl[d.tctrl] = nil end
        end
    end
end

do  -- its own climbable-gimmick searches (shared Medusa-family check)
    local td = sdk.find_type_definition("app.EmThkChkCh255FindClimbableGimmick")
    local m = td and td:get_method("evaluate")
    if m then
        pcall(sdk.hook, m, function(args)
            local st = thread.get_hook_storage()
            st["rr_pfcg"] = nil
            if not next(PURG.by_module) then return end
            local e = PURG.by_module[sdk.to_int64(args[3])]
            if e then st["rr_pfcg"] = e end
        end, function(retval)
            local st = thread.get_hook_storage()
            local e = st and st["rr_pfcg"]
            if not e then return retval end
            st["rr_pfcg"] = nil
            local found = is_true(retval)
            e.searches = (e.searches or 0) + 1
            local comp = e.comp
            if e.searches <= 10 or found ~= e.last_found then
                -- v1.9.81: no object calls inside the hook - just the result
                PURG.log(string.format("Purgener climb search #%d: %s", e.searches, found and "FOUND" or "nothing"))
            end
            e.last_found = found
            if found then return retval end
            local ps = PURG.pillar()
            if ps and ps.tag == "purgener" and ps.state == "spawned" and ps.comp and comp then
                local here, pp = upos_go(e.go), upos_go(ps.go)
                if here and pp and (flat_dist(here, pp) or 99) < 30 then
                    local ok = pcall(function() comp:set_field("<ClimberTargetGimmick>k__BackingField", ps.comp) end)
                    if not e.forced_logged then
                        e.forced_logged = true
                        PURG.log("Purgener climb search: pointed it at the pillar (" .. (ok and "target set" or "could not set target") .. ")")
                    end
                    if ok then return sdk.to_ptr(1) end
                end
            end
            return retval
        end)
    end
end

re.on_frame(function()
    frame_no = frame_no + 1
    if config.enabled and (config.purgener_watch or K.RELEASE) then pcall(PURG.tick) end
    if config.enabled and (config.purgener_watch or config.dragon_spawner_stats or K.RELEASE) then pcall(PURG.dragon_tick) end
    if not K.RELEASE and next(PURG.watch) then pcall(PURG.watch_frame) end
    if not K.RELEASE then pcall(K.gag_rows_frame, os.clock()) end
    if TEST.waiting then pcall(TEST.tick) end
    if TEST.here and os.clock() - (TEST.here_t or 0) > 300 then
        log("Test spawn: no monster spawned near you in 5 minutes - cancelled (" .. TEST.here .. ")")
        TEST.here = nil
    end
    if WAVES.cur and os.clock() - WAVES.cur.last > 4 then pcall(WAVES.flush) end
    if config.enabled then pcall(PX.corpse_tick, os.clock()) end
    if config.enabled then pcall(K.gagana_tick, os.clock()) end
    if config.enabled then pcall(K.hold_tick, os.clock()) end
    if config.enabled then pcall(K.eye_down_tick, os.clock()) end
    if config.enabled then pcall(K.eye_phase_tick, os.clock()) end
    if config.enabled then pcall(K.eye_revive_tick, os.clock()) end
    if config.enabled then pcall(K.eye_minion_tick, os.clock()) end   -- v1.9.168
    if #deferred > 0 then pcall(run_deferred) end
    if log_dirty and os.clock() - last_log_write >= 2.0 then
        last_log_write = os.clock(); log_dirty = false
        pcall(fs.write, K.LOG_FILE, table.concat(file_lines, "\n"))
    end
    if not config.enabled then
        if #pending_reverts > 0 then pcall(revert_swaps, true) end
        return
    end
    local now = os.clock()
    if now - last_vortex_check >= 2.0 then
        last_vortex_check = now
        local ok, err = pcall(refresh_vortex)
        if not ok then log("Vortex check error: " .. tostring(err)) end
    end
    if now - last_tick >= 1.0 then
        last_tick = now
        pcall(capture_arena_center)
        pcall(sample_walkable)
        local ok, err = pcall(find_and_scale_new)
        if not ok then log("Scale error: " .. tostring(err)) end
        if #pending_reverts > 0 then pcall(revert_swaps, false) end
        pcall(keep_attack_rate)
    end
    if config.medusa_study or (config.purgener_study and next(study)) then
        local okS, errS = pcall(process_study, now)
        if not okS then log("Study error: " .. tostring(errS)) end
    end
    if next(medusa) and not frost_on_game_thread then
        local okF, errF = pcall(process_frost)
        if not okF then log("Medusa look error: " .. tostring(errF)) end
    end
    if PX.scout and config.medusa_pillar_scout then pcall(PX.scout, now, false) end
    if PX.tick then PX.tick() end
    if next(medusa) and now - (last_petri_tick or 0) >= 0.25 then
        last_petri_tick = now
        local okP, errP = pcall(process_petrify, now)
        if not okP then log("Medusa petrify error: " .. tostring(errP)) end
        if process_petrify_extra then
            local okB, errB = pcall(process_petrify_extra, now)
            if not okB then log("Medusa beam error: " .. tostring(errB)) end
        end
    end
    if next(medusa) and now - (last_medusa_tick or 0) >= 0.25 then
        last_medusa_tick = now
        local ok, err = pcall(process_medusa)
        if not ok then log("Medusa error: " .. tostring(err)) end
    end
end)

-- Menu -------------------------------------------------------------------------------
re.on_draw_ui(function()
    if not imgui.tree_node("Rancor Reinforcements") then return end
    local changed, any = false, false

    if K.RELEASE then
        imgui.text(VERSION .. "  |  Rancor fight: " .. (vortex_now and (DEVOUR.active and "YES (Devouring)" or "YES") or "no"))
    else
        imgui.text(VERSION .. "  |  spawn hooks: " .. hooked .. "  |  watch hooks: " .. research_hooks ..
            "  |  vortex fight: " .. (vortex_now and "YES" or "no"))
    end
    changed, config.enabled = imgui.checkbox("Enabled", config.enabled); any = any or changed
    changed, config.require_vortex = imgui.checkbox("Only during Rancor vortex fights", config.require_vortex); any = any or changed
    changed, config.only_real_rancors = imgui.checkbox("Only in the game's Rancor events (never story / quest fights)", config.only_real_rancors); any = any or changed
    if not K.RELEASE then
    changed, config.purgener_watch = imgui.checkbox("Watch Purgeners (log their AI, climbs, escapes)", config.purgener_watch); any = any or changed
    end
    changed, config.purgener_pillar = imgui.checkbox("Place the climbable pillar next to a Purgener", config.purgener_pillar); any = any or changed
    if not K.RELEASE then
    changed, config.purgener_study = imgui.checkbox("Log a Purgener's AI decisions (think rows, conditions)", config.purgener_study); any = any or changed
    local own_p = (tonumber(config.purgener_pillar_gid) or 408) ~= 235
    changed, own_p = imgui.checkbox("Purgener uses its own big pillar (gimmick 408 - looks right, but it can't climb it yet)", own_p)
    if changed then config.purgener_pillar_gid = own_p and 408 or 235; any = true end
    end
    changed, config.purgener_hp = imgui.drag_float("Purgener (Devouring final boss) HP", config.purgener_hp, 1000, 20000, 2000000); any = any or changed
    changed, config.purgener_attack = imgui.slider_float("Purgener damage multiplier (all of its moves)", config.purgener_attack, 0.5, 5.0); any = any or changed
    changed, config.purgener_pillar_interval = imgui.slider_int("Purgener pillar attempts: seconds between", config.purgener_pillar_interval, 30, 300); any = any or changed
    changed, config.devour_final_share = imgui.slider_float("Devouring finale: Purgener's share (of the dragon-carcass / Death finales)", config.devour_final_share, 0, 1); any = any or changed
    changed, config.purgener_takes_death = imgui.checkbox("The Purgener may also take Death's finale", config.purgener_takes_death); any = any or changed
    changed, config.eye_parts_aim = imgui.slider_float("Evil Eye tentacles: turn toward you while casting (deg/s, 0 = off)", config.eye_parts_aim, 0, 360); any = any or changed
    if not K.RELEASE then
    changed, config.eye_arena_warp = imgui.checkbox("Evil Eye: warp to spots around the arena (virtual lair)", config.eye_arena_warp); any = any or changed
    end
    changed, config.medusa_petrify_len = imgui.slider_float("Medusa petrify beam length (1.0 = normal)", config.medusa_petrify_len, 0.2, 1.5); any = any or changed
    changed, config.golem_hp_mult = imgui.slider_float("Golem HP (x its own, main + medallions)", config.golem_hp_mult, 1, 20); any = any or changed
    if K.hydra_ready() then   -- v1.9.157: only with the Hydra files installed
    changed, config.hydra_hp = imgui.drag_float("Hydra HP", config.hydra_hp, 1000, 20000, 2000000); any = any or changed
    changed, config.hydra_attack = imgui.slider_float("Hydra damage multiplier", config.hydra_attack, 0.5, 5.0); any = any or changed
    end
    changed, config.purgener_points_split = imgui.checkbox("Purgener: spread its HP over its weak points", config.purgener_points_split); any = any or changed
    changed, config.golem_attack = imgui.slider_float("Golem damage multiplier", config.golem_attack, 0.5, 6.0); any = any or changed
    if not K.RELEASE then
    changed, config.golem_transform_scale = imgui.checkbox("Golem: stretch its model to that size", config.golem_transform_scale); any = any or changed
    end
    changed, config.golem_medal_split = imgui.checkbox("Golem: spread its HP over the medallions", config.golem_medal_split); any = any or changed
    changed, config.brine_golem_hp_mult = imgui.slider_float("Brine Golem HP (x its own, over the medallions)", config.brine_golem_hp_mult, 1, 20); any = any or changed
    changed, config.brine_golem_attack = imgui.slider_float("Brine Golem damage multiplier", config.brine_golem_attack, 0.5, 6.0); any = any or changed
    changed, config.vermund_hp = imgui.drag_float("Vermund Purgener HP (over its weak points)", config.vermund_hp, 2000, 50000, 2000000); any = any or changed
    changed, config.vermund_attack = imgui.slider_float("Vermund Purgener damage multiplier", config.vermund_attack, 0.5, 6.0); any = any or changed
    if not K.RELEASE then
    changed, config.dragon_hp = imgui.drag_float("Dragon (Devouring final boss) HP", config.dragon_hp, 5000, 20000, 5000000); any = any or changed
    changed, config.dragon_scale = imgui.slider_float("Dragon size (1.0 = normal)", config.dragon_scale, 0.3, 1.5); any = any or changed
    changed, config.dragon_attack = imgui.slider_float("Dragon damage multiplier", config.dragon_attack, 0.5, 5.0); any = any or changed
    if not K.RELEASE then
    changed, config.dragon_spawner_stats = imgui.checkbox("Use these Dragon settings for Enemy Spawner Dragons too (all variants _00/_10/_20/_30)", config.dragon_spawner_stats); any = any or changed
    end
    changed, config.dragon_breath_aim = imgui.slider_float("Dragon breath: head/neck aim (max deg, 0 = off)", config.dragon_breath_aim, 0, 120); any = any or changed
    changed, config.dragon_breath_turn = imgui.slider_float("Dragon breath: body turning toward you (deg/s)", config.dragon_breath_turn, 0, 180); any = any or changed
    end
    imgui.text(string.format("  This Rancor's final boss: %s", tostring(event.final_pick or "not rolled yet")))
    pcall(GF.ui)
    if not K.RELEASE and imgui.tree_node("Test spawn (identify a monster)") then
        local l = TEST.candidates()
        local ch
        ch, TEST.idx = imgui.combo("Monster ID", TEST.idx, l)
        ch, TEST.custom = imgui.input_text("...or type an ID", TEST.custom)
        local typed = (TEST.custom or ""):gsub("[^%w_]", "")
        local pick = (typed ~= "" and typed) or l[TEST.idx]
        -- v1.9.72: a family ID (ch260000) is not a spawnable monster - use its _00 variant
        if pick and pick:match("^ch%d%d%d%d%d%d$") and id_value[pick .. "_00"] then pick = pick .. "_00" end
        if imgui.button("Put " .. tostring(pick) .. " in the next big-enemy slot") then
            if pick and id_value[pick] then
                TEST.armed = pick
                log("Test spawn armed: " .. pick .. " (next major Rancor slot; Satanica's spawns are never used)")
            else
                log("Test spawn: unknown ID " .. tostring(pick))
            end
        end
        if imgui.button("Spawn " .. tostring(pick) .. " in front of me (Evil Eye method)") then
            if pick and id_value[pick] then
                TEST.evil = { id = pick, t = os.clock() }
                log("Evil Eye method requested: " .. pick .. " (experimental - save first)")
            else
                log("Test spawn: unknown ID " .. tostring(pick))
            end
        end
        imgui.text("  Evil Eye method: experimental, needs another monster near you, may crash - save first.")
        if imgui.button("Repair spawn records near me") then TEST.repair_at = 0 end
        -- v1.9.76: the "anywhere" and raw-model buttons are gone: swapping a random world spawn never
        -- produced a monster, and a monster placed straight from its file crashed the game (10:57:33,
        -- DD2.exe+0x2c05ec null read) - monsters need the game's spawn system to set them up.
        imgui.text("  Uses a real Rancor wave slot (the only safe way found so far). The Devouring Rancor")
        imgui.text("  has the biggest arena for judging a monster's size.")
        imgui.text(TEST.armed and ("  Armed: " .. TEST.armed .. " - waiting for the next big-enemy spawn") or "  Not armed")
        imgui.text("  Save first: monsters from other areas (e.g. the Unmoored World) may fail to load or crash.")
        imgui.tree_pop()
    end
    imgui.separator()
    -- v1.9.124: reinforcements per Rancor (spread evenly over its big-enemy slots)
    changed, config.per_rancor_regular = imgui.slider_int("Reinforcements per regular Rancor", config.per_rancor_regular, 0, 6); any = any or changed
    changed, config.per_rancor_virulent = imgui.slider_int("Reinforcements per Virulent Rancor", config.per_rancor_virulent, 0, 8); any = any or changed
    changed, config.per_rancor_devour = imgui.slider_int("Reinforcements per Devouring Rancor (plus the finale roll)", config.per_rancor_devour, 0, 10); any = any or changed
    if event.q then
        imgui.text(string.format("  This %s Rancor: %d of %d placed, %d big-enemy slots so far", tostring(event.q.kind), event.q.used,
            math.floor(tonumber(config["per_rancor_" .. tostring(event.q.kind)]) or 0), event.q.seen))
    end
    for _, rf in ipairs(REINFORCEMENTS) do
      if not rf.off and not (rf.needs == "hydra" and not K.hydra_ready()) then
        local per = rf.key == "evil_eye" and " chance per wave" or " weight (how often it's the pick)"
        if rf.variant_of then per = ": chance to replace a Rancor " .. (rf.variant_label or "enemy") .. " (Rancors only, not the last boss wave)" end
        if not rf.final_boss and not rf.finale_only then
        changed, config[rf.key .. "_chance"] = imgui.slider_float(rf.name .. per, config[rf.key .. "_chance"], 0, 1); any = any or changed
        end
        if rf.key == "drake" then
            changed, config.drake_final_share = imgui.slider_float("Drake share of the Thimble finale slot", config.drake_final_share, 0, 1); any = any or changed
            -- v1.9.158: the Virulent Rancor's own finale shares
            imgui.text("  Virulent Rancor finale (the Thimble's slot; what is left = the Thimble stays):")
            changed, config.vir_eye_final_share = imgui.slider_float("  Virulent finale: Evil Eye share", config.vir_eye_final_share, 0, 1); any = any or changed
            changed, config.vir_drake_final_share = imgui.slider_float("  Virulent finale: Brine Drake share", config.vir_drake_final_share, 0, 1); any = any or changed
            changed, config.vir_sphinx_final_share = imgui.slider_float("  Virulent finale: Brine Sphinx share", config.vir_sphinx_final_share, 0, 1); any = any or changed
            changed, config.vir_vermund_final_share = imgui.slider_float("  Virulent finale: Vermund Purgener share", config.vir_vermund_final_share, 0, 1); any = any or changed
            changed, config.vir_no_thimble = imgui.checkbox("  Virulent finale: the Thimble never stays (one of the four always takes it)", config.vir_no_thimble); any = any or changed
            changed, config.reg_dullahan_final_share = imgui.slider_float("Regular finale: Brine Dullahan share of the Thimble's slot", config.reg_dullahan_final_share, 0, 1); any = any or changed
        end
        if rf.key == "brine_sphinx" then
            changed, config.brine_sphinx_hp = imgui.drag_float("Brine Sphinx HP", config.brine_sphinx_hp, 1000, 20000, 2000000); any = any or changed
            changed, config.brine_sphinx_attack = imgui.slider_float("Brine Sphinx damage multiplier", config.brine_sphinx_attack, 0.5, 5.0); any = any or changed
        end
        if rf.key == "evil_eye" then
            imgui.text("  The Evil Eye is a Virulent Rancor finale pick only (its share: the Brine Drake's Virulent sliders above)")
            changed, config.evil_eye_minions = imgui.slider_int("Evil Eye minions per Rancor event", config.evil_eye_minions, 0, 8); any = any or changed
            changed, config.evil_eye_tentacles = imgui.slider_int("Evil Eye tentacles per Rancor event", config.evil_eye_tentacles, 0, 6); any = any or changed
        end
        if rf.key == "evil_eye" then
            changed, config.evil_eye_max_per_event = imgui.slider_int("Max Evil Eyes per Rancor event", config.evil_eye_max_per_event, 0, 5); any = any or changed
            imgui.text(string.format("  This Rancor event: %d Evil Eye(s), %d minion(s), %d tentacle(s)", event.eyes, event.minions, event.tentacles or 0))
        elseif rf.match_native then
            local st = K.native_stats(rf)
            imgui.text(string.format("  Takes the %s's stats: %s HP, damage %s (%s)", rf.variant_label or "native", tostring(st.hp),
                st.batk and string.format("x%.2f", st.batk) or "its own", st.kind and ("learned in a " .. st.kind .. " Rancor") or "none seen yet - default HP"))
        elseif not rf.final_boss and not rf.variant_of then
            changed, config[rf.key .. "_max_per_wave"] = imgui.slider_int("Max " .. rf.name .. " per wave", config[rf.key .. "_max_per_wave"], 0, 5); any = any or changed
            if rf.max_per_event then
                changed, config[rf.key .. "_max_per_event"] = imgui.slider_int("Max " .. rf.name .. " per Rancor event", config[rf.key .. "_max_per_event"], 0, 5); any = any or changed
                imgui.text(string.format("  This Rancor event: %d spawned, %d alive (never more than %d at once)",
                    event.by_key and event.by_key[rf.key] or 0, rf.alive_n or 0, rf.max_alive or 99))
            end
        end
        if rf.native_hp then
            changed, config[rf.key .. "_use_scaled_hp"] = imgui.checkbox(rf.name .. ": use Lesser Demon HP instead of its own " .. rf.native_hp, config[rf.key .. "_use_scaled_hp"]); any = any or changed
        end
      end
    end
    imgui.separator()
    changed, config.hp = imgui.drag_float("Max HP (Lesser Demon = 192000)", config.hp, 1000, 1000, 1000000); any = any or changed
    changed, config.guard_hp = imgui.drag_float("Guard HP (Lesser Demon = 30000)", config.guard_hp, 500, 0, 200000); any = any or changed
    changed, config.attack_rate = imgui.slider_float("Damage multiplier", config.attack_rate, 0.5, 5.0); any = any or changed
    changed, config.eye_redirect_warp = imgui.checkbox("Evil Eye warps land near you (not in its dungeon)", config.eye_redirect_warp); any = any or changed
    changed, config.eye_keep_alive = imgui.checkbox("Don't let the Rancor remove a living Evil Eye at wave end", config.eye_keep_alive); any = any or changed
    changed, config.corpse_cleanup = imgui.checkbox("Remove our bosses' bodies once their wave is over", config.corpse_cleanup); any = any or changed
    changed, config.hold_end = imgui.checkbox("Rancor doesn't end while our reinforcements are still alive", config.hold_end); any = any or changed
    if config.hold_end then
        changed, config.hold_end_max = imgui.slider_int("  ...but at most (seconds)", config.hold_end_max, 30, 600); any = any or changed
    end
    changed, config.eye_down_speed = imgui.slider_float("Evil Eye: its down time (all tentacles broken) runs this much faster", config.eye_down_speed, 1, 20); any = any or changed
    changed, config.eye_down_anim = imgui.slider_float("Evil Eye: fall / get-up animation speed while down", config.eye_down_anim, 1, 5); any = any or changed
    changed, config.eye_revive_resist = imgui.slider_float("Evil Eye: damage taken while regrowing tentacles is reduced by", config.eye_revive_resist, 0, 0.95); any = any or changed
    changed, config.eye_tele_phase = imgui.checkbox("Evil Eye teleport phase: hunts you and each pawn, attacks between teleports, regrows at the end", config.eye_tele_phase); any = any or changed
    changed, config.eye_swarm = imgui.checkbox("Evil Eye swarm: while it lives, every small Rancor enemy becomes its eyeball minion (they die with it)", config.eye_swarm); any = any or changed
    changed, config.eye_arrival_minions = imgui.slider_int("Evil Eye: extra minions when it arrives (from the next small spawns)", config.eye_arrival_minions, 0, 8); any = any or changed
    changed, config.eye_parts_arena = imgui.checkbox("Evil Eye ground tentacles come up inside the arena (off: that move's tentacles are cancelled)", config.eye_parts_arena); any = any or changed
    changed, config.gagana_swoops = imgui.checkbox("Gagana: allow its swoop attacks in Rancors", config.gagana_swoops); any = any or changed
    if not K.RELEASE then
    changed, config.gagana_flight = imgui.checkbox("Gagana: force its flight state on (test - didn't work)", config.gagana_flight); any = any or changed
    end
    changed, config.leash = imgui.checkbox("Pull Griffins back if they end up outside the arena", config.leash); any = any or changed
    if config.leash then
        changed, config.leash_dist = imgui.slider_float("  Arena leash distance (m)", config.leash_dist, 20, 150); any = any or changed
        changed, config.leash_height = imgui.slider_float("  Arena leash height (m)", config.leash_height, 15, 100); any = any or changed
        changed, config.leash_secs = imgui.slider_float("  Seconds outside before pulling back", config.leash_secs, 1, 30); any = any or changed
        changed, config.leash_dist_devour = imgui.slider_float("  Leash distance in the Devouring Rancor (m)", config.leash_dist_devour, 60, 300); any = any or changed
        changed, config.leash_max_recalls = imgui.slider_int("  Max pulls per minute per monster", config.leash_max_recalls, 1, 10); any = any or changed
        imgui.text(string.format("  This Rancor: %s, its enemies spawn up to %.0f m out", DEVOUR.active and "DEVOURING" or "normal", DEVOUR.extent or 0))
    end
    changed, config.medusa_battle_pos = imgui.checkbox("Medusa: give her battle positions near you (AI fix)", config.medusa_battle_pos); any = any or changed
    changed, config.medusa_fixes = imgui.checkbox("Medusa: grounding + combat fixes (from v0.20)", config.medusa_fixes); any = any or changed
    changed, config.medusa_force_battle = imgui.checkbox("Medusa: send her into her combat table", config.medusa_force_battle); any = any or changed
    if not K.RELEASE then
    changed, config.medusa_trace = imgui.checkbox("Medusa: detailed decision log (research, heavier)", config.medusa_trace); any = any or changed
    end
    changed, config.medusa_force_pass = imgui.checkbox("Medusa: let her attack rows through the pass-row gate", config.medusa_force_pass); any = any or changed
    if not K.RELEASE then
    changed, config.medusa_study = imgui.checkbox("STUDY a world Medusa in her lair (log only, changes nothing)", config.medusa_study); any = any or changed
    end
    changed, config.medusa_force_uniq = imgui.checkbox("Medusa: keep her 'can switch from moving to an attack' flag on", config.medusa_force_uniq); any = any or changed
    changed, config.medusa_aggression = imgui.slider_float("Medusa aggression (cuts her attack cooldowns; 0 = normal)", config.medusa_aggression, 0, 0.9); any = any or changed
    changed, config.medusa_force_attack = imgui.checkbox("Medusa: give her attack permission in the Rancor", config.medusa_force_attack); any = any or changed
    changed, config.medusa_attack_assist = imgui.checkbox("Medusa: attack-window assist (3-14 m, 40 deg in front)", config.medusa_attack_assist); any = any or changed
    if not K.RELEASE then
    changed, config.medusa_funnel = imgui.checkbox("Medusa: decision funnel log (research, light)", config.medusa_funnel); any = any or changed
    end
    changed, config.medusa_beam_at_you = imgui.checkbox("Medusa: petrify beam targets you (not your pawn)", config.medusa_beam_at_you); any = any or changed
    changed, config.medusa_pillar_aim = imgui.checkbox("Medusa: aim her pillar (coiled) bow and beam too", config.medusa_pillar_aim); any = any or changed
    changed, config.medusa_pillar_turn = imgui.slider_int("Medusa: coiled turn speed around the pillar (deg/s)", config.medusa_pillar_turn or 120, 0, 360); any = any or changed
    changed, config.medusa_arrow_lockon = imgui.slider_int("Medusa: snake-bow lock-on cone (deg, game default 20)", config.medusa_arrow_lockon or 180, 20, 180); any = any or changed
    changed, config.medusa_arrow_pitch = imgui.checkbox("Medusa: point her arrows at her target (up / down too)", config.medusa_arrow_pitch); any = any or changed
    changed, config.medusa_head_aim = imgui.slider_int("Medusa: turn her head toward her target (max deg, 0 = off)", config.medusa_head_aim or 70, 0, 120); any = any or changed
    changed, config.medusa_light_scale = imgui.slider_float("Medusa: eye light size (x)", config.medusa_light_scale or 1.5, 0.5, 3.0, "%.2f"); any = any or changed
    changed, config.medusa_beam_pitch = imgui.checkbox("Medusa: tilt her petrify beam toward targets above / below", config.medusa_beam_pitch); any = any or changed
    changed, config.medusa_petrify_mult = imgui.slider_float("Medusa: petrify build-up multiplier", config.medusa_petrify_mult, 0.5, 3.0); any = any or changed
    changed, config.medusa_pillar = imgui.checkbox("Spawn a climbable pillar at the arena center for Rancor Medusa", config.medusa_pillar); any = any or changed
    changed, config.medusa_pillar_use = imgui.checkbox("Send Medusa to the pillar (coil + beam from the pillar)", config.medusa_pillar_use); any = any or changed
    if not K.RELEASE then
    changed, config.medusa_pillar_lift = imgui.slider_float("Pillar origin height above floor (m)", tonumber(config.medusa_pillar_lift) or 0.0, 0.0, 20.0, "%.1f"); any = any or changed
    end
    changed, config.medusa_pillar_interval = imgui.slider_int("Seconds between her pillar attempts", config.medusa_pillar_interval or 120, 20, 300); any = any or changed
    if not K.RELEASE then
    changed, config.medusa_pillar_scout = imgui.checkbox("Research: pillar scout (logs Medusa's lair pillars)", config.medusa_pillar_scout); any = any or changed
    if imgui.button("Scout pillars now") and PX.scout then PX.scout(os.clock(), true) end
    if PX.buttons then PX.buttons() end
    end
    changed, config.medusa_beam_smart = imgui.checkbox("Medusa: beam goes to whoever is in beam range (you first)", config.medusa_beam_smart); any = any or changed
    changed, config.medusa_beam_chase = imgui.slider_float("Medusa: chase speed while firing (m/s, 0 = off)", config.medusa_beam_chase, 0, 8); any = any or changed
    changed, config.medusa_beam_turn = imgui.slider_float("Medusa: extra beam turning toward you (deg/s, 0 = off)", config.medusa_beam_turn, 0, 180); any = any or changed
    changed, config.medusa_beam_width = imgui.slider_float("Medusa: petrify beam size", config.medusa_beam_width, 1.0, 3.0); any = any or changed
    changed, config.medusa_beam_interval = imgui.slider_float("Medusa: petrify beam at least every N seconds (0 = normal)", config.medusa_beam_interval, 0, 60); any = any or changed
    changed, config.medusa_frost = imgui.checkbox("Medusa: Norgan frost look (visual only)", config.medusa_frost); any = any or changed
    if config.medusa_frost then
        changed, config.medusa_frost_strength = imgui.slider_float("  frost strength", config.medusa_frost_strength, 0, 1); any = any or changed
        changed, config.medusa_frost_r = imgui.slider_float("  frost tint red", config.medusa_frost_r, 0, 1.5); any = any or changed
        changed, config.medusa_frost_g = imgui.slider_float("  frost tint green", config.medusa_frost_g, 0, 1.5); any = any or changed
        changed, config.medusa_frost_b = imgui.slider_float("  frost tint blue", config.medusa_frost_b, 0, 1.5); any = any or changed
        changed, config.medusa_frost_glow = imgui.slider_float("  icy glow", config.medusa_frost_glow, 0, 3); any = any or changed
    end
    changed, config.medusa_arena_radius = imgui.slider_float("Medusa arena radius (m)", config.medusa_arena_radius, 10, 40); any = any or changed
    if lair then
        imgui.text(string.format("  Virtual lair: center (%.0f, %.0f, %.0f), radius %.0f m", lair.center.x, lair.center.y, lair.center.z, lair.radius))
        imgui.text(string.format("  radius source: %s, %d walkable samples, %d/16 spots on walked floor",
            tostring(lair.how), #walk_samples, lair.snapped or 0))
        if imgui.button("Rebuild virtual lair around me now") then arena_center = player_upos(); lair = nil; reset_samples() end
        if arena_center and imgui.button("I'm standing at the arena EDGE - set radius") then
            local d = flat_dist(player_upos(), arena_center)
            if d then
                config.medusa_arena_radius = d; config.medusa_radius_calibrated = true; any = true; lair = nil
                log(string.format("Arena radius calibrated: %.1f m", d))
            end
        end
        if config.medusa_radius_calibrated then
            imgui.same_line()
            if imgui.button("Use automatic radius") then config.medusa_radius_calibrated = false; any = true; lair = nil end
        end
    end
    if imgui.button("Reset to defaults") then
        for k, v in pairs(default_config) do config[k] = v end
        any = true
    end
    imgui.separator()
    local parts = {}
    for k, n in pairs(stats.swapped) do table.insert(parts, n .. " " .. k) end
    imgui.text(string.format("This session: %d waves | swapped in: %s", stats.waves,
        #parts > 0 and table.concat(parts, ", ") or "none"))
    if not K.RELEASE then for _, l in ipairs(log_lines) do imgui.text(l) end end

    if any then save_config() end
    imgui.tree_pop()
end)

log("Absolute world positions (Transform.get_UniversalPosition): " .. (K.HAS_UPOS and "available" or "NOT available"))
if not K.RELEASE then pcall(function()   -- v1.9.184: dev build only
    table.sort(RR_HOOK_LIST, function(a, b) return a.a < b.a end)
    local out = { "Rancor Reinforcements " .. VERSION .. " - hooked game functions (" .. os.date() .. ")", "absolute address  name" }
    for _, h in ipairs(RR_HOOK_LIST) do table.insert(out, string.format("0x%x  %s", h.a, h.n)) end
    fs.write("RancorReinforcements_hooks.txt", table.concat(out, "\n"))
    log("Hook map: " .. #RR_HOOK_LIST .. " hooked functions written to data/RancorReinforcements_hooks.txt")
end) end
log("Loaded " .. VERSION .. " (" .. hooked .. " spawn hooks, " .. research_hooks .. " watch hooks, " .. keep_hooks .. " keep-alive hooks, " ..
    medusa_hooks .. " Medusa hooks, " ..
    #destroy_methods .. " cleanup methods; reinforcements: " ..
    (function() local t = {} for _, r in ipairs(REINFORCEMENTS) do if not r.off then table.insert(t, r.name) end end return table.concat(t, ", ") end)() .. ")")

-- 15) v1.9.35: item finder / giver (menu: "Item giver") ------------------------------------------
-- Search the game's item list by name, then give an item to yourself. All game calls run on the
-- game's update thread. The first search also writes the item manager's give-methods to
-- data/RancorReinforcements_item_methods.txt.
;(function()
    if K.RELEASE then return end   -- v1.9.120: dev tool, not in the release build
    local GV = { query = "Wyrmslife", amount = 100, results = nil, status = "", req = nil, cache = nil }
    local MSG_GET = nil
    do
        local mtd = sdk.find_type_definition("via.gui.message")
        MSG_GET = mtd and (mtd:get_method("get(System.Guid)") or mtd:get_method("get"))
    end
    local function msg(guid)
        if not guid or not MSG_GET then return nil end
        return safe(function() return MSG_GET:call(nil, guid) end)
    end
    local function item_name(param)
        -- string fields / getters first, then Guid fields whose name mentions Name
        local td = safe(function() return param:get_type_definition() end)
        local tdi = td
        while tdi do
            for _, f in ipairs(safe(function() return tdi:get_fields() end) or {}) do
                if not f:is_static() then
                    local fn = f:get_name()
                    local ftn = safe(function() return f:get_type():get_full_name() end) or ""
                    if fn:lower():find("name", 1, true) and not fn:lower():find("explain", 1, true) then
                        if ftn == "System.Guid" then
                            local g = safe(function() return param:get_field(fn) end)
                            local s2 = g and msg(g)
                            if type(s2) == "string" and s2 ~= "" then return s2 end
                        elseif ftn == "System.String" then
                            local s2 = safe(function() return param:get_field(fn) end)
                            if type(s2) == "string" and s2 ~= "" then return s2 end
                        end
                    end
                end
            end
            tdi = safe(function() return tdi:get_parent_type() end)
        end
        for _, mname in ipairs({ "get_Name", "getName", "get_NameMsg" }) do
            local s2 = safe(function() return param:call(mname) end)
            if type(s2) == "string" and s2 ~= "" then return s2 end
            if type(s2) == "userdata" then local s3 = msg(s2); if type(s3) == "string" and s3 ~= "" then return s3 end end
        end
        return nil
    end
    local function find_item_dict(im)
        local best, best_n, best_name = nil, 0, nil
        local td = im:get_type_definition()
        local tdi = td
        while tdi do
            for _, f in ipairs(tdi:get_fields() or {}) do
                if not f:is_static() then
                    local ftn = safe(function() return f:get_type():get_full_name() end) or ""
                    if ftn:find("Dictionary`2<System.Int32,", 1, true) and ftn:find("Item", 1, true) then
                        local d = safe(function() return im:get_field(f:get_name()) end)
                        local n = d and safe(function() return d:call("get_Count") end) or 0
                        if n > best_n then best, best_n, best_name = d, n, f:get_name() .. " : " .. ftn end
                    end
                end
            end
            tdi = tdi:get_parent_type()
        end
        return best, best_n, best_name
    end
    local function build_cache()
        local im = sdk.get_managed_singleton("app.ItemManager")
        if not im then return nil, "no ItemManager" end
        local dict, n, dname = find_item_dict(im)
        local list = {}
        local report = { "Rancor Reinforcements - item manager (" .. os.date() .. ")", "item table: " .. tostring(dname) .. " (" .. tostring(n) .. ")", "" }
        if dict then
            local found = 0
            for id = 0, 30000 do
                if found >= n then break end
                local has = safe(function() return dict:call("ContainsKey", id) end)
                if has == true then
                    found = found + 1
                    local p = safe(function() return dict:call("get_Item", id) end)
                    local nm = p and item_name(p)
                    table.insert(list, { id = id, name = nm or ("(no name) #" .. id) })
                end
            end
        end
        local td = im:get_type_definition()
        for _, m in ipairs(td:get_methods() or {}) do
            local nm = m:get_name()
            local l = nm:lower()
            if (l:find("item", 1, true) and (l:find("get", 1, true) or l:find("add", 1, true) or l:find("give", 1, true))) or l:find("gold", 1, true) or l:find("crystal", 1, true) then
                local ps = {}
                for _, t in ipairs(safe(function() return m:get_param_types() end) or {}) do table.insert(ps, t:get_full_name()) end
                table.insert(report, string.format("  %s(%s)", nm, table.concat(ps, ", ")))
            end
        end
        table.insert(report, "")
        for _, e in ipairs(list) do table.insert(report, string.format("%6d  %s", e.id, e.name)) end
        pcall(fs.write, "RancorReinforcements_item_methods.txt", table.concat(report, "\n"))
        return list, string.format("%d items (table %s)", #list, tostring(dname))
    end
    local function give_method(im)
        -- prefer getItem(Int32, Int32, ...) whose extra params are all value types / enums, fewest params
        local best, best_score = nil, -1
        for _, m in ipairs(im:get_type_definition():get_methods() or {}) do
            if m:get_name() == "getItem" or m:get_name() == "addItem" then
                local ps = safe(function() return m:get_param_types() end) or {}
                local p1 = ps[1] and ps[1]:get_full_name()
                local p2 = ps[2] and ps[2]:get_full_name()
                if p1 == "System.Int32" and p2 == "System.Int32" then
                    local all_vt = true
                    for i = 3, #ps do
                        if not safe(function() return ps[i]:is_value_type() end) then all_vt = false end
                    end
                    local score = (m:get_name() == "getItem" and 100 or 0) + (all_vt and 50 or 0) - #ps
                    if score > best_score then best, best_score = m, score end
                end
            end
        end
        return best
    end
    local function do_give(id, amount)
        local im = sdk.get_managed_singleton("app.ItemManager")
        local m = im and give_method(im)
        if not m then return false, "no getItem/addItem(Int32, Int32, ...) method found" end
        local ps = m:get_param_types()
        local cm = sdk.get_managed_singleton("app.CharacterManager")
        local pl = cm and safe(function() return cm["<ManualPlayer>k__BackingField"] end)
        local cid = pl and (safe(function() return pl:call("get_CharaID") end) or safe(function() return pl["<CharaID>k__BackingField"] end))
        local args, sig = {}, {}
        for i, t in ipairs(ps) do
            local tn = t:get_full_name()
            table.insert(sig, tn)
            if i == 1 then args[i] = id
            elseif i == 2 then args[i] = amount
            elseif tn == "app.CharacterID" then args[i] = cid or 1
            elseif tn == "System.Boolean" then args[i] = false
            elseif safe(function() return t:is_value_type() end) then args[i] = 0
            else
                -- a class parameter (e.g. GetItemOption): give it a fresh default object
                local o = safe(function() return sdk.create_instance(tn) end)
                if o then pcall(function() o:call(".ctor") end); pcall(function() o:add_ref() end) end
                args[i] = o
            end
        end
        local n = #ps
        local ok, err = pcall(function() return m:call(im, table.unpack(args, 1, n)) end)
        return ok, string.format("%s(%s) -> %s", m:get_name(), table.concat(sig, ", "), ok and ("ok, returned " .. tostring(err)) or tostring(err))
    end
    re.on_application_entry("UpdateBehavior", function()
        local r = GV.req
        if not r then return end
        GV.req = nil
        if r.kind == "search" then
            if not GV.cache then
                local ok, list, info = pcall(build_cache)
                if not ok or not list then GV.status = "item list error: " .. tostring(list or info); log_now("Item giver: " .. GV.status); return end
                GV.cache = list
                log_now("Item giver: " .. tostring(info) .. " - list written to data/RancorReinforcements_item_methods.txt")
            end
            local q = (GV.query or ""):lower()
            local res = {}
            for _, e in ipairs(GV.cache) do
                if q == "" or e.name:lower():find(q, 1, true) or tostring(e.id) == q then table.insert(res, e) end
                if #res >= 40 then break end
            end
            GV.results = res
            GV.status = string.format("%d match(es) for '%s'", #res, GV.query or "")
            log("Item giver: " .. GV.status)
        elseif r.kind == "give" then
            local ok, info = do_give(r.id, r.amount)
            GV.status = (ok and "Gave " or "FAILED to give ") .. r.amount .. "x " .. r.name .. " - " .. info
            log_now("Item giver: " .. GV.status)
        end
    end)
    re.on_draw_ui(function()
        if not imgui.tree_node("Rancor Reinforcements - Item giver") then return end
        local ch
        ch, GV.query = imgui.input_text("Item name contains", GV.query or "")
        ch, GV.amount = imgui.slider_int("Amount", GV.amount or 100, 1, 999)
        if imgui.button("Search items") then GV.req = { kind = "search" } end
        imgui.text(GV.status or "")
        for i, e in ipairs(GV.results or {}) do
            if imgui.button(string.format("Give %d##give%d", GV.amount, i)) then
                GV.req = { kind = "give", id = e.id, amount = GV.amount, name = e.name }
            end
            imgui.same_line()
            imgui.text(string.format("%s  (id %d)", e.name, e.id))
        end
        imgui.tree_pop()
    end)
end)()


-- =====================================================================================================
-- v1.9.122: dev-only test API, used by Claude's in-game bridge (data/claude_cmd.lua) and the offline
-- harness. It only reads state and arms the mod's existing test switches. Never present in a release build.
-- =====================================================================================================
if K.RELEASE then
    RR_DEV = nil
else
    local function region_list(chara)
        local hit = safe(function() return chara:get_Hit() end)
        if not hit then return nil end
        local out = {}
        for i = 0, 40 do
            local hp = safe(function() return hit:call("getRegionHp(System.Int32)", i) end)
            local mx = safe(function() return hit:call("getRegionOriginalMaxHp(System.Int32)", i) end)
            if hp and mx and mx > 0 then out[#out + 1] = { i = i, hp = hp, max = mx } end
        end
        return out
    end
    RR_DEV = {
        version = VERSION,
        K = K,
        REINFORCEMENTS = REINFORCEMENTS,
        defaults = default_config,
        config = function() return config end,
        save_config = function() save_config() end,
        -- v1.9.152: record-takeover spawn for the Monster Lab (the path that works for scripted
        -- bosses and the skeleton/lich family): the game's next ordinary ch2* spawn becomes `id`
        -- and is teleported in front of the player. Returns true if armed.
        test_spawn_here = function(id, no_move)
            if type(id) ~= "string" or not id_value[id] then return false, "unknown id " .. tostring(id) end
            TEST.here = id
            TEST.here_t = os.clock()
            TEST.no_move = no_move and true or nil   -- v1.9.154: parasite bosses desync when teleported
            log("Lab takeover armed: next world spawn becomes " .. id .. (no_move and " (left where it spawns)" or ""))
            return true
        end,
        test_spawn_cancel = function() TEST.here = nil end,
        test_spawn_pending = function() return TEST.here end,
        status = function()
            local n_tracked = 0
            for _ in pairs(tracked) do n_tracked = n_tracked + 1 end
            local chances = {}
            for _, rf in ipairs(REINFORCEMENTS) do chances[rf.key] = config[rf.key .. "_chance"] end
            return {
                version = VERSION, release = K.RELEASE == true, enabled = config.enabled,
                vortex = vortex_now, devouring = DEVOUR.active, wave = WAVES.cur and WAVES.cur.n or 0,
                event = event, pending_swaps = #pending_reverts, tracked = n_tracked,
                satanica_active = SATANICA.active(os.clock()), test_armed = TEST.armed, chances = chances,
                rancor_kind = K.KIND.kind, rancor_id = K.KIND.id, per_rancor = event.q,
                eye_final_share = config.eye_final_share, hooks = hooked,
            }
        end,
        -- every monster this mod placed and is still tracking
        tracked = function()
            local out = {}
            for addr, t in pairs(tracked) do
                local rf = reinforcement_for(t.name)
                local hit = t.chara and safe(function() return t.chara:get_Hit() end)
                out[#out + 1] = {
                    addr = addr, name = t.name, key = rf and rf.key,
                    hp = hit and safe(function() return hit:call("get_Hp") end),
                    max_hp = hit and safe(function() return hit:call("get_OriginalMaxHp") end),
                    age = os.clock() - (t.spawned_at or os.clock()),
                }
            end
            return out
        end,
        -- weak point / region HP of tracked monsters whose name starts with `prefix` (golem, purgener...)
        regions = function(prefix)
            local out = {}
            for _, t in pairs(tracked) do
                if not prefix or t.name:sub(1, #prefix) == prefix then out[t.name] = t.chara and region_list(t.chara) end
            end
            return out
        end,
        -- force the next big-enemy wave slot to a reinforcement key ("golem") or a character ID ("ch252000_00")
        arm = function(what)
            local rf = rf_by_key(what)
            local id = rf and rf.id or what
            if not id_value[id] then return false, "unknown id " .. tostring(id) end
            TEST.armed = id
            log("DEV: next big-enemy slot armed with " .. id)
            return true, id
        end,
        disarm = function() TEST.armed = nil end,
        -- next regular-Rancor final roll gives the Evil Eye
        force_eye_final = function() K.DEV_FORCE_EYE = true; log("DEV: next final-boss roll forced to the Evil Eye") end,
        -- v1.9.158: next Thimble finale roll forced to "drake" / "sphinx" / "vermund" (sphinx / vermund: Virulent Rancors only)
        force_finale = function(key) K.DEV_FORCE_FINALE = key; log("DEV: next Thimble finale roll forced to " .. tostring(key)) end,
        -- Devouring Rancor: choose its final boss for this fight ("purgener", "dragon", "none")
        -- Devouring Rancor: the finale roll gives this reinforcement key ("purgener"; "none" = the game's own)
        force_devour_final = function(key) K.DEV_FORCE_FINAL = key; event.final_pick = nil
            log("DEV: next Devouring finale roll forced to " .. tostring(key)) end,
        -- a living monster in the scene whose GameObject name starts with `prefix` (e.g. "ch253012")
        chara_of = function(prefix)
            for _, m in ipairs(find_components("app.Monster")) do
                local go = safe(function() return m:call("get_GameObject") end)
                local name = go and safe(function() return go:call("get_Name") end)
                if name and name:sub(1, #prefix) == prefix then
                    return safe(function() return go:call("getComponent(System.Type)", sdk.typeof("app.Character")) end), name, go
                end
            end
        end,
        -- sample the regular pick n times for the current state (no side effects)
        sample_pick = function(n, flying)
            local counts = {}
            for _ = 1, n or 1000 do
                local rf = pick_reinforcement(flying)
                local k = rf and rf.key or "none"
                counts[k] = (counts[k] or 0) + 1
            end
            return counts
        end,
        log_tail = function(n)
            local out = {}
            for i = math.max(1, #file_lines - (n or 40) + 1), #file_lines do out[#out + 1] = file_lines[i] end
            return out
        end,
        log = function(msg) log("DEV: " .. tostring(msg)) end,
        -- v1.9.164: Rancor Brine Sphinx warp tests. sphinx_warp(0..5) asks her warp controller for that warp
        -- (0 BattleWarp, 1 SubdueSucceed, 2 DestroyWarp, 3 WarpToTreasureBox, 4 OutOfStage, 5 gaze dodge)
        sphinx_warp = function(sit)
            local out = {}
            for a, e in pairs(K.SPX.wc) do
                local ok, r = pcall(function() return e.wc:call("requestWarp(app.Ch253001WarpController.WarpSituationEnum)", sit) end)
                out[#out + 1] = string.format("%s: requestWarp(%s) -> %s %s", e.name, tostring(K.SPX.SIT[sit] or sit), tostring(ok), tostring(r))
            end
            return out
        end,
        sphinx = function()
            local out = {}
            for a, e in pairs(K.SPX.wc) do
                local f = function(n) return tostring(safe(function() return e.wc:get_field(n) end)) end
                local p, pp = K.SPX.read_pos(e.wc, "WarpPosition"), player_upos()
                local up = upos_go(e.t.go)
                out[#out + 1] = string.format("%s: phase %s, situation %s, destroy %s, warp point %s m, she is %s m from you, warps %d, fixed %d",
                    e.name, f("WarpPhase"), f("WarpSituation"), f("WarpDestroy"),
                    (p and pp) and string.format("%.0f", flat_dist(pp, p) or -1) or "?", (up and pp) and string.format("%.0f", flat_dist(pp, up) or -1) or "?",
                    e.warps or 0, e.fixed or 0)
            end
            return out
        end,
    }
    log("Dev test API ready (RR_DEV)")
end
