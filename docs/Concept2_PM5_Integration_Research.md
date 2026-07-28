# Concept2 PM5 Integration Research

## Overview
The Concept2 PM5 Performance Monitor supports comprehensive bidirectional communication via Bluetooth Low Energy (BLE), enabling both data collection and workout programming capabilities.

## Current Implementation Status
✅ **Implemented**: Basic data collection from PM5
- Heart rate monitoring
- Stroke rate (SPM)
- Pace per 500m
- Distance rowed
- Power output (watts)

## PM5 Bluetooth Capabilities

### 1. Data Collection (Currently Implemented)
The PM5 broadcasts real-time rowing metrics via standard BLE services:

#### FTMS Service (Fitness Machine Service)
- **UUID**: 0x1826
- **Rower Data Characteristic**: 0x2AD1
- Provides: stroke rate, total distance, instantaneous pace, average pace, instantaneous power, total energy, energy per hour, energy per minute, heart rate, metabolic equivalent, elapsed time, remaining time

#### C2 Proprietary Service
- **UUID**: CE060000-43E5-11E4-916C-0800200C9A66
- Enhanced metrics including:
  - Drag factor
  - Drive length
  - Drive time
  - Recovery time
  - Peak force
  - Average force
  - Work per stroke
  - Stroke count

### 2. Workout Beaming Capabilities (Not Yet Implemented)

#### What Can Be Beamed
The PM5 accepts custom workouts via BLE using the C2 proprietary protocol:

1. **Interval Workouts**
   - Time-based intervals (e.g., 30s work/30s rest)
   - Distance-based intervals (e.g., 500m on/1min rest)
   - Variable interval structures

2. **Target Workouts**
   - Pace targets (maintain specific split times)
   - Heart rate zone targets
   - Power/watt targets
   - Stroke rate targets

3. **Custom Workouts**
   - Complex multi-segment workouts
   - Warmup/cooldown phases
   - Pyramid structures
   - HIIT protocols

#### How Workout Beaming Works

**C2 Workout Programming Service**
- **UUID**: CE060020-43E5-11E4-916C-0800200C9A66
- **Workout Control Characteristic**: CE060021-43E5-11E4-916C-0800200C9A66
- **Workout Definition Characteristic**: CE060022-43E5-11E4-916C-0800200C9A66

**Protocol Steps**:
1. Connect to PM5 via BLE
2. Discover C2 Workout Programming Service
3. Write workout definition (binary format)
4. Send start command
5. Monitor workout progress via data characteristics
6. PM5 displays workout on screen with targets and progress

## Integration Recommendations

### Phase 1: Enhanced Data Collection ✅ (Partially Complete)
- [x] Basic rowing metrics
- [ ] Force curve data
- [ ] Drag factor monitoring
- [ ] Detailed stroke analysis
- [ ] Workout summary statistics

### Phase 2: Simple Workout Beaming
Implement basic workout transfer for SemperClock workouts:
```swift
// Example: Transfer HIIT workout to PM5
func beamWorkoutToPM5(_ workout: Workout) {
    // Convert SemperClock workout format to C2 binary format
    let c2Workout = convertToC2Format(workout)

    // Write to PM5 Workout Definition characteristic
    pm5.writeValue(c2Workout, for: workoutDefinitionCharacteristic)

    // Start workout on PM5
    pm5.writeValue(startCommand, for: workoutControlCharacteristic)
}
```

### Phase 3: Advanced Integration
- **Synchronized Display**: Mirror PM5 display on Apple TV
- **Real-time Coaching**: Provide technique feedback based on force curves
- **Auto-sync Results**: Upload completed workouts to Concept2 Logbook
- **Virtual Racing**: Enable ghost boat/partner workouts

## Implementation Approach

### Option 1: Pull Statistics Only (Current)
**Pros**:
- Simple implementation
- Non-intrusive to rower's PM5 experience
- Works with any PM5 workout

**Cons**:
- User must manually program workouts on PM5
- No control over PM5 display

### Option 2: Full Workout Control (Recommended)
**Pros**:
- Complete integration with SemperClock workouts
- Automatic PM5 configuration
- Synchronized displays across all devices
- Better user experience

**Cons**:
- More complex implementation
- Requires C2 binary protocol knowledge
- May override user's PM5 preferences

### Hybrid Approach (Best of Both)
1. **Default Mode**: Pull statistics only
2. **Enhanced Mode**: Optional workout beaming
3. **User Choice**: Settings toggle for PM5 control level

## Technical Implementation Details

### Workout Binary Format
```
Struct C2Workout {
    header: [UInt8] = [0x01, 0x00]  // Version
    workoutType: UInt8               // 0x00=Just Row, 0x01=Fixed Distance, etc.
    intervals: [C2Interval]
}

Struct C2Interval {
    type: UInt8       // 0x00=Distance, 0x01=Time, 0x02=Rest
    value: UInt32     // Distance in meters or time in 0.01 seconds
    restTime: UInt32  // Rest duration if applicable
    targetPace: UInt16 // Split time in 0.1 seconds
}
```

### Sample Code for Workout Beaming
```swift
extension Concept2Manager {
    func beamCustomWorkout(_ workout: Workout) {
        guard let pm5 = connectedPM5 else { return }

        // Build binary workout data
        var workoutData = Data()

        // Header
        workoutData.append(contentsOf: [0x01, 0x00]) // Version 1.0
        workoutData.append(0x05) // Custom interval workout

        // Convert each exercise to PM5 interval
        for exercise in workout.exercises {
            if exercise.equipment == .rower {
                // Interval type (time-based)
                workoutData.append(0x01)

                // Duration in centiseconds
                let centiseconds = UInt32(exercise.duration * 100)
                workoutData.append(contentsOf: centiseconds.bytes)

                // Target pace (optional)
                if let targetPace = exercise.targetPace {
                    let splitTime = UInt16(targetPace * 10)
                    workoutData.append(contentsOf: splitTime.bytes)
                }
            }
        }

        // Write to PM5
        pm5.writeValue(workoutData,
                      for: workoutDefinitionCharacteristic,
                      type: .withResponse)
    }
}
```

## Testing Strategy

### Simulator Testing
- Mock PM5 BLE peripheral for data simulation
- Test workout format conversion
- Verify data parsing and display

### Physical Testing Requirements
- Concept2 Model D/E with PM5
- Test various workout types
- Verify PM5 screen synchronization
- Test connection stability during rowing

## User Experience Considerations

### Settings Options
```
Concept2 Integration Level:
[ ] Basic - Display rowing data only
[ ] Enhanced - Sync workouts to PM5
[ ] Full Control - SemperClock controls PM5 display

Auto-connect to PM5: [ON/OFF]
Upload to Concept2 Logbook: [ON/OFF]
Show force curves on TV: [ON/OFF]
```

### Workout Flow
1. User creates workout in SemperClock
2. If PM5 connected and enhanced mode enabled:
   - Prompt: "Beam workout to PM5?"
3. On confirmation:
   - Transfer workout to PM5
   - PM5 displays workout with intervals
   - SemperClock mirrors data on TV
4. Post-workout:
   - Collect summary from PM5
   - Optional upload to Concept2 Logbook

## Next Steps

1. **Immediate**: Fix current data display issues
2. **Short-term**: Implement force curve visualization
3. **Medium-term**: Add workout beaming for basic intervals
4. **Long-term**: Full PM5 control and Logbook integration

## Resources

- [Concept2 PM5 BLE Protocol Documentation](https://www.concept2.com/service/software/software-development-kit)
- [ErgData API](https://www.concept2.com/ergdata/api)
- [FTMS Bluetooth Profile](https://www.bluetooth.com/specifications/specs/fitness-machine-service-1-0/)
- [C2 SDK Examples](https://github.com/concept2/pm5-sdk)

## Conclusion

The PM5 offers extensive integration possibilities beyond simple data collection. Implementing workout beaming would significantly enhance the user experience by:
- Eliminating manual workout programming on PM5
- Ensuring perfect synchronization between devices
- Providing a seamless, integrated training experience

Recommended approach: Start with enhanced data collection, then gradually add workout beaming capabilities based on user feedback and testing results.