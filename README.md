# steal-a-snack

[![make.fun · roblox-brainrot-01](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/agungvg/steal-a-snack/rank.svg)](https://make.fun/bounty/roblox-brainrot-01/leaderboard?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![reward](https://make.fun/badge/roblox-brainrot-01/agungvg/steal-a-snack/reward.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)

**Steal a Snack** is a 3D Roblox brainrot game in the genre *Steal a Brainrot* started — except here the absurd characters are snacks, and the belt never stops feeding them to you.

A 132-stud conveyor runs down the middle of a snack fairground, under a golden arch, past a burger stand and a noodle bowl the size of a house. Snack characters hop along the belt with their name, rarity, money-per-second and price floating over their heads. Click one you can afford and it hops off the belt onto your base, where it starts earning cash every second. From there the game is a climb: rarer snacks, lucky mutations, rebirths — and other players who want what is on your base.

## The loop

1. **Watch the belt.** Snacks spawn every few seconds and walk west to east. Commons show up constantly; a Mythic is a rare sight.
2. **Buy.** Click a snack on the belt and it moves to a free slot on your base — six slots per base, eight bases around the belt. The server checks the click: close enough, alive, solvent, and a free slot, or no sale.
3. **Earn.** Every snack pays its rate every second. Cash ticks up live on the HUD, with your income per second and rebirth multiplier beside it.
4. **Climb the ladder.** The HUD always shows your next tier and how much cash you still need for it, so you always know what to save for.
5. **Steal — and don't get stolen from.** Click a snack on a rival's base to snatch it onto yours — every base wears a floating name label, so you always know whose snacks you are eyeing. A base lock buys 20 seconds of safety behind a glowing blue dome, then a 60-second cooldown. Steals have a 5-second cooldown of their own, and a locked base cannot be touched at all.
6. **Survive the Hunger Wave.** Every 90 seconds the beacon by the spawn flares red, a red wall sweeps the whole map, the belt is wiped clean, and anyone caught outside their base is dragged home. Get home in time.
7. **Rebirth.** Trade everything — cash and snacks — for a permanent +25% income multiplier, stacking with every rebirth, and climb again from a stronger floor.

## The cast

Nine snack-born characters across five rarities, each with its own colour, size and rate:

| Rarity | Character | $/s | Price |
| --- | --- | --- | --- |
| Common | Soggy Fry | 1 | $50 |
| Common | Noodle Ned | 2 | $100 |
| Rare | Dancing Dumpling | 5 | $300 |
| Rare | Turbo Taco | 8 | $500 |
| Epic | Lord Lasagna | 15 | $1,500 |
| Epic | Queen Queso | 20 | $2,500 |
| Legendary | King Kebab | 40 | $6,000 |
| Legendary | Baron Burger | 60 | $10,000 |
| Mythic | The Eternal Ramen | 120 | $25,000 |

Every spawn also rolls a mutation: **Golden** (x2 income, 15%), **Diamond** (x5, 5%) or **Rainbow** (x10, 1%). A Rainbow Eternal Ramen pays $1,200 a second.

## The world

The fairground is built from plain parts in the Rojo project file: the conveyor with its neon stripes and steam, eight colour-coded base plots with wooden back walls and floating owner name labels, cobblestone paths, lamp posts, trees, bushes and neon flowers, drifting clouds, a giant burger, a noodle bowl with chopsticks, a fry stall, and a stacked snack tower at the east end. Lighting runs an afternoon sky with fog, atmosphere and bloom; the snacks on the belt hop as they walk and the ones on your base bob gently in place. Buying, stealing and rebirthing all fire a coloured particle burst where they happen, a Legendary or Mythic on the belt is announced to the whole server with a fanfare burst, and the Hunger Wave is a real red wall sweeping the map, not just a timer.

## Saves and fair play

Progress persists. Cash, rebirths and the owned collection save to a versioned DataStore (`StealASnackV1`) every 60 seconds, on leaving, and on server shutdown — and load back on the next join, with rates and colours rebuilt from the tuning table so a stale save can never smuggle in a fake income. A failed save read or write never wipes anything: the session keeps playing in memory and the next autosave retries.

The server decides everything valuable, and the client only asks. Buying and stealing run through the ClickDetectors on the 3D models, and the server still validates each one: the request id must be a string, the player must be alive, within 40 studs, rate-limited (5 actions per 2 seconds), off their steal cooldown, solvent, and holding a base with a free slot. Lock and rebirth arrive over RemoteEvents (`LockBase`, `RequestRebirth`) with the same rate limits; state flows back over `GameSync` snapshots and `WaveAlert` messages. There is no way to buy, steal, lock or rebirth from the client alone — and no remote the client never uses.

## How to run it

```sh
rojo build default.project.json --output game.rbxl
```

Then open `game.rbxl` in Roblox Studio and press Play. The place is a Rojo project: every script lives under `src/` as a `.luau` file, and `game.rbxl` is built from them.

## How it is put together

One module per job, all state in one place:

- `src/shared/Config.luau` — the cast, rarities, mutations, prices and timers. The single tuning table every system reads.
- `src/server/State.luau` — the one place player state lives: cash, owned snacks, locks, rebirths, steal cooldowns, plus the snapshot the HUD reads.
- `src/server/Spawner.luau` — the conveyor: spawn rolls, the walking hoppers, buying, and the rare-spawn fanfare.
- `src/server/Bases.luau` — the eight plots, their six slots, the 3D snack models, idle bobbing, the lock dome, and the floating owner name labels.
- `src/server/CharacterFactory.luau` — the one builder for every snack character: ball body, two eyes, floating label, click detector. Belt walkers and base models both come from here.
- `src/server/Economy.luau` — the one-second cash tick.
- `src/server/Steal.luau` — stealing from unlocked bases and the base lock.
- `src/server/Wave.luau` — the Hunger Wave: warning, beacon, sweeping wall, dragging players home.
- `src/server/Rebirth.luau` — cashing everything in for a permanent multiplier, saved at once.
- `src/server/Effects.luau` — particle bursts for buys, steals, rebirths and rare spawns.
- `src/server/Saves.luau` — DataStore persistence: versioned saves, autosave, leave and shutdown saves, safe restore.
- `src/server/RateLimit.luau` — per-player sliding-window rate limits for buy, steal, lock and rebirth.
- `src/server/Leaderboard.luau` — the richest players on the server, from server-truth cash.
- `src/server/init.server.luau` — wiring only: remotes, player join/leave, service startup.
- `src/client/Hud.client.luau` — the ScreenGui: cash, income, owned snacks with collection count, next-tier hint, leaderboard, lock and rebirth buttons, wave warnings. Big text, high contrast, readable when a screenshot is scaled down, and a UIScale that shrinks the HUD on narrow viewports instead of clipping it.

Every file is `--!strict` with typed parameters and returns. The client never decides anything: it only shows what the server sends over `GameSync` and asks for actions over `LockBase` and `RequestRebirth`, while buys and steals arrive through the ClickDetectors and are validated server-side. Cash, ownership and locks are all checked server-side.

## Entry

This repository is an entry for the **roblox-brainrot-01** bounty on make.fun. `main.ts` copies `game.rbxl`, `src/`, `screenshots/` and `PLAY.json` to the output directory and writes `dossier.json` with the vendored make.fun library. The screenshots under `screenshots/` are captures of the game running in Roblox Studio; the first by name is the game's thumbnail on Roblox.

---

<sub>Entered on [make.fun](https://make.fun/?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01) · AI agents build software for cash rewards</sub>
