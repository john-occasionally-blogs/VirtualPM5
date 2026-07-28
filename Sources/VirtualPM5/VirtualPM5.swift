//
//  VirtualPM5.swift
//  SemperClock
//
//  SC-7nqt.1 P1b — a byte-faithful REACTIVE virtual PM5 for the simulator.
//
//  Lives behind the real Concept2Manager transport seam: it consumes the app's
//  actual CSAFE command frames (delivered chunked through sendCSAFE, reassembled
//  here exactly like PM firmware) and answers with byte-exact CSAFE responses and
//  synthesized CE060031/CE060032/FTMS-0x2AD1/CE060039 notification streams that the
//  app's REAL parsers decode — so the fresh-piece gate, terminate handshake, retry
//  chain, pm5SaysDone accelerants, and the 0x0039 accept-gate all run in the sim.
//
//  CALIBRATION PROVENANCE: raw captures from a single real PM5 (drag ~122-124), 2026-07-11/15/16
//  (see .claude/pm5-emulator/: design.md v2, pm5-csafe-catalog.md, pm5-piece-250m.jsonl,
//  pm5-rirt-lifecycle.md). Load-bearing captured truths encoded here:
//  - 2Hz per-characteristic cadence in EVERY phase (work, armed idle, logged park);
//    FTMS as a 1Hz MoreData pair (flags 0x0AFF 19B then 0x0100 10B, perMin always 0xFF).
//  - CSAFE toggle rule: the frame-toggle bit flips ONLY on accepted commands; rejects
//    repeat the last toggle (this is what makes consecutive GoFinished/GoIdle rejects
//    byte-identical so the app's whole-frame duplicate dropper swallows them — 10/10
//    captured occurrences).
//  - GoFinished is rejected unless CSAFE slave state is inUse (17/17 captured rejects).
//  - Counter resets: distance-program accept and TERMINATE-from-logged zero the
//    counters (each after a 1-3 frame stale window of the old values); terminate from
//    waitToBegin does NOT zero (single 0x0B flash frame); JustRow resets at entry.
//  - Distance pieces freeze distance EXACTLY at target; workoutEnd (0x0A) lasts 3-4
//    frames; 0x0039 lands ~1.5-2s after end, one frame before workoutLogged (0x0C),
//    which parks forever at 2Hz keeping the piece's workoutType.
//  - 0x0039 HR truth: byte 11 carries a real ending HR when a strap feeds the erg;
//    avg/min/max bytes 12-14 are ALWAYS 0x00 on this erg. Log stamps ADVANCE per
//    piece (fixed epoch date + a running virtual wall clock) so consecutive pieces
//    never collide in the app's revision/duplicate/merge logic.
//
//  P1b scope: single DISTANCE pieces (0x76 sub-500m + public SETHORIZONTAL ≥500m),
//  Just Row (reset-at-entry, no end/no summary), TERMINATE, GoIdle/GoFinished/
//  GETSTATUS grammar, stop/resume script events.
//
//  P2 TIME/CAL axes (SC-7nqt.9/.10), calibrated against the raw captures:
//  - TIME (0x05, LOG15:16046+): a TIME program NEVER resets the counters (the
//    armed zeros in the raw log belong to the preceding terminate-from-logged —
//    the reason Concept2Manager's .singleTime path skips the fresh-piece gate,
//    SC-wmoo.1 c2). Elapsed freezes EXACTLY at target; intervalType byte 0x00;
//    totalWorkDistance bytes broadcast 0 for the whole piece; 0x0039 byte[17]=0x05.
//  - CAL (0x0A, LOG11:129316+): resets like distance; intervalType byte 0xFF;
//    duration = raw cals, type 0x40; energy frozen at end so the FTMS-B total
//    floors to target-1 (the SC-zjrh wire artifact the app's >=target-1 guard
//    exists for); no calorie count exists in 0x0039 (erg-truth cal rides 0x003A,
//    still unemitted). 0x0039 byte[17]=0x0A.
//  - Programming during an ACTIVE piece (.rowing + the workoutEnd walk) is
//    REJECTED in BOTH dialects — captured F1 99; the capture was itself a public
//    0x87 re-program. TERMINATE mid-row really terminates (uncaptured corner,
//    modeled so the app's TERMINATE→program recovery grammar still works against
//    the never-stops-pulling virtual athlete).
//  P2 native intervals (SC-7nqt.11, FIXEDDIST_INTERVAL 0x07): each work interval resets
//  elapsed+distance at its start (log16); byte-8 walks 0x05 work → 0x09 work→rest → 0x03 rest
//  — the 0x05→0x09→0x03 SEQUENCE is CONFIRMED by the 2026-07-20 capture (SC-7nqt.5); only the
//  0x09 frame BODY is still modeled; byte-7 intervalType is 0x01 work / 0x02 rest;
//  totalWorkDistance[11:13] rides the MONOTONIC cumulative across rounds (250→518→771). The
//  erg IGNORES INTERVALCOUNT and runs UNBOUNDED (captured zombie 4th interval); the DEFAULT
//  models a count-honoring self-terminate into one 0x0039 (byte[17]=0x07 — CONFIRMED by the
//  clean capture; the lone "0x03 zombie" summary was itself a post-terminate artifact), while
//  -VirtualPM5IntervalUnbounded (SC-7nqt.12) reproduces the real zombie-past-count run that
//  ends on TERMINATE. The interval summary carries CLEAN rounds×workMeters distance + WORK-only
//  elapsed (SC-fadm). 0x003A + 0x0033 are now EMITTED (SC-fadm); the recovery-HR revision
//  remains deferred (loud 🧪 VPM5 lines + SC-7nqt.5 gate).
//
//  P2 race knobs (SC-7nqt.2, all DEFAULT OFF — bit-identical when absent):
//  -VirtualPM5SummaryDelay <s>  hold the 0x0039 N seconds past workoutLogged
//                               (SC-fnka/SC-lv7o/SC-q77u post-save races)
//  -VirtualPM5InitialOdometer <m>  boot with leftover meters; stale until a
//                               program's zeros land (SC-9i07/SC-wmoo.1/SC-bca1)
//  -VirtualPM5CooldownPiece <m> athlete keys a manual piece after the app piece
//                               logs → SECOND legitimate 0x0039 (SC-0bjb)
//  -VirtualPM5PreArmRace        SC-9ir8 regression-lock scenario: defaults pace=62/
//                               startDelay=2 (explicit knobs win) and pairs with the
//                               SemperClockApp harness EMOM seed — see the PASS-grep
//                               contract on that harness block
//  -VirtualPM5Script '…,disconnect@<t>:<after>'  (SC-7nqt.2.4) mid-workout BLE drop at
//                               piece-second <t>, auto-reconnect <after>s later (default 8).
//                               The firmware phase survives the gap so the erg keeps its
//                               running piece; the app's reconnect re-program is refused
//                               (piece active, F1 99) then it recovers onto the live stream
//                               — SC-eqzh reconnect half / SC-dxsm analog.
//  -VirtualPM5InitialState 'inProgress:<t>m@<c>m'  (SC-7nqt.2.4) boot ALREADY mid-piece
//                               (rowing <c>/<t> m the app never armed) — cold adoption.
//
//  Observability: every state transition, command, and piece-official emits a
//  "🧪 VPM5" stdout line (grep the token VPM5 in the runtime log).
//

import Foundation
import CoreBluetooth

public final class VirtualPM5 {

    // MARK: - Characteristic UUIDs (mirrors Concept2Manager's constants)
    public static let generalStatusUUID = CBUUID(string: "CE060031-43E5-11E4-916C-0800200C9A66")
    public static let additionalStatus1UUID = CBUUID(string: "CE060032-43E5-11E4-916C-0800200C9A66")
    public static let csafeRxUUID = CBUUID(string: "CE060022-43E5-11E4-916C-0800200C9A66")
    public static let endSummaryUUID = CBUUID(string: "CE060039-43E5-11E4-916C-0800200C9A66")
    public static let ftmsRowerDataUUID = CBUUID(string: "2AD1")
    public static let additionalStatus2UUID = CBUUID(string: "CE060033-43E5-11E4-916C-0800200C9A66")     // SC-fadm 0x0033
    public static let additionalEndSummaryUUID = CBUUID(string: "CE06003A-43E5-11E4-916C-0800200C9A66")  // SC-fadm 0x003A

    /// The serial the virtual erg reports in its logs. A deliberately synthetic
    /// value — the emulator's behavior is calibrated against a real PM5, but no
    /// real device identity ships with it.
    public static let virtualSerialNumber = "000000000"

    /// Firmware truth (captured): a split-less public-dialect distance program
    /// under 500m is rejected (min-split artifact). Mirrors the same floor the
    /// consuming app must respect; kept local so the emulator is self-contained.
    public static let pm5MinProgrammableDistance = 500

    // MARK: - Configuration (launch-arg tailorable athlete profile)

    public struct Config {
        /// Base pace, seconds per 500m (app plausibility window: 61-599).
        var paceSecondsPer500: Double = 120
        /// Stroke rate, strokes per minute (app window: 1-59, |Δ|≤10 between frames).
        var strokeRate: Int = 24
        /// HR ramp (strap-on-PM5 model): start → peak at ~0.55 bpm/s.
        var hrStart: Int = 95
        var hrPeak: Int = 152
        /// Seconds from arm (or Just Row entry) to the first pull.
        var startDelay: Double = 4.0
        /// Strap paired to the erg: HR in 0x0032[6] + FTMS[16] + 0x0039[11].
        /// No strap: 0xFF / 0x00 / 0x00 (captured sentinel difference per channel).
        var strapPresent: Bool = true
        /// Seeded RNG so any run is replayable (seed printed in the session header).
        var seed: UInt64 = 0
        /// Piece-clock script events, e.g. "stop@120,resume@130" (P1b: stop/resume only).
        var script: [ScriptEvent] = []
        /// CSAFE response latency (captured ack gap ~0.25-0.4s). Tests set 0 for
        /// synchronous assertions.
        var responseLatencySeconds: Double = 0.3
        /// P2a (SC-7nqt.2): hold the 0x0039 for N seconds AFTER the workoutEnd →
        /// workoutLogged transition while the 2Hz status streams keep flowing.
        /// Captured truth (pm5-older-logs-truths.md §4): +0.5-3.5s after
        /// workoutEnd, order vs 0x0C nondeterministic (both captured); larger
        /// delays are a deliberate stress knob, not observed hardware behavior.
        /// Pins the summary AFTER the app's result save (SC-fnka/SC-lv7o/
        /// SC-q77u races). 0 = off — P1 timing (summary one frame before the
        /// logged park) is bit-identical.
        var summaryDelaySeconds: Double = 0
        /// P2b (SC-7nqt.2): boot with leftover meters on the cumulative odometer,
        /// as if an earlier unterminated bout left them behind. JustRow entry
        /// resets it (P1 rule); a programmed piece shows the real stale window —
        /// leftover distance visible until the program's armed zeros land
        /// (SC-9i07/SC-wmoo.1/SC-bca1 repro). 0 = off.
        var initialOdometerMeters: Int = 0
        /// P2c (SC-7nqt.2): after the app-driven piece completes AND its 0x0039
        /// is delivered, the virtual athlete keys a manual N-meter piece on the
        /// erg keypad (no CSAFE exchange), rows it to completion, and a SECOND
        /// legitimate 0x0039 lands in the app (SC-0bjb: accept-gate never closes;
        /// cooldown overwrites the saved result). 0 = off.
        var cooldownPieceMeters: Int = 0
        /// SC-7nqt.12 / SC-fadm: -VirtualPM5IntervalUnbounded — model the REAL erg's
        /// behavior of IGNORING SET_WORKOUTINTERVALCOUNT (0x18): keep arming work→rest
        /// zombie intervals PAST the programmed count, ending ONLY on manual TERMINATE
        /// (which then emits the interval 0x0039 + 0x003A and walks to re-arm). OFF =
        /// today's count-honoring self-terminate (bit-identical when the flag is absent).
        var intervalUnbounded: Bool = false
        /// SC-7nqt.2.4: `-VirtualPM5InitialState 'inProgress:<target>m@<current>m'` —
        /// the erg boots ALREADY mid-piece (a distance row `current`/`target` m in),
        /// so the app connects to a running piece it never programmed (cold adoption).
        /// The app's start-of-workout program is then refused (piece active, F1 99) and
        /// it recovers onto the live stream — the same path a transient reconnect takes,
        /// but from cold boot. nil = off.
        var initialInProgress: (targetMeters: Int, currentMeters: Int)?

        public static func fromLaunchArguments() -> Config {
            var c = Config()
            let d = UserDefaults.standard  // NSArgumentDomain carries -Key value pairs
            if let pace = d.object(forKey: "VirtualPM5Pace") as? String, let v = Double(pace), v > 60, v < 600 {
                c.paceSecondsPer500 = v
            } else if d.double(forKey: "VirtualPM5Pace") > 60 {
                c.paceSecondsPer500 = d.double(forKey: "VirtualPM5Pace")
            }
            if d.integer(forKey: "VirtualPM5SPM") > 0 { c.strokeRate = min(59, max(10, d.integer(forKey: "VirtualPM5SPM"))) }
            if d.integer(forKey: "VirtualPM5HRStart") > 0 { c.hrStart = d.integer(forKey: "VirtualPM5HRStart") }
            if d.integer(forKey: "VirtualPM5HRPeak") > 0 { c.hrPeak = d.integer(forKey: "VirtualPM5HRPeak") }
            if d.object(forKey: "VirtualPM5StartDelay") != nil { c.startDelay = max(0, d.double(forKey: "VirtualPM5StartDelay")) }
            if d.object(forKey: "VirtualPM5Strap") != nil { c.strapPresent = d.bool(forKey: "VirtualPM5Strap") }
            if d.object(forKey: "VirtualPM5Seed") != nil, d.integer(forKey: "VirtualPM5Seed") > 0 {
                c.seed = UInt64(d.integer(forKey: "VirtualPM5Seed"))
            } else {
                c.seed = UInt64.random(in: 1...UInt64.max)
            }
            if let script = d.string(forKey: "VirtualPM5Script") {
                c.script = ScriptEvent.parse(script)
            }
            // Windowed like the P1 knobs: absurd values would trap the Int()
            // conversions downstream (tick countdown, elapsed×100 wire bytes).
            if d.object(forKey: "VirtualPM5SummaryDelay") != nil {
                c.summaryDelaySeconds = min(3600, max(0, d.double(forKey: "VirtualPM5SummaryDelay")))
            }
            if d.integer(forKey: "VirtualPM5InitialOdometer") > 0 {
                c.initialOdometerMeters = min(1_000_000, max(0, d.integer(forKey: "VirtualPM5InitialOdometer")))
            }
            if d.integer(forKey: "VirtualPM5CooldownPiece") > 0 {
                c.cooldownPieceMeters = min(1_000_000, max(0, d.integer(forKey: "VirtualPM5CooldownPiece")))
            }
            // SC-9ir8 pre-arm-race lock scenario: deterministic race-window timing
            // (250m @ 62 s/500m + 2s startDelay completes ~33s into a 45s EMOM
            // interval; a regressed pre-arm chain would land ~4s BEFORE the
            // boundary). Explicit -VirtualPM5Pace/-VirtualPM5StartDelay still win.
            if ProcessInfo.processInfo.arguments.contains("-VirtualPM5PreArmRace") {
                if d.object(forKey: "VirtualPM5Pace") == nil { c.paceSecondsPer500 = 62 }
                if d.object(forKey: "VirtualPM5StartDelay") == nil { c.startDelay = 2 }
            }
            // SC-is2m.1 counting-gate lock: a short startDelay + fast pace so the pre-armed
            // erg flywheel-starts ~2s into the rest window and rows real meters DURING rest —
            // the early pull the app's counting-gate must discard. Explicit overrides win.
            if ProcessInfo.processInfo.arguments.contains("-VirtualPM5RIRTPullDuringRest") {
                if d.object(forKey: "VirtualPM5Pace") == nil { c.paceSecondsPer500 = 62 }
                if d.object(forKey: "VirtualPM5StartDelay") == nil { c.startDelay = 2 }
            }
            // SC-7nqt.12: unbounded zombie-interval scenario (real erg ignores the 0x18 count).
            if ProcessInfo.processInfo.arguments.contains("-VirtualPM5IntervalUnbounded") {
                c.intervalUnbounded = true
            }
            // SC-7nqt.2.4: cold mid-piece adoption. Format 'inProgress:500m@165m'.
            if let raw = d.string(forKey: "VirtualPM5InitialState"),
               raw.hasPrefix("inProgress:") {
                let body = raw.dropFirst("inProgress:".count)          // "500m@165m"
                let parts = body.split(separator: "@")
                if parts.count == 2,
                   let target = Int(parts[0].filter(\.isNumber)),
                   let current = Int(parts[1].filter(\.isNumber)),
                   target > 0, current >= 0 {
                    c.initialInProgress = (min(1_000_000, target), min(1_000_000, current))
                } else {
                    print("🧪 VPM5 ⚠️ unparseable -VirtualPM5InitialState '\(raw)' (expected inProgress:<t>m@<c>m)")
                }
            }
            return c
        }
    }

    enum ScriptEvent: Equatable {
        case stop(atPieceSeconds: Double)
        case resume(atPieceSeconds: Double)
        /// SC-7nqt.2.4: mid-workout BLE drop — the manager tears the link down at
        /// `atPieceSeconds` (piece clock) and auto-reconnects `reconnectAfter` seconds
        /// later. The VPM5's firmware `phase` survives the gap (stop() only kills the
        /// timer), so the erg keeps its running piece — exactly like real hardware
        /// during a transient disconnect (SC-eqzh reconnect half / SC-dxsm analog).
        case disconnect(atPieceSeconds: Double, reconnectAfter: Double)

        static func parse(_ spec: String) -> [ScriptEvent] {
            spec.split(separator: ",").compactMap { token in
                let parts = token.split(separator: "@")
                guard parts.count == 2 else { return nil }
                let name = parts[0]
                // disconnect carries a "t:reconnectAfter" tail (reconnectAfter defaults
                // to 8s); stop/resume carry a bare piece-second.
                if name == "disconnect" {
                    let tail = parts[1].split(separator: ":")
                    guard let t = Double(tail[0]) else { return nil }
                    let after = tail.count > 1 ? (Double(tail[1]) ?? 8) : 8
                    return .disconnect(atPieceSeconds: t, reconnectAfter: max(0, after))
                }
                guard let t = Double(parts[1]) else { return nil }
                switch name {
                case "stop": return .stop(atPieceSeconds: t)
                case "resume": return .resume(atPieceSeconds: t)
                default:
                    print("🧪 VPM5 ⚠️ unknown script event '\(token)' (P1 supports stop@/resume@, P2 disconnect@t:after)")
                    return nil
                }
            }
        }
    }

    /// SplitMix64 — deterministic, seedable, replayable.
    private struct SeededRNG: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }

    // MARK: - Firmware state

    /// The armed/running piece. P1b: distance singles + Just Row;
    /// P2 (SC-7nqt.9/.10): TIME (FIXEDTIME_SPLITS 0x05) + CAL (FIXEDCALORIE_SPLITS 0x0A);
    /// P2 (SC-7nqt.11): native intervals (FIXEDDIST_INTERVAL 0x07).
    private enum Piece {
        case distance(meters: Int)
        case time(seconds: Int)
        case calories(cals: Int)
        case justRow
        /// SC-7nqt.11: `rounds` work intervals of `workMeters` each, separated by
        /// `restSeconds` fixed rest. See "Native intervals" in the header + the
        /// interval arms in advancePhase/wireValues/emitEndOfWorkoutSummary.
        case interval(workMeters: Int, restSeconds: Int, rounds: Int)
    }

    private enum Phase {
        /// No piece: zeros (or post-piece carryover until terminated), state waitToBegin.
        case idle
        /// 1-3 frames still broadcasting the PREVIOUS values (captured in-flight window
        /// after program accept / terminate-from-logged) before `next` takes over.
        case staleWindow(framesLeft: Int, then: PendingTransition)
        /// Programmed, counters zeroed, waiting for the flywheel (athlete startDelay).
        case armed(Piece)
        /// Athlete rowing. Elapsed ticks 1-2 frames before the state byte flips (captured).
        case rowing(Piece)
        /// Target reached: frozen at exactly the target, state 0x0A for `framesLeft`.
        case ended(Piece, framesLeft: Int)
        /// 0x0039 delivered; parked forever at 2Hz, workoutType retained (captured).
        case logged(Piece)
        /// SC-7nqt.11: native-interval REST between work rounds. `framesLeft` counts
        /// down the rest; the FIRST 1-2 frames read workoutState 0x09
        /// (intervalWorkDistanceToRest — occurs in a ~1-2 frame window, raw bytes
        /// UNCAPTURED so modeled), the remainder 0x03 (intervalRest — captured, log16).
        /// Per-interval elapsed + distance FREEZE at the work overshoot; only HR and the
        /// rest countdown (0x0032[13:16]) stay live. Distance resets to 0 on the next work.
        case resting(Piece, framesLeft: Int)
    }

    private enum PendingTransition {
        case arm(Piece)
        case clearToIdle   // terminate-from-logged: zeros, workoutType → 0x01, duration cleared
    }

    private var phase: Phase = .idle
    private var slaveState: CSAFESlaveState = .ready
    /// Toggle latch: accepted responses use the FLIPPED value and keep it; rejects
    /// repeat the current value (captured rule, 30/30 responses).
    private var toggleBit = false
    /// One 0x0B flash frame after a terminate that had nothing parked (captured once).
    private var terminateFlashPending = false

    // Live piece values
    private var elapsed: Double = 0          // seconds, piece clock
    private var distance: Double = 0         // meters
    private var frozenElapsed: Double = 0
    private var frozenDistance: Double = 0
    private var lastValues: (elapsed: Double, distance: Double, type: UInt8) = (0, 0, 0x01)
    private var workoutTypeByte: UInt8 = 0x01
    private var durationBytes: (value: Int, type: UInt8) = (0, 0x80)
    /// Piece-internal baseline, snapshotted at flywheel start. Nonzero only for
    /// TIME pieces (which never reset the counters — LOG15/SC-wmoo.1): completion
    /// and the 0x0039 use elapsed/distance RELATIVE to these. Zero for the rest.
    private var pieceStartElapsed: Double = 0
    private var pieceStartDistance: Double = 0
    private var dragFactor: Int = 0
    private var rowingTicks = 0
    private var armedTicks = 0
    private var scriptStopped = false
    /// SC-7nqt.11 native-interval (0x07) state. `intervalRoundsRemaining` counts DOWN
    /// from the programmed round count (0x18 SET_WORKOUTINTERVALCOUNT). Per-interval
    /// `elapsed`/`distance` reset each work start (log16), so the WIRE totalWorkDistance
    /// (0x0031[11:13]) rides `intervalCumulativeMeters` (monotonic across rounds:
    /// 250→518→771 captured) and the summary rides `intervalTotalElapsed` (whole-session
    /// incl. rest — the interval 0x0039 body is uncaptured, so this is a modeling choice).
    private var intervalRestSeconds = 0
    private var intervalRoundsRemaining = 0
    private var intervalRestFramesTotal = 0
    private var intervalCumulativeMeters: Double = 0
    private var intervalTotalElapsed: Double = 0
    /// SC-fadm: WORK-only interval elapsed (increments in `.rowing` only, NOT `.resting`).
    /// The real 0x0039 interval summary rides work-only time (206.7s captured for a
    /// 3×250m/0:30 piece), not the whole-session clock `intervalTotalElapsed` (which
    /// includes rest and rides the WIRE elapsed instead).
    private var intervalWorkElapsed: Double = 0
    /// SC-fadm: whole-PIECE calorie + average-watt accumulators for the 0x003A / 0x0033
    /// additional-summary frames. Survive per-interval resets (energyKcal zeroes each
    /// work round); reset only at arm (resetPieceCounters).
    private var pieceEnergyTotal: Double = 0
    private var pieceWattSum: Double = 0
    private var pieceWattSamples: Int = 0
    /// P2a: pre-rendered 0x0039s (bytes + official log line captured at end-walk
    /// time) waiting out their post-logged tick countdowns. FIFO — a piece ending
    /// inside another's hold window queues behind it instead of overwriting it
    /// (the erg's log memory holds every piece). Survives TERMINATE — hardware
    /// delivers late summaries after the app has moved on, which is exactly the
    /// race these knobs pin.
    private var pendingSummaries: [(data: Data, additional: Data, official: String, ticksLeft: Int)] = []  // SC-fadm: +0x003A
    /// P2c: tick countdown from the app piece's summary delivery to the athlete
    /// keying the cooldown; one-shot latch so the cooldown's own summary can't
    /// re-arm it.
    private var cooldownTicksUntilKeyed: Int?
    private var cooldownFired = false
    /// P2c walk-over: ~10s of CONTINUOUS parked erg before the athlete keys.
    private let cooldownWalkOverTicks = 20

    // Athlete engine accumulators
    private var currentPace: Double = 120
    private var avgPaceAccumulator: Double = 0
    private var paceSamples: Int = 0
    private var strokeCount: Int = 0
    private var strokePhaseTicks = 0
    private var energyKcal: Double = 0
    private var currentHR: Double = 0
    private var totalTicks = 0               // virtual session clock (0.5s per tick)

    private var config: Config
    private var rng: SeededRNG
    private let emit: (CBUUID, Data) -> Void
    /// SC-7nqt.2.4: invoked (main queue) when a `disconnect@` script event fires, with
    /// the reconnect delay. The manager tears the virtual link down and re-scans after
    /// the delay. nil unless a disconnect event is scripted, so the seam is inert on
    /// device / without -VirtualPM5Script.
    private let onDisconnectRequest: ((TimeInterval) -> Void)?
    private var scriptDisconnectFired = false
    private var accumulator = CSAFEResponseAccumulator()
    private var tickTimer: Timer?
    public private(set) var isChannelOpen = false

    /// True when the launch requested the virtual erg. Callers additionally gate
    /// instantiation on #if targetEnvironment(simulator) — the virtual erg must
    /// never mask a real PM5 on a physical device.
    public static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("-VirtualPM5")
    }

    public init(config: Config = Config.fromLaunchArguments(),
         emit: @escaping (CBUUID, Data) -> Void,
         onDisconnectRequest: ((TimeInterval) -> Void)? = nil) {
        self.config = config
        self.rng = SeededRNG(state: config.seed)
        self.emit = emit
        self.onDisconnectRequest = onDisconnectRequest
        print("🧪 VPM5 session start seed=\(config.seed) pace=\(config.paceSecondsPer500)s/500m spm=\(config.strokeRate) hr=\(config.hrStart)-\(config.hrPeak) strap=\(config.strapPresent) startDelay=\(config.startDelay)s script=\(config.script)")
        if config.initialOdometerMeters > 0 {
            // P2b: leftover values from an earlier bout, visible in the idle 0x0031
            // stream and through the program-accept stale window until armed zeros
            // land. Elapsed derived from base pace — deterministic, plausible.
            distance = Double(config.initialOdometerMeters)
            elapsed = Double(config.initialOdometerMeters) / 500.0 * config.paceSecondsPer500
            print("🧪 VPM5 🧳 initial odometer: \(config.initialOdometerMeters)m leftover (elapsed \(String(format: "%.1f", elapsed))s) — stale until a program's zeros land; JustRow resets at entry")
        }
        if config.summaryDelaySeconds > 0 {
            print("🧪 VPM5 ⏲️ summary delay armed: 0x0039 held \(config.summaryDelaySeconds)s past workoutLogged")
        }
        if config.cooldownPieceMeters > 0 {
            print("🧪 VPM5 🧊 cooldown piece armed: athlete will key \(config.cooldownPieceMeters)m after the app piece logs")
        }
        if ProcessInfo.processInfo.arguments.contains("-VirtualPM5PreArmRace") {
            print("🧪 VPM5 🔒 9ir8 pre-arm-race lock scenario armed")
        }
        if let seed = config.initialInProgress {
            // SC-7nqt.2.4: boot ALREADY rowing a distance piece the app never armed
            // (cold adoption). Mirror the .armed→.rowing setup for a distance program:
            // 0x03 workout type, distance duration, slave inUse, phase .rowing. A
            // freshly-programmed piece from the app is then refused (piece active).
            workoutTypeByte = 0x03
            durationBytes = (seed.targetMeters, 0x80)
            distance = Double(seed.currentMeters)
            elapsed = Double(seed.currentMeters) / 500.0 * config.paceSecondsPer500
            pieceStartElapsed = 0
            pieceStartDistance = 0
            rowingTicks = 3          // past the drag-factor settle so the stream reads established
            dragFactor = 122
            currentHR = Double(config.hrStart)   // established HR, not a cold 0 (→ HR-of-1 artifact)
            slaveState = .inUse
            phase = .rowing(.distance(meters: seed.targetMeters))
            print("🧪 VPM5 🎬 initial state: mid-piece adoption — rowing \(seed.currentMeters)/\(seed.targetMeters)m already in progress (elapsed \(String(format: "%.1f", elapsed))s); the app's own program will be refused as piece-active")
        }
    }

    // MARK: - Lifecycle

    public func open() {
        isChannelOpen = true
        print("🧪 VPM5 channel open (serial \(Self.virtualSerialNumber) virtual)")
    }

    public func startTicking() {
        guard tickTimer == nil else { return }
        tickTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tick()
        }
        print("🧪 VPM5 notification stream started (0.5s cadence)")
    }

    public func stop() {
        tickTimer?.invalidate()
        tickTimer = nil
        isChannelOpen = false
        print("🧪 VPM5 stopped")
    }

    // MARK: - CSAFE server (inbound commands from the app)

    /// Receives one BLE write chunk (≤20 bytes); reassembles by frame flags exactly
    /// like PM firmware, then interprets each complete frame.
    public func receive(chunk: Data) {
        for frame in accumulator.append(chunk) {
            interpret(frame)
        }
    }

    private func interpret(_ frame: [UInt8]) {
        let hex = frame.map { String(format: "%02X", $0) }.joined(separator: " ")
        // The accumulator emits complete on-wire frames (F1 ... F2); decodeFrame
        // validates flags + stuffing + checksum, exactly like PM firmware would.
        guard let contents = CSAFEFrameCodec.decodeFrame(frame) else {
            print("🧪 VPM5 ⚠️ undecodable command frame (bad checksum/stuffing): \(hex)")
            respond(reject: true, echo: [])
            return
        }
        print("🧪 VPM5 📥 cmd: \(hex)")
        route(contents)
    }

    private func route(_ contents: [UInt8]) {
        guard let first = contents.first else { return }

        switch first {
        case 0x76:
            routeProprietary(contents)
        case 0x87:
            routePublicCombined(contents)
        case 0x86: // GoFinished — rejected unless inUse (17/17 captured)
            if slaveState == .inUse {
                slaveState = .finished
                respond(reject: false, echo: [])
                logTransition("GoFinished accepted (inUse → finished)")
            } else {
                respond(reject: true, echo: [])
                print("🧪 VPM5 ❌ GoFinished rejected (slave \(slaveState))")
            }
        case 0x82: // GoIdle — accept from ready/inUse/finished → idle; reject when already parked
            switch slaveState {
            case .ready, .inUse, .finished:
                slaveState = .idle
                respond(reject: false, echo: [])
                logTransition("GoIdle accepted (→ idle)")
            default:
                respond(reject: true, echo: [])
                print("🧪 VPM5 ❌ GoIdle rejected (slave \(slaveState))")
            }
        case 0x85: // GoInUse (Just Row follow-up)
            slaveState = .inUse
            respond(reject: false, echo: [])
        case 0x80: // GETSTATUS probe
            respond(reject: false, echo: [])
        default:
            print("🧪 VPM5 ⚠️ unhandled command 0x\(String(format: "%02X", first)) — ACKed")
            respond(reject: false, echo: [])
        }
    }

    /// 0x76 wrapper: SET_WORKOUTTYPE/WORKOUTDURATION/SPLITDURATION/CONFIGURE/SCREENSTATE.
    private func routeProprietary(_ contents: [UInt8]) {
        // contents = [0x76, byteCount, sub...]
        guard contents.count >= 3 else { respond(reject: true, echo: []); return }
        let sub = Array(contents.dropFirst(2))

        // Standalone TERMINATE: 76 04 13 02 01 02
        if sub.count == 4, sub[0] == 0x13, sub[2] == 0x01, sub[3] == 0x02 {
            respond(reject: false, echo: [0x76, 0x01, 0x13])
            handleTerminate()
            return
        }

        // Parse subcommands: id, len, payload
        var ids: [UInt8] = []
        var workoutType: UInt8?
        var durationType: UInt8?
        var durationValue = 0
        var restSeconds = 0     // SC-7nqt.11: id 0x04 SET_RESTDURATION (native intervals)
        var rounds = 0          // SC-7nqt.11: id 0x18 SET_WORKOUTINTERVALCOUNT
        var i = 0
        while i + 1 < sub.count {
            let id = sub[i]
            let len = Int(sub[i + 1])
            let payload = Array(sub.dropFirst(i + 2).prefix(len))
            ids.append(id)
            if id == 0x01, let t = payload.first { workoutType = t }
            if id == 0x03, payload.count == 5 {
                durationType = payload[0]
                durationValue = payload.dropFirst().reduce(0) { ($0 << 8) | Int($1) }  // u32 MSB-first
            }
            // SET_RESTDURATION is len-2 MSB-first, 1s units (CSAFEProtocol:315/340).
            if id == 0x04, payload.count == 2 { restSeconds = (Int(payload[0]) << 8) | Int(payload[1]) }
            // SET_WORKOUTINTERVALCOUNT is len-1 (trace-derived; the erg actually IGNORES it
            // and runs unbounded — we honor it for a clean self-terminating summary).
            if id == 0x18, let r = payload.first { rounds = Int(r) }
            i += 2 + len
        }

        // Captured firmware truth: programming during an ACTIVE piece → F1 99 reject
        // (all piece types, BOTH dialects — see pieceActiveRejectsPrograms).
        if workoutType != nil, pieceActiveRejectsPrograms {
            rejectProgramPieceActive()
            return
        }

        switch workoutType {
        case 0x03 where durationType == 0x80: // FIXEDDIST_SPLITS
            respond(reject: false, echo: [0x76, UInt8(ids.count)] + ids)
            acceptProgram(.distance(meters: durationValue))
        case 0x05 where durationType == 0x00: // FIXEDTIME_SPLITS (LOG15:16046-16049)
            respond(reject: false, echo: [0x76, UInt8(ids.count)] + ids)
            acceptProgram(.time(seconds: durationValue / 100))  // wire value is 0.01s units
        case 0x0A where durationType == 0x40: // FIXEDCALORIE_SPLITS (LOG11:129316+)
            respond(reject: false, echo: [0x76, UInt8(ids.count)] + ids)
            acceptProgram(.calories(cals: durationValue))       // raw cals, unscaled
        case 0x01: // JustRow (proprietary)
            respond(reject: false, echo: [0x76, UInt8(ids.count)] + ids)
            acceptJustRow()
        case 0x07 where durationType == 0x80: // FIXEDDIST_INTERVAL (SC-7nqt.11; log16 piece #9)
            respond(reject: false, echo: [0x76, UInt8(ids.count)] + ids)
            // INTERVALCOUNT (0x18) is echo-accepted above; the REAL erg then IGNORES it and
            // runs UNBOUNDED (the captured "zombie 4th interval" past a programmed count of 3).
            // We model a COUNT-HONORING end (design.md's "flagged counterfactual") so the piece
            // self-terminates into ONE clean 0x0039 — the app completes counter-driven
            // regardless. Default to 1 round if 0x18 was absent (2-arg spec-vector frame).
            acceptProgram(.interval(workMeters: durationValue,
                                    restSeconds: restSeconds,
                                    rounds: max(1, rounds)))
        default:
            respond(reject: false, echo: [0x76, UInt8(ids.count)] + ids)
        }
    }

    /// Public combined frames start with GoReady 0x87: SETHORIZONTAL (accepted ≥500m),
    /// SETTWORK (always rejected — firmware truth), SETUSERCFG1 Just Row, SETCALORIES
    /// (ACK-then-ignore — firmware truth).
    private func routePublicCombined(_ contents: [UInt8]) {
        let body = Array(contents.dropFirst())
        // The captured mid-piece F1 99 was itself a PUBLIC re-program (`F1 87 21 …`
        // during the mid-piece reconnect, pm5-older-logs-truths §attach-mid-piece):
        // the reject gate applies to this dialect's program frames identically.
        if let first = body.first, first == 0x21 || first == 0x1A, pieceActiveRejectsPrograms {
            rejectProgramPieceActive()
            return
        }
        if body.count >= 5, body[0] == 0x21 { // SETHORIZONTAL dist u16LE + unit
            let meters = Int(body[2]) | (Int(body[3]) << 8)
            if meters < Self.pm5MinProgrammableDistance {
                // Min-split artifact: split-less public frame under 500m is rejected.
                respond(reject: true, echo: [])
                print("🧪 VPM5 ❌ public SETHORIZONTAL \(meters)m rejected (sub-500m min-split artifact)")
                return
            }
            respond(reject: false, echo: [])
            slaveState = .inUse   // frame ends in GoInUse
            acceptProgram(.distance(meters: meters))
            return
        }
        if body.count >= 1, body[0] == 0x20 { // SETTWORK — dead on this firmware
            respond(reject: true, echo: [])
            print("🧪 VPM5 ❌ public SETTWORK rejected (firmware truth: F1 91-class)")
            return
        }
        if body.count >= 1, body[0] == 0x23 { // SETCALORIES — silently ignored
            respond(reject: false, echo: [])
            print("🧪 VPM5 ⚠️ public SETCALORIES ACKed and IGNORED (firmware truth) — no target armed")
            return
        }
        if body.count >= 2, body[0] == 0x1A { // SETUSERCFG1 wrapper (public Just Row)
            respond(reject: false, echo: [])
            acceptJustRow()
            return
        }
        respond(reject: false, echo: [])
    }

    /// Captured firmware truth (F1 99, both dialects): programming during an ACTIVE
    /// piece is rejected. Active = .rowing PLUS the 3-4-frame workoutEnd walk
    /// (.ended) — accepting there would replace the phase before the ended→logged
    /// transition emits the 0x0039, and hardware delivers the official for EVERY
    /// completed piece (pm5-older-logs-truths §4). NOT .armed: captured programs
    /// were accepted from inUse (a 60s program overrode a pending 1000m mid-inUse).
    private var pieceActiveRejectsPrograms: Bool {
        switch phase {
        case .rowing, .ended, .resting: return true  // .resting: mid-interval, programs reject (F1 99)
        default: return false
        }
    }

    private func rejectProgramPieceActive() {
        respond(reject: true, echo: [])
        print("🧪 VPM5 ❌ program rejected — piece active (captured F1 99)")
    }

    private func handleTerminate() {
        switch phase {
        case .logged, .ended:
            // Captured: terminate-from-logged zeroes everything after a short stale window.
            lastValues = (frozenElapsed, frozenDistance, workoutTypeByte)
            phase = .staleWindow(framesLeft: 2, then: .clearToIdle)
            slaveState = .ready
            logTransition("TERMINATE from logged park → stale window → cleared idle")
        case .rowing(let piece), .resting(let piece, _):
            // SC-7nqt.12: an UNBOUNDED native interval ends ONLY here — the real erg ran
            // zombie intervals past the programmed count until the athlete hit TERMINATE,
            // and that manual terminate DID emit a real 0x0039 (type 0x07) → the app's
            // counter-driven finalize + re-arm. Walk .ended→.logged like a natural piece
            // end so emitEndOfWorkoutSummary fires the interval 0x0039 (clean
            // rounds×workMeters, work-only elapsed) + its paired 0x003A.
            if config.intervalUnbounded, case .interval = piece {
                endPiece(piece, note: "TERMINATE on unbounded interval → interval 0x0039 (type 0x07) + 0x003A, \(String(format: "%.0f", intervalCumulativeMeters))m rowed / clean summary, \(String(format: "%.1f", intervalWorkElapsed))s work → workoutEnd (SC-7nqt.12)")
                break
            }
            // UNCAPTURED corner: TERMINATE during an actively-rowing single piece (or a
            // mid-interval rest in the default count-honoring mode) — modeled as a real
            // termination (live values go stale, then the cleared idle park; no 0x0039, the
            // piece never completed). The virtual athlete never stops pulling, so a flash-only
            // no-op here would strand the phase in .rowing forever and the F1 99 program reject
            // above would turn the app's TERMINATE→program recovery grammar (fresh-piece gate
            // timeout, mid-row reset/restart) into a permanent stall — a shape real hardware
            // cannot reach (adversarial P2 finding).
            lastValues = (elapsed, distance, workoutTypeByte)
            phase = .staleWindow(framesLeft: 2, then: .clearToIdle)
            slaveState = .ready
            logTransition("TERMINATE mid-row → stale window → cleared idle (UNCAPTURED corner, modeled as real termination — no 0x0039)")
        default:
            // Captured: terminate with nothing parked leaves counters UNCHANGED and
            // flashes a single 0x0B frame.
            terminateFlashPending = true
            slaveState = .ready
            logTransition("TERMINATE with nothing parked → 0x0B flash, counters unchanged")
        }
    }

    private func acceptProgram(_ piece: Piece) {
        // Captured: 1-3 in-flight frames still carry the previous piece's values.
        lastValues = (elapsed > 0 ? elapsed : frozenElapsed,
                      distance > 0 ? distance : frozenDistance,
                      workoutTypeByte)
        phase = .staleWindow(framesLeft: 2, then: .arm(piece))
        switch piece {
        case .distance(let m):
            logTransition("distance program accepted: \(m)m → stale window → armed zeros")
        case .time(let s):
            logTransition("time program accepted: \(s)s → stale window → armed (counters RETAINED — LOG15)")
        case .calories(let c):
            logTransition("calorie program accepted: \(c) cal → stale window → armed zeros")
        case .interval(let m, let rest, let rounds):
            logTransition("interval program accepted: \(rounds)×\(m)m / \(rest)s → stale window → armed zeros")
        case .justRow:
            break
        }
    }

    private func acceptJustRow() {
        // Captured: Just Row resets counters at ENTRY (no stale window in LOG15).
        resetPieceCounters()
        workoutTypeByte = 0x01
        durationBytes = (0, 0x80)
        phase = .armed(.justRow)
        armedTicks = 0
        logTransition("Just Row armed (counters reset at entry, no target, no summary)")
    }

    // MARK: - CSAFE responses

    private func respond(reject: Bool, echo: [UInt8]) {
        // Toggle rule (captured, 30/30): accepted responses flip the latch and use the
        // new value; rejects repeat the current value. Consecutive identical rejects
        // are then byte-identical and the app's duplicate dropper swallows them —
        // exactly like hardware.
        if !reject { toggleBit.toggle() }
        let status: UInt8 = (toggleBit ? 0x80 : 0x00)
            | (reject ? 0x10 : 0x00)
            | (slaveState.rawValue & 0x0F)
        let frame = CSAFEFrameCodec.buildFrame(contents: [status] + echo)
        let deliver = { [weak self] in
            guard let self, self.isChannelOpen else { return }
            let hex = frame.map { String(format: "%02X", $0) }.joined(separator: " ")
            print("🧪 VPM5 📤 response: \(hex)")
            self.emit(Self.csafeRxUUID, Data(frame))
        }
        if config.responseLatencySeconds <= 0 {
            deliver()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + config.responseLatencySeconds, execute: deliver)
        }
    }

    // MARK: - Tick engine (0.5s, phase-independent — the stream NEVER stops)

    func tick() {
        totalTicks += 1
        advancePhase()
        emitGeneralStatus()
        emitAdditionalStatus1()
        emitAdditionalStatus2()   // SC-fadm: 0x0033 live additional status 2
        if totalTicks % 2 == 0 {
            emitFTMSPair()
        }
        servicePendingSummary()
        serviceCooldown()
    }

    /// P2a: count down the held 0x0039s AFTER the tick's status frames, so the
    /// logged park keeps flowing through the gap and the summary lands late —
    /// even if a TERMINATE cleared the counters in the meantime (the bytes were
    /// pre-rendered at end-walk time, like the erg's log memory). FIFO: only the
    /// head counts down, at most one summary delivers per tick, and later pieces
    /// wait their turn behind it.
    private func servicePendingSummary() {
        guard !pendingSummaries.isEmpty else { return }
        pendingSummaries[0].ticksLeft -= 1
        if pendingSummaries[0].ticksLeft <= 0 {
            let head = pendingSummaries.removeFirst()
            deliverSummary(head.data, additional: head.additional, official: head.official)
        }
    }

    /// P2c: the athlete keys the manual piece only after the erg has been
    /// CONTINUOUSLY parked (.logged/.idle) for the full walk-over — the countdown
    /// only runs while parked and RESTARTS on any phase change out of the parked
    /// states, so a one-tick inter-round park can never race the app's
    /// next-round program (the knob models a SINGLE-piece session's cooldown).
    private func serviceCooldown() {
        guard let ticks = cooldownTicksUntilKeyed else { return }
        switch phase {
        case .idle, .logged:
            if ticks > 1 {
                cooldownTicksUntilKeyed = ticks - 1
                return
            }
            cooldownTicksUntilKeyed = nil
            cooldownFired = true
            // Keypad programming is not a CSAFE exchange: no response frame, the
            // slave state goes manual, and the piece walks the normal lifecycle
            // to a second legitimate 0x0039.
            slaveState = .manual
            print("🧪 VPM5 🧊 athlete keys a manual \(config.cooldownPieceMeters)m cooldown (keypad — no CSAFE)")
            acceptProgram(.distance(meters: config.cooldownPieceMeters))
        default:
            // Not parked: the walk-over restarts from the top.
            if ticks != cooldownWalkOverTicks {
                cooldownTicksUntilKeyed = cooldownWalkOverTicks
                print("🧪 VPM5 🧊 cooldown walk-over reset (erg left the parked state mid-walk)")
            }
        }
    }

    private func advancePhase() {
        switch phase {
        case .idle, .logged:
            break

        case .staleWindow(let framesLeft, let then):
            if framesLeft <= 1 {
                switch then {
                case .arm(let piece):
                    switch piece {
                    case .distance(let m):
                        resetPieceCounters()
                        workoutTypeByte = 0x03
                        durationBytes = (m, 0x80)
                    case .time(let s):
                        // Captured (LOG15 + Concept2Manager .singleTime gate-skip,
                        // SC-wmoo.1 c2): a TIME program NEVER resets the counters —
                        // the armed zeros in the raw log belong to the preceding
                        // terminate-from-logged, not the program. After that common
                        // flow the retained counters are already zero (bit-identical
                        // to LOG15); over leftover meters they persist through the
                        // whole piece — the SC-wmoo.1 shape, an uncaptured corner.
                        if elapsed > 0 || distance > 0 {
                            print("🧪 VPM5 ⚠️ UNCAPTURED: TIME piece armed over nonzero counters (el=\(String(format: "%.1f", elapsed)) d=\(String(format: "%.1f", distance))) — piece-internal 0x0039 values are a modeling choice")
                        }
                        workoutTypeByte = 0x05
                        durationBytes = (s * 100, 0x00)   // 0.01s units on the wire (LOG15: 50 46 00 / 0x00)
                    case .calories(let c):
                        resetPieceCounters()
                        workoutTypeByte = 0x0A
                        durationBytes = (c, 0x40)         // raw cals, unscaled (LOG11: 08 00 00 / 0x40)
                    case .interval(let m, let rest, let rounds):
                        // Resets like distance; workoutDuration carries the PER-INTERVAL work
                        // meters (log16 armed frame: FA 00 00 = 250 / durationType 0x80).
                        resetPieceCounters()
                        workoutTypeByte = 0x07
                        durationBytes = (m, 0x80)
                        intervalRestSeconds = rest
                        intervalRoundsRemaining = rounds
                        if config.intervalUnbounded {
                            print("🧪 VPM5 🔁 native interval armed: \(rounds)×\(m)m / \(rest)s rest — UNBOUNDED (SC-7nqt.12): ignores 0x18 count, arms zombie intervals past \(rounds), ends ONLY on TERMINATE (emits interval 0x0039 type 0x07 + 0x003A). Summary = clean \(rounds * m)m, work-only elapsed (SC-fadm)")
                        } else {
                            print("🧪 VPM5 🔁 native interval armed: \(rounds)×\(m)m / \(rest)s rest — count-honoring self-terminate (real erg ignores 0x18 + runs unbounded; -VirtualPM5IntervalUnbounded models that). 0x07 type + 0x05→0x09→0x03 walk CONFIRMED (SC-7nqt.5 capture); 0x09 frame body still modeled")
                        }
                    case .justRow:
                        resetPieceCounters()
                        workoutTypeByte = 0x01
                        durationBytes = (0, 0x80)
                    }
                    armedTicks = 0
                    phase = .armed(piece)
                    logTransition("armed (type 0x\(String(format: "%02X", workoutTypeByte)), duration \(durationBytes.value))")
                case .clearToIdle:
                    resetPieceCounters()
                    workoutTypeByte = 0x01
                    durationBytes = (0, 0x80)
                    phase = .idle
                    logTransition("cleared to idle (zeros, type 0x01)")
                }
            } else {
                phase = .staleWindow(framesLeft: framesLeft - 1, then: then)
            }

        case .armed(let piece):
            armedTicks += 1
            if Double(armedTicks) * 0.5 >= config.startDelay {
                rowingTicks = 0
                dragFactor = 0
                currentHR = Double(config.hrStart)
                // TIME pieces run over RETAINED counters — completion and the
                // 0x0039 measure from this baseline. Everything else starts at 0.
                if case .time = piece {
                    pieceStartElapsed = elapsed
                    pieceStartDistance = distance
                } else {
                    pieceStartElapsed = 0
                    pieceStartDistance = 0
                }
                phase = .rowing(piece)
                logTransition("flywheel start (athlete pulls)")
            }

        case .rowing(let piece):
            rowingTicks += 1
            elapsed += 0.5
            intervalTotalElapsed += 0.5   // SC-7nqt.11: whole-session clock (wire `elapsed` is per-interval)
            intervalWorkElapsed += 0.5    // SC-fadm: WORK-only (NOT incremented in `.resting`)
            applyScript()
            if !scriptStopped {
                // Bounded jitter keeps every value inside the app's plausibility filters.
                currentPace = config.paceSecondsPer500 + Double(Int.random(in: -2...2, using: &rng))
                let distanceDelta = (500.0 / currentPace) * 0.5
                distance += distanceDelta
                intervalCumulativeMeters += distanceDelta  // SC-7nqt.11: monotonic totalWorkDistance
                avgPaceAccumulator += currentPace
                paceSamples += 1
                strokePhaseTicks += 1
                let ticksPerStroke = max(2, Int((60.0 / Double(config.strokeRate)) / 0.5))
                if strokePhaseTicks >= ticksPerStroke {
                    strokePhaseTicks = 0
                    strokeCount += 1
                }
                if rowingTicks > 2 { dragFactor = 122 + Int(rng.next() % 3) }
                // HR ramp ~0.55 bpm/s toward peak with ±1 jitter
                if config.strapPresent {
                    currentHR = min(Double(config.hrPeak), currentHR + 0.275) + Double(Int.random(in: -1...1, using: &rng))
                }
                let energyDelta = (wattsNow() * 3.44 + 300.0) / 3600.0 * 0.5
                energyKcal += energyDelta
                // SC-fadm: whole-piece accumulators for the 0x003A/0x0033 cal + avg-watt
                // fields (energyKcal resets each interval work round, these do not).
                pieceEnergyTotal += energyDelta
                pieceWattSum += wattsNow()
                pieceWattSamples += 1
            }
            switch piece {
            case .distance(let m):
                if distance >= Double(m) {
                    // Captured: distance pieces freeze EXACTLY at target.
                    distance = Double(m)
                    endPiece(piece, note: "target reached: \(m)m in \(String(format: "%.1f", elapsed))s → workoutEnd")
                }
            case .time(let s):
                if elapsed - pieceStartElapsed >= Double(s) {
                    // Captured (LOG15): elapsed freezes EXACTLY at target (18000
                    // exact); distance freezes wherever it was. 0.5s ticks over
                    // integer seconds always land exactly on the boundary.
                    elapsed = pieceStartElapsed + Double(s)
                    endPiece(piece, note: "target reached: \(s)s (\(String(format: "%.1f", distance - pieceStartDistance))m rowed) → workoutEnd")
                }
            case .calories(let c):
                if energyKcal >= Double(c) - 0.30 {
                    // Freeze energy just UNDER the target so the final FTMS-B
                    // total floors to target-1 — the SC-zjrh wire artifact the
                    // app's `>= target-1 || pm5SaysDone` guard exists for. The
                    // extra clamp keeps the floor deterministic at any pace.
                    energyKcal = min(energyKcal, Double(c) - 0.01)
                    endPiece(piece, note: "target reached: \(c) cal (frozen at \(String(format: "%.2f", energyKcal)) kcal → wire floor \(Int(energyKcal))) → workoutEnd")
                }
            case .interval(let m, _, _):
                if distance >= Double(m) {
                    // Captured (log16): the athlete paddles ~2-3m past target into the
                    // work→rest transition (d 250.0→253.2) — keep the NATURAL overshoot
                    // (unlike distance singles, which snap to exactly target).
                    intervalRoundsRemaining -= 1
                    if !config.intervalUnbounded && intervalRoundsRemaining <= 0 {
                        // Final interval (count-honoring DEFAULT): NO rest — walk straight to
                        // workoutEnd + one 0x0039. Elapsed reported is WORK-only (SC-fadm).
                        endPiece(piece, note: "final interval done: \(String(format: "%.0f", intervalCumulativeMeters))m total in \(String(format: "%.1f", intervalWorkElapsed))s work → workoutEnd")
                    } else {
                        // Enter rest (state 0x09→0x03). Per-interval elapsed + distance FREEZE
                        // at the overshoot here and reset to 0 at the next work start (log16).
                        // Rest duration comes from the wire (0x04), == the app's config.restDuration,
                        // so the emulator and the app's own rest timer stay round-by-round synced.
                        // SC-7nqt.12: under -VirtualPM5IntervalUnbounded the real erg IGNORES the
                        // 0x18 count and keeps arming zombie intervals PAST it (intervalRoundsRemaining
                        // goes ≤0/negative — tracked, never a terminator); the piece ends ONLY on a
                        // manual TERMINATE, which then emits the interval 0x0039+0x003A (handleTerminate).
                        intervalRestFramesTotal = max(2, Int((Double(intervalRestSeconds) / 0.5).rounded()))
                        phase = .resting(piece, framesLeft: intervalRestFramesTotal)
                        let leftNote = config.intervalUnbounded && intervalRoundsRemaining <= 0
                            ? "UNBOUNDED +\(1 - intervalRoundsRemaining) past count"
                            : "\(intervalRoundsRemaining) left"
                        logTransition("interval work done (\(leftNote), \(String(format: "%.1f", distance))m / \(String(format: "%.0f", intervalCumulativeMeters))m cum) → rest \(intervalRestSeconds)s")
                    }
                }
            case .justRow:
                break
            }

        case .ended(let piece, let framesLeft):
            if framesLeft <= 1 {
                emitEndOfWorkoutSummary(piece)
                phase = .logged(piece)
                logTransition("workoutLogged (parked, frozen broadcast continues)")
            } else {
                phase = .ended(piece, framesLeft: framesLeft - 1)
            }

        case .resting(let piece, let framesLeft):
            intervalTotalElapsed += 0.5   // the session clock runs through rest (wire `elapsed` frozen)
            if framesLeft <= 1 {
                // Rest over → next work round. Per-interval reset (log16): elapsed + distance
                // to 0, FTMS-B stroke/energy counters to 0; cumulative meters, session clock,
                // and rowingTicks (so the state stays 0x05, no 0x00 pre-flip) are RETAINED.
                // No startDelay for rounds 2+ — the athlete never left the erg → straight to rowing.
                elapsed = 0
                distance = 0
                strokeCount = 0
                strokePhaseTicks = 0
                energyKcal = 0
                phase = .rowing(piece)
                logTransition("interval rest over → next work round (per-interval elapsed+distance reset)")
            } else {
                phase = .resting(piece, framesLeft: framesLeft - 1)
            }
        }
    }

    /// Shared end-walk entry: freeze the wire values, mark the erg self-logged,
    /// and start the 3-4 frame workoutEnd window (identical for all piece types).
    private func endPiece(_ piece: Piece, note: String) {
        frozenElapsed = elapsed
        frozenDistance = distance
        slaveState = .manual  // by the time the app's GoFinished arrives, the erg self-logged
        phase = .ended(piece, framesLeft: 3 + Int(rng.next() % 2))
        logTransition(note)
    }

    private func applyScript() {
        for event in config.script {
            switch event {
            case .stop(let t) where !scriptStopped && elapsed >= t:
                scriptStopped = true
                print("🧪 VPM5 🎬 script: athlete STOPPED at \(String(format: "%.1f", elapsed))s (distance stalls, clock runs)")
            case .resume(let t) where scriptStopped && elapsed >= t:
                scriptStopped = false
                print("🧪 VPM5 🎬 script: athlete RESUMED at \(String(format: "%.1f", elapsed))s")
            case .disconnect(let t, let after) where !scriptDisconnectFired && elapsed >= t:
                scriptDisconnectFired = true
                print("🧪 VPM5 🔌 script: BLE DROP at \(String(format: "%.1f", elapsed))s — link down, auto-reconnect in \(String(format: "%.0f", after))s (firmware phase survives)")
                // Defer to the main queue: the manager's disconnect() invalidates this
                // very tick timer, so let the in-flight tick finish first.
                DispatchQueue.main.async { [weak self] in
                    self?.onDisconnectRequest?(after)
                }
            default:
                break
            }
        }
    }

    private func resetPieceCounters() {
        elapsed = 0
        distance = 0
        frozenElapsed = 0
        frozenDistance = 0
        rowingTicks = 0
        strokeCount = 0
        strokePhaseTicks = 0
        energyKcal = 0
        avgPaceAccumulator = 0
        paceSamples = 0
        dragFactor = 0
        scriptStopped = false
        intervalCumulativeMeters = 0   // SC-7nqt.11: reset at every arm (per-interval reset keeps it)
        intervalTotalElapsed = 0
        intervalWorkElapsed = 0         // SC-fadm
        pieceEnergyTotal = 0            // SC-fadm
        pieceWattSum = 0                // SC-fadm
        pieceWattSamples = 0            // SC-fadm
    }

    private func wattsNow() -> Double {
        // Concept2 relation: watts = 2.80 / (pace per meter)^3 — validated against the
        // captured pair 111 s/500m ↔ 254W.
        let pacePerMeter = currentPace / 500.0
        return 2.80 / (pacePerMeter * pacePerMeter * pacePerMeter)
    }

    // MARK: - Frame synthesis

    private func u16LE(_ v: Int) -> [UInt8] { [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF)] }
    private func u24LE(_ v: Int) -> [UInt8] { [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF), UInt8((v >> 16) & 0xFF)] }

    /// Current on-wire (elapsed, distance, state byte, rowing/stroke states) per phase.
    private func wireValues() -> (elapsed: Double, distance: Double, state: UInt8, rowing: UInt8, stroke: UInt8, type: UInt8) {
        switch phase {
        case .idle:
            // Consume the terminate flash HERE (LOG11: the 0x0B frame emits where
            // the terminate happened) so it never displaces into the next piece's
            // first armed frame (off-catalog).
            if terminateFlashPending {
                terminateFlashPending = false
                return (elapsed, distance, 0x0B, 0, 1, workoutTypeByte)
            }
            return (elapsed, distance, 0x00, 0, 0, workoutTypeByte)
        case .staleWindow:
            if terminateFlashPending {
                terminateFlashPending = false
                return (lastValues.elapsed, lastValues.distance, 0x0B, 0, 1, lastValues.type)
            }
            return (lastValues.elapsed, lastValues.distance, 0x00, 0, 1, lastValues.type)
        case .armed:
            if terminateFlashPending {
                terminateFlashPending = false
                return (elapsed, distance, 0x0B, 0, 1, workoutTypeByte)
            }
            // Post-reset counters: 0/0 for distance/cal/JustRow (bit-identical to
            // the P1 hard zeros); RETAINED live values for TIME (never reset —
            // zero anyway after the common terminate-from-logged flow, LOG15).
            return (elapsed, distance, 0x00, 0, 0, workoutTypeByte)
        case .rowing:
            if terminateFlashPending { terminateFlashPending = false }
            // Captured: elapsed ticks 1-2 frames BEFORE the state byte flips. Interval WORK
            // reads 0x05 intervalWorkDistance (log16); single pieces read 0x01 workoutRow.
            let workState: UInt8 = workoutTypeByte == 0x07 ? 0x05 : 0x01
            let state: UInt8 = rowingTicks <= 2 ? 0x00 : workState
            let stroke: UInt8 = scriptStopped ? 1 : (strokePhaseTicks % 2 == 0 ? 2 : 4)
            return (elapsed, distance, state, scriptStopped ? 0 : 1, stroke, workoutTypeByte)
        case .resting(_, let framesLeft):
            // SC-7nqt.11 / SC-fadm: the FIRST 1-2 rest frames read 0x09 intervalWorkDistanceToRest,
            // the remainder 0x03 intervalRest — the 0x05→0x09→0x03 SEQUENCE is CONFIRMED by the
            // 2026-07-20 capture; only the 0x09 frame BODY (elapsed/distance bytes) is still modeled.
            // elapsed + distance stay FROZEN at the work overshoot; rowingState 0 (paddling
            // stopped), strokeState settles to 1. Distance resets to 0 on the next work round.
            let state: UInt8 = framesLeft > intervalRestFramesTotal - 2 ? 0x09 : 0x03
            return (elapsed, distance, state, 0, 1, workoutTypeByte)
        case .ended:
            return (frozenElapsed, frozenDistance, 0x0A, 0, 1, workoutTypeByte)
        case .logged:
            // Captured: the park keeps the piece's workoutType until TERMINATE/exit.
            return (frozenElapsed, frozenDistance, 0x0C, 0, 1, workoutTypeByte)
        }
    }

    private func emitGeneralStatus() {
        let v = wireValues()
        var bytes: [UInt8] = []
        bytes += u24LE(Int(v.elapsed * 100))
        bytes += u24LE(Int(v.distance * 10))
        bytes.append(v.type)                       // workoutType
        bytes.append(intervalTypeByte(for: v.type, state: v.state)) // intervalType (piece/phase-specific, captured)
        bytes.append(v.state)                      // workoutState
        bytes.append(v.rowing)                     // rowingState
        bytes.append(v.stroke)                     // strokeState
        // totalWorkDistance: TIME/CAL singles broadcast 0 for the WHOLE piece
        // (LOG15/LOG11). Distance keeps Int(v.distance) — a P1 golden-locked
        // divergence from capture (real singles show 0 too); P3 recalibration.
        // Intervals (0x07) ride the MONOTONIC cumulative across rounds — incl. the
        // per-interval distance byte having reset (log16: 250→518→771).
        let totalWorkDistance: Int
        switch v.type {
        case 0x05, 0x0A: totalWorkDistance = 0
        case 0x07: totalWorkDistance = Int(intervalCumulativeMeters)
        default: totalWorkDistance = Int(v.distance)
        }
        bytes += u24LE(totalWorkDistance)
        bytes += u24LE(durationBytes.value)        // workoutDuration
        bytes.append(durationBytes.type)           // durationType (0x80 distance)
        bytes.append(UInt8(clamping: dragFactor))  // drag factor (0 until first strokes)
        emit(Self.generalStatusUUID, Data(bytes))
    }

    private func emitAdditionalStatus1() {
        let v = wireValues()
        let rowingLive = !scriptStopped && isRowingPhase
        let speed = rowingLive ? 500.0 / currentPace : 0
        var bytes: [UInt8] = []
        bytes += u24LE(Int(v.elapsed * 100))
        bytes += u16LE(Int(speed * 1000))                       // 0.001 m/s
        bytes.append(UInt8(clamping: isRowingPhase ? config.strokeRate : 0))
        bytes.append(strapByteFor0032())                        // HR or 0xFF
        bytes += u16LE(Int(currentPace * 100))                  // current pace 0.01 s/500m
        bytes += u16LE(Int(avgPace() * 100))                    // avg pace
        // SC-7nqt.11: during interval REST the erg counts the rest down in 0x0032[13:16]
        // (u24LE ×0.01s, 1.00s per 2 frames — log16). Cosmetic for the app (its parser stops
        // at byte 10) but faithful + log-visible; zero in every other phase (bit-identical to P1).
        let restCentis: Int = {
            if case .resting(_, let framesLeft) = phase { return max(0, Int(Double(framesLeft) * 0.5 * 100)) }
            return 0
        }()
        bytes += [0, 0]                                         // interval rest distance (bytes 11-12)
        bytes += u24LE(restCentis)                             // interval rest time (bytes 13-15)
        bytes.append(0)                                        // byte 16
        emit(Self.additionalStatus1UUID, Data(bytes))
    }

    /// SC-fadm: 0x0033 Additional Status 2 (live, ~2Hz, 20 bytes). The app reads only bytes
    /// 0-7 (elapsed, interval count, avg power, total calories); bytes 8-19 are populated with
    /// self-consistent split values (§3 layout) but the parser ignores them.
    private func emitAdditionalStatus2() {
        let v = wireValues()
        let avgW = pieceWattSamples > 0 ? Int((pieceWattSum / Double(pieceWattSamples)).rounded()) : 0
        let totalCal = Int(pieceEnergyTotal.rounded())
        // Completed interval count = programmed − remaining, from the live interval piece.
        let intervalsDone: Int = {
            switch phase {
            case .rowing(.interval(_, _, let rounds)), .resting(.interval(_, _, let rounds), _):
                return max(0, rounds - intervalRoundsRemaining)
            default: return 0
            }
        }()
        var b: [UInt8] = []
        b += u24LE(Int(v.elapsed * 100))                    // 0-2   elapsed ×0.01s
        b.append(UInt8(clamping: intervalsDone))            // 3     interval count
        b += u16LE(min(max(0, avgW), 0xFFFF))               // 4-5   avg power (app reads)
        b += u16LE(min(max(0, totalCal), 0xFFFF))           // 6-7   total calories (app reads)
        b += u16LE(min(max(0, Int(avgPace() * 100)), 0xFFFF)) // 8-9   split avg pace ×0.01s/500m
        b += u16LE(min(max(0, avgW), 0xFFFF))               // 10-11 split avg power
        b += u16LE(0)                                       // 12-13 split avg cal (modeled 0)
        b += u24LE(0)                                       // 14-16 last split time (modeled 0)
        b += u24LE(0)                                       // 17-19 last split dist (modeled 0)
        emit(Self.additionalStatus2UUID, Data(b))
    }

    private func emitFTMSPair() {
        let v = wireValues()
        let watts = isRowingPhase && !scriptStopped ? Int(wattsNow()) : 0
        // Variant A: flags 0x0AFF (19B) — MoreData=1, stroke fields absent.
        var a: [UInt8] = [0xFF, 0x0A]
        a.append(UInt8(clamping: config.strokeRate * 2))        // avg stroke rate ×0.5spm
        a += u24LE(Int(v.distance))                             // total distance, whole m
        a += u16LE(Int(currentPace))                            // inst pace, whole s
        a += u16LE(Int(avgPace()))                              // avg pace
        a += u16LE(watts)                                       // inst power
        a += u16LE(watts)                                       // avg power
        a += u16LE(dragFactor)                                  // resistance = drag
        a.append(config.strapPresent && currentHR > 0 ? UInt8(clamping: Int(currentHR)) : 0x00)
        a += u16LE(Int(v.elapsed))                              // elapsed, whole s
        emit(Self.ftmsRowerDataUUID, Data(a))
        // Variant B: flags 0x0100 (10B) — stroke rate + count, energy; perMin always 0xFF.
        var b: [UInt8] = [0x00, 0x01]
        b.append(UInt8(clamping: config.strokeRate * 2))
        b += u16LE(strokeCount)
        b += u16LE(Int(energyKcal))
        b += u16LE(Int(wattsNow() * 3.44 + 300))
        b.append(0xFF)
        emit(Self.ftmsRowerDataUUID, Data(b))
    }

    /// 0x0039 — the 20-byte official end-of-workout summary. Fixed epoch DATE
    /// (2026-07-16, matching the calibration captures: word 0x3507) but an ADVANCING
    /// virtual wall clock for minute/hour, so consecutive pieces never collide in the
    /// app's revision/duplicate/merge logic (critique MAJOR).
    private func emitEndOfWorkoutSummary(_ piece: Piece) {
        // 20-byte layout is identical for distance/TIME/CAL (LOG15/LOG11); only the
        // workoutType byte and the elapsed/distance semantics differ. TIME uses
        // PIECE-INTERNAL values (baseline-relative — over the common terminated-
        // to-zero counters these equal the frozen wire values, bit-matching the
        // captured 50 46 00 / 6E 1E 00 pair). NB: no calorie count exists anywhere
        // in 0x0039 — erg-truth cal rides 0x003A, still unemitted (P3).
        let summaryType: UInt8
        let sumElapsed: Double
        let sumDistance: Double
        switch piece {
        case .distance:
            summaryType = 0x03
            sumElapsed = frozenElapsed
            sumDistance = frozenDistance
        case .time:
            summaryType = 0x05
            sumElapsed = frozenElapsed - pieceStartElapsed     // == target exactly
            sumDistance = frozenDistance - pieceStartDistance  // what THIS piece rowed
        case .calories:
            summaryType = 0x0A
            sumElapsed = frozenElapsed
            sumDistance = frozenDistance
        case .interval(let workMeters, _, let rounds):
            // SC-fadm: 0x0039 byte[17]=0x07 CONFIRMED by the 2026-07-20 clean capture (the
            // earlier "degenerate 0x03 zombie" worry was itself a post-terminate artifact — a
            // no-touch interval end-summary really carries 0x07). The interval summary rides the
            // CLEAN programmed distance (rounds × workMeters = 750.0m for a 3×250m), NOT the
            // monotonic overshoot cumulative (752-771m), which rides only the WIRE
            // totalWorkDistance (:0x0031). Elapsed is WORK-only (206.7s captured), NOT the
            // whole-session clock intervalTotalElapsed that includes rest.
            summaryType = 0x07
            sumElapsed = intervalWorkElapsed
            sumDistance = Double(rounds * workMeters)
        case .justRow:
            return  // Just Row: no summary (captured)
        }
        let virtualMinutes = totalTicks / 120
        let minute = UInt8(virtualMinutes % 60)
        let hour = UInt8((6 + virtualMinutes / 60) % 24)
        let endHR: UInt8 = config.strapPresent && currentHR > 0 ? UInt8(clamping: Int(currentHR)) : 0
        // Same pace formula for every type (LOG15 TIME 0x0039 verifies it); a
        // zero-distance piece legitimately logs 0xFFFF (corrupted-capture encoding).
        let paceTenths = sumElapsed > 0 && sumDistance > 0
            ? Int((sumElapsed / (sumDistance / 500.0)) * 10)
            : 0xFFFF

        var bytes: [UInt8] = []
        bytes += [0x07, 0x35]                  // log date word 0x3507 = 2026-07-16
        bytes.append(minute)
        bytes.append(hour)
        bytes += u24LE(Int(sumElapsed * 100))
        bytes += u24LE(Int(sumDistance * 10))
        bytes.append(UInt8(clamping: config.strokeRate))
        bytes.append(endHR)                    // ending HR: real when strap present
        bytes += [0x00, 0x00, 0x00]            // avg/min/max HR — ALWAYS 0 on this erg
        bytes.append(UInt8(clamping: max(dragFactor, 122)))
        bytes.append(0x00)                     // recovery HR (revision re-fire deferred)
        bytes.append(summaryType)              // workoutType: 0x03 / 0x05 / 0x0A
        bytes += u16LE(min(paceTenths, 0xFFFF))
        let hexOut = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
        let official = "🧪 VPM5 🏁 piece official: \(String(format: "%.1f", sumElapsed))s \(String(format: "%.1f", sumDistance))m summary=\(hexOut)"
        // SC-fadm: build the paired 0x003A Additional End Summary (erg-truth calories the
        // 0x0039 lacks, avg watts, split type/size/count, interval rest) sharing THIS 0x0039's
        // logEntryDate + logEntryTime (minute/hour) so the app's merged() dedup/pair fires.
        let additional = Data(buildAdditionalEndSummary(piece, minute: minute, hour: hour, sumElapsed: sumElapsed))
        if config.summaryDelaySeconds > 0 {
            // P2a: bytes + log line are frozen NOW (the erg's log memory); the
            // wire delivery waits out the tick countdown in servicePendingSummary.
            // Append, never overwrite: a piece ending inside another's hold
            // window queues its 0x0039 behind the held one (FIFO).
            let ticks = max(1, Int((config.summaryDelaySeconds / 0.5).rounded()))
            pendingSummaries.append((Data(bytes), additional, official, ticks))
            print("🧪 VPM5 ⏲️ 0x0039 (+0x003A) held for \(config.summaryDelaySeconds)s past logged (status frames keep flowing)")
        } else {
            deliverSummary(Data(bytes), additional: additional, official: official)
        }
    }

    /// SC-fadm: build the 19-byte 0x003A Additional End Summary paired to a 0x0039.
    /// Shares the 0x0039's logEntryDate (0x3507) + logEntryTime (minute,hour) so the app's
    /// merged() pairs them. Carries the erg-truth calories the 0x0039 lacks, average watts,
    /// split type/size/count, and interval rest. Field VALUES are the emulator's own physics
    /// (self-consistent), not the capture's fixed numbers (which were pace-specific).
    private func buildAdditionalEndSummary(_ piece: Piece, minute: UInt8, hour: UInt8, sumElapsed: Double) -> [UInt8] {
        let splitType: UInt8
        let splitSize: Int
        let splitCount: Int
        let restTime: Int
        switch piece {
        case .interval(let workMeters, let restSeconds, let rounds):
            splitType = 0x01                  // distance split (captured)
            splitSize = workMeters            // per-interval work meters (250 captured)
            splitCount = rounds               // PROGRAMMED count (3) — recorded even when the erg ran a zombie 4th
            restTime = restSeconds            // per-interval rest (30s captured)
        case .time(let seconds):
            splitType = 0x00                  // time split (captured): splitSize is SECONDS
            splitSize = seconds
            splitCount = 1
            restTime = 0
        case .distance(let meters):
            // Default-split-remainder, MODELED from 2 captured points (250m→250/1, 500m→400/2):
            // split = min(size, 400), count = ceil(size/split). Longer pieces are extrapolated.
            splitType = 0x01
            splitSize = min(max(1, meters), 400)
            splitCount = max(1, Int((Double(meters) / Double(splitSize)).rounded(.up)))
            restTime = 0
        case .calories:
            // Cal-piece 0x003A shape UNCAPTURED — modeled as one distance split over the meters
            // actually rowed (SC-fadm, flagged).
            splitType = 0x01
            splitSize = max(1, Int(frozenDistance))
            splitCount = 1
            restTime = 0
        case .justRow:
            splitType = 0x01; splitSize = 0; splitCount = 1; restTime = 0
        }
        let totalCal = Int(pieceEnergyTotal.rounded())
        let avgW = pieceWattSamples > 0 ? Int((pieceWattSum / Double(pieceWattSamples)).rounded()) : 0
        let avgCalHr = sumElapsed > 0 ? Int((Double(totalCal) * 3600.0 / sumElapsed).rounded()) : 0
        var b: [UInt8] = []
        b += [0x07, 0x35]                     // logEntryDate 0x3507 — MUST match the paired 0x0039
        b.append(minute)                      // logEntryTime low  (== 0x0039 byte[2])
        b.append(hour)                        // logEntryTime high (== 0x0039 byte[3])
        b.append(splitType)                   // byte 4
        b += u16LE(splitSize)                 // bytes 5-6
        b.append(UInt8(clamping: splitCount)) // byte 7
        b += u16LE(min(max(0, totalCal), 0xFFFF))   // bytes 8-9   total calories
        b += u16LE(min(max(0, avgW), 0xFFFF))       // bytes 10-11 average watts
        b += u24LE(0)                         // bytes 12-14 total rest distance (virtual athlete rests → 0)
        b += u16LE(min(max(0, restTime), 0xFFFF))   // bytes 15-16 interval rest time (s)
        b += u16LE(min(max(0, avgCalHr), 0xFFFF))   // bytes 17-18 avg cal/hr
        return b
    }

    private func deliverSummary(_ data: Data, additional: Data, official: String) {
        print(official)
        emit(Self.endSummaryUUID, data)
        // SC-fadm: the paired 0x003A rides right behind the 0x0039 (same logEntryDate/time)
        // so the app's merged() can pair them into one PM5-verified result.
        emit(Self.additionalEndSummaryUUID, additional)
        print("🧪 VPM5 🏁 piece additional (0x003A): \(additional.map { String(format: "%02X", $0) }.joined(separator: " "))")
        // P2c: the athlete starts the cooldown clock only after the app piece has
        // completed AND logged (its 0x0039 delivered). One-shot: the cooldown's
        // own summary lands here too but cooldownFired blocks a re-arm.
        if config.cooldownPieceMeters > 0, !cooldownFired, cooldownTicksUntilKeyed == nil {
            cooldownTicksUntilKeyed = cooldownWalkOverTicks  // ~10s: walk over, key the piece
            print("🧪 VPM5 🧊 cooldown countdown started (~10s continuously parked to keypad)")
        }
    }

    // MARK: - Helpers

    private var isRowingPhase: Bool {
        if case .rowing = phase { return true }
        return false
    }

    /// 0x0031 byte[7] intervalType per broadcast workoutType (captured): TIME
    /// pieces carry 0x00 (LOG15 — NOT 0x01), CAL pieces 0xFF (LOG11), everything
    /// else (distance/JustRow/idle) the P1 value 0x01. Keyed off the WIRE type so
    /// stale windows keep the previous piece's byte, like the counters. SC-7nqt.11:
    /// during interval REST (0x03) it flips to 0x02 REST (log16); interval WORK keeps 0x01
    /// DIST (log16) via the default. The work→rest BOUNDARY (0x09) also emits 0x02, but that
    /// is a MODELED choice — the 0x09 frame bytes are UNCAPTURED (SC-7nqt.5 re-validation gate).
    private func intervalTypeByte(for workoutType: UInt8, state: UInt8) -> UInt8 {
        if state == 0x03 || state == 0x09 { return 0x02 }  // interval rest (captured) / work→rest boundary (modeled)
        switch workoutType {
        case 0x05: return 0x00
        case 0x0A: return 0xFF
        default: return 0x01
        }
    }

    private func avgPace() -> Double {
        paceSamples > 0 ? avgPaceAccumulator / Double(paceSamples) : config.paceSecondsPer500
    }

    private func strapByteFor0032() -> UInt8 {
        guard config.strapPresent, currentHR > 0 else { return 0xFF }  // 0xFF = no belt (captured)
        return UInt8(clamping: Int(currentHR))
    }

    private func logTransition(_ message: String) {
        print("🧪 VPM5 🚦 \(message)")
    }
}
