# Realm of Crowns

Open-world medieval fantasy action RPG on Roblox. The design doc is
"Realm of Crowns — Game Design Basics" in Claude Docs.

## What's built so far

Build order steps from the design doc:

- [x] **1. Saving and leveling:** XP, levels (cap 300), 3 stat points per level, a level bar. Data saves with DataStores.
- [x] **2. Basic combat:** Brawler 3-hit click combo, HP bars, three training dummies.
- [ ] 3. Enemies (Rats)
- [ ] 4. Quests

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
- Click to punch: right, left, then a heavier right. Wait a moment and the combo starts over.
- The dummy shows damage numbers and an HP bar. Defeat it for 40 XP; it gets back up after 3 seconds.

## Project layout

```
src/shared/          ReplicatedStorage.Shared (used by server and client)
  Config/            numbers from the design doc: leveling, combat, asset IDs
  Remotes.luau       all RemoteEvents
src/server/          ServerScriptService.Server
  Main.server.luau   starts the services
  Services/          DataService, LevelingService, CharacterService,
                     CombatService, Damageable, TrainingGround, DevCommands
src/client/          StarterPlayerScripts.Client
  Main.client.luau   starts the controllers
  Controllers/       HUD, CombatController, HealthBars
blender/             Blender scripts that build the 3D models
tools/               upload_model.py: uploads a model to Roblox with Open Cloud
```

## Models

Models are built from Python scripts in `blender/` so they can be changed and
rebuilt. To rebuild and upload one (needs `pip install bpy`, plus
`ROBLOX_API_KEY` and `ROBLOX_USER_ID` set):

```bash
python blender/training_dummy.py blender/out
```

```bash
python tools/upload_model.py blender/out/TrainingDummy.fbx "Realm of Crowns - Training Dummy"
```

Put the printed asset ID in `src/shared/Config/Assets.luau`.

The game loads models with `InsertService`, which only works if the place is
owned by the same account that owns the model. If it can't load, the game
builds a simple dummy out of parts instead, so testing still works.
