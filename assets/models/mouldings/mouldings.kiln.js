const meta = { name: 'Wall mouldings' };
// Crack & Stack: the library's wall mouldings (room plan phase 1), each a
// 1 m straight length along +X with its back flat at Z = 0 and its face
// toward +Z. Godot stretches each piece along X to a wall run's length and
// gives it the walnut material, so the material here is only a stand-in.
// Profiles are [out from the wall, height] in metres.

// An arc of points from angle a0 to a1 (degrees) around (cx, cy).
function arc(cx, cy, r, a0, a1, steps) {
  const out = [];
  for (let i = 0; i <= steps; i++) {
    const a = (a0 + (a1 - a0) * i / steps) * Math.PI / 180;
    out.push([cx + r * Math.cos(a), cy + r * Math.sin(a)]);
  }
  return out;
}

// Skirting board: a 16 cm plinth with a rounded ovolo on top.
const SKIRTING = [[0, 0], [0.022, 0], [0.022, 0.13],
  ...arc(0.012, 0.13, 0.01, 0, 90, 6), [0.012, 0.142], [0.009, 0.15], [0.009, 0.16], [0, 0.16]];
// Dado rail: a rounded chair rail, 6 cm tall, 3.5 cm proud.
const DADO = [[0, 0], [0.018, 0], ...arc(0.018, 0.016, 0.016, -90, 0, 5),
  [0.034, 0.03], ...arc(0.022, 0.044, 0.012, 0, 90, 5), [0.012, 0.056], [0.012, 0.06], [0, 0.06]];
// Cornice: a cove under the ceiling, 15 cm down, 11 cm out; its top at 0.15.
const CORNICE = [[0, 0], [0.012, 0], [0.012, 0.012], [0.02, 0.02],
  ...arc(0.105, 0.02, 0.085, 180, 90, 10), [0.11, 0.105], [0.11, 0.13], [0.115, 0.135], [0.115, 0.15], [0, 0.15]];

async function piece(name, profile, material, parent, z) {
  // extrudeProfile on axis x maps (u, v) to (d, v, -u): pass -out as u so
  // the face comes out toward +Z.
  const geo = await extrudeProfile(profile.map(([o, h]) => [-o, h]), { depth: 1, axis: 'x', center: false });
  const part = createPart(name, geo, material, { position: [0, 0, z], parent });
  part.name = name;
  return part;
}

async function build() {
  const root = createRoot('Mouldings');
  const walnut = pbrMaterial({ albedo: 0x5a3a26, roughness: 0.55, metalness: 0, name: 'Walnut' });
  // Laid side by side along Z only so the review sheet shows all three.
  await piece('Skirting', SKIRTING, walnut, root, 0);
  await piece('Dado', DADO, walnut, root, 0.3);
  await piece('Cornice', CORNICE, walnut, root, 0.6);
  return root;
}
