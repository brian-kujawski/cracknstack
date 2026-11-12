const meta = { name: 'Furniture parts' };
// Crack & Stack: shared parts for the library furniture (room plan phase 4),
// so the tables, the side table and the cabinets speak the bookcase's
// language (its fluted pilasters, brass details).
// FlutedLeg is a unit leg: 1 m tall from the floor (y = 0) up, 1 m square
// at the top. Godot scales it across to a leg's real top width and up to its
// height. Its top BLOCK is plain and square, where the apron meets it; below
// that it tapers to FOOT of its width and has three flutes down each face.
// FootCap is the brass cup the foot stands in, at the same unit scale.
// Everything sits at its real place in the model (Godot keeps placements).
const BLOCK = 0.13;
const FOOT = 0.72;
const CAP = 0.05;

// A square 1 wide, centred, with three rounded flutes cut into each face.
function flutedSquare() {
  const half = 0.5, flutes = 3, inset = 0.14, depth = 0.05;
  const pts = [];
  // Walk the four faces anticlockwise; each face from corner to corner.
  const corners = [[-half, -half], [half, -half], [half, half], [-half, half]];
  for (let f = 0; f < 4; f++) {
    const [ax, ay] = corners[f];
    const [bx, by] = corners[(f + 1) % 4];
    const dx = bx - ax, dy = by - ay;
    // Inward normal of this face.
    const nx = -dy, ny = dx;
    pts.push([ax, ay]);
    const span = 1 - 2 * inset;
    for (let k = 0; k < flutes; k++) {
      const t0 = inset + span * (k + 0.15) / flutes;
      const t1 = inset + span * (k + 0.85) / flutes;
      for (let i = 0; i <= 6; i++) {
        const t = t0 + (t1 - t0) * i / 6;
        const d = depth * Math.sin(Math.PI * i / 6);
        pts.push([ax + dx * t + nx * d, ay + dy * t + ny * d]);
      }
    }
  }
  return pts;
}

async function build() {
  const root = createRoot('Furniture');
  const walnut = pbrMaterial({ albedo: 0x5a3a26, roughness: 0.55, metalness: 0, name: 'Walnut' });
  const brass = pbrMaterial({ albedo: 0xb08a3e, roughness: 0.35, metalness: 1, name: 'Brass' });
  const shaft = 1 - BLOCK;
  // Extruded from the top down (then turned over) so the taper lands at the foot.
  const geo = await extrudeProfile(flutedSquare(), { depth: shaft, axis: 'y', center: false, taper: FOOT });
  const leg = createPart('FlutedLeg', geo, walnut, { position: [0, shaft, 0], rotation: [180, 0, 0], parent: root });
  leg.name = 'FlutedLeg';
  const block = createPart('LegBlock', boxGeo(1, BLOCK, 1), walnut, { position: [0, shaft + BLOCK / 2, 0], parent: root });
  block.name = 'LegBlock';
  const cap = createPart('FootCap', boxGeo(FOOT + 0.06, CAP, FOOT + 0.06), brass, { position: [0, CAP / 2, 0], parent: root });
  cap.name = 'FootCap';
  return root;
}
