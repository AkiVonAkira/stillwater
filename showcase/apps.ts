// App window mockups for the README showcase. Every color comes from palette.json.
// Text is drawn as skeleton bars, so the image carries no names, paths, or messages.

export type Palette = {
  canvas: string;
  canvasRaised: string;
  canvasOverlay: string;
  border: string;
  text: string;
  textMuted: string;
  textFaint: string;
  warm: string;
  accent: string;
  accentHover: string;
  accentDeep: string;
  onAccent: string;
  error: string;
  warning: string;
  selection: string;
  syntax: { [key: string]: string };
};

function sk(w: number, c: string, h = 9, o = 1): string {
  return `<i class="sk" style="width:${w}px;height:${h}px;background:${c};opacity:${o}"></i>`;
}
function row(inner: string, style = ""): string {
  return `<div class="row" style="${style}">${inner}</div>`;
}
// Seeded so every run draws the same bar widths.
function rnd(seed: number): () => number {
  let s = seed;
  return () => (s = (s * 9301 + 49297) % 233280) / 233280;
}
function mix(a: string, pct: number, b = "transparent"): string {
  return `color-mix(in srgb, ${a} ${pct}%, ${b})`;
}

function titlebar(P: Palette, label: string): string {
  return `<div class="tb" style="background:${P.canvasOverlay};border-bottom:1px solid ${P.border}">
    <span class="dots"><b style="background:${P.error}"></b><b style="background:${P.warning}"></b><b style="background:${P.syntax.function}"></b></span>
    <span class="lbl" style="color:${P.textMuted}">${label}</span></div>`;
}

export function vscode(P: Palette): string {
  const S = P.syntax;
  const r = rnd(7);
  const syn = [S.keyword, S.function, S.string, S.support, S.constant, S.parameter, S.variable];
  const indent = [0, 1, 1, 2, 2, 2, 1, 1, 0, 0, 1, 2, 2, 1, 0, 0, 1, 1, 2, 3, 3, 2, 1, 0, 0, 1, 1, 0];
  let lines = "";
  indent.forEach((ind, i) => {
    let bars = "";
    if (i % 9 === 8) bars = sk(80 + r() * 160, S.comment, 9, 0.9);
    else {
      const n = 1 + Math.floor(r() * 4);
      for (let k = 0; k < n; k++) bars += sk(24 + r() * 70, syn[Math.floor(r() * syn.length)], 9, 0.9);
    }
    const active = i === 5;
    lines += `<div class="cl" style="${active ? `background:${P.canvasRaised}` : ""}"><span class="ln" style="color:${active ? P.accent : P.textFaint}">${i + 1}</span><span style="width:${ind * 22}px;flex:none"></span>${bars}</div>`;
  });
  let tree = "";
  [0, 1, 1, 2, 2, 1, 0, 1, 1, 1, 0, 0, 1, 1].forEach((d: number, i: number) => {
    tree += row(
      `<span style="width:${d * 12}px;flex:none"></span>${sk(8, i % 4 ? P.warm : P.accent, 8, 0.8)}${sk(50 + r() * 70, i === 4 ? P.text : P.textMuted, 8)}`,
      `padding:5px 12px;${i === 4 ? `background:${P.selection}` : ""}`,
    );
  });
  const icons = [0, 1, 2, 3, 4]
    .map((i) => `<span class="ico" style="border-color:${i === 0 ? P.text : P.textFaint}">${i === 2 ? `<em style="background:${P.accent}"></em>` : ""}</span>`)
    .join("");
  return `<div class="win" style="background:${P.canvas};border-color:${P.border}">
   ${titlebar(P, "Visual Studio Code")}
   <div class="flex1" style="display:flex">
    <div style="width:48px;border-right:1px solid ${P.border};padding-top:12px;display:flex;flex-direction:column;align-items:center;gap:18px">${icons}</div>
    <div style="width:220px;border-right:1px solid ${P.border};padding-top:8px">${row(sk(70, P.textMuted, 7), "padding:6px 12px 10px")}${tree}</div>
    <div class="flex1" style="display:flex;flex-direction:column">
      <div style="display:flex;border-bottom:1px solid ${P.border}">
        <div class="tab" style="background:${P.border};box-shadow:inset 0 2px ${P.text}">${sk(8, S.support, 8)}${sk(70, P.text, 8)}</div>
        <div class="tab">${sk(8, S.string, 8)}${sk(56, P.textMuted, 8)}</div>
        <div class="tab">${sk(8, P.warm, 8)}${sk(64, P.textMuted, 8)}</div>
      </div>
      <div class="flex1" style="padding:10px 0;overflow:hidden">${lines}</div>
    </div>
   </div>
   <div style="height:26px;flex:none;border-top:1px solid ${P.border};display:flex;align-items:center;gap:14px;padding-right:10px">
     <span style="background:${P.accent};width:30px;height:26px"></span>${sk(60, P.text, 7)}${sk(30, P.warning, 7)}<span class="flex1"></span>${sk(50, P.textMuted, 7)}${sk(40, P.textMuted, 7)}
   </div></div>`;
}

export function ghostty(P: Palette): string {
  const S = P.syntax;
  const r = rnd(3);
  // Same 16 colors as ghostty/Stillwater.
  const ansi = [P.canvas, P.error, S.function, P.warning, S.support, S.constant, P.accent, P.text, P.border, P.error, S.function, S.string, S.support, S.constant, P.accentHover, S.variable];
  let info = row(sk(70, P.accent, 9) + sk(10, P.textMuted, 9) + sk(80, P.accent, 9));
  info += row(sk(170, P.textFaint, 3), "margin:4px 0 8px");
  for (let i = 0; i < 8; i++) info += row(sk(40 + r() * 30, P.accent, 9) + sk(80 + r() * 90, P.text, 9, 0.85), "margin-bottom:7px");
  const swatch = (cols: string[]) => `<div style="display:flex">${cols.map((c) => `<span style="width:24px;height:16px;background:${c}"></span>`).join("")}</div>`;
  const prompt = (cmd: string) => `<div class="row" style="margin:12px 0 10px;gap:0">
      <span class="pill" style="background:${P.accent};z-index:3">${sk(40, P.onAccent, 8)}</span>
      <span class="pill" style="background:${P.selection};margin-left:-12px;padding-left:22px;z-index:2">${sk(56, P.text, 8)}</span>
      <span class="pill" style="background:${P.canvasRaised};margin-left:-12px;padding-left:22px;margin-right:12px">${sk(22, P.warm, 8)}</span>${cmd}</div>`;
  const logo = Array.from({ length: 49 }, (_, i) => {
    const x = i % 7;
    const y = Math.floor(i / 7);
    const on = Math.abs(x - 3) + Math.abs(y - 3) <= 3;
    const c = y < 3 ? P.accent : y === 3 ? P.accentHover : P.accentDeep;
    return `<span style="width:14px;height:14px;border-radius:3px;background:${on ? c : "transparent"}"></span>`;
  }).join("");
  return `<div class="win" style="background:${P.canvas};border-color:${P.border}">
   ${titlebar(P, "Ghostty")}
   <div class="flex1" style="padding:8px 18px">
    ${prompt(sk(70, S.function, 9))}
    <div style="display:flex;gap:24px;margin:6px 0 4px">
      <div style="display:grid;grid-template-columns:repeat(7,14px);gap:4px;align-content:start;padding-top:6px">${logo}</div>
      <div>${info}<div style="margin-top:10px">${swatch(ansi.slice(0, 8))}${swatch(ansi.slice(8))}</div></div>
    </div>
    ${prompt(`<i class="cur" style="background:${P.accent}"></i>`)}
   </div></div>`;
}

export function discord(P: Palette): string {
  const S = P.syntax;
  const r = rnd(11);
  const roles = [P.accent, P.warm, S.constant, S.function, P.warning];
  let rail = "";
  for (let i = 0; i < 7; i++) {
    const bg = i === 0 ? P.accent : i === 1 ? P.accentDeep : P.canvasRaised;
    rail += `<span style="width:40px;height:40px;flex:none;border-radius:${i === 1 ? 12 : 20}px;background:${bg}"></span>`;
  }
  let ch = row(sk(110, P.text, 10), `padding:15px 14px;border-bottom:1px solid ${P.border};margin-bottom:8px`);
  for (let i = 0; i < 11; i++) {
    if (i === 0 || i === 6) {
      ch += row(sk(70, P.textFaint, 7), "padding:12px 14px 6px");
      continue;
    }
    const act = i === 2;
    ch += row(
      sk(10, P.textFaint, 10) + sk(60 + r() * 60, act || i === 4 ? P.text : P.textMuted, 9),
      `padding:6px 10px;margin:1px 8px;border-radius:6px;${act ? `background:${mix(P.selection, 55)}` : ""}`,
    );
  }
  let msgs = "";
  for (let i = 0; i < 5; i++) {
    let body = "";
    const n = 1 + Math.floor(r() * 3);
    for (let k = 0; k < n; k++) body += row(sk(120 + r() * 260, P.text, 9, 0.75), "margin-top:8px");
    const mention = i === 3;
    const bg = mention ? `background:linear-gradient(to right, ${mix(P.accent, 12)} 40%, transparent);box-shadow:inset 2px 0 ${P.accent}` : "";
    msgs += `<div style="display:flex;gap:12px;padding:10px 16px;${bg}">
      <span style="width:38px;height:38px;border-radius:50%;flex:none;background:${roles[i % 5]};opacity:.85"></span>
      <div>${row(sk(60 + r() * 40, roles[i % 5], 10) + sk(44, P.textFaint, 7))}${body}</div></div>`;
  }
  return `<div class="win" style="background:${P.canvas};border-color:${P.border}">
   ${titlebar(P, "Discord")}
   <div class="flex1" style="display:flex">
    <div style="width:64px;background:${P.canvasOverlay};display:flex;flex-direction:column;align-items:center;gap:8px;padding-top:12px">${rail}</div>
    <div style="width:210px;background:${P.canvasOverlay};border-right:1px solid ${P.border}">${ch}</div>
    <div class="flex1" style="display:flex;flex-direction:column">
      ${row(sk(12, P.textFaint, 12) + sk(90, P.text, 10), `padding:14px 16px;border-bottom:1px solid ${P.border}`)}
      <div class="flex1" style="padding-top:6px;overflow:hidden">${msgs}</div>
      <div style="margin:0 16px 16px;height:42px;flex:none;border-radius:10px;background:${P.canvasRaised};display:flex;align-items:center;gap:12px;padding:0 14px">${sk(20, P.textMuted, 20)}${sk(160, P.textFaint, 9)}</div>
    </div>
   </div></div>`;
}

export function spotify(P: Palette): string {
  const S = P.syntax;
  const r = rnd(5);
  const arts = [
    [P.accent, P.accentDeep], [P.warm, P.border], [S.constant, P.selection], [P.warning, P.warm],
    [P.accentHover, P.selection], [S.keyword, P.border], [S.function, P.accentDeep], [P.selection, P.canvasOverlay],
  ];
  const art = (i: number, sz: number, rad = 6) => `<span style="width:${sz}px;height:${sz}px;flex:none;border-radius:${rad}px;background:linear-gradient(135deg, ${arts[i % 8][0]}, ${arts[i % 8][1]})"></span>`;
  let lib = "";
  for (let i = 0; i < 7; i++) {
    lib += row(
      art(i + 2, 40, i === 1 ? 20 : 4) + `<div>${row(sk(70 + r() * 50, i === 0 ? P.accent : P.text, 8))}${row(sk(50 + r() * 30, P.textMuted, 7), "margin-top:6px")}</div>`,
      `padding:6px 10px;gap:10px;border-radius:6px;${i === 0 ? `background:${P.canvasRaised}` : ""}`,
    );
  }
  let cards = "";
  for (let i = 0; i < 5; i++) {
    cards += `<div style="background:${P.canvasRaised};border-radius:8px;padding:10px;flex:none">${art(i, 108)}${row(sk(80, P.text, 8), "margin-top:10px")}${row(sk(60, P.textMuted, 7), "margin-top:6px")}</div>`;
  }
  let tracks = "";
  for (let i = 0; i < 3; i++) {
    const on = i === 0;
    tracks += row(
      sk(10, on ? P.accent : P.textFaint, 8) + art(i + 4, 30, 3) + sk(140 + r() * 80, on ? P.accent : P.text, 8) + `<span class="flex1"></span>` + sk(30, P.textMuted, 7),
      "padding:6px 10px;gap:12px",
    );
  }
  const bar = (w: string, pct: number, fill: string) => `<div style="width:${w};height:4px;border-radius:2px;background:${P.border}"><div style="width:${pct}%;height:4px;border-radius:2px;background:${fill}"></div></div>`;
  return `<div class="win" style="background:${P.canvasOverlay};border-color:${P.border}">
   ${titlebar(P, "Spotify")}
   <div class="flex1" style="display:flex;gap:8px;padding:8px;min-height:0">
    <div style="width:240px;flex:none;background:${P.canvas};border-radius:8px;padding:8px;overflow:hidden">${row(sk(80, P.text, 10), "padding:8px 10px 12px")}${lib}</div>
    <div class="flex1" style="background:linear-gradient(to bottom, ${mix(P.accentDeep, 45, P.canvas)}, ${P.canvas} 45%);border-radius:8px;padding:20px;overflow:hidden">
      <div style="display:flex;gap:18px;align-items:end">${art(0, 120, 6)}<div>${row(sk(50, P.text, 7))}${row(sk(220, P.text, 22), "margin:10px 0")}${row(sk(120, P.textMuted, 8))}</div></div>
      <div class="row" style="margin:18px 0 10px;gap:14px"><span style="width:40px;height:40px;border-radius:50%;background:${P.accent}"></span>${sk(20, P.textMuted, 20)}</div>
      ${tracks}
      ${row(sk(110, P.text, 11), "margin:14px 0 10px")}
      <div style="display:flex;gap:12px">${cards}</div>
    </div>
   </div>
   <div style="height:72px;flex:none;display:flex;align-items:center;padding:0 16px;gap:12px">
     ${art(0, 48, 4)}<div style="width:180px">${row(sk(100, P.text, 8))}${row(sk(70, P.textMuted, 7), "margin-top:6px")}</div>
     <div class="flex1" style="display:flex;flex-direction:column;align-items:center;gap:10px">
       <div class="row" style="gap:16px">${sk(14, P.textMuted, 14)}${sk(14, P.text, 14)}<span style="width:32px;height:32px;border-radius:50%;background:${P.text}"></span>${sk(14, P.text, 14)}${sk(14, P.accent, 14)}</div>
       ${bar("70%", 38, P.accent)}
     </div>
     <div style="width:180px;display:flex;justify-content:end">${bar("90px", 60, P.text)}</div>
   </div></div>`;
}

export function t3code(P: Palette): string {
  const S = P.syntax;
  const r = rnd(9);
  let threads = "";
  for (let i = 0; i < 10; i++) {
    const on = i === 1;
    threads += row(sk(90 + r() * 70, on ? P.text : P.warm, 8, on ? 1 : 0.8), `padding:8px 12px;margin:1px 6px;border-radius:6px;${on ? `background:${mix(P.accent, 20, P.canvas)}` : ""}`);
  }
  const text = (w: number, n: number) => {
    let b = "";
    for (let i = 0; i < n; i++) b += row(sk(w - r() * 60, P.text, 8, 0.8), "margin:7px 0");
    return b;
  };
  return `<div class="win" style="background:${P.canvas};border-color:${P.border}">
   ${titlebar(P, "T3 Code")}
   <div class="flex1" style="display:flex">
    <div style="width:230px;background:${P.canvasOverlay};border-right:1px solid ${P.border};padding-top:8px">${row(sk(60, P.textMuted, 7), "padding:8px 18px")}${threads}</div>
    <div class="flex1" style="display:flex;flex-direction:column;padding:16px 28px">
      <div style="align-self:end;background:${P.canvasRaised};border:1px solid ${P.border};border-radius:12px;padding:6px 14px">${text(240, 2)}</div>
      <div style="margin-top:12px">${text(420, 3)}</div>
      <div style="background:${P.canvasOverlay};border:1px solid ${P.border};border-radius:8px;padding:12px 14px;margin:8px 0">${row(sk(60, S.keyword, 8) + sk(90, S.function, 8))}${row(sk(40, S.support, 8) + sk(120, S.string, 8), "margin-top:8px")}</div>
      ${text(380, 2)}
      <span class="flex1"></span>
      <div style="border:1px solid ${P.border};background:${P.canvasRaised};border-radius:14px;padding:14px;display:flex;align-items:end;gap:10px">
        <div class="flex1">${sk(200, P.warm, 8, 0.7)}<div class="row" style="margin-top:18px">${sk(70, P.textMuted, 16, 0.6)}${sk(50, P.textMuted, 16, 0.6)}</div></div>
        <span style="width:30px;height:30px;border-radius:50%;background:${P.accent}"></span>
      </div>
    </div>
   </div></div>`;
}

export const CSS = `
.stage{position:relative;overflow:hidden;font-family:"Segoe UI",Inter,system-ui,sans-serif}
.win{position:absolute;display:flex;flex-direction:column;border:1px solid;border-radius:12px;overflow:hidden;box-shadow:0 30px 60px -10px rgba(0,0,0,.55),0 0 0 1px rgba(0,0,0,.4)}
.tb{height:34px;flex:none;display:flex;align-items:center;padding:0 12px;gap:12px}
.dots{display:flex;gap:7px}.dots b{width:11px;height:11px;border-radius:50%;opacity:.9}
.lbl{font-size:12px;font-weight:600;letter-spacing:.02em}
.flex1{flex:1;min-width:0}
.sk{display:inline-block;flex:none;border-radius:999px}
.row{display:flex;align-items:center;gap:8px}
.cl{display:flex;align-items:center;gap:8px;height:22px;padding-right:12px}
.ln{width:44px;text-align:right;padding-right:12px;font:11px ui-monospace,Consolas,monospace;flex:none}
.ico{width:22px;height:22px;border:2px solid;border-radius:5px;position:relative;box-sizing:border-box}
.ico em{position:absolute;right:-7px;bottom:-7px;width:12px;height:12px;border-radius:50%}
.tab{display:flex;align-items:center;gap:8px;padding:0 16px;height:36px;box-sizing:border-box}
.pill{display:inline-flex;align-items:center;height:24px;padding:0 14px;border-radius:999px;position:relative}
.cur{display:inline-block;width:10px;height:18px}
`;
