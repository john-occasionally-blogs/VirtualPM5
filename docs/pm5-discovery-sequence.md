# PM5 BLE Connection / Discovery / Subscription Sequence — verbatim

Source: <private capture archive>
Device: PM5 XXXXXXXXX Row (real hardware), app v2.31.2 (578), 2026-07-16 ~20:49.

## Initial connection (log lines 49–121, filtered to 🚣 rowing-channel lines, verbatim in order)

```
🚣 📡 Scanning for Concept2 rowers...
🚣 📱 Found: PM5 XXXXXXXXX Row (RSSI: -45)
🚣 🛑 Stopped scanning. Found 1 device(s)
🚣 🔗 Connecting to PM5 XXXXXXXXX Row...
🚣 ✅ Connected to PM5 XXXXXXXXX Row
🚣 📡 Broadcasting connection status: Connected
🚣 🔍 Discovered service: CE060020-43E5-11E4-916C-0800200C9A66
🚣 🎯 Found CSAFE Service! Discovering ALL characteristics...
🚣 🔍 Discovered service: CE060010-43E5-11E4-916C-0800200C9A66
🚣 🔍 Discovering characteristics for unknown service: CE060010-43E5-11E4-916C-0800200C9A66
🚣 🔍 Discovered service: CE060030-43E5-11E4-916C-0800200C9A66
🚣 🔍 Discovered service: CE060040-43E5-11E4-916C-0800200C9A66
🚣 🔍 Discovering characteristics for unknown service: CE060040-43E5-11E4-916C-0800200C9A66
🚣 🔍 Discovered service: 1826
🚣 📊 Found characteristic: CE060022-43E5-11E4-916C-0800200C9A66 - [notify]
🚣 ✅ Found CSAFE Rx characteristic (CE060022) - subscribed for responses
🚣 📊 Found characteristic: CE060021-43E5-11E4-916C-0800200C9A66 - [WRITE, WRITE_NO_RESP]
🚣 ✅ Found CSAFE Tx characteristic (CE060021) - properties: WRITE, WRITE_NO_RESP
🚣 ✅ CSAFE Tx ready for writing commands!
🚣 🔄 processPendingWorkoutProgram() called
🚣 🔄 State: pending=false, peripheral=true, csafeTx=true
🚣 ℹ️ No pending workout program to send
🚣 📊 Found characteristic: CE060012-43E5-11E4-916C-0800200C9A66 - [read]
🚣 📊 Found characteristic: CE060013-43E5-11E4-916C-0800200C9A66 - [read]
🚣 📊 Found characteristic: CE060014-43E5-11E4-916C-0800200C9A66 - [read]
🚣 📊 Found characteristic: CE060015-43E5-11E4-916C-0800200C9A66 - [read]
🚣 📊 Found characteristic: CE060011-43E5-11E4-916C-0800200C9A66 - [read]
🚣 📊 Found characteristic: CE060016-43E5-11E4-916C-0800200C9A66 - [read]
🚣 📊 Found characteristic: CE060017-43E5-11E4-916C-0800200C9A66 - [read]
🚣 📊 Found characteristic: CE060018-43E5-11E4-916C-0800200C9A66 - [read]
🚣 📊 Found characteristic: CE060031-43E5-11E4-916C-0800200C9A66 - [notify]
🚣 📊 Subscribed to primary rowing data
🚣 📊 Found characteristic: CE060032-43E5-11E4-916C-0800200C9A66 - [notify]
🚣 📊 Subscribed to secondary rowing data
🚣 📊 Found characteristic: CE060033-43E5-11E4-916C-0800200C9A66 - [notify]
🚣 📊 Subscribed to Additional Status 2 (0x0033: avg power, total calories)
🚣 📊 Found characteristic: CE060034-43E5-11E4-916C-0800200C9A66 - [read, WRITE]
🚣 📊 Found sample-rate characteristic (0x0034) — leaving default 500ms
🚣 📊 Found characteristic: CE060035-43E5-11E4-916C-0800200C9A66 - [notify]
🚣 📊 Subscribed to Stroke Data (0x0035: stroke count)
🚣 📊 Found characteristic: CE060036-43E5-11E4-916C-0800200C9A66 - [notify]
🚣 🔬 Subscribed to unknown characteristic CE060036-43E5-11E4-916C-0800200C9A66 for discovery
🚣 📊 Found characteristic: CE060037-43E5-11E4-916C-0800200C9A66 - [notify]
🚣 🔬 Subscribed to unknown characteristic CE060037-43E5-11E4-916C-0800200C9A66 for discovery
🚣 📊 Found characteristic: CE060038-43E5-11E4-916C-0800200C9A66 - [notify]
🚣 🔬 Subscribed to unknown characteristic CE060038-43E5-11E4-916C-0800200C9A66 for discovery
🚣 📊 Found characteristic: CE060039-43E5-11E4-916C-0800200C9A66 - [notify]
🚣 🏁 Subscribed to End of Workout Summary (0x0039)
🚣 📊 Found characteristic: CE06003A-43E5-11E4-916C-0800200C9A66 - [notify]
🚣 🏁 Subscribed to Additional End of Workout Summary (0x003A)
🚣 📊 Found characteristic: CE06003B-43E5-11E4-916C-0800200C9A66 - [notify]
🚣 🔬 Subscribed to unknown characteristic CE06003B-43E5-11E4-916C-0800200C9A66 for discovery
🚣 📊 Found characteristic: CE060080-43E5-11E4-916C-0800200C9A66 - [notify]
🚣 🔬 Subscribed to unknown characteristic CE060080-43E5-11E4-916C-0800200C9A66 for discovery
🚣 📊 Found characteristic: CE06003D-43E5-11E4-916C-0800200C9A66 - [notify]
🚣 🔬 Subscribed to unknown characteristic CE06003D-43E5-11E4-916C-0800200C9A66 for discovery
🚣 📊 Found characteristic: CE06003E-43E5-11E4-916C-0800200C9A66 - [notify]
🚣 🔬 Subscribed to unknown characteristic CE06003E-43E5-11E4-916C-0800200C9A66 for discovery
🚣 📊 Found characteristic: CE06003F-43E5-11E4-916C-0800200C9A66 - [notify]
🚣 🔬 Subscribed to unknown characteristic CE06003F-43E5-11E4-916C-0800200C9A66 for discovery
🚣 📊 Found characteristic: CE060041-43E5-11E4-916C-0800200C9A66 - [WRITE, WRITE_NO_RESP]
🚣 📊 Found characteristic: 2ACC - [read]
🚣 📊 Found characteristic: 2AD1 - [notify]
🚣 📊 Subscribed to fitness machine rowing data
🚣 🔬 CE060031 raw (19 bytes): 00 00 00 00 00 00 00 01 00 00 00 00 00 00 00 00 00 80 00
🚣 🚦 PM5 workout state → waitToBegin
🚣 🔬 CE060032 raw (17 bytes): 00 00 00 00 00 00 FF 00 00 00 00 00 00 00 00 00 00
🚣 🔬 CE060032 parsed: speed=0.00m/s SR=0spm pace=-s/500m avgPace=-
🚣 🔬 UNKNOWN char CE06003E-43E5-11E4-916C-0800200C9A66 (19 bytes): 01 01 2D 01 00 00 00 00 00 00 00 00 20 00 00 00 00 00 00
🚣 🔬 FTMS 0x2AD1 raw (19 bytes): FF 0A 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
🚣 🔬 FTMS flags=0x0AFF → [AvgStrokeRate, TotalDistance, InstPace, AvgPace, InstPower, AvgPower, Resistance, HeartRate, ElapsedTime]
🚣 🔬 FTMS avg power: 0W
```

## Mid-session reconnect (log lines 131146–131240, same sequence repeats)

```
🚣 🔬 CE060032 raw (17 bytes): 50 46 00 EE 0F 16 FF 16 30 F7 30 00 00 00 00 00 00
🚣 🔬 CE060031 raw (19 bytes): 50 46 00 0E 1C 00 05 00 0C 00 01 00 00 00 50 46 00 00 7C
⏱️ 🚣 Stroke: 22 spm, Connected: true
🚣 🔌 Disconnected from PM5 XXXXXXXXX Row
🚣 📡 Broadcasting connection status: Disconnected
🚣 🛑 Stopped scanning. Found 1 device(s)
🚣 🔗 Connecting to PM5 XXXXXXXXX Row...
🚣 ✅ Connected to PM5 XXXXXXXXX Row
🚣 📡 Broadcasting connection status: Connected
🚣 🔍 Discovered service: CE060020-43E5-11E4-916C-0800200C9A66
🚣 🎯 Found CSAFE Service! Discovering ALL characteristics...
🚣 🔍 Discovered service: CE060010-43E5-11E4-916C-0800200C9A66
🚣 🔍 Discovering characteristics for unknown service: CE060010-43E5-11E4-916C-0800200C9A66
🚣 🔍 Discovered service: CE060030-43E5-11E4-916C-0800200C9A66
🚣 🔍 Discovered service: CE060040-43E5-11E4-916C-0800200C9A66
🚣 🔍 Discovering characteristics for unknown service: CE060040-43E5-11E4-916C-0800200C9A66
🚣 🔍 Discovered service: 1826
🚣 📊 Found characteristic: CE060022-43E5-11E4-916C-0800200C9A66 - [notify]
🚣 ✅ Found CSAFE Rx characteristic (CE060022) - subscribed for responses
🚣 📊 Found characteristic: CE060021-43E5-11E4-916C-0800200C9A66 - [WRITE, WRITE_NO_RESP]
🚣 ✅ Found CSAFE Tx characteristic (CE060021) - properties: WRITE, WRITE_NO_RESP
🚣 ✅ CSAFE Tx ready for writing commands!
🚣 🔄 processPendingWorkoutProgram() called
🚣 🔄 State: pending=false, peripheral=true, csafeTx=true
🚣 ℹ️ No pending workout program to send
🚣 📊 Found characteristic: CE060012-43E5-11E4-916C-0800200C9A66 - [read]
🚣 📊 Found characteristic: CE060013-43E5-11E4-916C-0800200C9A66 - [read]
🚣 📊 Found characteristic: CE060014-43E5-11E4-916C-0800200C9A66 - [read]
🚣 📊 Found characteristic: CE060015-43E5-11E4-916C-0800200C9A66 - [read]
🚣 📊 Found characteristic: CE060011-43E5-11E4-916C-0800200C9A66 - [read]
🚣 📊 Found characteristic: CE060016-43E5-11E4-916C-0800200C9A66 - [read]
🚣 📊 Found characteristic: CE060017-43E5-11E4-916C-0800200C9A66 - [read]
🚣 📊 Found characteristic: CE060018-43E5-11E4-916C-0800200C9A66 - [read]
🚣 📊 Found characteristic: CE060031-43E5-11E4-916C-0800200C9A66 - [notify]
🚣 📊 Subscribed to primary rowing data
🚣 📊 Found characteristic: CE060032-43E5-11E4-916C-0800200C9A66 - [notify]
🚣 📊 Subscribed to secondary rowing data
🚣 📊 Found characteristic: CE060033-43E5-11E4-916C-0800200C9A66 - [notify]
🚣 📊 Subscribed to Additional Status 2 (0x0033: avg power, total calories)
🚣 📊 Found characteristic: CE060034-43E5-11E4-916C-0800200C9A66 - [read, WRITE]
🚣 📊 Found sample-rate characteristic (0x0034) — leaving default 500ms
🚣 📊 Found characteristic: CE060035-43E5-11E4-916C-0800200C9A66 - [notify]
🚣 📊 Subscribed to Stroke Data (0x0035: stroke count)
🚣 📊 Found characteristic: CE060036-43E5-11E4-916C-0800200C9A66 - [notify]
🚣 🔬 Subscribed to unknown characteristic CE060036-43E5-11E4-916C-0800200C9A66 for discovery
🚣 📊 Found characteristic: CE060037-43E5-11E4-916C-0800200C9A66 - [notify]
🚣 🔬 Subscribed to unknown characteristic CE060037-43E5-11E4-916C-0800200C9A66 for discovery
🚣 📊 Found characteristic: CE060038-43E5-11E4-916C-0800200C9A66 - [notify]
🚣 🔬 Subscribed to unknown characteristic CE060038-43E5-11E4-916C-0800200C9A66 for discovery
🚣 📊 Found characteristic: CE060039-43E5-11E4-916C-0800200C9A66 - [notify]
🚣 🏁 Subscribed to End of Workout Summary (0x0039)
🚣 📊 Found characteristic: CE06003A-43E5-11E4-916C-0800200C9A66 - [notify]
🚣 🏁 Subscribed to Additional End of Workout Summary (0x003A)
🚣 📊 Found characteristic: CE06003B-43E5-11E4-916C-0800200C9A66 - [notify]
🚣 🔬 Subscribed to unknown characteristic CE06003B-43E5-11E4-916C-0800200C9A66 for discovery
🚣 📊 Found characteristic: CE060080-43E5-11E4-916C-0800200C9A66 - [notify]
🚣 🔬 Subscribed to unknown characteristic CE060080-43E5-11E4-916C-0800200C9A66 for discovery
🚣 📊 Found characteristic: CE06003D-43E5-11E4-916C-0800200C9A66 - [notify]
🚣 🔬 Subscribed to unknown characteristic CE06003D-43E5-11E4-916C-0800200C9A66 for discovery
🚣 📊 Found characteristic: CE06003E-43E5-11E4-916C-0800200C9A66 - [notify]
🚣 🔬 Subscribed to unknown characteristic CE06003E-43E5-11E4-916C-0800200C9A66 for discovery
🚣 📊 Found characteristic: CE06003F-43E5-11E4-916C-0800200C9A66 - [notify]
🚣 🔬 Subscribed to unknown characteristic CE06003F-43E5-11E4-916C-0800200C9A66 for discovery
🚣 📊 Found characteristic: CE060041-43E5-11E4-916C-0800200C9A66 - [WRITE, WRITE_NO_RESP]
🚣 📊 Found characteristic: 2ACC - [read]
🚣 📊 Found characteristic: 2AD1 - [notify]
🚣 📊 Subscribed to fitness machine rowing data
🚣 🔬 CE060031 raw (19 bytes): 50 46 00 0E 1C 00 05 00 0C 00 01 00 00 00 50 46 00 00 7C
🚣 🔬 CE060032 raw (17 bytes): 50 46 00 EE 0F 16 FF 16 30 F7 30 00 00 00 00 00 00
🚣 🔬 CE060031 raw (19 bytes): 50 46 00 0E 1C 00 05 00 0C 00 01 00 00 00 50 46 00 00 7C
🚣 🔬 CE060032 raw (17 bytes): 50 46 00 EE 0F 16 FF 16 30 F7 30 00 00 00 00 00 00
🚣 🔬 CE060031 raw (19 bytes): 50 46 00 0E 1C 00 05 00 0C 00 01 00 00 00 50 46 00 00 7C
🚣 🔬 CE060032 raw (17 bytes): 50 46 00 EE 0F 16 FF 16 30 F7 30 00 00 00 00 00 00
🚣 🔬 FTMS 0x2AD1 raw (19 bytes): FF 0A 00 CE 02 00 00 00 00 00 00 00 00 00 00 00 00 B4 00
🚣 🔬 FTMS flags=0x0AFF → [AvgStrokeRate, TotalDistance, InstPace, AvgPace, InstPower, AvgPower, Resistance, HeartRate, ElapsedTime]
🚣 🔬 FTMS avg power: 0W
🚣 📊 Stroke: 0 spm, Pace: --:--, Power: 0W, Dist: 718m, Remaining: 0m
🚣 🔬 FTMS 0x2AD1 raw (10 bytes): 00 01 00 43 00 00 00 00 00 FF
🚣 🔬 FTMS flags=0x0100 → [StrokeRate+Count, Energy]
🚣 🔬 FTMS energy: total=0kcal, 0kcal/hr, 255kcal/min
📱 🚣 ⏭️ Skipping duplicate Concept2 data (within 100ms)
🚣 📊 Stroke: 0 spm, Pace: --:--, Power: 0W, Dist: 718m, Remaining: 0m
🚣 🔬 CE060031 raw (19 bytes): 50 46 00 0E 1C 00 05 00 0C 00 01 00 00 00 50 46 00 00 00
🚣 🔬 CE060032 raw (17 bytes): 50 46 00 00 00 00 FF 00 00 00 00 00 00 00 00 00 00
🚣 🔬 CE060031 raw (19 bytes): 50 46 00 0E 1C 00 05 00 0C 00 01 00 00 00 50 46 00 00 00
🚣 🔬 CE060032 raw (17 bytes): 50 46 00 00 00 00 FF 00 00 00 00 00 00 00 00 00 00
🚣 🔬 FTMS 0x2AD1 raw (19 bytes): FF 0A 00 CE 02 00 00 00 00 00 00 00 00 00 00 00 00 B4 00
🚣 🔬 FTMS flags=0x0AFF → [AvgStrokeRate, TotalDistance, InstPace, AvgPace, InstPower, AvgPower, Resistance, HeartRate, ElapsedTime]
🚣 🔬 FTMS avg power: 0W
```

## Notes

- Services advertised/discovered, in order: CE060020 (CSAFE control), CE060010 (device info — chars CE060011–18, all [read]), CE060030 (rowing status — chars CE060031–3F, CE060080), CE060040 (unknown, char CE060041 [WRITE, WRITE_NO_RESP]), 1826 (standard FTMS — chars 2ACC [read], 2AD1 [notify]).
- App subscribes (notify) to: CE060022 (CSAFE Rx), CE060031, CE060032, CE060033, CE060035, CE060036*, CE060037*, CE060038*, CE060039, CE06003A, CE06003B*, CE060080*, CE06003D*, CE06003E*, CE06003F*, 2AD1. (* = 'unknown characteristic … for discovery').
- CE060021 = CSAFE Tx (WRITE, WRITE_NO_RESP). CE060034 = sample-rate control [read, WRITE]; app logs 'leaving default 500ms'.
- Characteristic discovery order within CE060030 service: 31, 32, 33, 34, 35, 36, 37, 38, 39, 3A, 3B, 80, 3D, 3E, 3F (note 0x3C absent, 0x80 delivered between 3B and 3D).
- First notifications arrive immediately after subscription, BEFORE any CSAFE write: CE060031 (idle frame, all-zero + durationType 0x80), CE060032 (HR byte = FF), CE06003E, then the FTMS 2AD1 pair (flags 0x0AFF 19B + flags 0x0100 10B).
- On reconnect at L131149 the identical service/char walk repeats; last pre-disconnect 0031 frame (L131147) was the frozen workoutLogged frame of the 3min piece (el=180.00 d=718.2, b8=0x0C).
