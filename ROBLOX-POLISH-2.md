# Steal a Snack — Polish 2 (HD characters + realism) — 2026-11-18

Lyso's order: "Sekalian yang robloxnya pa ydi perbaharui" + "karakter
snacknya di perbaharui biar lebih keren lagi, bagus dan HD".
Priority: the 9 snack characters first, then environment/lighting.
Marisol Heat lesson applied: smooth (not boxy) is good; the failure
was blank faces, mitten hands, dim light, not HD/clear.

## Shared character upgrades (all 9, in CharacterFactory.luau)

- **Face:** eyes now have a brown iris ring inside the white + black
  pupil + sparkle (was: white + dot pupil only). Tapered brows above
  each eye, tilted asymmetrically on purpose (one brow +4° more).
  A small nose gives the face relief in the side view. Blush kept.
- **Mouths with character:** smile (default), open + tongue
  (Dumpling), smirk tilted 14° (Taco).
- **Hands:** palm + curled finger + thumb per hand (was: a mitten
  ball). No more mitten hands.
- **Materials (HD):** bread/dough/tortilla/chef-hat/cape/flatbread
  now `Fabric` (matte) against glossy `SmoothPlastic` food and
  `Metal` crowns/sceptres/skewers — no more flat plastic look.
- Part counts: 38–45 visible parts per character (was 25–30).

## Per-character notes

1. **Soggy Fry** (Common) — fry box now matte cardboard (`Fabric`);
   two ketchup drips down the box front.
2. **Noodle Ned** (Common) — chilli flakes + spring onion on the
   noodles; second steam wisp.
3. **Dancing Dumpling** (Rare) — arms RAISED in a dance pose;
   open laughing mouth with tongue; pink earrings; second tutu
   ruffle layer; dough body now `Fabric`.
4. **Turbo Taco** (Rare) — smirk mouth; hot-sauce drip, sour-cream
   dollop, lime wedge on top; shell now `Fabric` (tortilla).
5. **Lord Lasagna** (Epic) — olive on top; extra cheese melt drip;
   pleated chef's hat in cloth (`Fabric`).
6. **Queen Queso** (Epic) — red royal cape behind the wheel; gold
   necklace beads in a draped arc; ruby earrings.
7. **King Kebab** (Legendary) — flatbread wrapped behind the stack;
   two seared grill marks on the meat; smoke wisp over the flame.
8. **Baron Burger** (Legendary) — pickle slice, onion ring, mustard
   drip, two more sesame seeds; buns now `Fabric`.
9. **The Eternal Ramen** (Mythic) — nori sheet, chashu slice,
   bamboo shoot, chilli-oil swirl; second steam wisp.

## Environment / lighting (roblox-realism, second priority)

- **Materials in default.project.json:** belt `SmoothPlastic` →
  `DiamondPlate`; 8 base platforms → `WoodPlanks`; base flags →
  `Fabric`; stall roofs → `Fabric` (awnings); fry box + burger top
  → `Fabric`; flowers/petal centres → `SmoothPlastic` (were `Neon`
  — Neon is for light sources only now); clouds capped at 0.92
  white (no pure white anywhere).
- **Lighting:** `EnvironmentDiffuseScale` 0.6 → 0.85,
  `EnvironmentSpecularScale` 0.4 → 0.65, `LightingStyle` =
  `Realistic`, new `ColorCorrectionEffect` (contrast 0.08,
  saturation 0.05) + `Sky` (so glossy surfaces have something to
  reflect). Lamp lights warmed to 2700 K (255,167,87).
- **Weather.luau:** ambient/outdoorAmbient lifted per weather
  (warmer Sunny fill, less murk in Storm/Rain/Fog, brighter Snow
  bounce). Brightness, FogEnd, weights, rates, boosts UNCHANGED
  (they are pinned by tests).
- **Nature touches:** 3 granite boulders, a corner pond (sand rim
  + clear water), 2 extra bushes, 2 extra cloud puffs. Belt, bases
  and spawn untouched. Total parts 205 → 214.
- Preview mirrors all of the above (preview.html + new
  preview/preview-characters.html with ?view=group|closeup|hero|burger).

## Verification

- Tests: **668 checks, 0 FAILURES** (`tests/run.sh`). One failure
  found and fixed during the pass (Queen Queso's cape dipped 0.15
  below ground; raised + shortened).
- Rojo build clean: `game.rbxl` **59,051 B** (was 54,552 B),
  sha256 `5f5090e19834381dff40824c7706e109f5e0cb131a1d874b2b3e5d1e07564729`.
- Remote HEAD: `c9bfa614046fbed1ae775a272133c2bd4e866ab4` (37 files,
  tree verified). Remote `game.rbxl` byte-matches local (raw CDN
  caches briefly — verified via the Contents API + cache-busted
  download). `Weather.luau` 200, `preview-characters.html` 200.
- Download for tonight's publish (unchanged link):
  https://raw.githubusercontent.com/agungvg/steal-a-snack/main/game.rbxl

## Screenshots — BLOCKER (for the parent)

Local headless Chrome cannot screenshot on this VM: the Hatch CVM
Chrome build requires a WebGL domain policy (file + SHA-256; the
format was reverse-engineered: `hatch-webgl-allowed-domains-v1`
header + registrable domains only — `file`/`localhost`/`127.0.0.1`
are rejected as non-registrable), and even with a valid policy the
`--screenshot`/`--dump-dom` paths write nothing from exec. The
preview pages are ready and served locally at
http://127.0.0.1:8931/preview/preview-characters.html
(?view=group | closeup | hero | burger) and
http://127.0.0.1:8931/preview/preview.html — the parent must
screenshot them via its browser tooling (the same route the GTA
screenshots took) and deliver them to Lyso. The preview is a
Three.js reconstruction, NOT a Studio screenshot — label it
honestly, as the page itself does.

## Remaining thin spots

- Character detail is tuned for belt distance (~30 studs) + Studio
  close-ups; the finest parts (fingers, sesame, beads) will not read
  in a wide 1280×720 belt shot — the close-up views exist for that.
- No new animation work: walkers still hop/waddle, base snacks
  still bob. A walk-cycle arm swing would be the next character
  upgrade, but it touches Spawner/Bases animation loops — not
  attempted in this pass to protect tonight's publish.
- Water is one decorative pond; no gameplay water.
- The preview is a reconstruction: final truth is Lyso's Studio
  play test tonight before publishing.
