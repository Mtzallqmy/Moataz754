# Yemeni driving world

The native route is sampled at four horizontal meters and grouped into thirty 500 m sectors. Six regions share one continuous route with distinct altitude, terrain color and surface profiles. The streamer maintains collision for the current sector and two neighbors on either side, including the destination before vehicle recovery. Exact sector-boundary vertices are shared by adjacent strips. Near terrain carries collision and outer strips supply the distant silhouette. The native map uses route distance and world coordinates without a geographic service.

Road lane markings, foothills, a coastal ribbon, desert trails and scattered scenery are generated locally. An original stone tower is built in Blender and committed as a glTF binary. Roadside scatter is batched into MultiMesh instances. Traffic pools up to ten cars and adjusts speed to curvature and same-lane gaps. The world clock changes sky, ambient light and sun angle. Preset weather changes fog, surface shading and vehicle friction.

This route uses a single connected corridor. True junctions, traffic overtaking, tunnel interiors, bridges, a full terrain LOD hierarchy and broader city blocks are outstanding. See [Test results](TEST_RESULTS.md) for verified collision and streaming behavior.
