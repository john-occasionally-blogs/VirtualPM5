# VirtualPM5

A **byte-faithful, reactive Concept2 PM5 rowing-erg emulator** for Swift, built so rowing apps can be developed and regression-tested on the iOS/tvOS/watchOS **simulators** — no physical erg required.

VirtualPM5 is not a "mock" that returns friendly numbers. It is a firmware-level test double, calibrated frame-by-frame against raw BLE captures of a real PM5:

- It **consumes your app's actual CSAFE command frames** — delivered in ≤20-byte BLE write chunks, reassembled by frame flags exactly like PM firmware — and answers with byte-exact CSAFE responses.
- It **synthesizes the real notification streams** your parsers already decode: `0x0031` General Status, `0x0032` Additional Status 1, `0x0033` Additional Status 2, FTMS `0x2AD1` Rower Data, and the `0x0039`/`0x003A` end-of-workout summaries — at the captured 2 Hz per-characteristic cadence, in every phase (work, armed idle, logged park).
- It **models the state machine the hardware actually walks**: `waitToBegin → workoutRow → (intervalRest…) → workoutEnd → workoutLogged`, including the quirks that only show up on real ergs.

## Captured firmware truths it reproduces

These are the behaviors that hide bugs when a simplistic mock papers over them — each one is encoded here because it was observed in raw captures of real hardware:

- **CSAFE frame-toggle rule:** the toggle bit flips only on *accepted* commands; rejects repeat the last toggle, so consecutive identical rejects are byte-identical (and a duplicate-dropper in your app will swallow them, exactly like on hardware).
- **`GoFinished` is rejected unless the CSAFE slave state is `inUse`** (17/17 captured rejects).
- **Counter-reset semantics:** a distance/calorie program accept and a terminate-from-`workoutLogged` zero the counters *after a 1–3 frame stale window of old values*; a TIME program never resets them; Just Row resets at entry.
- **Distance pieces freeze distance exactly at target**; `workoutEnd` lasts 3–4 frames; the `0x0039` summary lands ~1.5–2s after the end, one frame before `workoutLogged`, which then parks forever at 2 Hz.
- **Sub-500m split-less public-dialect distance programs are rejected** (min-split artifact).
- **Programming during an active piece is rejected in both dialects** (`F1 99`).
- **Native intervals:** per-interval elapsed/distance resets, the `0x05 → 0x09 → 0x03` work→rest state walk, monotonic cumulative `totalWorkDistance` — and the real erg's habit of *ignoring* `SET_WORKOUTINTERVALCOUNT` and running unbounded "zombie" intervals (opt-in flag).
- **Log stamps advance per piece** so consecutive pieces never collide in revision/duplicate/merge logic.

## What's in the package

| Component | Purpose |
| :--- | :--- |
| `VirtualPM5` | The emulator: CSAFE server + notification synthesizer + virtual athlete (pace/SPM/HR profile, seeded RNG, scriptable events). |
| `CSAFEFrameCodec` | Standard-frame encoder/decoder (stuffing, checksum, BLE chunking) per the CSAFE spec. |
| `PM5CommandBuilder` | Byte-exact workout-programming frame builders, public and proprietary (0x76) dialects, with spec golden vectors in the tests. |
| `CSAFEResponse`, `PM5GeneralStatus`, `PM5AdditionalStatus1/2`, `PM5EndOfWorkoutSummaryPacket`, `PM5AdditionalEndSummaryPacket` | Parsers for responses and every notification payload. |
| `Tests/…/Fixtures/pm5-piece-250m.jsonl` | An anonymized raw capture of a real 3×250m/0:30r native-interval piece, used as calibration evidence. |

## Quick start

Add the package, then place the emulator behind your BLE transport seam. The integration contract is deliberately tiny — the emulator speaks `(CBUUID, Data)` pairs, exactly like characteristic notifications:

```swift
import VirtualPM5

// 1. Instantiate where you'd otherwise connect a CBPeripheral.
//    `emit` is called for every virtual notification — route it into the same
//    ingest path your real CBCentralManager delegate uses.
let erg = VirtualPM5(emit: { characteristicUUID, data in
    myManager.ingest(characteristicUUID: characteristicUUID, data: data)
})

// 2. Open the channel and start the 2 Hz notification streams.
erg.open()
erg.startTicking()

// 3. Outbound: send your CSAFE frames exactly like BLE writes (≤20-byte chunks).
let frame = PM5CommandBuilder.publicFixedDistanceFrame(meters: 2000)
for chunk in CSAFEFrameCodec.chunked(frame) {
    erg.receive(chunk: Data(chunk))
}
```

Gate it so a virtual erg can never mask a real one on a physical device:

```swift
#if targetEnvironment(simulator)
if VirtualPM5.isRequested {   // launch argument -VirtualPM5
    // wire the emulator instead of scanning for peripherals
}
#endif
```

## Tailoring the virtual athlete (launch arguments)

`VirtualPM5.Config.fromLaunchArguments()` (the default config) reads these. All knobs default **off/neutral** — with none present the emulator is bit-identical to its calibrated baseline.

| Argument | Effect |
| :--- | :--- |
| `-VirtualPM5` | Opt in (checked by `VirtualPM5.isRequested`). |
| `-VirtualPM5Pace <s>` | Base pace, seconds per 500m. |
| `-VirtualPM5SPM <n>` | Stroke rate. |
| `-VirtualPM5HRStart <bpm>` / `-VirtualPM5HRPeak <bpm>` | HR ramp for the strap-on-erg model. |
| `-VirtualPM5Strap <0\|1>` | Whether a strap feeds the erg (drives the per-channel HR sentinel differences). |
| `-VirtualPM5StartDelay <s>` | Seconds from arm to first pull. |
| `-VirtualPM5Seed <n>` | Seeded RNG — any run is replayable. |
| `-VirtualPM5Script '<events>'` | Piece-clock events, e.g. `stop@120,resume@130`, `disconnect@60:8` (mid-piece BLE drop, auto-reconnect 8s later). |
| `-VirtualPM5SummaryDelay <s>` | Hold the `0x0039` N seconds past `workoutLogged` (summary/save race testing). |
| `-VirtualPM5InitialOdometer <m>` | Boot with leftover meters — stale until a program's zeros land. |
| `-VirtualPM5InitialState 'inProgress:<target>m@<current>m'` | Boot already mid-piece (cold adoption); the app's own program is refused as piece-active. |
| `-VirtualPM5CooldownPiece <m>` | After the app's piece logs, the athlete keys a manual piece → a second legitimate `0x0039`. |
| `-VirtualPM5IntervalUnbounded` | Reproduce the real erg ignoring the interval count (zombie intervals, terminate-to-end). |

Because the profile is per-process, **multiple simulators can each run their own differently-tuned virtual erg** — enabling realistic multi-participant rowing scenarios with zero hardware.

## Provenance & fidelity

Behavior is calibrated against raw BLE captures of a **single real PM5** (2026). No device identity ships with this package — serials in logs are synthetic (`000000000`), and the bundled capture fixture is anonymized. A few channels (`0x0033`, `0x003A`) are *parser-conformant rather than capture-verified* where the reference logs never raw-dumped them; these are noted in the source.

This project was extracted from a production rowing/workout app, where it replaced a hand-written mock and caught real-hardware bug classes (arm/terminate/re-arm races, summary/save races, counter-reset artifacts) entirely in the simulator. Comment references of the form `SC-xxxx` are issue IDs from that host project's tracker, kept for archaeology.

## Scope & non-goals

- **A development/test tool.** It emulates an erg for your app's benefit; it is not a device controller, does not talk to real hardware, and must not be used to fabricate workout data presented as real.
- The virtual athlete is deterministic-with-jitter, not a physics model — pace/SPM/HR follow the configured profile, not a biomechanical simulation.
- Firmware truths reflect the captured reference erg's firmware era; other firmware revisions may differ in corners.

## Trademark & affiliation

This project is **not affiliated with, endorsed, or sponsored by Concept2, Inc.** "Concept2", "PM5", and "RowErg" are trademarks of Concept2, Inc., used here only to describe interoperability. Protocol details derive from Concept2's publicly published documents: *Concept2 PM CSAFE Communication Definition* (Rev 0.25) and *Concept2 PM Bluetooth Smart Communication Interface Definition* (Rev 1.30).

## License

[Apache-2.0](LICENSE)
