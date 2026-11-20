# My Car native project

Source audit baseline: a8595b76e302a39086f8b46532a0cce517b590d5 on main. The root React application remains the web prototype. Android is exported exclusively from Masalik-3D.

| Subsystem | Baseline status | Source evidence and native migration |
| --- | --- | --- |
| Boot and singletons | Broken | MainMenu scene and two autoloads were absent. Persistence and fleet scripts collided with autoload names. The icon existed under assets/textures. |
| Driving | Broken in game | Wheel rays existed in main_game but the exported arrays were empty. The controller applied constant drive force and combined braking with reverse. physicsEngine.ts is the reference for drivetrain and tire behavior. |
| Fleet and models | Incomplete | Five native data entries and one chassis scene. vehicleFleet.ts and vehicleBuilder.ts contain the ten web IDs, specifications and procedural visual design. |
| World | Incomplete | mountain_road_generator.gd defined a 2 km strip. The streaming manager only tracked flags. worldBuilder.ts and roadSpline.ts contain the web world, regional definitions and coordinate model. |
| Weather and traffic | Incomplete | Weather returned friction modifiers. Traffic stored a density integer. Neither changed the native scene. |
| Native interface | Missing | No usable lobby, garage, Settings, map or touch input. Reuse concepts from MainMenuLobby, GarageShowroomModal, SettingsAndSaveModal, YemenWorldMapModal, SmartSteeringWheel and ControlStudioModal. |
| Career and local navigation | Missing | missionsCatalog.ts and MissionsAndStoryModal contain browser content. No native mission completion or pathfinding existed. |
| Audio | Missing | audioEngine.ts contains a functioning architectural reference. No native audio implementation existed. |
| Persistence | Broken | Autoload collision and direct truncating writes. Browser persistenceManager.ts uses localStorage and IndexedDB, which are inaccessible to the native process without import. |
| Exports and CI | Broken | Export preset was under android/ and CI was nested inside the Godot project. The workflow referenced two absent scripts. |
| Older engineering reports | Documented only in part | Treat the source tree and test results as authoritative where reports describe unconnected features. |

Godot 4.7.2 and Jolt handle native simulation. The Compatibility renderer targets GLES 3.0; APK manifest inspection establishes the actual minimum API. Native gameplay reads bundled resources and user storage only.

## Integrated runtime

The native menu enters either a free drive or a mission in the same driving scene. The selected original fleet ID supplies the vehicle physics and geometry. The route spline drives sector loading, lane traffic, recovery, regional themes and the offline map. Physical progress through ordered checkpoint gates determines mission completion. Garage purchases, paint, driving settings, records and active attempts are stored with same-directory staged writes and a validated previous copy. The save manager can import a JSON export from the original web app. Web-only settings are outside the native migration.

For Android export and release, see [Android build](ANDROID_BUILD.md). For measured checks, see [Test results](TEST_RESULTS.md).
