# One complete RIRT round on a real PM5 — annotated verbatim log excerpt

Source: `<private capture archive>` (LOG15, 2026-07-15, v2.30.7 build 573, PM5 XXXXXXXXX, chest strap paired to the PM5).
Workout: "Row-dy Snatch" — repsInRemainingTime (RIRT), 5 rounds of [250m row + Alt Db Snatch reps in remaining work time] with timed rest.
This excerpt is **round 3** (a TRACKED round — it follows LOST round 2, so it arms cleanly at the rest→work boundary), running through the **round-4 pre-arm** and the work-end teardown. `NNNNN:` prefixes are line numbers in erg-row.log. Local log rate ≈ 25 lines/s while rowing, ≈ 28–38 lines/s in rest/reps phases (calibrated against the 1-second countdown lines and PM5 official elapsed times), so ~50 lines ≈ 1.8 s.

## Phase A — rest before round 3 ends; ARM (terminate stale piece → program → armed)

```
61084: 🏋️ ⏰ Countdown: 1 seconds remaining in rest
61112: 🚣 📋 programWorkout() called with: singleDistance(meters: 250)
61115: 🚣 🧹 PM5 parked at workoutLogged from a previous piece — sending TERMINATE before programming
61116: 🚣 📤 CSAFE [TERMINATE_STALE_PIECE]: F1 76 04 13 02 01 02 60 F2
61117: 🚣 🔄 Round 3: programmed PM5 for 250m native (pre-armed)
61118: 🚣 🔄 Rowing segment armed for round 3: target 250m
61119: 🏋️ Starting round 3 of 5
61121: 🚣 🕐 Dropping stale 0x0031 packet while awaiting fresh piece (d=250.0, state=workoutLogged)
61123: 🚣 📥 CSAFE ok (state: manual): F1 08 76 01 13 6C F2
61143: 🚣 🕐 Dropping stale 0x0031 packet while awaiting fresh piece (d=250.0, state=waitToBegin)
61145: 🚣 ✅ Ready to send workout program (post-terminate)
61147: 🚣 📋 Programming distance workout: 250m
61148: 🚣 📤 CSAFE [DISTANCE_WORKOUT_0x76_SUB500]: F1 76 18 01 01 03 03 05 80 00 00 00 FA 05 05 80 00 00 00 FA 14 01 01 13 02 01 01 6E F2
61149: 🚣 ✅ CSAFE frame chunk written to PM5
61151: 🚣 🕐 Dropping stale 0x0031 packet while awaiting fresh piece (d=250.0, state=waitToBegin)
61153: 🚣 ✅ CSAFE frame chunk written to PM5
61154: 🚣 📥 CSAFE ok (state: idle): F1 82 76 05 01 03 05 14 13 F3 01 F2
61175: 🚣 🚦 PM5 workout state → waitToBegin
```

Annotations:
- The PM5 was still parked at `workoutLogged` from the round-2 piece (it stays there indefinitely). TERMINATE = `0x76`-wrapped `13 02 01 02` (screen-state: TERMINATEWORKOUT). Ack comes ~0.4 s later, CSAFE status nibble here `manual` (0x08); other terminates in the same session acked `offline` (0x09/0x89) or `idle` — the status nibble varies with the erg's screen context.
- 0x0031 packets during the transition still carry the OLD piece's frozen distance (`d=250.0`) — first with `state=workoutLogged`, then (post-terminate, within ~1 packet ≈ 0.5 s) `state=waitToBegin` still with stale d. The app's fresh-piece gate drops these until distance resets.
- The 28-byte program frame is written in 2 BLE chunks (20-byte MTU chunking; ~0.2 s apart). Program ack `F1 82 76 05 01 03 05 14 13 F3 01 F2`: status `0x82` (toggle+idle), echo of accepted sub-commands `01 03 05 14 13`, checksum `0xF1` byte-stuffed as `F3 01`.
- After the program lands, 0x0031 goes to the ARMED idle pattern (all-zero counters + programmed duration):
  `00 00 00 | 00 00 00 | 03 | 01 | 00 | 00 | 01 | 00 00 00 | FA 00 00 | 80 | 00`
  (elapsed=0, dist=0, workoutType=3 fixedDist, intervalType=1, workoutState=0 waitToBegin, rowingState=0, strokeState=1, totalWorkDist=0, duration=0x0000FA=250 m, durationType=0x80 distance, DF=0). This exact packet repeats at ~2 Hz throughout the wait.

## Phase B — athlete pulls; piece runs (workoutRow), distance counts UP at ~2–2.5 Hz

```
61279: 🚣 🚦 PM5 workout state → workoutRow          ← first 0x0031 with state=1, ~4s after "Starting round 3"
61376: 🚣 📊 Stroke: 29 spm, Pace: 2:10, Power: 158W, Dist: 18m, Remaining: 231m
61643: 🚣 📊 Stroke: 27 spm, Pace: 1:53, Power: 244W, Dist: 62m, Remaining: 188m
61899: 🚣 📊 Stroke: 27 spm, Pace: 1:48, Power: 276W, Dist: 110m, Remaining: 140m
62153: 🚣 📊 Stroke: 26 spm, Pace: 1:49, Power: 272W, Dist: 153m, Remaining: 96m
62409: 🚣 📊 Stroke: 26 spm, Pace: 1:49, Power: 267W, Dist: 199m, Remaining: 50m
62643: 🚣 📊 Stroke: 26 spm, Pace: 1:48, Power: 278W, Dist: 247m, Remaining: 2m
```

Mid-row 0x0031 sample (line 61281 area): `F6 0B 00 | 2F 05 00 | 03 01 01 01 04 | 00 00 00 | FA 00 00 | 80 | 7A` — elapsed 0x0BF6=30.62 s, dist 0x052F=132.7 m, state=1 workoutRow, strokeState=4, DF byte=0x7A(122) live while rowing (it is 0 on the very first strokes and while idle). 0x0032 at ~2 Hz carries strap HR in byte[6]; FTMS 0x2AD1 19-byte+10-byte pair at ~1 Hz each also carries HR (byte[16] of the 19-byte form). App-side HR updates land ~4.5×/s from these combined.

## Phase C — 250 m reached: workoutEnd → (segment complete) → workoutLogged → 0x0039 summary ~1.8 s later

```
62647: 🚣 🚦 PM5 workout state → workoutEnd
62648: 🚣 ✅ Workout complete! Distance target reached: 250.0m
62656: 🚣 🔄 Segment complete (round 3): 250m in 55.6s, cumulative 500m
62688: 🚣 🚦 PM5 workout state → workoutLogged       ← ~1.5s after workoutEnd (order vs 0x0039 varies piece-to-piece)
62697: 🚣 🏁 PM5 End of Workout Summary (0x0039, 20 bytes): F7 34 1E 15 EA 15 00 C4 09 00 1B 98 00 00 00 7A 00 03 62 04
62698: 🚣 🏁 PM5 official: 56.1s, 250.0m, 27spm, pace 112.2s/500m, DF 122
62709: 🚣 📊 PM5 summary paired with segment round 3
```

0x0039 decode (validated across 20+ pieces in both 07-11 and 07-15 logs):
`[0-1]` log date (0x34F7 = 2026-07-15; 07-11 log has 0x34B7) · `[2]` minute (0x1E=30) · `[3]` hour (0x15=21) · `[4-6]` elapsed LE 0.01 s (0x15EA=5610→56.1 s) · `[7-9]` distance LE 0.1 m (0x09C4=2500→250.0 m) · `[10]` avg SPM (0x1B=27) · `[11]` ending HR (0x98=152; 0x00 in the 07-11 log where no strap was paired) · `[12-14]` 00 · `[15]` avg drag factor (0x7A=122) · `[16]` 00 · `[17]` workout type (03=fixedDist, 05=fixedTime, 0x0A=fixedCal, 01=JustRow/corrupted) · `[18-19]` avg pace LE 0.1 s (0x0462=1122→112.2 s/500m; FF FF=invalid).

## Phase D — segment teardown + ROUND-4 PRE-ARM (this is what poisons even rounds — SC-9ir8)

```
62880: 🚣 🔄 Sending cmdGoFinished (0x86) to PM5 (segment end, staying connected)
62881: 🚣 📤 CSAFE [SEGMENT_GO_FINISHED]: F1 86 86 F2
62882: 🚣 🗑️ Cleared programmed workout
62883: 🚣 ❌ CSAFE previous-frame reject: F1 98 98 F2      ← GoFinished from LOGGED = reject (0x98 = toggle|reject|manual)
62925: 🚣 🔄 Sending cmdGoIdle (0x82) to PM5 (ready for next segment)
62926: 🚣 📤 CSAFE [SEGMENT_GO_IDLE]: F1 82 82 F2
62928: 🚣 🔁 Dropping duplicate CSAFE response delivery
62949: 🚣 📋 programWorkout() called with: singleDistance(meters: 250)
62952: 🚣 🧹 PM5 parked at workoutLogged from a previous piece — sending TERMINATE before programming
62953: 🚣 📤 CSAFE [TERMINATE_STALE_PIECE]: F1 76 04 13 02 01 02 60 F2
62954: 🚣 🔄 Round 4: programmed PM5 for 250m native (pre-armed)
62955: 🚣 🔄 Rowing segment armed for round 4: target 250m
62956: 🚣 📥 CSAFE ok (state: manual): F1 08 76 01 13 6C F2
62958: 🚣 🕐 Dropping stale 0x0031 packet while awaiting fresh piece (d=250.0, state=waitToBegin)
62978: 🚣 ✅ Ready to send workout program (post-terminate)
62981: 🚣 📤 CSAFE [DISTANCE_WORKOUT_0x76_SUB500]: F1 76 18 01 01 03 03 05 80 00 00 00 FA 05 05 80 00 00 00 FA 14 01 01 13 02 01 01 6E F2
62983: 🚣 🚦 PM5 workout state → waitToBegin
62995: 🚣 📥 CSAFE ok (state: idle): F1 82 76 05 01 03 05 14 13 F3 01 F2      ← round 4 fully armed, ~10s after round-3 row ended
```

## Phase E — round-3 reps finish; work-end teardown deactivates the just-armed segment

```
64518: 🏋️ ⏰ Countdown: 5 seconds remaining in work
64656: 🏋️ ⏰ Countdown: 1 seconds remaining in work
64690: 🚣 🔄 Sending cmdGoFinished (0x86) to PM5 (segment end, staying connected)
64691: 🚣 📤 CSAFE [SEGMENT_GO_FINISHED]: F1 86 86 F2
64692: 🚣 🗑️ Cleared programmed workout
64693: 🚣 🔄 Rowing segment deactivated: rowed 0m this round, cumulative 500m   ← kills the round-4 segment (app-side)
64694: 🏋️ Work phase complete - entering rest for round 3
64723: 🚣 ❌ CSAFE previous-frame reject: F1 92 92 F2      ← GoFinished while ARMED = reject (0x92 = toggle|reject|idle)
64766: 🚣 🔄 Sending cmdGoIdle (0x82) to PM5 (ready for next segment)
64767: 🚣 📤 CSAFE [SEGMENT_GO_IDLE]: F1 82 82 F2          ← GoIdle sent AFTER round-4 was armed
65198: 📋 🚣 Broadcasting round row metrics: iPhone-40B8 R3 split=55.6s HR=145
65200: 🚣 📊 SC-c9fl round 3 metrics: split=55.6s meters=250 HR avg=145 peak=160 Z4
```

## Phase F — rest, then round 4 starts REFUSED app-side (the SC-9ir8 alternation)

```
68754: 🏋️ ⏰ Countdown: 5 seconds remaining in rest
68897: 🏋️ ⏰ Countdown: 1 seconds remaining in rest
68936: 🚣 🔄 armRowingSegment: round 4 already armed (highest: 4)   ← the refusal signature
68937: 🏋️ Starting round 4 of 5
69081: 🚣 🚦 PM5 workout state → workoutRow           ← the ERG still runs its armed 250m piece
70514: 🚣 🚦 PM5 workout state → workoutEnd
70546: 🚣 🏁 PM5 End of Workout Summary (0x0039, 20 bytes): F7 34 22 15 DA 16 00 C4 09 00 19 95 00 00 00 7A 00 03 92 04
70547: 🚣 🏁 PM5 official: 58.5s, 250.0m, 25spm, pace 117.0s/500m, DF 122     ← PM5-side CLEAN for round 4
70548: 🚣 🚦 PM5 workout state → workoutLogged
72401: 📋 🚣 Broadcasting round row metrics: iPhone-40B8 R4 split=-s HR=143   ← app-side round 4 = LOST
72403: 🚣 📊 SC-c9fl round 4 metrics: split=-s meters=- HR avg=143 peak=160 Z3
```

Contrast with round 2 (the other lost round): identical app-side refusal, but there the post-arm `GoIdle` at 50833 was ACKed by the erg (`F1 82 82 F2`, state idle at 50862), and the round-2 piece then ran with 0x0031 workoutType flipping 03→01 after the first packet, ended at 250 m via workoutEnd anyway, and produced a **corrupted 0x0039**: `F7 34 1A 15 58 16 00 00 00 00 0B 8F 00 00 00 7B 00 01 FF FF` → "57.2s, 0.0m, 11spm, pace 6553.5s/500m", workoutType byte 0x01 (line 56662-56663). For round 4 the GoIdle response was swallowed as a duplicate (line 64768ff) and the piece stayed type-03 clean — i.e. GoIdle-after-arm corrupting the piece log is a race, not deterministic.

## Round-cycle timing (line-rate estimates, ±15%)

| Phase | Lines | ≈ Seconds |
|---|---|---|
| Round-3 arm (programWorkout → armed ack) | 61112→61154 | ~1.5 s |
| Armed wait (waitToBegin → first pull) | 61175→61279 | ~4 s |
| Row 250 m | 61279→62647 | 55.6 s (PM5 official 56.1 s) |
| workoutEnd → workoutLogged | 62647→62688 | ~1.5 s |
| workoutEnd → 0x0039 summary | 62647→62697 | ~1.8 s |
| Row end → round-4 pre-arm complete | 62647→62995 | ~12 s |
| Reps remainder of work interval | 62647→64694 | ~70 s (work interval ≈ 120 s total) |
| Rest (incl. score entry hold) | 64694→68937 | ~110–130 s |
| workoutRow→workoutRow (round 3 → round 4) | 61279→69081 | **240 s (4:00 exactly)** |

**Wall-clock anchor (authoritative, overrides line-rate estimates):** the 0x0039 minute/hour bytes `[2..3]` stamp each round's piece end at 21:22 / 21:26 / 21:30 / 21:34 / 21:38 (0x16/0x1A/0x1E/0x22/0x26, hour 0x15) — the round cycle is EXACTLY 4 min. Independent cross-check: `Sending 'timerUpdate'` ticks at ~0.9 Hz (50 ticks during the 55.6 s round-3 row → 1 tick ≈ 1.11 s) give row 56 s + workoutEnd→re-arm ~12 s + armed wait 154 ticks ≈ 171 s ≈ 239 s ✓.

A second tick-measured decomposition of the cycle (round 1→2 and 3→4, ticks × 1.11 s): workoutEnd → SEGMENT_GO_FINISHED = 8 ticks ≈ 9 s; GO_FINISHED → GoIdle ≈ 1 s; GoIdle → TERMINATE+reprogram ≈ 1 s; re-arm → work-end deactivation = 47 ticks ≈ 52 s; refusal (`already armed`) fires ~4 ticks before the erg's workoutRow.

All five rounds: R1 56.4s/250m tracked · R2 app-lost + PM5-corrupt (0.0m log) · R3 55.6s/250m tracked · R4 app-lost, PM5-clean 250m · R5 54.5s/250m tracked. PM5 officials: 56.9/57.2(0m)/56.1/58.5/55.6 s.

**Final round (R5) teardown differs**: no next round to pre-arm, so SEGMENT_GO_FINISHED (78467) comes 66 timerUpdate ticks ≈ **73 s AFTER workoutLogged** (76489) — it fires on workout completion/score entry, not on the ~9 s segment path. It is immediately followed by `🚣 🛑 Stopped scanning` and `📊 Mixed workout rowing metadata: 750m across 3 segment(s)` (78470) — cumulative meters count ONLY the 3 tracked rounds.
