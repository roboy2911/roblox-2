# Realm of Crowns

Open-world medieval fantasy action RPG on Roblox. The design doc is
"Realm of Crowns — Game Design Basics" in Claude Docs.

## What's built so far

Build order steps from the design doc:

- [x] **1. Saving and leveling:** XP, levels (cap 300), 3 stat points per level, a level bar. Data saves with DataStores.
- [x] **2. Basic combat:** Brawler 3-hit click combo, HP bars, three training dummies.
- [x] **3. Enemies:** Rats that wander, chase, bite, die, drop XP and gold, and respawn.
- [x] **4. Quests:** Elder Bram in Millbrook gives a Rats quest and a Bandit Thugs quest (Lv. 10+).

## Setup

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then in this folder run:

   ```bash
   rokit install
   ```

2. Install the Rojo plugin in Roblox Studio (Plugins tab, or from the Rojo website).
3. Open a place in Studio (the Baseplate template is fine). Publish it to Roblox,
   then turn on **Game Settings > Security > Enable Studio Access to API Services**
   so saving works in Studio.
4. Start the Rojo server:

   ```bash
   rojo serve
   ```

5. In Studio, open the Rojo plugin and click **Connect**. Then press Play.

## How to test

**Step 1, saving and leveling**

- Your level, XP bar and HP bar are at the bottom of the screen.
- In Studio, type `/xp 500` in chat to gain XP (also `/gold 1000` and `/resetdata`).
  These commands only work in Studio.
- Stop the game and press Play again: your level should still be there.
- If you see "Progress is not saving this session", Studio API access is off (see Setup step 3).

**Step 2, combat**

- Walk to the dirt circle with the sign (in front of spawn).
- Click to attack: right jab, left jab, then a crouching uppercut. You auto-turn
  toward the nearest dummy and lunge into each punch.
- Hits land when the fist connects: impact flash, shockwave ring, sparks and dust,
  camera shake, a tiny freeze-frame, and the dummy wobbles back.
- Defeat a dummy for 40 XP; it falls over and gets back up after 3 seconds.
- Punch animations need R15 characters (Game Settings > Avatar).

**Step 3, enemies**

- Walk to the **Rat Field** (dirt patch with barrels and hay, to the left of spawn).
- Rats wander around. Get close and they chase you. Before biting they rear back:
  move away or behind them to dodge.
- Your hits interrupt bites and knock rats back; the uppercut launches them.
- A rat gives 30 XP and 8 to 14 gold, then respawns 15 seconds later.
- Lead a rat far from its field and it gives up, walks home and heals.

**Step 4, quests**

- Elder Bram stands near spawn by a market stall, with a "!" over his head.
  Walk up and press **E** to talk.
- **Rat Problem** (Lv. 1+): defeat 6 Rats for 270 XP and 60 gold.
- **Bandit Trouble** (Lv. 10+): defeat 6 Bandit Thugs at the Bandit Camp (right of
  spawn) for 990 XP and 200 gold. Bandit Thugs raise their sword before slashing.
- The tracker in the top right shows progress. Quests finish on their own when
  you reach the count, and your active quest is saved.
- Studio shortcut: `/level 10` jumps to a level.

## Project layout

```
src/shared/          ReplicatedStorage.Shared (used by server and client)
  Config/            numbers from the design doc: leveling, combat, enemies, asset IDs
  Remotes.luau       all RemoteEvents
src/server/          ServerScriptService.Server
  Main.server.luau   starts the services
  Services/          DataService, LevelingService, CharacterService,
                     CombatService, Damageable, TrainingGround,
                     EnemyRig, EnemyService, DevCommands
src/client/          StarterPlayerScripts.Client
  Main.client.luau   starts the controllers
  Controllers/       HUD, CombatController, HealthBars, EnemyAnimator, Feedback
  Combat/            punch keyframes, the animator that plays them, hit effects
blender/             Blender scripts that build the 3D models
tools/               upload_model.py: uploads a model to Roblox with Open Cloud
```

## Models and textures

Every model and effect image is made in Blender from Python scripts, with our
own baked textures (no Roblox materials or built-in images):

- `blender/common.py`: shared shapes, procedural materials (wood, straw, fur,
  cloth, metal, dirt...) and the bake-and-export step
- `blender/training_dummy.py`, `rat.py`, `characters.py` (quest giver, bandit),
  `props.py` (barrel, hay bale, crate, tent, campfire, sign, dirt pad, stall),
  `effects.py` (spark, dust, glow, ring, trail images)

To rebuild and upload (needs `pip install bpy`, plus `ROBLOX_API_KEY` and
`ROBLOX_USER_ID` set):

```bash
python blender/props.py blender/out
```

(and the same for the other scripts), then:

```bash
python tools/build_assets.py blender/out
```

That uploads anything that changed and rewrites `src/shared/Config/Assets.luau`.
Textures are uploaded as Decals; the server looks up their image IDs when it
starts (`AssetService`).

The game can only load these assets if the place is owned by the same account
that uploaded them. If they can't load, simple stand-in blocks are used so the
game still works.
