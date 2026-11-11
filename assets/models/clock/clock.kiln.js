const meta = { name: 'Longcase clock parts' };
// Crack & Stack: the turned and shaped parts of the longcase clock
// (ShopClock), so it matches the library furniture: brass urn finials,
// turned hood columns, bun feet and the arched crest over the hood.
// Each part sits at the origin, its bottom at y = 0 (the crest's back at
// z = 0, its face toward +Z); ShopClock places the copies it needs. The
// materials here are stand-ins: Godot gives them the walnut and brass.

function arc(cx, cy, r, a0, a1, steps) {
  const out = [];
  for (let i = 0; i <= steps; i++) {
    const a = (a0 + (a1 - a0) * i / steps) * Math.PI / 180;
    out.push([cx + r * Math.cos(a), cy + r * Math.sin(a)]);
  }
  return out;
}

async function build() {
  const root = createRoot('Clock');
  const walnut = pbrMaterial({ albedo: 0x5a3a26, roughness: 0.55, metalness: 0, name: 'Walnut' });
  const brass = pbrMaterial({ albedo: 0xb08a3e, roughness: 0.35, metalness: 1, name: 'Brass' });

  // Finial: a small square-ish foot, an urn, a neck and a flame-like spire, 11 cm.
  const finial = [[0, 0], [0.018, 0], [0.018, 0.008], [0.012, 0.012], [0.01, 0.018],
    ...arc(0, 0.04, 0.022, -70, 70, 8).map(([x, y]) => [Math.max(x, 0.004), y]),
    [0.006, 0.062], [0.011, 0.068], [0.006, 0.074], [0.009, 0.085], [0.004, 0.1], [0, 0.11]];
  const f = createPart('Finial', await revolveProfile(finial, { segments: 24 }), brass, { parent: root });
  f.name = 'Finial';

  // Hood column: base, plain shaft with entasis, a ring and a small capital, 54 cm.
  const H = 0.54;
  const column = [[0, 0], [0.024, 0], [0.024, 0.012], [0.02, 0.016], [0.022, 0.022], [0.016, 0.03],
    [0.015, H * 0.5], [0.013, H - 0.04], [0.017, H - 0.034], [0.013, H - 0.028],
    [0.016, H - 0.02], [0.024, H - 0.01], [0.024, H], [0, H]];
  const c = createPart('HoodColumn', await revolveProfile(column, { segments: 24 }), walnut, { parent: root });
  c.name = 'HoodColumn';

  // Bun foot: a squashed ball on a thin collar, 5 cm tall.
  const bun = [[0, 0], [0.026, 0], ...arc(0, 0.024, 0.044, -35, 50, 10), [0.03, 0.044], [0.03, 0.05], [0, 0.05]];
  const b = createPart('BunFoot', await revolveProfile(bun, { segments: 32 }), walnut, { parent: root });
  b.name = 'BunFoot';

  // Crest: a board across the hood's front, 50 cm wide, low at the ends
  // with a stepped shoulder and a round arch in the middle, 2.5 cm deep.
  const crest = [[-0.25, 0], [0.25, 0], [0.25, 0.03], [0.16, 0.03], [0.16, 0.045], [0.1, 0.045],
    ...arc(0, 0.045, 0.1, 0, 180, 18).slice(1, -1), [-0.1, 0.045], [-0.16, 0.045], [-0.16, 0.03], [-0.25, 0.03]];
  const k = createPart('Crest', await extrudeProfile(crest, { depth: 0.025, axis: 'z', center: false }), walnut, { parent: root });
  k.name = 'Crest';
  return root;
}
