const meta = { name: 'Bookcase mouldings' };
// Crack & Stack: the binder bookcase's mouldings (room plan phase 3). Each
// piece is a 1 m straight length along +X with its back flat at Z = 0 and its
// face toward +Z; Godot stretches it along a run (or up, for the pilaster)
// and gives it the walnut, so the material here is only a stand-in.
// Profiles are [out, height] in metres. ShelfUnit's sizes they must match:
// BOARD_THICKNESS 0.04 + BAND_DROP 0.008 (the shelf edge), DIVIDER 0.012,
// SIDE_THICKNESS 0.03.

function arc(cx, cy, r, a0, a1, steps) {
  const out = [];
  for (let i = 0; i <= steps; i++) {
    const a = (a0 + (a1 - a0) * i / steps) * Math.PI / 180;
    out.push([cx + r * Math.cos(a), cy + r * Math.sin(a)]);
  }
  return out;
}

// Shelf edge: 4.8 cm tall, top flush at 0, a flat face for the nameplates
// above a rounded bead at the bottom, its top edge eased.
const SHELF_EDGE = [[0, -0.048], [0.006, -0.048], ...arc(0.006, -0.042, 0.006, -90, 90, 6),
  [0.012, -0.036], [0.012, -0.002], [0.01, 0], [0, 0]];
// Crown under the top: a cove 5 cm tall reaching 3.5 cm out, its top at 0.
const CROWN = [[0, -0.05], [0.006, -0.05], [0.006, -0.044], ...arc(0.04, -0.044, 0.034, 180, 90, 10),
  [0.035, -0.01], [0.035, 0], [0, 0]];
// Base cap: the moulding along the top of the panelled base, 3 cm tall.
const BASE_CAP = [[0, 0], [0.018, 0], ...arc(0.012, 0.012, 0.012, -30, 90, 6), [0.006, 0.024], [0.006, 0.03], [0, 0.03]];

async function piece(name, profile, material, parent, z) {
  // extrudeProfile on axis x maps (u, v) to (d, v, -u): pass -out as u so
  // the face comes out toward +Z.
  const geo = await extrudeProfile(profile.map(([o, h]) => [-o, h]), { depth: 1, axis: 'x', center: false });
  const part = createPart(name, geo, material, { position: [0, 0, z], parent });
  part.name = name;
  return part;
}

// A fluted pilaster face 1 m tall (along +Y), `width` wide, centred on x = 0,
// its back at z = 0: a flat board with three rounded flutes cut in.
function pilaster(width, depth) {
  const flutes = 3;
  const pts = [[-width / 2, 0], [-width / 2, depth]];
  const inner = width - 0.008;
  for (let f = 0; f < flutes; f++) {
    const a = -inner / 2 + inner * f / flutes;
    const b = a + inner / flutes;
    const mid = (a + b) / 2, r = (b - a) / 2 * 0.8;
    pts.push([a, depth]);
    for (let i = 0; i <= 6; i++) {
      const t = Math.PI * i / 6;
      pts.push([mid - r * Math.cos(t), depth - r * 0.6 * Math.sin(t)]);
    }
    pts.push([b, depth]);
  }
  pts.push([width / 2, depth], [width / 2, 0]);
  return pts;
}

async function build() {
  const root = createRoot('Bookcase');
  const walnut = pbrMaterial({ albedo: 0x5a3a26, roughness: 0.55, metalness: 0, name: 'Walnut' });
  // All at the origin: Godot keeps each part's placement in the model, so
  // they must not be spread out for the review sheet.
  await piece('ShelfEdge', SHELF_EDGE, walnut, root, 0);
  await piece('Crown', CROWN, walnut, root, 0);
  await piece('BaseCap', BASE_CAP, walnut, root, 0);
  // Pilaster: profile in (x, z), extruded 1 m up Y.
  const profile = pilaster(0.03, 0.014);
  const geo = await extrudeProfile(profile.map(([x, z]) => [x, -z]), { depth: 1, axis: 'y', center: false });
  const part = createPart('Pilaster', geo, walnut, { parent: root });
  part.name = 'Pilaster';
  return root;
}
