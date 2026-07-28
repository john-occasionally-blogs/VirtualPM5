# Concept2 PM5 Workout Programming Implementation Guide

## Overview
This document outlines how to send pre-planned workouts to the Concept2 PM5 rower via Bluetooth using CSAFE commands.

## Current Implementation Status
- ✅ **Read-only BLE connection** to PM5 (CE060030 service)
- ✅ **Real-time data collection** (stroke rate, pace, distance, power, etc.)
- ❌ **CSAFE command support** (not implemented)
- ❌ **Workout programming** (not implemented)

## Required BLE Services

### Currently Used (Read-Only)
```swift
private let pmServiceUUID = CBUUID(string: "CE060030-43E5-11E4-916C-0800200C9A66")
private let primaryCharUUID = CBUUID(string: "CE060031-43E5-11E4-916C-0800200C9A66")
private let secondaryCharUUID = CBUUID(string: "CE060032-43E5-11E4-916C-0800200C9A66")
```

### Need to Add (Write/Control)
```swift
private let controlServiceUUID = CBUUID(string: "CE060020-43E5-11E4-916C-0800200C9A66")
private let transmitCharUUID = CBUUID(string: "CE060021-43E5-11E4-916C-0800200C9A66")  // Write
private let receiveCharUUID = CBUUID(string: "CE060022-43E5-11E4-916C-0800200C9A66")   // Read responses
```

## CSAFE Protocol

### Frame Structure
All CSAFE commands must be wrapped in this frame format:
```
[0xF1] [Address] [Length] [FrameCount] [Commands...] [Checksum] [0xF2]
```

### Frame Builder Function
```swift
func buildCSAFEFrame(commands: [UInt8], frameCount: UInt8) -> Data {
    var frame: [UInt8] = []

    frame.append(0xF1)                      // Start flag
    frame.append(0x00)                      // PM5 address
    frame.append(UInt8(commands.count))     // Data length
    frame.append(frameCount)                // Frame counter
    frame.append(contentsOf: commands)      // Actual commands

    // Checksum (XOR of all bytes except start/stop flags)
    let checksum = frame[1...].reduce(0, ^)
    frame.append(checksum)
    frame.append(0xF2)                      // Stop flag

    return Data(frame)
}
```

## Workout Types

### 1. Just Row (Free Rowing)
```swift
// Reset to "Just Row" mode
let commands: [UInt8] = [0x24, 0x00]  // CSAFE_SETPROGRAM_CMD = Just Row
```

### 2. Single Distance
```swift
// Example: 2000m
let commands: [UInt8] = [
    0x24, 0x01,                    // Set program to "Single Distance"
    0x21,                          // CSAFE_SETHORIZONTAL_CMD
    0xD0, 0x07, 0x00,             // 2000m in little-endian (0x07D0)
    0x01                          // Units: meters
]
```

### 3. Single Time
```swift
// Example: 20 minutes
let commands: [UInt8] = [
    0x24, 0x02,              // Set program to "Single Time"
    0x20,                    // CSAFE_SETTWORK_CMD
    0x00, 0x14, 0x00        // 0 hours, 20 minutes, 0 seconds
]
```

### 4. Intervals (Complex)
```swift
// Example: 8 x 500m with 1:00 rest
// Uses PM5 proprietary commands (0x76 prefix)
let commands: [UInt8] = [
    0x24, 0x05,                    // Set program to "Custom Interval"
    0x76, 0x03, 0x01,             // Interval type: distance
    0x76, 0x05, 0xF4, 0x01,       // Work: 500m (0x01F4)
    0x76, 0x06, 0x3C,             // Rest: 60 seconds
    0x76, 0x07, 0x08              // Number of intervals: 8
]
```

## CSAFE Command Reference

| Command | Hex | Description | Parameters |
|---------|-----|-------------|------------|
| CSAFE_SETPROGRAM_CMD | 0x24 | Set workout program | 0x00=Just Row, 0x01=Distance, 0x02=Time, 0x05=Interval |
| CSAFE_SETTWORK_CMD | 0x20 | Set time workout | [hours, minutes, seconds] |
| CSAFE_SETHORIZONTAL_CMD | 0x21 | Set distance workout | [low, mid, high bytes, units] |
| CSAFE_PM_SET_INTERVALTYPE | 0x76 0x03 | Set interval type | 0x00=time, 0x01=distance |
| CSAFE_PM_SET_INTERVALWORKTIME | 0x76 0x05 | Set work interval | [low, high bytes] |
| CSAFE_PM_SET_INTERVALRESTTIME | 0x76 0x06 | Set rest time | [seconds] |
| CSAFE_PM_SET_INTERVALS | 0x76 0x07 | Set number of intervals | [count] |

## Known PM5 Firmware Issues

### Critical Bug (Firmware v19+)
- **Problem**: Each BLE write creates a new state machine instance
- **Impact**: Commands sent in separate writes don't maintain state
- **Solution**: Send all related commands in a SINGLE BLE write operation

### Message Reliability
- BLE messages can be dropped during workout transitions
- Always verify command acknowledgment via receive characteristic
- Implement timeout and retry logic

## Implementation Strategy

### Phase 1: Basic Workouts
1. Just Row mode
2. Single distance (2000m, 5000m, 10000m)
3. Single time (20:00, 30:00, 60:00)

### Phase 2: Interval Workouts
1. Distance intervals (4x500m, 8x250m)
2. Time intervals (4x4:00, 8x2:00)
3. Custom combinations

### Phase 3: Advanced Features
1. Variable interval programming
2. Workout history/favorites
3. Sync with SemperClock workout plans

## Testing Approach

### Mock Testing
Extend `MockConcept2Manager` to simulate:
- CSAFE command acceptance
- Response generation
- Workout state transitions

### Physical Testing Order
1. Just Row mode (simplest, most reliable)
2. Single distance/time workouts
3. Simple intervals (after basic workouts verified)
4. Complex multi-stage workouts

## Code Integration Points

### Concept2Manager.swift Changes
1. Add CSAFE service UUIDs
2. Implement service discovery for control service
3. Add transmit/receive characteristic handlers
4. Implement CSAFE frame builder
5. Add workout programming methods

### UI Integration
1. Add "Program Workout" section to Concept2View
2. Workout type selector (segmented control)
3. Parameter inputs (distance/time/intervals)
4. Send to PM5 button
5. Status feedback

## References
- CSAFE Protocol v0.27
- Concept2 PM5 BLE Communication Definition
- ErgometerJS implementation
- Py3Row Python library
- c2api C++ implementation