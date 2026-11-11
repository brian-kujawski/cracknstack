const meta = { name: 'Picture light' };
// Crack & Stack: a brass picture light (room plan phase 2) on the wall above
// a frame. The wall is the plane z = 0, the room is +Z, and the origin is on
// the wall where the backplate is fixed. The Hood is 1 m long along X so
// Godot can stretch it to the frame; the two Caps sit at x = +-0.5 and Godot
// moves them to the stretched hood's ends. Godot swaps in its own brass.
const REACH = 0.2;          // wall to the hood's centre
const DROP = 0.06;          // backplate centre down to the hood's centre
const HOOD_R = 0.04;

function arc(cx, cy, r, a0, a1, steps) {
  const out = [];
  for (let i = 0; i <= steps; i++) {
    const a = (a0 + (a1 - a0) * i / steps) * Math.PI / 180;
    out.push([cx + r * Math.cos(a), cy + r * Math.sin(a)]);
  }
  return out;
}

async function build() {
  const root = createRoot('PictureLight');
  const brass = pbrMaterial({ albedo: 0xb08a3e, roughness: 0.35, metalness: 1, name: 'Brass' });
  // Oval backplate on the wall.
  createPart('Backplate', await revolveProfile([[0, 0], [0.045, 0], [0.045, 0.006], [0.035, 0.012], [0, 0.012]], { segments: 32, bevel: 0.002, axis: 'z' }), brass,
    { scale: [0.75, 1, 1], parent: root });
  // A swan-neck arm from the backplate out to the hood's spine.
  const arm = catmullRomPath([[0, 0, 0.01], [0, 0.03, 0.07], [0, 0.0, 0.15], [0, -DROP + HOOD_R + 0.004, REACH - 0.01]], 10);
  createPart('Arm', taperedTube(arm, arm.map(() => 0.0065), { radialSegments: 12 }), brass, { parent: root });
  // The hood: a round trough open down and back toward the frame,
  // 1 m long along X. extrudeProfile on axis x maps (u, v) to (x, v, -u).
  const outer = arc(0, 0, HOOD_R, -75, 165, 18);
  const inner = arc(0, 0, HOOD_R - 0.0025, 165, -75, 18);
  const section = [...outer, ...inner].map(([z, y]) => [-(z), y]);
  createPart('Hood', await extrudeProfile(section, { depth: 1, axis: 'x', center: true }), brass,
    { position: [0, -DROP, REACH], parent: root });
  for (const side of [-1, 1]) {
    createPart(side < 0 ? 'CapL' : 'CapR', cylinderGeo(HOOD_R + 0.002, HOOD_R + 0.002, 0.004, 24), brass,
      { position: [side * 0.5, -DROP, REACH], rotation: [0, 0, 90], parent: root });
  }
  return root;
}
