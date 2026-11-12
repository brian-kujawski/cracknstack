const meta = { name: 'Library pendant' };
// Crack & Stack: the brass library pendant with a green cased-glass shade
// over each table (room plan phase 2, style bible 4.5). The origin is the
// centre of the shade's rim. Godot places the Canopy at the ceiling and
// stretches the Rod (1 m tall here, from y = 0 up) to reach it, and swaps in
// its own brass, glass and opal materials by part name, so the materials
// here are stand-ins for the review render.
const SHADE_R = 0.2;        // shade rim radius
const SHADE_H = 0.14;       // rim to the top of the bell
const COLLAR_Y = SHADE_H + 0.012;

async function build() {
  const root = createRoot('LibraryPendant');
  const brass = pbrMaterial({ albedo: 0xb08a3e, roughness: 0.35, metalness: 1, name: 'Brass' });
  const glass = pbrMaterial({ albedo: 0x1f5a2e, roughness: 0.15, metalness: 0, name: 'GreenGlass' });
  const opal = pbrMaterial({ albedo: 0xf2ead8, roughness: 0.6, metalness: 0, emissive: 0xffd199, emissiveIntensity: 1.0, name: 'Opal' });
  // Ceiling canopy: its flat top at y = 0, hanging down 4 cm.
  createPart('Canopy', await revolveProfile([[0, -0.04], [0.03, -0.04], [0.05, -0.022], [0.07, -0.012], [0.07, 0], [0, 0]], { segments: 32, bevel: 0.003 }), brass,
    { parent: root });
  // The rod, 1 m from y = 0 up; Godot scales it to the drop.
  createPart('Rod', cylinderGeo(0.006, 0.006, 1, 12), brass, { position: [0, 0.5, 0], parent: root });
  // Fitter: a turned collar and a small ball where rod meets shade.
  createPart('Collar', await revolveProfile([[0, 0], [0.04, 0], [0.044, 0.01], [0.032, 0.03], [0.014, 0.045], [0.014, 0.06], [0, 0.06]], { segments: 32, bevel: 0.003 }), brass,
    { position: [0, COLLAR_Y - 0.01, 0], parent: root });
  createPart('Knop', sphereGeo(0.016, 16, 12), brass, { position: [0, COLLAR_Y + 0.062, 0], parent: root });
  // Bell-shaped shade: green cased glass outside, opal white inside.
  const outer = [[0.035, SHADE_H + 0.02], [0.065, SHADE_H], [0.14, SHADE_H * 0.55], [SHADE_R, 0.014], [SHADE_R + 0.008, 0],
                 [SHADE_R - 0.004, 0], [SHADE_R - 0.01, 0.012], [0.135, SHADE_H * 0.55 - 0.005], [0.06, SHADE_H - 0.006], [0.03, SHADE_H + 0.014]];
  createPart('Shade', await revolveProfile(outer, { segments: 64 }), glass, { parent: root });
  const lining = [[0.03, SHADE_H + 0.012], [0.059, SHADE_H - 0.008], [0.134, SHADE_H * 0.55 - 0.007], [SHADE_R - 0.011, 0.011], [SHADE_R - 0.013, 0.009],
                  [0.132, SHADE_H * 0.55 - 0.009], [0.057, SHADE_H - 0.01], [0.028, SHADE_H + 0.01]];
  createPart('Lining', await revolveProfile(lining, { segments: 64 }), opal, { parent: root });
  // Brass band round the rim.
  createPart('Rim', torusGeo(SHADE_R + 0.004, 0.0045, 8, 64), brass, { position: [0, 0.002, 0], rotation: [90, 0, 0], parent: root });
  return root;
}
