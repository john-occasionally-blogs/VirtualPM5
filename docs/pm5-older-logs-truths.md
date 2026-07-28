# PM5 behavioral truths mined from the two older real-erg logs

- LOG11 = `<private capture archive>` (262,666 lines, v2.28.2 build 547, 13:53:57→~15:42, watch reachable, NO strap on PM5)
- LOG15 = `<private capture archive>` (84,115 lines, v2.30.7 build 573, 20:31→21:45, strap paired to PM5, watch passive)
- Both logs DO contain raw hex dumps: `CE060031 raw (19 bytes)`, `CE060032 raw (17 bytes)`, `FTMS 0x2AD1 raw`, and `0x0039 (20 bytes)` — plus every CSAFE TX/RX frame in hex.
- App emitters: `Shared/Concept2Manager.swift` (state publish :1441, 0x0039 dump :1172, official :1221, stale-drop :1431, fresh-piece gate timeout :162/:168, TERMINATE :628, SUB500 :879, TIME :912, CAL :926) and `Shared/WorkoutSession.swift` (armRowingSegment :7908–:7996, segment complete :8062, deactivate :8129, summary pairing :1149).

## 1. State machine as observed (0x0031 byte[8] published transitions)

Every successful piece in both logs: `waitToBegin → workoutRow → workoutEnd → workoutLogged` (LOG11 has 12 such cycles, LOG15 has 10). A transient `terminate` state appears once (LOG11:169629) right after a TERMINATE while parked. No other states ever appeared — no intervalRest (the interval piece never started, see §5), no countdown/pause states.

- **workoutEnd → workoutLogged is automatic**, no user/app action, in ~1.2–2.3 s (LOG15 48698→48752 ≈2 s; LOG11 42662→42841 ≈1.9 s wall-clock-verified against 1 Hz watch timerUpdate lines 42632=143.8 s / 42760=144.8 s).
- **workoutLogged persists indefinitely** with fully frozen 0x0031 (final distance, final elapsed) until the app sends TERMINATE: LOG11 sat parked ~8 min after the 499 m piece (d=499.0 still stale at 70683) and ~11 min after a 250 m piece (d=250.0 stale at 129266).
- **Notify streams NEVER stop**: 0x0031/0x0032 keep flowing at ~2 Hz in every state, including waitToBegin, workoutLogged, and multi-minute idle gaps.

## 2. RIRT work/rest/re-arm cycle (LOG15 lines 47127–78483) — see pm5-rirt-lifecycle.md for full excerpt

Arm sequence when parked at LOGGED (used between every round): `TERMINATE_STALE_PIECE` (`F1 76 04 13 02 01 02 60 F2`) → ack ~0.4 s (status nibble varies: offline/manual/idle) → 0x0031 state flips to waitToBegin within ~1 packet, **distance stays stale for 1–2 more packets** → program frame `DISTANCE_WORKOUT_0x76_SUB500` (2 BLE chunks) → ack ~0.5 s → 0x0031 becomes the all-zero ARMED pattern with duration bytes set: `00×6 | 03 01 00 00 01 | 00 00 00 | FA 00 00 | 80 | 00`. Total arm latency ≈ 1.5 s.

Across a rest: **distance/elapsed neither freeze nor carry — they are RESET to 0 by the re-arm** (the erg is given a brand-new piece each round). Between workoutEnd and the re-arm they FREEZE at final values. App accumulates cumulative meters itself ("cumulative 500m"). The armed all-zero packet repeats at 2 Hz for the whole rest (340 near-identical packets measured across the round-3→4 gap, lines 62700–69080).

**Round cadence (wall-clock authoritative)**: the 0x0039 minute stamps put the five piece-ends at 21:22/21:26/21:30/21:34/21:38 — a hard 4-minute cycle: ~56 s row + ~9 s completion-to-re-arm + ~171 s armed idle (reps + rest; 154 timerUpdate ticks at 1.11 s/tick). **Final round**: with no round to pre-arm, GO_FINISHED comes ~73 s after workoutLogged (76489→78467, 66 ticks) at workout completion, followed by `📊 Mixed workout rowing metadata: 750m across 3 segment(s)` (78470) — only tracked rounds count.

**SC-9ir8 even-round refusal signature** (app bug, alternating): round N tracked → app pre-arms round N+1 ~10 s after round-N's row ends (mid work phase) → at work-phase end the teardown logs `🗑️ Cleared programmed workout` + `🔄 Rowing segment deactivated: rowed 0m this round` (50770-50771, 64692-64693) → at round-N+1 start: `armRowingSegment: round N+1 already armed (highest: N+1)` (55031, 68936) → round N+1 row untracked (`R2 split=-s`, `R4 split=-s`; `SC-c9fl round N metrics: split=-s meters=-`). The round after a lost round arms cleanly at the rest→work boundary and tracks.

**PM5-side corruption race**: the teardown's GoIdle (0x82) is sent AFTER the next round is armed. When the erg ACKs it (round 2: `F1 82 82 F2` ok idle at 50862) the subsequent piece runs and auto-ends at 250 m, but its 0x0031 workoutType flips 03→01 one packet in, and its 0x0039 is garbage: `F7 34 1A 15 58 16 00 00 00 00 0B 8F 00 00 00 7B 00 01 FF FF` = 57.2 s, **0.0 m**, 11 spm, pace 0xFFFF, type byte 0x01 (JustRow). When the GoIdle response is lost/duplicate-dropped (round 4), the piece stays type-03 and logs a clean 250.0 m summary. Emulator: model GoIdle-after-arm as *sometimes* downgrading the pending piece's log entry while never stopping the live countdown.

## 3. CSAFE TX/RX vocabulary observed (complete catalog, both logs)

TX (all frames XOR-checksummed between F1...F2):
- `TERMINATE_STALE_PIECE`: `F1 76 04 13 02 01 02 60 F2` (0x76 wrapper: screen-state TERMINATEWORKOUT)
- `DISTANCE_WORKOUT_0x76_SUB500` (250 m): `F1 76 18 01 01 03 03 05 80 00 00 00 FA 05 05 80 00 00 00 FA 14 01 01 13 02 01 01 6E F2` (WORKOUTTYPE=3; WORKOUTDURATION type 0x80 val 0xFA BE; SPLITDURATION same; CONFIGURE_WORKOUT=1; SCREENSTATE 01 01 = PREPARETOROWWORKOUT). Variants: 100 m (…00 64…), 300 m (…01 2C…), 499 m (…01 F3 03… — note the extra byte-stuffing 0xF3 03 for value byte 0xF3!)
- `TIME_WORKOUT_0x76` (180 s): `F1 76 18 01 01 05 03 05 00 00 00 46 50 05 05 00 00 00 46 50 14 01 01 13 02 01 01 68 F2` (type=5, duration type 0x00, 0x4650=18000×0.01 s)
- `CALORIES_WORKOUT_0x76` (8 cal / 30 cal): `F1 76 18 01 01 0A 03 05 40 00 00 00 08 …67 F2` (type=0x0A, duration type 0x40)
- `JUST_ROW`: `F1 87 1A 03 01 01 00 9E F2` (GoReady + SETUSERCFG1{WORKOUTTYPE=0}), then `JUSTROW_GOINUSE`: `F1 85 85 F2`
- Legacy v1 distance (≥500 m in build 547/573 first pieces): `F1 87 21 03 F4 01 24 24 02 00 00 85 D7 F2` (GoReady + SetHorizontal 500 LE 0x24-meters + SetProgram + GoInUse)
- Legacy interval (LOG11 only, FAILED — SC-g70z): `F1 87 1A 10 01 01 07 03 02 FA 80 04 01 1E 18 01 03 14 01 01 E4 F2` (GoReady + SETUSERCFG1 len 0x10: WORKOUTTYPE=7 FIXEDDIST_INTERVAL, malformed duration `03 02 FA 80`, RESTDURATION 0x1E=30 s, 0x18 count=3, CONFIGURE) + `INTERVAL_GOINUSE` `F1 85 85 F2`
- `SEGMENT_GO_FINISHED` `F1 86 86 F2`, `SEGMENT_GO_IDLE`/`RETRY_GO_IDLE` `F1 82 82 F2`

RX (status byte = frame-toggle 0x80 | prev-frame-reject 0x10 | state nibble {1 ready,2 idle,5 inUse,7 finished,8 manual,9 offline}):
- Program acks echo accepted sub-commands: `F1 01 76 05 01 03 05 14 13 72 F2` / toggled `F1 81 76 05 01 03 05 14 13 F3 02 F2` / idle-flavored `F1 82 76 05 01 03 05 14 13 F3 01 F2` (note **byte-stuffing of checksums 0xF1/0xF2 as F3 01/F3 02**)
- TERMINATE acks: `F1 09|89 76 01 13 6D|ED F2` (offline), `F1 08 76 01 13 6C F2` (manual), `F1 82|02 76 01 13 E6|66 F2` (idle), `F1 05 76 01 13 61 F2` (inUse)
- Go* acks: `F1 85 85 F2`/`F1 05 05 F2` (inUse), `F1 82 82 F2`/`F1 02 02 F2` (idle), 0x1A ack `F1 01 1A 00 1B F2` (ready)
- Rejects observed: `F1 11 11 F2` (GoFinished while armed/ready), `F1 92 92`/`F1 98 98`/`F1 19 19`/`F1 97 97`/`F1 17 17`/`F1 99 99` (GoFinished from logged — nibble varies), `F1 15 1A 00 0F F2` + `F1 15 15 F2` (interval re-program while inUse), `F1 99 99 F2` (program during active piece)
- App also logs `🔁 Dropping duplicate CSAFE response delivery` — the PM5 re-delivers identical response frames (toggle bit unchanged), emulator should reproduce.

## 4. 0x0039 End-of-Workout Summary — content & timing

20-byte layout (validated on 15+ pieces): `[0-1]` date word (0x34B7=07-11, 0x34F7=07-15) · `[2]` minute · `[3]` hour · `[4-6]` elapsed LE ×0.01 s · `[7-9]` distance LE ×0.1 m · `[10]` avg SPM · `[11]` ending HR (0x00 when no strap — LOG11 all pieces; real values 0x7D–0x98 in LOG15) · `[12-14]` 0 · `[15]` avg drag factor · `[16]` 0 · `[17]` workout type (1 JustRow, 3 fixedDist, 5 fixedTime, 0x0A fixedCal) · `[18-19]` avg pace LE ×0.1 s (0xFFFF invalid).

**Timing: the 0x0039 notification arrives ~1.2–3.5 s after workoutEnd in EVERY observed piece across both logs** (LOG11 wall-clock-verified ≈1.2–1.9 s via watch 1 Hz clock for the first two 500 m pieces; the third 500 m piece measured 4 timerUpdate ticks ≈ 3.3 s at LOG11's 0.83 s/tick, lines 209134→209243; LOG15 ≈0.5–2.4 s via timerUpdate ticks — e.g. RIRT R1 = 2 ticks ≈ 2.2 s, 1000 m piece = 1 tick ≈ 1.1 s, 180 s piece < 1 s). Order vs the workoutLogged state flip is nondeterministic: usually 0x0039 first (LOG11 500 m pieces, LOG15 RIRT R1/R2/R5), sometimes logged first (LOG15 300 m piece 40697<40703, RIRT R3 62688<62697, LOG11 EMOM i4 142634<142660, i5 146501<146523). Sometimes it lands after the app already sent GoFinished (LOG11 131094<131148). **The "~1 min late" claim is not supported by either log** — no summary took longer than ~3.5 s. (If that claim exists it must be about UX backfill or a different session.) Note: the summary is per-piece and also arrives for corrupted pieces (round-2 garbage) and EMOM cal pieces; **JustRow pieces produce NO workoutEnd and NO 0x0039** (LOG15 50 m JustRow piece: workoutRow at 41242, app-side completion at 50.9 m, then nothing until a bare waitToBegin ~100 s later at 44512).
0x003A is subscribed but no separate parse lines appear in either log.

## 5. LOG11 interval-arming failure (SC-g70z) — the full trail

First attempt (169261–169955): app terminated the stale EMOM piece, sent the legacy 0x1A interval frame → **ack OK (ready)** `F1 01 1A 00 1B F2` → `INTERVAL_GOINUSE` → **ack OK (inUse)** `F1 85 85 F2` — yet 0x0031 NEVER produced a fresh piece: stale `d=101.5` packets continued at 2 Hz for minutes. The app's 12 s fresh-piece gate timed out (169625: `Fresh-piece gate timed out — PM5 still workoutLogged; sending TERMINATE and re-arming gate once`), the second TERMINATE acked `inUse` (`F1 05 76 01 13 61 F2`), a transient `state=terminate` packet appeared (169629), then waitToBegin (169955) — still with stale d=101.5.
Second attempt (171386–171749): every re-send now gets **previous-frame-reject with state inUse**: `F1 15 1A 00 0F F2` (interval frame) and `F1 15 15 F2` (GoInUse); RETRY_GO_IDLE didn't clear it; attempts 2/3/4 all rejected identically. The erg was stuck: CSAFE screen state inUse, workout state waitToBegin, stale distance — until the user gave up (no interval piece ever ran; ~30k lines later d was still 101.5 at 200763). Emulator: accepting 0x1A interval programming with OK-then-nothing, and reject-loop `0x15` on re-attempts, is real observed hardware behavior for this (malformed) frame.

## 6. JustRow (LOG15 50 m piece, 40947–44512)

- App rule: `Distance 50m is below the native single-split floor (100m) — using Just Row mode` (Concept2Manager.swift:730).
- On JUST_ROW program + GoInUse: 0x0031 resets to all-zeros with workoutType=1 and **duration bytes zero** (`00×6 | 01 01 00 00 01 | 00 00 00 | 00 00 00 | 80 | 00`) — piece elapsed/distance (the "odometer" the app sees) DO reset on entry.
- First pull → workoutRow (packet `6E 00 00 1B 00 00 01 01 01 01 03 …`), distance counts up past the app's 50 m target (app completes itself at 50.9 m); **no workoutEnd, no workoutLogged, no 0x0039 ever**; erg silently returned to waitToBegin ~100 s after the athlete stopped (44512) — inactivity timeout or user Menu press, indistinguishable in the log.
- Sub-100m stale-completion blindspot: `Workout complete! Distance target reached: 50.0m` fired at 40957 BEFORE the row even started, off the previous piece's stale d=300 m packet (SC-wmoo family evidence).

## 7. EMOM cal pieces (LOG11 129254–148725) — the tightest re-arm cadence observed

5×60 s intervals, 8-cal row each. Per interval: piece auto-ends at 8 cal (~23-25 s, ~101–110 m) → GoFinished (reject `F1 19 19 F2`) → 0x0039 → workoutLogged → GoIdle (~1 s later) → TERMINATE (ack offline) → waitToBegin → CALORIES_WORKOUT_0x76 → ack ready → armed ~30 s before the next interval; workoutRow within ~2-3 s of the interval tick. Officials: 25.3s/110m, 24.7s/108m, 22.7s/103m, 23.3s/104m, 22.0s/101m — all type 0x0A, DF 123. This proves the full terminate→program→arm→run→log cycle sustains a 60 s period indefinitely (5×) — exactly the cycle the emulator must support for RIRT/EMOM.

## 8. HR — what a strap-via-PM5 stream really looks like (LOG15) vs the passive watch (LOG11)

- LOG15 (strap→PM5): HR delivered in **0x0032 byte[6]** at ~2 Hz AND **FTMS 0x2AD1 19-byte form byte[16]** at ~1 Hz → app-side HR updates ≈4.5/s, granularity 1–2 bpm/update. Session dynamics across RIRT rounds (sampled): work peaks 148→158→160→160→165, rest troughs 102–116; per-round `SC-c9fl` avgs 132/139/145/143/147, peaks 151/158/160/160/165. 0x0039 byte[11] carries ending HR. The app labels this source "unknown" in `📦 📡 Broadcasting HR … source: unknown` (14,138 lines) — only 5 early lines say `💓 PM5-relayed HR`. Watch contributed nothing (zero Watch-HR lines).
- LOG11 (no strap): 0x0032 byte[6] = **0xFF constantly** (invalid marker) and the FTMS HR byte is 0x00; HR came only from the watch at **~1 update per 2.5 s** (24 `⌚ Watch HR` lines per 60 s window; 584 total), arriving via WCSession messages, tagged `source: Watch`. Emulator: per-athlete strap = write HR into 0x0032[6] + FTMS[16] + 0x0039[11]; no-strap = 0xFF in 0x0032[6].

## 9. Notification cadences & BLE surface (for stream synthesis)

- 0x0031: 2.0 Hz in every state (8 packets / 4 s rest slice; 142 app stroke-ticks / 55.6 s row). 0x0032: 2.0 Hz. FTMS 0x2AD1: alternating 19-byte (flags 0x0AFF) and 10-byte (flags 0x0100, stroke count + energy) forms, ~1 Hz each. Notifications arrive in bursts (app dedups "within 100ms").
- Full char inventory the app subscribes/discovers on connect (LOG11:60–130): services CE060010/20/30/40 + FTMS 0x1826; CSAFE Rx CE060022 [notify], Tx CE060021 [WRITE, WRITE_NO_RESP]; reads CE060011–18; notifies 0x0031, 0x0032, 0x0033 (avg power/total cal), 0x0034 sample-rate char [read/WRITE] ("leaving default 500ms"), 0x0035 stroke data, 0x0036–0x0038, 0x0039, 0x003A, 0x003B, 0x003D–0x003F, CE060080, plus 0x2ACC and 0x2AD1 [notify]; CE060041 [WRITE].
- 0x0031 19-byte layout as consumed: [0-2] elapsed ×0.01 s LE, [3-5] distance ×0.1 m LE, [6] workoutType, [7] intervalType(=1 always here), [8] workoutState, [9] rowingState, [10] strokeState, [11-13] totalWorkDistance, [14-16] workoutDuration (raw meters / 0.01 s / cal by type), [17] durationType (0x80 dist, 0x00 time, 0x40 cal), [18] dragFactor (0 while idle/first strokes, then live value e.g. 0x7A=122).
- 0x0032 17-byte: [0-2] elapsed, [3-4] speed ×0.001 m/s, [5] strokeRate, [6] HR (0xFF=none), [7-8] pace, … (app parse line: `CE060032 parsed: speed=… SR=… pace=…`).

## 10. Reconnect/background behaviors (multi-device emulator relevance)

- **Backgrounding crash (LOG11 ~23726-23741)**: `App entering background — stopping MC services` → SIGSEGV `EXC_BAD_ACCESS KERN_INVALID_ADDRESS`, main thread, `MCTransport.rebuildParticipants(from:)` ← `session(_:peer:didChange:)` closure (ips: SemperClock-2026-07-11-140633.ips, 14:06:32, procRole "Non UI"). NOT PM5-related, but it produced a golden PM5 scenario:
- **Attach mid-piece**: the 500 m piece armed at 13:53 (first program, `F1 87 21 …`, ack inUse) stayed armed on the erg through the app's death; the user started rowing while the app was dead; on relaunch+reconnect (14:07:47) 0x0031 immediately streamed the in-progress piece (state=workoutRow, d=165.3→190.8 climbing during the retry window). Programming during the active piece → `F1 99 99 F2` reject; app retried (backoff 1.0 s, RETRY_GO_IDLE) then simply adopted the running piece, which completed normally (official 139.9 s/500.0 m). Emulator must survive: connect → discover → immediate mid-piece stream.
- Pace-jump filter: app ignores implausible pace steps (`Ignoring suspicious pace jump: 1:45 -> 3:07`, LOG15:38024) — emulator pace streams should be continuous to avoid tripping it.
- Duplicate/stale 0x0031 handling: `Dropping stale 0x0031 packet while awaiting fresh piece (d=…, state=…)` (Concept2Manager.swift:1431) is the app's gate; an emulator MUST reproduce the stale-distance-after-terminate window (1–2 packets) and frozen-logged streams, or it will hide these code paths.
