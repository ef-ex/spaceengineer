// Shared isometric "viewport" renderer for the UI style prototypes.
// Draws ONE ship (same geometry in all three skins) so the prototypes differ
// only in visual style, not content. drawShip(svgEl, PALETTE) — palette per file.

const SCENE = (() => {
  // Forward is +X (matches designer.gd). Nose tapers at the high-X end.
  const hull = [];
  for (let x = 0; x < 10; x++) {
    const inset = x >= 8 ? x - 7 : 0;
    for (let y = inset; y < 6 - inset; y++) hull.push([x, y]);
  }
  const rooms = [
    { x: 0, y: 1, w: 3, d: 4, key: "quarters", label: "Quarters" },
    { x: 3, y: 1, w: 4, d: 4, key: "cargo",    label: "Cargo bay" },
    { x: 7, y: 2, w: 2, d: 2, key: "bridge",   label: "Bridge" },
  ];
  const equip = [
    { x: 4, y: 2, w: 2, d: 2, h: 1.0, key: "reactor", label: "Reactor" },
    { x: 1, y: 2, w: 1, d: 1, h: 0.6, key: "tank" },
    { x: 1, y: 3, w: 1, d: 1, h: 0.6, key: "tank" },
    { x: 5, y: 1, w: 1, d: 1, h: 0.5, key: "vent" },
    { x: 7, y: 3, w: 1, d: 1, h: 0.55, key: "console" },
  ];
  return { hull, rooms, equip };
})();

function drawShip(svg, P) {
  const TW = 46, TH = 23, ZS = 30;            // 2:1 isometric, z lift
  const pts = [], parts = [], labels = [];
  const pr = (x, y, z) => {                    // project world -> screen
    const sx = (x - y) * TW, sy = (x + y) * TH - z * ZS;
    pts.push([sx, sy]);
    return [sx, sy];
  };
  const poly = (cs, fill, stroke, sw) => {
    const d = cs.map((c) => pr(c[0], c[1], c[2]).join(",")).join(" ");
    parts.push(
      `<polygon points="${d}" fill="${fill}" ${stroke ? `stroke="${stroke}" stroke-width="${sw || 1}"` : ""} stroke-linejoin="round"/>`
    );
  };

  // deck plating (one diamond per hull cell — gives the grid)
  SCENE.hull.forEach(([x, y]) =>
    poly([[x, y, 0], [x + 1, y, 0], [x + 1, y + 1, 0], [x, y + 1, 0]], P.hullFill, P.hullStroke, 1)
  );
  // rooms (flat tinted regions on the deck)
  SCENE.rooms.forEach((r) => {
    const c = P.rooms[r.key] || P.rooms._;
    poly([[r.x, r.y, 0.02], [r.x + r.w, r.y, 0.02], [r.x + r.w, r.y + r.d, 0.02], [r.x, r.y + r.d, 0.02]],
      c.fill, c.stroke, c.sw || 1.5);
    if (r.label) labels.push({ p: pr(r.x + r.w / 2, r.y + r.d / 2, 0.04), t: r.label, cls: "rlbl" });
  });
  // forward arrow on the ground at the nose
  poly([[10.15, 2.45, 0.03], [10.15, 3.55, 0.03], [11.5, 3, 0.03]], P.arrow, P.arrowStroke, P.arrowSw || 0);
  labels.push({ p: pr(11.95, 3, 0.03), t: "FORWARD", cls: "fwd" });
  // equipment (extruded boxes: east + south faces + top), painter-sorted
  [...SCENE.equip].sort((a, b) => (a.x + a.y) - (b.x + b.y)).forEach((e) => {
    const col = P.equip[e.key] || P.equip._;
    const { x, y, w, d, h } = e;
    poly([[x + w, y, 0], [x + w, y + d, 0], [x + w, y + d, h], [x + w, y, h]], col.right, col.edge, 0.8);
    poly([[x, y + d, 0], [x + w, y + d, 0], [x + w, y + d, h], [x, y + d, h]], col.left, col.edge, 0.8);
    poly([[x, y, h], [x + w, y, h], [x + w, y + d, h], [x, y + d, h]], col.top, col.edge, 0.8);
    if (e.label) labels.push({ p: pr(x + w / 2, y + d / 2, h), t: e.label, cls: "elbl" });
  });

  // fit the viewBox to the content
  const xs = pts.map((p) => p[0]), ys = pts.map((p) => p[1]);
  const minX = Math.min(...xs), maxX = Math.max(...xs), minY = Math.min(...ys), maxY = Math.max(...ys), pad = 64;
  svg.setAttribute("viewBox", `${(minX - pad).toFixed(1)} ${(minY - pad).toFixed(1)} ${(maxX - minX + 2 * pad).toFixed(1)} ${(maxY - minY + 2 * pad).toFixed(1)}`);
  svg.setAttribute("preserveAspectRatio", "xMidYMid meet");

  const lbl = labels.map((l) => {
    const fs = l.cls === "fwd" ? 13 : l.cls === "rlbl" ? 15 : 12.5;
    const fill = l.cls === "fwd" ? P.fwdText : l.cls === "rlbl" ? P.roomLabel : P.equipLabel;
    const ls = l.cls === "fwd" ? "4" : "0";
    return `<text x="${l.p[0].toFixed(1)}" y="${l.p[1].toFixed(1)}" text-anchor="middle" font-size="${fs}" letter-spacing="${ls}" fill="${fill}" font-family="${P.labelFont || "inherit"}" font-weight="500" paint-order="stroke" stroke="${P.labelHalo || "none"}" stroke-width="${P.labelHalo ? 3 : 0}" stroke-linejoin="round">${l.t}</text>`;
  }).join("");

  svg.innerHTML = parts.join("") + lbl;
}
