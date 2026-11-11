const meta = { name: 'Floor lamp' };
// Crack & Stack: the reading corner's brass floor lamp (room plan phase 2):
// a stepped round base, a turned stem with knops, and a finial over the
// shade. Heights match ReadingCorner (LAMP_BASE 0.32, SHADE_BOTTOM 1.43,
// LAMP_HEIGHT 1.73); the cloth shade and the light stay in GDScript.
const STEM_TOP = 1.51;

async function build() {
  const root = createRoot('FloorLamp');
  const brass = pbrMaterial({ albedo: 0xb08a3e, roughness: 0.35, metalness: 1, name: 'Brass' });
  createPart('Base', await revolveProfile([[0, 0], [0.16, 0], [0.16, 0.012], [0.148, 0.02], [0.12, 0.026], [0.1, 0.04], [0.06, 0.05],
    [0.04, 0.07], [0.022, 0.08], [0, 0.08]], { segments: 48, bevel: 0.003 }), brass, { parent: root });
  // Turned stem: thin shaft with knops at a third and two thirds.
  const p = [[0, 0.08], [0.016, 0.08]];
  const shaft = 0.012;
  for (const [y, r] of [[0.5, 0.03], [0.95, 0.024]]) {
    p.push([shaft, y - 0.05], [r * 0.7, y - 0.025], [r, y], [r * 0.7, y + 0.025], [shaft, y + 0.05]);
  }
  p.push([shaft, STEM_TOP - 0.06], [0.02, STEM_TOP - 0.04], [0.02, STEM_TOP], [0, STEM_TOP]);
  createPart('Stem', await revolveProfile(p, { segments: 24 }), brass, { parent: root });
  // Finial on the harp over the shade.
  createPart('Finial', await revolveProfile([[0, 0], [0.008, 0], [0.008, 0.06], [0.018, 0.075], [0.014, 0.09], [0, 0.1]], { segments: 24 }), brass,
    { position: [0, 1.73 - 0.02, 0], parent: root });
  return root;
}
