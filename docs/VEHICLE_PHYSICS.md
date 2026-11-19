# Native vehicle dynamics

The four RayCast3D suspension mounts operate on a Jolt RigidBody3D. Each wheel samples its contact plane, calculates compression and rebound, transfers load through the spring and anti-roll bar, and applies forces at its contact patch. Body inertia is estimated from chassis dimensions. Steering uses an Ackermann approximation with a progressive, speed-sensitive response.

The engine integrates net torque and inertia against a clutch and gear ratio. Separate forward ratios, reverse, neutral, park, final drive, and low range are available. The 4L transfer case multiplies the ordinary ratio by 2.55. Front, rear and all-wheel drive use distinct torque distributions. Differential locking couples wheel angular speeds through a bounded correction.

The tire model integrates wheel angular velocity in eight bounded substeps per 60 Hz chassis tick. The slip ratio is normalized using contact speed with a low-speed floor. A smooth saturation curve combines with lateral slip and a load-sensitive friction circle. ABS uses braking slip, TCS uses driven-wheel slip, and ESC provides bounded yaw correction. HDC adds brake demand above a low-speed threshold. This is a game-oriented model pending validation against real vehicle data.

Fuel burn and cooling use RPM/load-dependent state. The suspension, tire, engine and cooling models consume mechanical condition, which chassis impacts can degrade. The headless tests exercise a straight road and several actual chassis masses. See [Test results](TEST_RESULTS.md).
