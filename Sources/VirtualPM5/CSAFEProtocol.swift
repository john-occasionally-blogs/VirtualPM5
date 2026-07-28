//
//  CSAFEProtocol.swift
//  SemperClock
//
//  Pure CSAFE frame codec + PM5 packet parsers for the Concept2 PM5.
//  No CoreBluetooth dependency — fully unit-testable against the byte-exact
//  frames printed in the official specs:
//    - "Concept2 PM CSAFE Communication Definition" Rev 0.25 (frame format p8-11,
//      worked example frames pp.55, 78-90, state machine p46-48/161, enums pp.93-102)
//    - "Concept2 PM Bluetooth Smart Communication Interface Definition" Rev 1.30
//      (characteristic payload layouts pp.13-23, end-of-workout summary p21-22)
//

import Foundation

// MARK: - Frame codec

/// CSAFE standard-frame encoder/decoder (Rev 0.25 pp.8-10).
/// Wire format: 0xF1 <byte-stuffed(contents + XOR checksum)> 0xF2.
/// Checksum = XOR over UNstuffed contents (excludes flags and the checksum itself).
/// Stuffing: 0xF0→F3 00, 0xF1→F3 01, 0xF2→F3 02, 0xF3→F3 03.
public enum CSAFEFrameCodec {
    public static let frameStart: UInt8 = 0xF1
    public static let frameEnd: UInt8 = 0xF2
    public static let stuffFlag: UInt8 = 0xF3

    /// Max payload per BLE ATT write to the CSAFE Tx characteristic (spec Table 14: 20 bytes).
    public static let bleWriteChunkSize = 20

    public static func checksum(_ contents: [UInt8]) -> UInt8 {
        contents.reduce(0) { $0 ^ $1 }
    }

    public static func stuff(_ bytes: [UInt8]) -> [UInt8] {
        var out: [UInt8] = []
        out.reserveCapacity(bytes.count)
        for b in bytes {
            if b >= 0xF0 && b <= 0xF3 {
                out.append(stuffFlag)
                out.append(b - 0xF0)
            } else {
                out.append(b)
            }
        }
        return out
    }

    /// Reverses byte stuffing. Returns nil on a malformed escape sequence.
    public static func unstuff(_ bytes: [UInt8]) -> [UInt8]? {
        var out: [UInt8] = []
        out.reserveCapacity(bytes.count)
        var i = 0
        while i < bytes.count {
            let b = bytes[i]
            if b == stuffFlag {
                guard i + 1 < bytes.count, bytes[i + 1] <= 0x03 else { return nil }
                out.append(0xF0 + bytes[i + 1])
                i += 2
            } else {
                out.append(b)
                i += 1
            }
        }
        return out
    }

    /// Builds a complete on-wire standard frame from unstuffed frame contents.
    public static func buildFrame(contents: [UInt8]) -> [UInt8] {
        var body = contents
        body.append(checksum(contents))
        return [frameStart] + stuff(body) + [frameEnd]
    }

    /// Splits a full frame into BLE-writable chunks (PM reassembles by frame flags).
    public static func chunked(_ frame: [UInt8], chunkSize: Int = bleWriteChunkSize) -> [[UInt8]] {
        stride(from: 0, to: frame.count, by: chunkSize).map {
            Array(frame[$0..<min($0 + chunkSize, frame.count)])
        }
    }

    /// Decodes one complete frame (start flag through stop flag) into unstuffed,
    /// checksum-verified contents. Returns nil if flags/stuffing/checksum are invalid.
    public static func decodeFrame(_ frame: [UInt8]) -> [UInt8]? {
        guard frame.count >= 4, frame.first == frameStart, frame.last == frameEnd else { return nil }
        guard let body = unstuff(Array(frame[1..<(frame.count - 1)])), body.count >= 2 else { return nil }
        let contents = Array(body.dropLast())
        guard checksum(contents) == body.last else { return nil }
        return contents
    }
}

/// Accumulates BLE notification fragments into complete CSAFE frames.
/// Responses can span multiple ≤20-byte notifications; the literal stop flag 0xF2
/// only ever appears as a frame terminator (payload occurrences are byte-stuffed).
public struct CSAFEResponseAccumulator {
    private var buffer: [UInt8] = []

    public init() {}

    /// Feeds one BLE notification. Returns any complete frames it closed out.
    public mutating func append(_ data: Data) -> [[UInt8]] {
        var frames: [[UInt8]] = []
        for byte in data {
            if byte == CSAFEFrameCodec.frameStart {
                buffer = [byte] // new frame start resyncs the buffer (spec p9)
            } else if !buffer.isEmpty {
                buffer.append(byte)
                if byte == CSAFEFrameCodec.frameEnd {
                    frames.append(buffer)
                    buffer = []
                }
            }
            // Bytes outside any frame are discarded (resync at next start flag).
        }
        return frames
    }
}

// MARK: - Response status

/// CSAFE slave state machine states, from the response status byte's low nibble
/// (Rev 0.25 Table 9 p.11).
public enum CSAFESlaveState: UInt8 {
    case error = 0x00
    case ready = 0x01
    case idle = 0x02
    case haveID = 0x03
    case inUse = 0x05
    case paused = 0x06
    case finished = 0x07
    case manual = 0x08
    case offline = 0x09
}

/// Previous-frame status bits (0x30 mask) from the response status byte (Table 9 p.11).
/// `.reject` after a programming frame means the PM refused the workout configuration.
public enum CSAFEPrevFrameStatus: UInt8 {
    case ok = 0x00
    case reject = 0x10
    case bad = 0x20
    case notReady = 0x30
}

/// A decoded CSAFE response frame.
public struct CSAFEResponse {
    public let statusByte: UInt8
    public let commandData: [UInt8] // contents after the status byte (echoed commands / GET data)

    public var slaveState: CSAFESlaveState? { CSAFESlaveState(rawValue: statusByte & 0x0F) }
    public var prevFrameStatus: CSAFEPrevFrameStatus { CSAFEPrevFrameStatus(rawValue: statusByte & 0x30) ?? .ok }
    public var frameToggle: Bool { statusByte & 0x80 != 0 }

    /// Parses a raw accumulated frame (F1...F2) into a response. Nil if malformed.
    public static func parse(frame: [UInt8]) -> CSAFEResponse? {
        guard let contents = CSAFEFrameCodec.decodeFrame(frame), !contents.isEmpty else { return nil }
        return CSAFEResponse(statusByte: contents[0], commandData: Array(contents.dropFirst()))
    }
}

// MARK: - PM5 workout state (BLE General Status byte 8 / CSAFE_PM_GET_WORKOUTSTATE)

/// OBJ_WORKOUTSTATE_T (Rev 0.25 p.94). The erg-truth signal for piece lifecycle:
/// a completed piece walks WORKOUTEND → WORKOUTLOGGED (Appendix E p.161).
public enum PM5WorkoutState: UInt8 {
    case waitToBegin = 0
    case workoutRow = 1
    case countdownPause = 2
    case intervalRest = 3
    case intervalWorkTime = 4
    case intervalWorkDistance = 5
    case intervalRestEndToWorkTime = 6
    case intervalRestEndToWorkDistance = 7
    case intervalWorkTimeToRest = 8
    case intervalWorkDistanceToRest = 9
    case workoutEnd = 10
    case terminate = 11
    case workoutLogged = 12
    case rearm = 13

    /// The piece has reached its defined end (results are final or being logged).
    public var isComplete: Bool { self == .workoutEnd || self == .workoutLogged }
}

// MARK: - PM5 command builders

/// Byte-exact CSAFE frame builders for PM5 workout programming.
///
/// Two dialects exist:
/// - **Public** (default): GoReady + SETHORIZONTAL/SETTWORK + SETPROGRAM + GoInUse.
///   This is the dialect proven working on real hardware in this app (see
///   Concept2Manager "Key Discovery 2026-01-29"), per spec Fig 8 p.55.
/// - **Proprietary** (0x76 PUSH wrapper): the spec's canonical programming path
///   (worked examples pp.79-88). A 2026-01-29 field note says it was unreliable
///   over BLE — likely because frames >20 bytes were written unchunked and
///   unstuffed. Kept behind the `UseProprietaryProgramming` toggle for triage.
public enum PM5CommandBuilder {
    // Public short commands (Rev 0.25 p.49)
    public static let goIdle: UInt8 = 0x82
    public static let goInUse: UInt8 = 0x85
    public static let goFinished: UInt8 = 0x86
    public static let goReady: UInt8 = 0x87

    /// Frame carrying a single short state-transition command.
    public static func stateCommandFrame(_ command: UInt8) -> [UInt8] {
        CSAFEFrameCodec.buildFrame(contents: [command])
    }

    // MARK: Public dialect (proven on hardware)

    /// GoReady + SETHORIZONTAL(meters, unit 0x24) + SETPROGRAM(0) + GoInUse.
    /// Matches the frame the app has always sent, now stuffing-safe
    /// (e.g. 5105m = 0x13F1 previously corrupted the frame).
    public static func publicFixedDistanceFrame(meters: Int) -> [UInt8] {
        let m = UInt16(clamping: meters)
        let contents: [UInt8] = [
            goReady,
            0x21, 0x03, UInt8(m & 0xFF), UInt8(m >> 8), 0x24, // SETHORIZONTAL, meters
            0x24, 0x02, 0x00, 0x00,                            // SETPROGRAM: programmed workout
            goInUse,
        ]
        return CSAFEFrameCodec.buildFrame(contents: contents)
    }

    /// GoReady + SETTWORK(h,m,s) + SETPROGRAM(0) + GoInUse (spec pp.78-79 fixed-time example).
    public static func publicFixedTimeFrame(seconds: Int) -> [UInt8] {
        let clamped = min(max(seconds, 20), 9 * 3600 + 59 * 60 + 59) // spec limits :20–9:59:59 (p.48)
        let contents: [UInt8] = [
            goReady,
            0x20, 0x03, UInt8(clamped / 3600), UInt8((clamped % 3600) / 60), UInt8(clamped % 60),
            0x24, 0x02, 0x00, 0x00,
            goInUse,
        ]
        return CSAFEFrameCodec.buildFrame(contents: contents)
    }

    /// GoReady + SETCALORIES(calories) + SETPROGRAM(0) + GoInUse (SC-abi4.10).
    /// Structurally identical to publicFixedDistanceFrame/publicFixedTimeFrame:
    /// deliberately built on the PROVEN public dialect (SETCALORIES 0x23, a 2-byte
    /// LE payload with no unit byte), NOT the g70z-suspect 0x1A/0x76 SET_WORKOUTDURATION
    /// wrapper — so it does not inherit that path's unverified encoding risk.
    public static func publicFixedCaloriesFrame(calories: Int) -> [UInt8] {
        let c = UInt16(clamping: calories)
        let contents: [UInt8] = [
            goReady,
            0x23, 0x02, UInt8(c & 0xFF), UInt8(c >> 8), // SETCALORIES, calories 2-byte LE
            0x24, 0x02, 0x00, 0x00,                      // SETPROGRAM: programmed workout
            goInUse,
        ]
        return CSAFEFrameCodec.buildFrame(contents: contents)
    }

    // MARK: Proprietary dialect (0x76 PUSH wrapper, spec pp.79-88) — toggle-gated

    private static func proprietaryFrame(subCommands: [UInt8]) -> [UInt8] {
        CSAFEFrameCodec.buildFrame(contents: [0x76, UInt8(subCommands.count)] + subCommands)
    }

    private static func u32MSB(_ value: Int) -> [UInt8] {
        let v = UInt32(clamping: value)
        return [UInt8(v >> 24), UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)]
    }

    /// Golden vector (2000m, 400m splits, spec p.80):
    /// F1 76 18 01 01 03 03 05 80 00 00 07 D0 05 05 80 00 00 01 90 14 01 01 13 02 01 01 28 F2
    public static func proprietaryFixedDistanceFrame(meters: Int, splitMeters: Int) -> [UInt8] {
        var sub: [UInt8] = []
        sub += [0x01, 0x01, 0x03]                       // SET_WORKOUTTYPE: FIXEDDIST_SPLITS
        sub += [0x03, 0x05, 0x80] + u32MSB(meters)      // SET_WORKOUTDURATION: distance
        sub += [0x05, 0x05, 0x80] + u32MSB(splitMeters) // SET_SPLITDURATION: distance
        sub += [0x14, 0x01, 0x01]                       // CONFIGURE_WORKOUT: enable
        sub += [0x13, 0x02, 0x01, 0x01]                 // SET_SCREENSTATE: PREPARETOROWWORKOUT
        return proprietaryFrame(subCommands: sub)
    }

    /// Golden vector (20:00, 4:00 splits, spec pp.80-81):
    /// F1 76 18 01 01 05 03 05 00 00 01 D4 C0 05 05 00 00 00 5D C0 14 01 01 13 02 01 01 E0 F2
    public static func proprietaryFixedTimeFrame(seconds: Int, splitSeconds: Int) -> [UInt8] {
        var sub: [UInt8] = []
        sub += [0x01, 0x01, 0x05]                                // FIXEDTIME_SPLITS
        sub += [0x03, 0x05, 0x00] + u32MSB(seconds * 100)        // duration in 0.01s
        sub += [0x05, 0x05, 0x00] + u32MSB(splitSeconds * 100)   // split in 0.01s
        sub += [0x14, 0x01, 0x01]
        sub += [0x13, 0x02, 0x01, 0x01]
        return proprietaryFrame(subCommands: sub)
    }

    /// Fixed-calorie single via the proprietary wrapper (SC-vr0d). Mirrors
    /// proprietaryFixedTimeFrame with workout type FIXEDCALORIE_SPLITS (0x0A) and
    /// SET_WORKOUTDURATION duration type 0x40 (calories), value in whole calories
    /// (unscaled, like distance — NOT ×100 like time). The public SETCALORIES (0x23)
    /// frame is silently ignored by PM5 firmware (drops to Just Row), so this is the
    /// working path — proven the same day the sibling time frame was accepted on-erg.
    /// Golden vector (20 cal, 20-cal split):
    /// F1 76 18 01 01 0A 03 05 40 00 00 00 14 05 05 40 00 00 00 14 14 01 01 13 02 01 01 67 F2
    public static func proprietaryFixedCaloriesFrame(calories: Int, splitCalories: Int) -> [UInt8] {
        var sub: [UInt8] = []
        sub += [0x01, 0x01, 0x0A]                       // SET_WORKOUTTYPE: FIXEDCALORIE_SPLITS
        sub += [0x03, 0x05, 0x40] + u32MSB(calories)     // SET_WORKOUTDURATION: calories
        sub += [0x05, 0x05, 0x40] + u32MSB(splitCalories)// SET_SPLITDURATION: calories
        sub += [0x14, 0x01, 0x01]                       // CONFIGURE_WORKOUT: enable
        sub += [0x13, 0x02, 0x01, 0x01]                 // SET_SCREENSTATE: PREPARETOROWWORKOUT
        return proprietaryFrame(subCommands: sub)
    }

    /// Golden vector (spec p.79): F1 76 07 01 01 01 13 02 01 01 61 F2
    public static func proprietaryJustRowFrame() -> [UInt8] {
        proprietaryFrame(subCommands: [0x01, 0x01, 0x01, 0x13, 0x02, 0x01, 0x01])
    }

    /// Golden vector (500m work / 30s rest, spec pp.82-83):
    /// F1 76 15 01 01 07 03 05 80 00 00 01 F4 04 02 00 1E 14 01 01 13 02 01 01 0A F2
    public static func proprietaryDistanceIntervalFrame(meters: Int, restSeconds: Int) -> [UInt8] {
        let rest = UInt16(clamping: restSeconds)
        var sub: [UInt8] = []
        sub += [0x01, 0x01, 0x07]                          // FIXEDDIST_INTERVAL
        sub += [0x03, 0x05, 0x80] + u32MSB(meters)
        sub += [0x04, 0x02, UInt8(rest >> 8), UInt8(rest & 0xFF)] // SET_RESTDURATION, 1s units, MSB-first
        sub += [0x14, 0x01, 0x01]
        sub += [0x13, 0x02, 0x01, 0x01]
        return proprietaryFrame(subCommands: sub)
    }

    /// SC-g70z: multi-round distance-interval frame. Same as the 2-arg spec vector
    /// above plus SET_WORKOUTINTERVALCOUNT (0x18, len-1, `rounds`) before
    /// CONFIGURE_WORKOUT so the PM5 caps the piece at `rounds` intervals.
    ///
    /// The count command byte + its 1-byte value are TRACE-DERIVED: the app's own
    /// captured CSAFE trace (live-erg 2026-07-11 Bout 8, the accepted-but-never-arming
    /// public 0x1A frame) carried `18 01 03` for a 3-round program. The *exact*
    /// multi-round proprietary encoding (count command, whether a per-interval split is
    /// also required, rest units at >255s) is UNPROVEN on hardware — this is the
    /// live-erg re-validation gate. Deliberately NO SET_SPLITDURATION (0x05): neither
    /// the spec golden vector nor the captured device frame carries a split for a
    /// distance interval, so adding one would be a second unproven guess. The dialect
    /// switch itself (→ proprietary 0x76 + the terminating SET_SCREENSTATE that the dead
    /// public path omitted) is the HIGH-confidence half of the fix.
    public static func proprietaryDistanceIntervalFrame(meters: Int, restSeconds: Int, rounds: Int) -> [UInt8] {
        let rest = UInt16(clamping: restSeconds)
        var sub: [UInt8] = []
        sub += [0x01, 0x01, 0x07]                                  // FIXEDDIST_INTERVAL
        sub += [0x03, 0x05, 0x80] + u32MSB(meters)                 // SET_WORKOUTDURATION: distance
        sub += [0x04, 0x02, UInt8(rest >> 8), UInt8(rest & 0xFF)]  // SET_RESTDURATION, 1s units, MSB-first
        sub += [0x18, 0x01, UInt8(clamping: max(1, rounds))]       // SET_WORKOUTINTERVALCOUNT (trace-derived)
        sub += [0x14, 0x01, 0x01]                                  // CONFIGURE_WORKOUT: enable
        sub += [0x13, 0x02, 0x01, 0x01]                            // SET_SCREENSTATE: PREPARETOROWWORKOUT
        return proprietaryFrame(subCommands: sub)
    }

    /// Terminate the current/finished workout — the documented programmatic path from
    /// WORKOUTLOGGED back to WaitToBegin before re-programming (spec p.88 + Appendix E p.161).
    /// Golden vector: F1 76 04 13 02 01 02 62 F2
    public static func terminateWorkoutFrame() -> [UInt8] {
        proprietaryFrame(subCommands: [0x13, 0x02, 0x01, 0x02]) // SCREENVALUEWORKOUT_TERMINATEWORKOUT
    }
}

// MARK: - PM5 BLE packet parsers

/// Parsed C2 rowing General Status (characteristic 0x0031, 19 bytes, BLE spec Rev 1.30 p.13).
public struct PM5GeneralStatus {
    public let elapsedTime: TimeInterval     // bytes 0-2, 0.01s LE
    public let distance: Double              // bytes 3-5, 0.1m LE
    public let workoutType: UInt8?           // byte 6
    public let intervalType: UInt8?          // byte 7
    public let workoutState: PM5WorkoutState? // byte 8
    public let rowingState: UInt8?           // byte 9
    public let strokeState: UInt8?           // byte 10
    public let workoutDuration: UInt32?      // bytes 14-16 (0.01s if time-type)
    public let workoutDurationType: UInt8?   // byte 17
    public let dragFactor: Int?              // byte 18

    public static func parse(_ bytes: [UInt8]) -> PM5GeneralStatus? {
        guard bytes.count >= 6 else { return nil }
        let elapsed = Double(u24LE(bytes, 0)) / 100.0
        let dist = Double(u24LE(bytes, 3)) / 10.0
        guard bytes.count >= 19 else {
            return PM5GeneralStatus(elapsedTime: elapsed, distance: dist, workoutType: nil,
                                    intervalType: nil, workoutState: nil, rowingState: nil,
                                    strokeState: nil, workoutDuration: nil,
                                    workoutDurationType: nil, dragFactor: nil)
        }
        return PM5GeneralStatus(
            elapsedTime: elapsed,
            distance: dist,
            workoutType: bytes[6],
            intervalType: bytes[7],
            workoutState: PM5WorkoutState(rawValue: bytes[8]),
            rowingState: bytes[9],
            strokeState: bytes[10],
            workoutDuration: u24LE(bytes, 14),
            workoutDurationType: bytes[17],
            dragFactor: bytes[18] > 0 ? Int(bytes[18]) : nil
        )
    }
}

/// Parsed C2 rowing Additional Status 1 (characteristic 0x0032, 17 bytes, BLE spec p.14).
public struct PM5AdditionalStatus1 {
    public let elapsedTime: TimeInterval    // bytes 0-2, 0.01s
    public let speed: Double                // bytes 3-4, 0.001 m/s
    public let strokeRate: Int              // byte 5, spm
    public let heartRate: Int?              // byte 6, bpm (255 = invalid, 0 treated as absent)
    public let currentPace: TimeInterval?   // bytes 7-8, 0.01s per 500m
    public let averagePace: TimeInterval?   // bytes 9-10, 0.01s per 500m

    public static func parse(_ bytes: [UInt8]) -> PM5AdditionalStatus1? {
        guard bytes.count >= 11 else { return nil }
        let hrRaw = Int(bytes[6])
        let paceRaw = u16LE(bytes, 7)
        let avgPaceRaw = u16LE(bytes, 9)
        return PM5AdditionalStatus1(
            elapsedTime: Double(u24LE(bytes, 0)) / 100.0,
            speed: Double(u16LE(bytes, 3)) / 1000.0,
            strokeRate: Int(bytes[5]),
            heartRate: (hrRaw > 0 && hrRaw < 255) ? hrRaw : nil,
            currentPace: paceRaw > 0 ? Double(paceRaw) / 100.0 : nil,
            averagePace: avgPaceRaw > 0 ? Double(avgPaceRaw) / 100.0 : nil
        )
    }
}

/// Parsed C2 rowing Additional Status 2 (characteristic 0x0033, 20 bytes, BLE spec p.15).
public struct PM5AdditionalStatus2 {
    public let elapsedTime: TimeInterval  // bytes 0-2
    public let intervalCount: Int         // byte 3
    public let averagePower: Int?         // bytes 4-5, watts
    public let totalCalories: Int?        // bytes 6-7, cals

    public static func parse(_ bytes: [UInt8]) -> PM5AdditionalStatus2? {
        guard bytes.count >= 8 else { return nil }
        let power = u16LE(bytes, 4)
        let cals = u16LE(bytes, 6)
        return PM5AdditionalStatus2(
            elapsedTime: Double(u24LE(bytes, 0)) / 100.0,
            intervalCount: Int(bytes[3]),
            averagePower: power > 0 ? Int(power) : nil,
            totalCalories: cals > 0 ? Int(cals) : nil
        )
    }
}

/// Parsed End of Workout Summary (characteristic 0x0039, 20 bytes, BLE spec p.21).
/// Fires at workout end; a REVISED copy (recovery HR filled in) is re-sent after
/// ~1 minute of rest unless powered off or a new workout starts — dedupe/merge on
/// (logEntryDate, logEntryTime).
public struct PM5EndOfWorkoutSummaryPacket {
    public let logEntryDate: UInt16       // bytes 0-1
    public let logEntryTime: UInt16       // bytes 2-3
    public let elapsedTime: TimeInterval  // bytes 4-6, 0.01s
    public let distance: Double           // bytes 7-9, 0.1m
    public let averageStrokeRate: Int     // byte 10
    public let endingHeartRate: Int?      // byte 11
    public let averageHeartRate: Int?     // byte 12
    public let minHeartRate: Int?         // byte 13
    public let maxHeartRate: Int?         // byte 14
    public let averageDragFactor: Int?    // byte 15
    public let recoveryHeartRate: Int?    // byte 16 (0 = not yet valid)
    public let workoutType: UInt8         // byte 17
    public let averagePace: TimeInterval? // bytes 18-19, 0.1s per 500m

    public static func parse(_ bytes: [UInt8]) -> PM5EndOfWorkoutSummaryPacket? {
        guard bytes.count >= 20 else { return nil }
        func hr(_ b: UInt8) -> Int? { (b > 0 && b < 255) ? Int(b) : nil }
        let paceRaw = u16LE(bytes, 18)
        return PM5EndOfWorkoutSummaryPacket(
            logEntryDate: u16LE(bytes, 0),
            logEntryTime: u16LE(bytes, 2),
            elapsedTime: Double(u24LE(bytes, 4)) / 100.0,
            distance: Double(u24LE(bytes, 7)) / 10.0,
            averageStrokeRate: Int(bytes[10]),
            endingHeartRate: hr(bytes[11]),
            averageHeartRate: hr(bytes[12]),
            minHeartRate: hr(bytes[13]),
            maxHeartRate: hr(bytes[14]),
            averageDragFactor: bytes[15] > 0 ? Int(bytes[15]) : nil,
            recoveryHeartRate: bytes[16] > 0 ? Int(bytes[16]) : nil,
            workoutType: bytes[17],
            averagePace: paceRaw > 0 ? Double(paceRaw) / 10.0 : nil
        )
    }
}

/// Parsed Additional End of Workout Summary (characteristic 0x003A, 19 bytes, BLE spec p.22).
public struct PM5AdditionalEndSummaryPacket {
    public let logEntryDate: UInt16      // bytes 0-1
    public let logEntryTime: UInt16      // bytes 2-3
    public let splitIntervalType: UInt8  // byte 4
    public let splitIntervalSize: Int    // bytes 5-6 (meters or seconds)
    public let splitIntervalCount: Int   // byte 7
    public let totalCalories: Int?       // bytes 8-9
    public let averageWatts: Int?        // bytes 10-11
    public let totalRestDistance: Int    // bytes 12-14, 1m
    public let intervalRestTime: Int     // bytes 15-16, seconds
    public let averageCaloriesPerHour: Int? // bytes 17-18

    public static func parse(_ bytes: [UInt8]) -> PM5AdditionalEndSummaryPacket? {
        guard bytes.count >= 19 else { return nil }
        let cals = u16LE(bytes, 8)
        let watts = u16LE(bytes, 10)
        let calRate = u16LE(bytes, 17)
        return PM5AdditionalEndSummaryPacket(
            logEntryDate: u16LE(bytes, 0),
            logEntryTime: u16LE(bytes, 2),
            splitIntervalType: bytes[4],
            splitIntervalSize: Int(u16LE(bytes, 5)),
            splitIntervalCount: Int(bytes[7]),
            totalCalories: cals > 0 ? Int(cals) : nil,
            averageWatts: watts > 0 ? Int(watts) : nil,
            totalRestDistance: Int(u24LE(bytes, 12)),
            intervalRestTime: Int(u16LE(bytes, 15)),
            averageCaloriesPerHour: calRate > 0 ? Int(calRate) : nil
        )
    }
}

// MARK: - Little-endian helpers

private func u16LE(_ bytes: [UInt8], _ offset: Int) -> UInt16 {
    UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
}

private func u24LE(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
    UInt32(bytes[offset]) | (UInt32(bytes[offset + 1]) << 8) | (UInt32(bytes[offset + 2]) << 16)
}
