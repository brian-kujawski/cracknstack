const meta = { name: 'Armchair' };
// Crack & Stack: the library's leather club chair. A tailored English club
// chair: low rolled arms with flat facing panels and brass nailheads, a
// slightly raked diamond-tufted back, one firm piped seat cushion, a walnut
// base rail on short turned legs with brass cups.
// Sizes match the game's collision: 0.85 wide (X), 0.90 deep (Z), back top
// 1.02, seat top 0.49, arm top 0.66, legs 0.09. Origin on the floor at the
// footprint centre; the chair faces +Z.
// Everything is merged into three parts at their real place in the chair
// (Godot keeps each part's placement and puts its own materials on):
// Leather (all upholstery), Wood (legs, base rail), Brass (nails, leg cups).

const W = 0.85, D = 0.90;
const HX = W / 2, HZ = D / 2;
const LEG = 0.09;          // leg height (top of legs, underside of base rail)
const RAIL = 0.125;        // top of the walnut base rail, where leather starts
const SEAT = 0.49;         // top of the seat cushion
const DECK = 0.40;         // top of the seat deck under the cushion
const ARM_TOP = 0.66;
const ARM_IN = 0.295;      // inner face of each arm (arms 13 cm wide)
const ARM_BACK = -0.445, ARM_FRONT = 0.43;
const BACK_TOP = 1.02;
const BACK_FRONT_LOW = [-0.14, RAIL];    // the back's front face, (z, y) at the rail
const BACK_FRONT_TOP = [-0.29, BACK_TOP - 0.005]; // ... and at the top
const RAKE = Math.atan2(BACK_FRONT_LOW[0] - BACK_FRONT_TOP[0], BACK_TOP - RAIL) * 180 / Math.PI; // ~9.5 degrees
// z of the back's front face at height y.
const backFrontZ = (y) => BACK_FRONT_LOW[0] + (y - RAIL) * (BACK_FRONT_TOP[0] - BACK_FRONT_LOW[0]) / (BACK_TOP - RAIL);
const ROLL = 0.055;        // radius of the arm roll

function arc(cx, cy, r, a0, a1, steps) {
  const out = [];
  for (let i = 0; i <= steps; i++) {
    const a = (a0 + (a1 - a0) * i / steps) * Math.PI / 180;
    out.push([cx + r * Math.cos(a), cy + r * Math.sin(a)]);
  }
  return out;
}

// ---- merging: every piece is a geometry plus a matrix, merged per material.
function mat4(pos = [0, 0, 0], rotDeg = [0, 0, 0], scale = [1, 1, 1]) {
  const r = rotDeg.map((d) => d * Math.PI / 180);
  const q = new THREE.Quaternion().setFromEuler(new THREE.Euler(r[0], r[1], r[2], 'XYZ'));
  return new THREE.Matrix4().compose(new THREE.Vector3(...pos), q, new THREE.Vector3(...scale));
}

class Bin {
  constructor() { this.pos = []; this.nrm = []; this.uv = []; this.idx = []; }
  add(geo, m) {
    const p = geo.getAttribute('position');
    const n = geo.getAttribute('normal');
    const nm = new THREE.Matrix3().getNormalMatrix(m);
    const base = this.pos.length / 3;
    const v = new THREE.Vector3(), w = new THREE.Vector3();
    for (let i = 0; i < p.count; i++) {
      v.set(p.getX(i), p.getY(i), p.getZ(i)).applyMatrix4(m);
      if (n) w.set(n.getX(i), n.getY(i), n.getZ(i)).applyMatrix3(nm).normalize();
      else w.set(0, 1, 0);
      this.pos.push(v.x, v.y, v.z);
      this.nrm.push(w.x, w.y, w.z);
      // Box projection in metres, by the dominant normal axis.
      const ax = Math.abs(w.x), ay = Math.abs(w.y), az = Math.abs(w.z);
      if (ax >= ay && ax >= az) this.uv.push(v.z, v.y);
      else if (ay >= az) this.uv.push(v.x, v.z);
      else this.uv.push(v.x, v.y);
    }
    // Mirrored matrices flip winding.
    const flip = m.determinant() < 0;
    const push = (a, b, c) => flip ? this.idx.push(base + a, base + c, base + b) : this.idx.push(base + a, base + b, base + c);
    if (geo.index) {
      const ix = geo.index;
      for (let i = 0; i < ix.count; i += 3) push(ix.getX(i), ix.getX(i + 1), ix.getX(i + 2));
    } else {
      for (let i = 0; i < p.count; i += 3) push(i, i + 1, i + 2);
    }
  }
  geometry() {
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(new Float32Array(this.pos), 3));
    g.setAttribute('normal', new THREE.BufferAttribute(new Float32Array(this.nrm), 3));
    g.setAttribute('uv', new THREE.BufferAttribute(new Float32Array(this.uv), 2));
    g.setIndex(new THREE.BufferAttribute(new Uint32Array(this.idx), 1));
    g.computeBoundingBox();
    g.computeBoundingSphere();
    return g;
  }
}

// Resample a polyline at an even spacing (by arc length).
function resample(pts, step, closed) {
  const loop = closed ? [...pts, pts[0]] : pts;
  const out = [];
  let carry = 0;
  for (let i = 0; i < loop.length - 1; i++) {
    const [ax, ay] = loop[i], [bx, by] = loop[i + 1];
    const len = Math.hypot(bx - ax, by - ay);
    let t = carry;
    while (t <= len) {
      out.push([ax + (bx - ax) * t / len, ay + (by - ay) * t / len]);
      t += step;
    }
    carry = t - len;
  }
  return out;
}

// ---- the rolled arm, as an (x, y) section for the right arm (+X side).
// Inner face straight up, a tight top with a small radius on the inner edge,
// a 5.5 cm roll over the outside tucking back in under itself, and an outer
// side that flares slightly out toward the roll.
function armSection() {
  const cx = HX - 0.006 - ROLL, cy = ARM_TOP - ROLL;
  const pts = [[ARM_IN, RAIL], [HX - 0.03, RAIL], [HX - 0.025, cy - 0.06]];
  pts.push(...arc(cx, cy, ROLL, -55, 90, 14));
  pts.push(...arc(ARM_IN + 0.015, ARM_TOP - 0.015, 0.015, 90, 180, 4));
  return pts;
}

// A closed anticlockwise polygon moved inward by d (mitred vertex offsets).
function offsetPoly(pts, d) {
  const n = pts.length;
  return pts.map((p, i) => {
    const a = pts[(i + n - 1) % n], b = pts[(i + 1) % n];
    const e1 = [p[0] - a[0], p[1] - a[1]], e2 = [b[0] - p[0], b[1] - p[1]];
    const l1 = Math.hypot(...e1) || 1, l2 = Math.hypot(...e2) || 1;
    const n1 = [-e1[1] / l1, e1[0] / l1], n2 = [-e2[1] / l2, e2[0] / l2];
    let nx = n1[0] + n2[0], ny = n1[1] + n2[1];
    const ln = Math.hypot(nx, ny) || 1;
    nx /= ln; ny /= ln;
    const k = d / Math.max(0.5, nx * n1[0] + ny * n1[1]);
    return [p[0] + nx * k, p[1] + ny * k];
  });
}

// A closed polygon with each corner eased by a quadratic curve starting
// r[i] along each edge from that corner.
function roundPoly(pts, r, steps) {
  const out = [];
  const n = pts.length;
  for (let i = 0; i < n; i++) {
    const p = pts[i], a = pts[(i + n - 1) % n], b = pts[(i + 1) % n];
    const la = Math.hypot(a[0] - p[0], a[1] - p[1]), lb = Math.hypot(b[0] - p[0], b[1] - p[1]);
    const p0 = [p[0] + (a[0] - p[0]) * r[i] / la, p[1] + (a[1] - p[1]) * r[i] / la];
    const p1 = [p[0] + (b[0] - p[0]) * r[i] / lb, p[1] + (b[1] - p[1]) * r[i] / lb];
    for (let k = 0; k <= steps; k++) {
      const t = k / steps, u = 1 - t;
      out.push([u * u * p0[0] + 2 * u * t * p[0] + t * t * p1[0], u * u * p0[1] + 2 * u * t * p[1] + t * t * p1[1]]);
    }
  }
  return out;
}

async function build() {
  const root = createRoot('Armchair');
  const leatherMat = pbrMaterial({ albedo: 0x6b3a22, roughness: 0.42, metalness: 0, name: 'Leather' });
  const walnutMat = pbrMaterial({ albedo: 0x3e2617, roughness: 0.5, metalness: 0, name: 'Walnut' });
  const brassMat = pbrMaterial({ albedo: 0xb08a3e, roughness: 0.3, metalness: 1, name: 'Brass' });
  const leather = new Bin(), wood = new Bin(), brass = new Bin();
  const I = mat4();

  const a = RAKE * Math.PI / 180;
  const up = [Math.cos(a), -Math.sin(a)];      // raked local +Y, as (y, z)
  const fwd = [Math.sin(a), Math.cos(a)];      // raked local +Z, as (y, z)

  // ---- legs: short turned walnut legs in brass cups.
  const legProfile = [[0, 0.012], [0.016, 0.012], [0.017, 0.03], [0.02, 0.055], [0.022, 0.066],
    [0.026, 0.069], [0.026, 0.076], [0.022, 0.079], [0.024, LEG], [0, LEG]];
  const legGeo = await revolveProfile(legProfile, { segments: 20 });
  const cupGeo = await revolveProfile([[0, 0], [0.017, 0], [0.019, 0.004], [0.0185, 0.013], [0, 0.013]], { segments: 20 });
  for (const sx of [-1, 1]) for (const sz of [-1, 1]) {
    const p = [sx * 0.355, 0, sz * 0.375];
    wood.add(legGeo, mat4(p));
    brass.add(cupGeo, mat4(p));
  }

  // ---- walnut base rail: a plinth with a small chamfered lip at the top.
  const plinthH = RAIL - LEG;
  wood.add(await roundedBoxGeo(0.83, plinthH - 0.008, 0.88, 0.006, { style: 'chamfer', segments: 2 }),
    mat4([0, LEG + (plinthH - 0.008) / 2, 0]));
  wood.add(await roundedBoxGeo(0.845, 0.01, 0.895, 0.004, { style: 'round', segments: 3 }),
    mat4([0, RAIL - 0.005, 0]));

  // ---- seat deck under the cushion, between the arms.
  const deckZ0 = backFrontZ(DECK) + 0.01, deckZ1 = 0.435;
  leather.add(await roundedBoxGeo(2 * ARM_IN + 0.01, DECK - RAIL, deckZ1 - deckZ0, 0.015),
    mat4([0, (DECK + RAIL) / 2, (deckZ0 + deckZ1) / 2]));
  // Front welt along the deck's top edge.
  leather.add(pipeAlongPath([[-ARM_IN, DECK - 0.006, deckZ1 - 0.004], [ARM_IN, DECK - 0.006, deckZ1 - 0.004]], 0.005,
    { tubularSegments: 2, radialSegments: 8 }), I);

  // ---- seat cushion: one firm cushion, crisp front, piped top and bottom edges.
  const cz0 = backFrontZ(SEAT) + 0.026, cz1 = 0.445, cw = 2 * ARM_IN - 0.006, ch = SEAT - DECK, cr = 0.018;
  leather.add(await roundedBoxGeo(cw, ch, cz1 - cz0, cr), mat4([0, (SEAT + DECK) / 2, (cz0 + cz1) / 2]));
  const e = cr * (1 - Math.SQRT1_2);
  for (const y of [SEAT - e, DECK + e]) {
    // Front edge, wrapping a little way round each front corner.
    const rc = cr - e;  // the corner radius seen from above, at the welt
    const corner = (sx) => arc(sx * (cw / 2 - cr), cz1 - cr, rc, sx > 0 ? 0 : 180, 90, 5).map(([x, z]) => [x, y, z]);
    const path = [[-(cw / 2 - e), y, cz1 - 0.06], ...corner(-1), ...corner(1).reverse(), [cw / 2 - e, y, cz1 - 0.06]];
    leather.add(pipeAlongPath(path, 0.0045, { tubularSegments: 64, radialSegments: 8 }), I);
  }

  // ---- arms.
  const section = armSection();
  const armGeo = await extrudeProfile(section, { depth: ARM_FRONT - ARM_BACK, axis: 'z', center: false, bevel: 0.006, segments: 3 });
  const facing = offsetPoly(section, 0.01);
  const facingGeo = await extrudeProfile(facing, { depth: 0.012, axis: 'z', center: false, bevel: 0.004, segments: 3 });
  // Welt round the front edge of the arm, framing the facing panel.
  const weltPts = resample(section, 0.01, true).map(([x, y]) => [x, y, ARM_FRONT]);
  const weltGeo = pipeAlongPath(weltPts, 0.004, { closed: true, tubularSegments: 200, radialSegments: 6 });
  const rearWeltGeo = pipeAlongPath(resample(section, 0.01, true).map(([x, y]) => [x, y, ARM_BACK + 0.002]), 0.004, { closed: true, tubularSegments: 200, radialSegments: 6 });
  // Nailheads: a row of small brass domes round the facing, inside the welt.
  const nailGeo = await revolveProfile([[0, 0], [0.0062, 0], ...arc(0, 0, 0.0062, 0, 90, 3).slice(1)], { segments: 8 });
  const nails = resample(offsetPoly(section, 0.02), 0.024, true).filter(([, y]) => y > RAIL + 0.03);
  for (const sx of [1, -1]) {
    const mirror = sx > 0 ? mat4() : mat4([0, 0, 0], [0, 0, 0], [-1, 1, 1]);
    leather.add(armGeo, mirror.clone().multiply(mat4([0, 0, ARM_BACK])));
    leather.add(facingGeo, mirror.clone().multiply(mat4([0, 0, ARM_FRONT])));
    leather.add(weltGeo, mirror);
    leather.add(rearWeltGeo, mirror);
    for (const [x, y] of nails) {
      brass.add(nailGeo, mat4([sx * x, y, ARM_FRONT + 0.012], [90, 0, 0], [1, 0.7, 1]));
    }
  }

  // ---- back: an outer shell extruded across the chair from its side
  // section (thick at the base, a raked front, a tight flat-topped roll),
  // narrow enough to hide inside the arms below the rolls, with a welt round
  // each side. A tufted inner panel stands on its front between the arms.
  const backTopY = BACK_TOP - 0.005, backRearLow = [-HZ + 0.012, RAIL], backRearTop = [-HZ + 0.006, backTopY];
  const backSide = roundPoly([backRearLow, BACK_FRONT_LOW, BACK_FRONT_TOP, backRearTop], [0.004, 0.004, 0.018, 0.018], 4);
  const backHalf = 0.39, backCorner = 0.1;
  // Seen from the front: square shoulders eased by a 10 cm radius.
  const backFace = roundPoly([[-backHalf, RAIL - 0.01], [backHalf, RAIL - 0.01], [backHalf, backTopY], [-backHalf, backTopY]],
    [0.001, 0.001, backCorner, backCorner], 10);
  const sideSolid = createPart('BackSide', await extrudeProfile(backSide.map(([z, y]) => [-z, y]), { depth: 2 * backHalf, axis: 'x', center: true }), leatherMat);
  const faceSolid = createPart('BackFace', await extrudeProfile(backFace, { depth: 0.6, axis: 'z', center: true }), leatherMat, { position: [0, 0, -0.2] });
  const shell = await boolIntersect('BackShell', sideSolid, faceSolid);
  leather.add(shell.geometry, I);
  // Welts round the shoulders of the back, front and rear, on the edge where
  // the sides and top meet the front and rear faces.
  const rearZ = (y) => backRearLow[0] + (y - RAIL) * (backRearTop[0] - backRearLow[0]) / (backTopY - RAIL);
  const shoulder = resample(roundPoly([[-backHalf, ARM_TOP - 0.03], [-backHalf, backTopY], [backHalf, backTopY], [backHalf, ARM_TOP - 0.03]],
    [0.001, backCorner, backCorner, 0.001], 10).slice(2, -2), 0.01, false);
  leather.add(pipeAlongPath(shoulder.map(([x, y]) => [x, Math.min(y, backTopY - 0.002), backFrontZ(Math.min(y, backTopY - 0.012)) - 0.002]), 0.0045, { tubularSegments: 300, radialSegments: 6 }), I);
  leather.add(pipeAlongPath(shoulder.map(([x, y]) => [x, Math.min(y, backTopY - 0.002), rearZ(y) + 0.002]), 0.0045, { tubularSegments: 300, radialSegments: 6 }), I);

  // Inner back panel: from just under the seat top to below the shell top,
  // standing proud of the shell's front face.
  const panelW = 2 * ARM_IN - 0.006, panelT = 0.05;
  const panelBottom = SEAT - 0.03, panelTop = BACK_TOP - 0.075;
  const panelH = (panelTop - panelBottom) / up[0];
  const pmY = (panelTop + panelBottom) / 2;
  const off = panelT / 2 - 0.012;
  const panelM = mat4([0, pmY + off * fwd[0], backFrontZ(pmY) + off * fwd[1]], [-RAKE, 0, 0]);
  leather.add(await roundedBoxGeo(panelW, panelH, panelT, 0.016), panelM);

  // Diamond tufting on the panel's front face: buttons, with shallow pleat
  // lines joining each to its diagonal neighbours.
  const faceZ = panelT / 2;
  const rows = [-0.15, -0.045, 0.06, 0.165];
  const colsEven = [-0.2, -0.067, 0.067, 0.2];
  const colsOdd = [-0.133, 0, 0.133];
  const btn = rows.map((y, r) => (r % 2 === 0 ? colsEven : colsOdd).map((x) => [x, y]));
  const buttonGeo = sphereGeo(0.011, 10, 6);
  for (const row of btn) for (const [x, y] of row) {
    leather.add(buttonGeo, panelM.clone().multiply(mat4([x, y, faceZ], [0, 0, 0], [1, 1, 0.6])));
  }
  // A thin rod between two points in the panel's space, sunk to half depth.
  const rodGeo = cylinderGeo(0.0038, 0.0038, 1, 6);
  const pleat = (x0, y0, x1, y1, z) => {
    const len = Math.hypot(x1 - x0, y1 - y0);
    const ang = Math.atan2(y1 - y0, x1 - x0) * 180 / Math.PI - 90;
    leather.add(rodGeo, panelM.clone().multiply(mat4([(x0 + x1) / 2, (y0 + y1) / 2, z], [0, 0, ang], [1, len, 1])));
  };
  for (let r = 0; r < btn.length - 1; r++) {
    for (const [x0, y0] of btn[r]) for (const [x1, y1] of btn[r + 1]) {
      if (Math.abs(x1 - x0) > 0.07) continue;
      pleat(x0, y0, x1, y1, faceZ);
    }
  }
  // Pleats running from the top and bottom rows out to the panel edges.
  for (const [x, y] of btn[0]) pleat(x, y, x, -panelH / 2 + 0.012, faceZ - 0.001);
  for (const [x, y] of btn[btn.length - 1]) pleat(x, y, x, panelH / 2 - 0.012, faceZ - 0.001);

  // ---- nailheads along the base of the front, just above the walnut rail.
  for (const [x] of resample([[-ARM_IN + 0.012, 0], [ARM_IN - 0.012, 0]], 0.024, false)) {
    brass.add(nailGeo, mat4([x, RAIL + 0.018, deckZ1], [90, 0, 0], [1, 0.7, 1]));
  }

  for (const [name, bin, material] of [['Leather', leather, leatherMat], ['Wood', wood, walnutMat], ['Brass', brass, brassMat]]) {
    const part = createPart(name, bin.geometry(), material, { parent: root });
    part.name = name;
  }
  return root;
}
