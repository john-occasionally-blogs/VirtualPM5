import XCTest
import CoreBluetooth
@testable import VirtualPM5

// MARK: - Codec + command-builder golden vectors (byte-exact per the Concept2 specs)

final class CSAFECodecTests: XCTestCase {

    /// Spec p.80 worked example: 2000m piece with 400m splits via the 0x76 wrapper.
    func testGoldenProprietaryDistanceVector() {
        let expected: [UInt8] = [
            0xF1, 0x76, 0x18, 0x01, 0x01, 0x03, 0x03, 0x05, 0x80, 0x00, 0x00, 0x07, 0xD0,
            0x05, 0x05, 0x80, 0x00, 0x00, 0x01, 0x90, 0x14, 0x01, 0x01,
            0x13, 0x02, 0x01, 0x01, 0x28, 0xF2,
        ]
        XCTAssertEqual(PM5CommandBuilder.proprietaryFixedDistanceFrame(meters: 2000, splitMeters: 400), expected)
    }

    /// Spec p.79 worked example: Just Row.
    func testGoldenJustRowVector() {
        let expected: [UInt8] = [0xF1, 0x76, 0x07, 0x01, 0x01, 0x01, 0x13, 0x02, 0x01, 0x01, 0x61, 0xF2]
        XCTAssertEqual(PM5CommandBuilder.proprietaryJustRowFrame(), expected)
    }

    /// Spec p.88: terminate the current/finished workout. Asserts the exact command
    /// bytes and checksum self-consistency (this frame is hardware-proven as the
    /// WORKOUTLOGGED → WaitToBegin path).
    func testTerminateFrameCommandBytes() throws {
        let frame = PM5CommandBuilder.terminateWorkoutFrame()
        let contents = try XCTUnwrap(CSAFEFrameCodec.decodeFrame(frame))
        XCTAssertEqual(contents, [0x76, 0x04, 0x13, 0x02, 0x01, 0x02])
    }

    /// 5105m = 0x13F1 — a distance whose byte encoding collides with the frame flags
    /// and MUST round-trip through byte stuffing intact.
    func testFrameRoundTripWithStuffing() throws {
        let frame = PM5CommandBuilder.publicFixedDistanceFrame(meters: 5105)
        let contents = try XCTUnwrap(CSAFEFrameCodec.decodeFrame(frame))
        XCTAssertEqual(contents.first, PM5CommandBuilder.goReady)
        XCTAssertEqual(contents.last, PM5CommandBuilder.goInUse)
    }

    /// Frames arrive over BLE in ≤20-byte notifications; the accumulator must
    /// reassemble exactly one frame from its chunks.
    func testAccumulatorReassemblesChunkedFrame() {
        let frame = PM5CommandBuilder.proprietaryFixedDistanceFrame(meters: 2000, splitMeters: 400)
        var acc = CSAFEResponseAccumulator()
        var frames: [[UInt8]] = []
        for chunk in CSAFEFrameCodec.chunked(frame) {
            frames += acc.append(Data(chunk))
        }
        XCTAssertEqual(frames, [frame])
    }
}

// MARK: - Emulator smoke tests

final class VirtualPM5EmulatorTests: XCTestCase {

    /// Builds an emulator with zero response latency (synchronous asserts) and a
    /// collector for every (characteristic, payload) it emits.
    private func makeErg() -> (erg: VirtualPM5, emitted: () -> [(uuid: CBUUID, data: Data)]) {
        var config = VirtualPM5.Config()
        config.responseLatencySeconds = 0
        var log: [(CBUUID, Data)] = []
        let erg = VirtualPM5(config: config, emit: { uuid, data in log.append((uuid, data)) })
        return (erg, { log })
    }

    private func send(_ frame: [UInt8], to erg: VirtualPM5) {
        for chunk in CSAFEFrameCodec.chunked(frame) {
            erg.receive(chunk: Data(chunk))
        }
    }

    func testPublicDistanceProgramIsAccepted() throws {
        let (erg, emitted) = makeErg()
        erg.open()
        send(PM5CommandBuilder.publicFixedDistanceFrame(meters: 500), to: erg)

        let responses = emitted().filter { $0.uuid == VirtualPM5.csafeRxUUID }
        XCTAssertFalse(responses.isEmpty, "expected a CSAFE response frame")
        let parsed = try XCTUnwrap(CSAFEResponse.parse(frame: [UInt8](responses.last!.data)))
        XCTAssertEqual(parsed.prevFrameStatus, .ok, "500m public program must be accepted")
        XCTAssertTrue(parsed.frameToggle, "accepted commands flip the frame-toggle latch")
    }

    /// Firmware truth: a split-less public-dialect program under 500m is rejected.
    func testPublicSub500mProgramIsRejected() throws {
        let (erg, emitted) = makeErg()
        erg.open()
        send(PM5CommandBuilder.publicFixedDistanceFrame(meters: 250), to: erg)

        let responses = emitted().filter { $0.uuid == VirtualPM5.csafeRxUUID }
        let parsed = try XCTUnwrap(CSAFEResponse.parse(frame: [UInt8](responses.last!.data)))
        XCTAssertEqual(parsed.prevFrameStatus, .reject, "sub-500m public program must be rejected")
    }

    func testStatusStreamFlowsAfterProgramming() {
        let (erg, emitted) = makeErg()
        erg.open()
        send(PM5CommandBuilder.publicFixedDistanceFrame(meters: 500), to: erg)
        for _ in 0..<6 { erg.tick() }

        let statusFrames = emitted().filter { $0.uuid == VirtualPM5.generalStatusUUID }
        XCTAssertFalse(statusFrames.isEmpty, "expected 0x0031 general-status notifications")
        XCTAssertTrue(statusFrames.allSatisfy { $0.data.count == 19 },
                      "0x0031 payloads are 19 bytes per BLE spec p.13")
    }

    /// The LIVE avg-pace fields (0x0032 bytes 9-10) report total-time ÷ total-distance like a
    /// real PM5 — never the arithmetic mean of instantaneous paces. Discriminating by
    /// construction: under this finishing-kick config the two formulas separate by >10 s/500m,
    /// so the test fails if either the ratio basis or the kick behavior regresses.
    func testLiveAvgPaceIsTotalTimeOverDistanceUnderFinishKick() throws {
        var config = VirtualPM5.Config()
        config.responseLatencySeconds = 0
        config.startDelay = 0
        config.seed = 42
        config.paceSecondsPer500 = 150
        config.finishKickPace = 65
        config.finishKickAfterSeconds = 20
        var log: [(CBUUID, Data)] = []
        let erg = VirtualPM5(config: config, emit: { uuid, data in log.append((uuid, data)) })
        erg.open()
        send(PM5CommandBuilder.proprietaryFixedDistanceFrame(meters: 250, splitMeters: 250), to: erg)
        var guardTicks = 0
        while !log.contains(where: { $0.0 == VirtualPM5.endSummaryUUID }), guardTicks < 400 {
            erg.tick()
            guardTicks += 1
        }
        XCTAssertLessThan(guardTicks, 400, "piece must complete and emit a 0x0039")

        let sumIdx = try XCTUnwrap(log.firstIndex { $0.0 == VirtualPM5.endSummaryUUID })
        let summary = try XCTUnwrap(PM5EndOfWorkoutSummaryPacket.parse([UInt8](log[sumIdx].1)))
        let truePace = summary.elapsedTime / (summary.distance / 500.0)

        let status1 = { (slice: ArraySlice<(CBUUID, Data)>) -> [[UInt8]] in
            slice.filter { $0.0 == VirtualPM5.additionalStatus1UUID }.map { [UInt8]($0.1) }
        }
        let livePaces = status1(log[..<sumIdx])
            .map { Double(Int($0[7]) | (Int($0[8]) << 8)) / 100.0 }
            .filter { $0 > 0 }
        XCTAssertGreaterThan(livePaces.count, 10, "rowing 0x0032 frames must flow")
        let tickMean = livePaces.reduce(0, +) / Double(livePaces.count)
        XCTAssertGreaterThan(abs(truePace - tickMean), 10.0,
                             "fixture must discriminate: the two formulas must separate")

        let last = try XCTUnwrap(status1(log[...]).last)
        let avgPaceWire = Double(Int(last[9]) | (Int(last[10]) << 8)) / 100.0
        XCTAssertEqual(avgPaceWire, truePace, accuracy: 3.0,
                       "live avg pace must be total-time ÷ total-distance")
        XCTAssertGreaterThan(abs(avgPaceWire - tickMean), 5.0,
                             "live avg pace must NOT be the tick-mean of instantaneous paces")
        erg.stop()
    }

    func testCapturedFixtureShipsWithPackage() throws {
        let url = try XCTUnwrap(Bundle.module.url(
            forResource: "pm5-piece-250m", withExtension: "jsonl", subdirectory: "Fixtures"))
        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertGreaterThan(text.split(separator: "\n").count, 10)
    }
}
