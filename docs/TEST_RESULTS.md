# Native test results

Godot 4.7.2.stable.official.ed1daf0bf and Jolt on desktop Linux. The automated suite uses 60 fixed physics ticks per second. These are simulation measurements.

The import, startup and integration gates completed. The integration run passed **71 checks**, with **zero failures**. It exercised native boot, four wheel contacts, flat idle, acceleration, braking, explicit reverse, steering, relayed multitouch events, streaming and collision at seven route locations, rain traction, traffic pooling, camera availability, map routing, garage and paint, mission start and continuation, a physically driven mission finish, v2 web save import, staged-save interruption and backup recovery.

| Vehicle | Mass | 0–100 km/h | Stop distance |
| --- | ---: | ---: | ---: |
| الشاهق | 1,920 kg | 19.98 s | 40.7 m from 100.0 km/h |
| المدينة | 1,380 kg | 12.33 s | 39.0 m from 100.0 km/h |
| الجبل | 4,400 kg | Below 100 km/h at the end of the 40 s run | 10.8 m from 49.7 km/h |

- Low range climbed 18.3 horizontal meters and gained 2.6 m of elevation in 3.5 seconds on an 8° slope.
- Hill descent control measured 8.9 km/h after six seconds on that slope.
- After 3.83 seconds accelerating from rest, the SUV measured 45.6 km/h on asphalt, 39.6 km/h on sand and 37.8 km/h on mud.
- A complete drive through the school's four gates took 14.08 seconds. The test stopped the vehicle at the finish and checked the saved reward.
- The APK manifest, ZIP alignment and debug certificate verified with the Android Build Tools. Package `com.moataz.masalik`, minimum API 26, target API 36, ARM64 only and no declared Internet permission.

Physical Android installation, airplane-mode operation, GPU frame pacing and sustained performance remain unverified. Story routes are available in the runtime catalog. The automated completion measurement covers the driving-school route.
