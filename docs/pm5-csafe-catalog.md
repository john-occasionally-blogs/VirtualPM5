# PM5 CSAFE TX/RX Catalog — erg-row-2026-07-16.log

Source: tethered console log, real PM5 XXXXXXXXX, app v2.31.2 (578).
Every `📤 CSAFE` TX paired with the next `📥 CSAFE ok` / `❌ reject` seen before the next TX.

## Session-order TX→RX log

| # | log line | TX name | TX hex | RX line | RX status | RX hex |
|---|---|---|---|---|---|---|
| 1 | 1267 | TIME_WORKOUT_0x76 | `F1 76 18 01 01 05 03 05 00 00 00 17 70 05 05 00 00 00 17 70 14 01 01 13 02 01 01 68 F2` | 1276 | ok (ready) | `F1 81 76 05 01 03 05 14 13 F3 02 F2` |
| 2 | 5116 | DISTANCE_WORKOUT | `F1 87 21 03 E8 03 24 24 02 00 00 85 C9 F2` | 5123 | ok (inUse) | `F1 05 05 F2` |
| 3 | 8046 | TIME_WORKOUT_0x76 | `F1 76 18 01 01 05 03 05 00 00 00 17 70 05 05 00 00 00 17 70 14 01 01 13 02 01 01 68 F2` | 8066 | ok (inUse) | `F1 85 76 05 01 03 05 14 13 F6 F2` |
| 4 | 13687 | TERMINATE_STALE_PIECE | `F1 76 04 13 02 01 02 60 F2` | 13694 | ok (finished) | `F1 07 76 01 13 63 F2` |
| 5 | 13701 | DISTANCE_WORKOUT | `F1 87 21 03 E8 03 24 24 02 00 00 85 C9 F2` | 13719 | ok (inUse) | `F1 85 85 F2` |
| 6 | 38914 | TERMINATE_STALE_PIECE | `F1 76 04 13 02 01 02 60 F2` | 38946 | ok (ready) | `F1 01 76 01 13 65 F2` |
| 7 | 38953 | DISTANCE_WORKOUT_0x76_SUB500 | `F1 76 18 01 01 03 03 05 80 00 00 00 FA 05 05 80 00 00 00 FA 14 01 01 13 02 01 01 6E F2` | 38960 | ok (ready) | `F1 81 76 05 01 03 05 14 13 F3 02 F2` |
| 8 | 41268 | SEGMENT_GO_FINISHED | `F1 86 86 F2` | 41303 | REJECT (prev-frame) | `F1 99 99 F2` |
| 9 | 41334 | SEGMENT_GO_IDLE | `F1 82 82 F2` | — | NO RESPONSE LOGGED | — |
| 10 | 41367 | TERMINATE_STALE_PIECE | `F1 76 04 13 02 01 02 60 F2` | 41370 | ok (offline) | `F1 09 76 01 13 6D F2` |
| 11 | 41396 | DISTANCE_WORKOUT_0x76_SUB500 | `F1 76 18 01 01 03 03 05 80 00 00 00 FA 05 05 80 00 00 00 FA 14 01 01 13 02 01 01 6E F2` | 41413 | ok (ready) | `F1 81 76 05 01 03 05 14 13 F3 02 F2` |
| 12 | 42953 | SEGMENT_GO_FINISHED | `F1 86 86 F2` | 42970 | REJECT (prev-frame) | `F1 91 91 F2` |
| 13 | 43039 | SEGMENT_GO_IDLE | `F1 82 82 F2` | 43053 | ok (idle) | `F1 02 02 F2` |
| 14 | 55618 | TERMINATE_STALE_PIECE | `F1 76 04 13 02 01 02 60 F2` | 55645 | ok (manual) | `F1 88 76 01 13 EC F2` |
| 15 | 55652 | DISTANCE_WORKOUT_0x76_SUB500 | `F1 76 18 01 01 03 03 05 80 00 00 00 FA 05 05 80 00 00 00 FA 14 01 01 13 02 01 01 6E F2` | 55678 | ok (idle) | `F1 02 76 05 01 03 05 14 13 71 F2` |
| 16 | 58140 | SEGMENT_GO_FINISHED | `F1 86 86 F2` | 58153 | REJECT (prev-frame) | `F1 18 18 F2` |
| 17 | 58220 | SEGMENT_GO_IDLE | `F1 82 82 F2` | — | NO RESPONSE LOGGED | — |
| 18 | 58259 | TERMINATE_STALE_PIECE | `F1 76 04 13 02 01 02 60 F2` | 58265 | ok (manual) | `F1 88 76 01 13 EC F2` |
| 19 | 58289 | DISTANCE_WORKOUT_0x76_SUB500 | `F1 76 18 01 01 03 03 05 80 00 00 00 FA 05 05 80 00 00 00 FA 14 01 01 13 02 01 01 6E F2` | 58305 | ok (idle) | `F1 02 76 05 01 03 05 14 13 71 F2` |
| 20 | 59849 | SEGMENT_GO_FINISHED | `F1 86 86 F2` | 59866 | REJECT (prev-frame) | `F1 12 12 F2` |
| 21 | 59951 | SEGMENT_GO_IDLE | `F1 82 82 F2` | — | NO RESPONSE LOGGED | — |
| 22 | 72134 | TERMINATE_STALE_PIECE | `F1 76 04 13 02 01 02 60 F2` | 72160 | ok (manual) | `F1 88 76 01 13 EC F2` |
| 23 | 72168 | DISTANCE_WORKOUT_0x76_SUB500 | `F1 76 18 01 01 03 03 05 80 00 00 00 FA 05 05 80 00 00 00 FA 14 01 01 13 02 01 01 6E F2` | 72174 | ok (idle) | `F1 02 76 05 01 03 05 14 13 71 F2` |
| 24 | 76166 | SEGMENT_GO_FINISHED | `F1 86 86 F2` | 76178 | REJECT (prev-frame) | `F1 18 18 F2` |
| 25 | 79300 | TERMINATE_STALE_PIECE | `F1 76 04 13 02 01 02 60 F2` | 79307 | ok (manual) | `F1 88 76 01 13 EC F2` |
| 26 | 79322 | DISTANCE_INTERVAL_0x76 | `F1 76 18 01 01 07 03 05 80 00 00 00 FA 04 02 00 1E 18 01 03 14 01 01 13 02 01 01 12 F2` | 79340 | ok (idle) | `F1 02 76 06 01 03 04 18 14 13 6B F2` |
| 27 | 96087 | DISTANCE_WORKOUT_0x76_SUB500 | `F1 76 18 01 01 03 03 05 80 00 00 00 FA 05 05 80 00 00 00 FA 14 01 01 13 02 01 01 6E F2` | 96108 | ok (manual) | `F1 88 76 05 01 03 05 14 13 FB F2` |
| 28 | 98371 | SEGMENT_GO_FINISHED | `F1 86 86 F2` | 98373 | REJECT (prev-frame) | `F1 98 98 F2` |
| 29 | 98425 | SEGMENT_GO_IDLE | `F1 82 82 F2` | — | NO RESPONSE LOGGED | — |
| 30 | 98442 | TERMINATE_STALE_PIECE | `F1 76 04 13 02 01 02 60 F2` | 98467 | ok (manual) | `F1 08 76 01 13 6C F2` |
| 31 | 98484 | DISTANCE_WORKOUT_0x76_SUB500 | `F1 76 18 01 01 03 03 05 80 00 00 00 FA 05 05 80 00 00 00 FA 14 01 01 13 02 01 01 6E F2` | 98511 | ok (idle) | `F1 82 76 05 01 03 05 14 13 F3 01 F2` |
| 32 | 117759 | SEGMENT_GO_FINISHED | `F1 86 86 F2` | 117777 | REJECT (prev-frame) | `F1 98 98 F2` |
| 33 | 119614 | TERMINATE_STALE_PIECE | `F1 76 04 13 02 01 02 60 F2` | 119618 | ok (manual) | `F1 08 76 01 13 6C F2` |
| 34 | 119631 | TIME_WORKOUT_0x76 | `F1 76 18 01 01 05 03 05 00 00 00 46 50 05 05 00 00 00 46 50 14 01 01 13 02 01 01 68 F2` | 119639 | ok (idle) | `F1 82 76 05 01 03 05 14 13 F3 01 F2` |

## Distinct TX frames (dedup)

| count | name | hex |
|---|---|---|
| 9 | TERMINATE_STALE_PIECE | `F1 76 04 13 02 01 02 60 F2` |
| 7 | DISTANCE_WORKOUT_0x76_SUB500 | `F1 76 18 01 01 03 03 05 80 00 00 00 FA 05 05 80 00 00 00 FA 14 01 01 13 02 01 01 6E F2` |
| 7 | SEGMENT_GO_FINISHED | `F1 86 86 F2` |
| 5 | SEGMENT_GO_IDLE | `F1 82 82 F2` |
| 2 | TIME_WORKOUT_0x76 | `F1 76 18 01 01 05 03 05 00 00 00 17 70 05 05 00 00 00 17 70 14 01 01 13 02 01 01 68 F2` |
| 2 | DISTANCE_WORKOUT | `F1 87 21 03 E8 03 24 24 02 00 00 85 C9 F2` |
| 1 | DISTANCE_INTERVAL_0x76 | `F1 76 18 01 01 07 03 05 80 00 00 00 FA 04 02 00 1E 18 01 03 14 01 01 13 02 01 01 12 F2` |
| 1 | TIME_WORKOUT_0x76 | `F1 76 18 01 01 05 03 05 00 00 00 46 50 05 05 00 00 00 46 50 14 01 01 13 02 01 01 68 F2` |

## Distinct RX frames (dedup)

| count | status | hex |
|---|---|---|
| 4 | ok (manual) | `F1 88 76 01 13 EC F2` |
| 3 | ok (ready) | `F1 81 76 05 01 03 05 14 13 F3 02 F2` |
| 3 | ok (idle) | `F1 02 76 05 01 03 05 14 13 71 F2` |
| 2 | ok (manual) | `F1 08 76 01 13 6C F2` |
| 2 | ok (idle) | `F1 82 76 05 01 03 05 14 13 F3 01 F2` |
| 1 | ok (inUse) | `F1 05 05 F2` |
| 1 | ok (inUse) | `F1 85 76 05 01 03 05 14 13 F6 F2` |
| 1 | ok (finished) | `F1 07 76 01 13 63 F2` |
| 1 | ok (inUse) | `F1 85 85 F2` |
| 1 | ok (ready) | `F1 01 76 01 13 65 F2` |
| 1 | ok (offline) | `F1 09 76 01 13 6D F2` |
| 1 | ok (idle) | `F1 02 02 F2` |
| 1 | ok (idle) | `F1 02 76 06 01 03 04 18 14 13 6B F2` |
| 1 | ok (manual) | `F1 88 76 05 01 03 05 14 13 FB F2` |
| 2 | REJECT | `F1 18 18 F2` |
| 2 | REJECT | `F1 98 98 F2` |
| 1 | REJECT | `F1 99 99 F2` |
| 1 | REJECT | `F1 91 91 F2` |
| 1 | REJECT | `F1 12 12 F2` |

## Byte-level decode of each distinct TX frame

All frames: `F1 <contents> <checksum=XOR of contents> F2`. 0x76 = CSAFE_SETUSERCFG1 (PM-proprietary wrapper); PM subcommands inside are `<id> <len> <data…>`.

**TIME_WORKOUT_0x76** (60s: `…17 70…`; 3min: `…46 50…`):
`76 18` wrapper len 24, then
- `01 01 05` PM_SET_WORKOUTTYPE = 5 (FIXEDTIME_SPLITS)
- `03 05 00 00 00 17 70` PM_SET_WORKOUTDURATION type=0x00 (time), u32BE 0x1770=6000 ×0.01s = 60.00s (3min frame: 0x4650=18000 = 180.00s)
- `05 05 00 00 00 17 70` PM_SET_SPLITDURATION type=0x00, 6000 = split=whole piece
- `14 01 01` PM_CONFIGURE_WORKOUT = 1 (programmed)
- `13 02 01 01` PM_SET_SCREENSTATE screenType=1 (workout), screenValue=1 (PREPARETOROWWORKOUT)

**DISTANCE_WORKOUT_0x76_SUB500** (250m): same shape with
- `01 01 03` WORKOUTTYPE = 3 (FIXEDDIST_SPLITS)
- `03 05 80 00 00 00 FA` WORKOUTDURATION type=0x80 (distance), 0xFA = 250 m
- `05 05 80 00 00 00 FA` SPLITDURATION distance 250 m
- `14 01 01`, `13 02 01 01` as above

**DISTANCE_INTERVAL_0x76** (3×250m/0:30r): `76 18` then
- `01 01 07` WORKOUTTYPE = 7 (FIXEDDIST_INTERVAL)
- `03 05 80 00 00 00 FA` WORKOUTDURATION distance 250 m (per interval)
- `04 02 00 1E` PM_SET_RESTDURATION u16BE 0x001E = 30 s
- `18 01 03` PM_SET_WORKOUTINTERVALCOUNT = 3
- `14 01 01`, `13 02 01 01` as above
(NOTE: PM5 echoed acceptance of all six ids `01 03 04 18 14 13` — see RX — yet still armed a 4th work interval after rest 3; see findings.)

**DISTANCE_WORKOUT** (1000m, public dialect, no 0x76):
- `87` CSAFE_GOREADY
- `21 03 E8 03 24` CSAFE_SETHORIZONTAL len 3: u16LE 0x03E8=1000, unit 0x24 (meters)
- `24 02 00 00` CSAFE_SETPROGRAM len 2, program 0 (programmed workout)
- `85` CSAFE_GOINUSE

**TERMINATE_STALE_PIECE**: `76 04 13 02 01 02` = PM_SET_SCREENSTATE screenType=1, screenValue=2 (TERMINATEWORKOUT)

**SEGMENT_GO_FINISHED**: `86` CSAFE_GOFINISHED (bare). **SEGMENT_GO_IDLE**: `82` CSAFE_GOIDLE (bare).

## RX frame anatomy

`F1 <status> [76 <n> <accepted-subcmd-ids…>] <checksum> F2`, with byte-stuffing on checksum (`F3 02`→0xF2, `F3 01`→0xF1).

Status byte = frame-toggle (bit7) | prevFrameStatus (bits 5-4: 0=ok, 1=reject) | slave state (bits 3-0):
1=ready, 2=idle, 5=inUse, 7=finished, 8=manual, 9=offline.

- Full-program accept echoes every subcommand id, e.g. `F1 81 76 05 01 03 05 14 13 F3 02 F2` = ready, accepted {01,03,05,14,13}. Interval accept: `F1 02 76 06 01 03 04 18 14 13 6B F2` = idle, accepted {01,03,04,18,14,13}.
- TERMINATE accept echoes only `13`: `F1 07 76 01 13 63 F2` (state varies: finished/ready/offline/manual).
- Public-dialect DISTANCE_WORKOUT gets a bare status frame (`F1 05 05 F2` / `F1 85 85 F2` = inUse) — standard commands are not echoed.
- ALL 7 SEGMENT_GO_FINISHED writes were REJECTED (`F1 99/91/18/12/98` — prevFrameStatus=1). PM5 was already past the piece (self-logged): slave state at reject time was offline(9)/ready(1)/manual(8)/idle(2)/manual/manual/manual. GOFINISHED from those states is illegal.
- 5 of 5 SEGMENT_GO_IDLE writes after a reject got either `F1 02 02 F2` (idle, 1×) or **no logged response** (4×).
- Programs are accepted from ready, idle, manual, AND inUse (frame #3: TIME_WORKOUT accepted while state=inUse mid-piece — echo `F1 85 76 05 …`).

## Observed programming lifecycle (per app segment)

`TERMINATE_STALE_PIECE` → ok → `*_0x76 program` → ok(echo) → PM5 0x0031 walks waitToBegin→…→workoutLogged on its own → app sends `GO_FINISHED` (always rejected) → `GO_IDLE` → next TERMINATE+program.
