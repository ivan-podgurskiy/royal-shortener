pub const css = "/* ============================================================
   Royal Shortener — design tokens & base styles
   ============================================================ */

/* ---- Fonts ---- */
@import url('https://fonts.googleapis.com/css2?family=Cormorant+Garamond:ital,wght@0,400;0,500;0,600;0,700;1,500&family=Marcellus&family=Manrope:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;700&display=swap');

/* ============================================================
   THEMES — set via data-theme on .royal-root
   ============================================================ */
.royal-root {
  /* default = Royal Navy & Gold */
  --bg:        oklch(0.16 0.045 273);
  --bg-deep:   oklch(0.12 0.04 273);
  --panel:     oklch(0.215 0.05 272);
  --panel-2:   oklch(0.255 0.052 272);
  --line:      oklch(0.42 0.05 272);

  --gold-1:    #f2d889;
  --gold-2:    #d9b35f;
  --gold-3:    #b78a3a;
  --gold-soft: rgba(224, 186, 110, 0.14);

  --ink:       oklch(0.95 0.012 88);
  --ink-soft:  oklch(0.82 0.018 280);
  --ink-mute:  oklch(0.66 0.025 278);

  --glow:      oklch(0.55 0.13 280 / 0.55);
  --accent-h:  273;
}

.royal-root[data-theme='oxblood'] {
  --bg:        oklch(0.16 0.05 22);
  --bg-deep:   oklch(0.115 0.045 22);
  --panel:     oklch(0.215 0.055 20);
  --panel-2:   oklch(0.255 0.058 20);
  --line:      oklch(0.42 0.06 22);
  --gold-1:    #f3e6c8;
  --gold-2:    #e2cda1;
  --gold-3:    #c2a878;
  --gold-soft: rgba(230, 210, 170, 0.13);
  --ink:       oklch(0.95 0.012 70);
  --ink-soft:  oklch(0.83 0.02 40);
  --ink-mute:  oklch(0.68 0.03 35);
  --glow:      oklch(0.5 0.15 25 / 0.55);
  --accent-h:  22;
}

.royal-root[data-theme='obsidian'] {
  --bg:        oklch(0.155 0.008 280);
  --bg-deep:   oklch(0.105 0.006 280);
  --panel:     oklch(0.205 0.009 280);
  --panel-2:   oklch(0.245 0.01 280);
  --line:      oklch(0.4 0.012 280);
  --gold-1:    #f0e4c0;
  --gold-2:    #d8c79b;
  --gold-3:    #b3a378;
  --gold-soft: rgba(216, 199, 155, 0.12);
  --ink:       oklch(0.95 0.008 90);
  --ink-soft:  oklch(0.82 0.008 280);
  --ink-mute:  oklch(0.65 0.01 280);
  --glow:      oklch(0.6 0.04 90 / 0.4);
  --accent-h:  90;
}

.royal-root[data-theme='imperial'] {
  --bg:        oklch(0.17 0.07 305);
  --bg-deep:   oklch(0.12 0.06 305);
  --panel:     oklch(0.225 0.075 305);
  --panel-2:   oklch(0.265 0.078 305);
  --line:      oklch(0.44 0.08 305);
  --gold-1:    #f3d98a;
  --gold-2:    #ddb65f;
  --gold-3:    #bb8d3a;
  --gold-soft: rgba(225, 185, 110, 0.15);
  --ink:       oklch(0.95 0.012 90);
  --ink-soft:  oklch(0.84 0.025 312);
  --ink-mute:  oklch(0.68 0.035 310);
  --glow:      oklch(0.55 0.18 315 / 0.55);
  --accent-h:  305;
}

/* ============================================================
   BASE
   ============================================================ */
* { box-sizing: border-box; }
html, body { margin: 0; padding: 0; }

.royal-root {
  background: var(--bg);
  color: var(--ink);
  font-family: 'Manrope', system-ui, sans-serif;
  font-size: 17px;
  line-height: 1.6;
  -webkit-font-smoothing: antialiased;
  min-height: 100vh;
  overflow-x: hidden;
  position: relative;
}

/* layered royal background */
.royal-bg {
  position: fixed;
  inset: 0;
  z-index: 0;
  pointer-events: none;
  background:
    radial-gradient(120% 80% at 50% -10%, var(--glow), transparent 60%),
    radial-gradient(90% 60% at 85% 110%, var(--gold-soft), transparent 55%),
    linear-gradient(180deg, var(--bg) 0%, var(--bg-deep) 100%);
}
.royal-bg::after {
  /* faint gold grain / vignette */
  content: '';
  position: absolute;
  inset: 0;
  background:
    radial-gradient(60% 50% at 50% 40%, transparent 55%, rgba(0,0,0,0.35) 100%);
  opacity: 0.9;
}
.royal-root[data-glow='off'] .royal-bg {
  background:
    radial-gradient(90% 60% at 85% 110%, var(--gold-soft), transparent 55%),
    linear-gradient(180deg, var(--bg) 0%, var(--bg-deep) 100%);
}

.royal-shell {
  position: relative;
  z-index: 1;
  max-width: 1180px;
  margin: 0 auto;
  padding: 0 32px;
}

/* ---- type helpers ---- */
.display { font-family: 'Cormorant Garamond', Georgia, serif; font-weight: 600; line-height: 1.02; letter-spacing: -0.01em; }
.roman   { font-family: 'Marcellus', Georgia, serif; }
.mono    { font-family: 'JetBrains Mono', ui-monospace, monospace; }

.eyebrow {
  font-family: 'Marcellus', serif;
  text-transform: uppercase;
  letter-spacing: 0.32em;
  font-size: 0.72rem;
  color: var(--gold-2);
  display: inline-flex;
  align-items: center;
  gap: 0.9em;
}
.eyebrow::before, .eyebrow::after {
  content: '';
  width: 26px;
  height: 1px;
  background: linear-gradient(90deg, transparent, var(--gold-3));
}
.eyebrow.solo::before { display: none; }

.gold-text {
  background: linear-gradient(100deg, var(--gold-1), var(--gold-2) 45%, var(--gold-3));
  -webkit-background-clip: text;
  background-clip: text;
  color: transparent;
}

/* ---- gold rule / flourish ---- */
.flourish {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 14px;
  color: var(--gold-3);
}
.flourish .rule {
  height: 1px;
  width: clamp(40px, 12vw, 160px);
  background: linear-gradient(90deg, transparent, var(--gold-3));
}
.flourish .rule.r { background: linear-gradient(270deg, transparent, var(--gold-3)); }

/* ============================================================
   BUTTONS
   ============================================================ */
.btn {
  font-family: 'Marcellus', serif;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  font-size: 0.78rem;
  border: none;
  cursor: pointer;
  border-radius: 2px;
  padding: 14px 26px;
  display: inline-flex;
  align-items: center;
  gap: 10px;
  transition: transform .25s cubic-bezier(.2,.8,.2,1), box-shadow .25s, filter .25s;
  white-space: nowrap;
  text-decoration: none;
}
.btn-gold {
  position: relative;
  color: #2a200a;
  background: linear-gradient(160deg, var(--gold-1), var(--gold-2) 55%, var(--gold-3));
  box-shadow: 0 1px 0 rgba(255,255,255,.35) inset, 0 10px 30px -10px rgba(0,0,0,.7);
}
.btn-gold:hover { transform: translateY(-2px); filter: brightness(1.05); box-shadow: 0 1px 0 rgba(255,255,255,.5) inset, 0 16px 40px -12px rgba(0,0,0,.8); }
.btn-gold:active { transform: translateY(0); }
.btn-ghost {
  background: transparent;
  color: var(--ink);
  border: 1px solid var(--line);
}
.btn-ghost:hover { border-color: var(--gold-3); color: var(--gold-1); }

/* ============================================================
   NAV
   ============================================================ */
.nav {
  position: relative;
  z-index: 3;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 26px 0;
  border-bottom: 1px solid color-mix(in oklab, var(--line) 45%, transparent);
}
.brand { display: flex; align-items: center; gap: 14px; }
.brand .wordmark {
  font-family: 'Marcellus', serif;
  letter-spacing: 0.2em;
  text-transform: uppercase;
  font-size: 1.02rem;
  color: var(--ink);
}
.brand .wordmark b { color: var(--gold-1); font-weight: 400; }
.nav-links { display: flex; align-items: center; gap: 34px; }
.nav-links a {
  color: var(--ink-soft);
  text-decoration: none;
  font-size: 0.9rem;
  letter-spacing: 0.02em;
  transition: color .2s;
}
.nav-links a:hover { color: var(--gold-1); }

/* crown mark (built from simple shapes) */
.crown {
  width: 34px; height: 30px;
  display: block;
  filter: drop-shadow(0 2px 6px rgba(0,0,0,.5));
}

/* ============================================================
   HERO
   ============================================================ */
.hero { padding: clamp(48px, 8vw, 96px) 0 40px; text-align: center; }
.hero h1 {
  font-family: 'Cormorant Garamond', serif;
  font-weight: 600;
  font-size: clamp(3rem, 8.5vw, 6.4rem);
  line-height: 0.98;
  letter-spacing: -0.015em;
  margin: 26px auto 0;
  max-width: 14ch;
  text-wrap: balance;
}
.hero .sub {
  margin: 26px auto 0;
  max-width: 60ch;
  color: var(--ink-soft);
  font-size: clamp(1rem, 1.4vw, 1.18rem);
  line-height: 1.65;
  text-wrap: pretty;
}

/* ============================================================
   SHORTENER WIDGET
   ============================================================ */
.shortener {
  position: relative;
  margin: 46px auto 0;
  max-width: 760px;
}
.panel {
  position: relative;
  background:
    linear-gradient(180deg, color-mix(in oklab, var(--panel) 88%, transparent), var(--panel));
  border: 1px solid color-mix(in oklab, var(--line) 70%, transparent);
  border-radius: 6px;
  box-shadow: 0 40px 90px -50px rgba(0,0,0,.95), 0 2px 0 rgba(255,255,255,.03) inset;
  padding: 10px;
}
/* corner flourishes */
.panel .corner {
  position: absolute; width: 16px; height: 16px;
  border: 1px solid var(--gold-3); opacity: .8;
}
.panel .corner.tl { top: -1px; left: -1px; border-right: 0; border-bottom: 0; }
.panel .corner.tr { top: -1px; right: -1px; border-left: 0; border-bottom: 0; }
.panel .corner.bl { bottom: -1px; left: -1px; border-right: 0; border-top: 0; }
.panel .corner.br { bottom: -1px; right: -1px; border-left: 0; border-top: 0; }

.input-row {
  display: flex;
  gap: 8px;
  align-items: stretch;
  background: var(--bg-deep);
  border: 1px solid color-mix(in oklab, var(--line) 55%, transparent);
  border-radius: 4px;
  padding: 8px;
}
.input-row:focus-within { border-color: var(--gold-3); box-shadow: 0 0 0 3px var(--gold-soft); }
.input-wrap { position: relative; flex: 1; display: flex; align-items: center; }
.input-wrap .leadmark {
  font-family: 'JetBrains Mono', monospace;
  color: var(--gold-2);
  padding: 0 6px 0 12px;
  font-size: 0.9rem;
  user-select: none;
}
.url-input {
  flex: 1;
  background: transparent;
  border: none;
  outline: none;
  color: var(--ink);
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.95rem;
  padding: 12px 12px 12px 0;
  text-overflow: ellipsis;
  min-width: 0;
}
.url-input::placeholder { color: var(--ink-mute); }

.helper-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px 12px 6px;
  gap: 14px;
  flex-wrap: wrap;
}
.helper-row .hint { color: var(--ink-mute); font-size: 0.82rem; }
.helper-row .hint b { color: var(--gold-2); font-weight: 500; }
.chip {
  font-size: 0.72rem;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  font-family: 'Marcellus', serif;
  color: var(--ink-soft);
  border: 1px solid var(--line);
  border-radius: 999px;
  padding: 5px 12px;
  background: transparent;
  cursor: pointer;
  transition: .2s;
}
.chip:hover { border-color: var(--gold-3); color: var(--gold-1); }
.chip.on { border-color: var(--gold-2); color: var(--gold-1); background: var(--gold-soft); }

/* ---- collapse stage ---- */
.stage {
  position: relative;
  margin-top: 12px;
  min-height: 0;
  height: 0;
  overflow: hidden;
  transition: height .5s cubic-bezier(.2,.8,.2,1);
}
.stage.open { height: auto; }

.collapse-track {
  position: relative;
  height: 64px;
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 6px 4px 0;
}
.long-url {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.86rem;
  color: var(--ink-soft);
  white-space: nowrap;
  transform-origin: center;
  will-change: transform, filter, opacity, letter-spacing;
}
.flare {
  position: absolute;
  top: 50%; left: 50%;
  width: 8px; height: 8px;
  transform: translate(-50%,-50%) scale(0);
  border-radius: 999px;
  background: radial-gradient(circle, #fff, var(--gold-1) 30%, transparent 70%);
  box-shadow: 0 0 30px 10px var(--gold-1);
  opacity: 0;
  pointer-events: none;
}
.sweep {
  position: absolute;
  top: 0; bottom: 0; width: 40%;
  left: -45%;
  background: linear-gradient(90deg, transparent, rgba(255,255,255,.0), var(--gold-1), rgba(255,255,255,.0), transparent);
  filter: blur(2px);
  opacity: 0;
  pointer-events: none;
}

/* ---- result card ---- */
.result {
  margin: 6px 4px 8px;
  border: 1px solid color-mix(in oklab, var(--gold-3) 55%, transparent);
  border-radius: 5px;
  background: linear-gradient(180deg, var(--gold-soft), transparent 60%), var(--bg-deep);
  padding: 22px;
  display: grid;
  grid-template-columns: 1fr auto;
  gap: 22px;
  align-items: center;
}
.result .short-line { display: flex; align-items: baseline; gap: 4px; flex-wrap: wrap; min-width: 0; }
.result .short {
  font-family: 'JetBrains Mono', monospace;
  font-size: clamp(1.2rem, 2.6vw, 1.6rem);
  font-weight: 500;
  color: var(--ink);
  letter-spacing: -0.01em;
  white-space: nowrap;
  line-height: 1.15;
}
.result .short .dom { color: var(--ink-mute); }
.result .short .slug { color: var(--gold-1); position: relative; }
.result .short .slug::after {
  content:''; position:absolute; left:0; right:0; bottom:-4px; height:2px;
  background: linear-gradient(90deg, var(--gold-1), transparent);
}
.result .meta {
  display: flex; gap: 18px; margin-top: 14px; flex-wrap: wrap;
}
.result .meta .m { display: flex; flex-direction: column; gap: 2px; }
.result .meta .m .k { font-size: 0.66rem; letter-spacing: .14em; text-transform: uppercase; color: var(--ink-mute); font-family:'Marcellus',serif; }
.result .meta .m .v { font-size: 0.92rem; color: var(--ink); font-family: 'JetBrains Mono', monospace; white-space: nowrap; }
.result-actions { display: flex; gap: 10px; margin-top: 18px; flex-wrap: wrap; }

.copy-btn {
  font-family: 'Marcellus', serif;
  letter-spacing: .12em;
  text-transform: uppercase;
  font-size: .72rem;
  padding: 11px 20px;
  border-radius: 3px;
  border: 1px solid var(--gold-3);
  background: var(--gold-soft);
  color: var(--gold-1);
  cursor: pointer;
  transition: .2s;
  display: inline-flex; align-items: center; gap: 8px;
  white-space: nowrap;
}
.copy-btn:hover { background: linear-gradient(160deg, var(--gold-1), var(--gold-3)); color:#2a200a; }
.copy-btn.copied { background: linear-gradient(160deg, var(--gold-1), var(--gold-3)); color:#2a200a; }
.link-btn {
  background: transparent; border: none; cursor: pointer;
  color: var(--ink-soft); font-family:'Manrope',sans-serif; font-size:.82rem;
  text-decoration: underline; text-underline-offset: 3px; text-decoration-color: var(--line);
  padding: 11px 4px;
}
.link-btn:hover { color: var(--gold-1); }

/* QR — faux seal built from a CSS grid of squares */
.qr {
  width: 104px; height: 104px;
  display: grid;
  grid-template-columns: repeat(11, 1fr);
  grid-template-rows: repeat(11, 1fr);
  gap: 2px;
  padding: 9px;
  background: #f4eede;
  border-radius: 4px;
  box-shadow: 0 0 0 1px var(--gold-3), 0 10px 24px -12px rgba(0,0,0,.8);
}
.qr i { background: #1c1a14; border-radius: 1px; }
.qr i.off { background: transparent; }

/* ---- recent ledger ---- */
.ledger { margin: 22px auto 0; max-width: 760px; }
.ledger .ledger-head {
  display:flex; align-items:center; gap:12px; color: var(--ink-mute);
  font-family:'Marcellus',serif; text-transform:uppercase; letter-spacing:.22em; font-size:.68rem;
  margin-bottom: 12px;
}
.ledger .ledger-head .rule { flex:1; height:1px; background: color-mix(in oklab,var(--line) 50%, transparent); }
.ledger-row {
  display:flex; align-items:center; justify-content:space-between; gap:16px;
  padding: 12px 14px;
  border: 1px solid color-mix(in oklab,var(--line) 40%, transparent);
  border-radius: 4px;
  margin-bottom: 8px;
  background: color-mix(in oklab, var(--panel) 40%, transparent);
}
.ledger-row .lr-left { display:flex; flex-direction:column; gap:3px; min-width:0; }
.ledger-row .lr-short { font-family:'JetBrains Mono',monospace; color: var(--gold-1); font-size:.92rem; }
.ledger-row .lr-long { font-family:'JetBrains Mono',monospace; color: var(--ink-mute); font-size:.74rem; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; max-width: 48ch; }
.ledger-row .lr-clicks { font-family:'Marcellus',serif; color: var(--ink-soft); font-size:.78rem; letter-spacing:.06em; white-space:nowrap; }
.mini-copy { background:transparent; border:1px solid var(--line); color:var(--ink-soft); border-radius:3px; cursor:pointer; padding:6px 12px; font-size:.7rem; font-family:'Marcellus',serif; letter-spacing:.1em; text-transform:uppercase; transition:.2s; }
.mini-copy:hover { border-color: var(--gold-3); color: var(--gold-1); }

/* ============================================================
   SECTION SCAFFOLD
   ============================================================ */
.section { position: relative; z-index: 1; padding: clamp(70px, 11vw, 130px) 0; }
.section-head { text-align: center; margin-bottom: 56px; }
.section-head h2 {
  font-family:'Cormorant Garamond',serif; font-weight:600;
  font-size: clamp(2.2rem, 5vw, 3.6rem); line-height:1.02; margin: 18px 0 0;
  letter-spacing:-0.01em;
}
.section-head p { color: var(--ink-soft); max-width: 52ch; margin: 16px auto 0; }

/* features */
.feature-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 18px;
}
.feature {
  position: relative;
  border: 1px solid color-mix(in oklab, var(--line) 45%, transparent);
  border-radius: 6px;
  padding: 34px 32px 32px;
  background: linear-gradient(180deg, color-mix(in oklab,var(--panel) 55%, transparent), transparent);
  overflow: hidden;
  transition: border-color .3s, transform .3s;
}
.feature:hover { border-color: color-mix(in oklab, var(--gold-3) 70%, transparent); transform: translateY(-3px); }
.feature::after {
  content:''; position:absolute; inset:0;
  background: radial-gradient(120% 80% at 100% 0%, var(--gold-soft), transparent 50%);
  opacity:0; transition: opacity .3s; pointer-events:none;
}
.feature:hover::after { opacity: 1; }
.feature .ficon {
  width: 46px; height: 46px; margin-bottom: 22px;
  display:flex; align-items:center; justify-content:center;
  border: 1px solid var(--gold-3); border-radius: 50%;
  color: var(--gold-1);
}
.feature h3 { font-family:'Cormorant Garamond',serif; font-weight:600; font-size: 1.7rem; margin: 0 0 8px; }
.feature p { color: var(--ink-soft); margin: 0; font-size: 0.98rem; line-height:1.6; }
.feature .fnum {
  position:absolute; top: 22px; right: 26px;
  font-family:'Marcellus',serif; color: color-mix(in oklab,var(--gold-3) 60%, transparent);
  font-size: 0.8rem; letter-spacing:.15em;
}

/* decree band */
.decree { text-align:center; position:relative; z-index:1; padding: clamp(60px,9vw,110px) 0; }
.decree .quote {
  font-family:'Cormorant Garamond',serif; font-style: italic; font-weight:500;
  font-size: clamp(1.7rem, 4vw, 3rem); line-height:1.28; max-width: 22ch; margin: 28px auto 0;
  text-wrap: pretty;
}
.decree .quote b { font-style: normal; }
.decree .attribution { margin-top: 26px; color: var(--ink-mute); font-family:'Marcellus',serif; letter-spacing:.18em; text-transform:uppercase; font-size:.72rem; }

/* stats ledger band */
.stats { display:flex; justify-content:center; gap: clamp(32px, 7vw, 96px); flex-wrap:wrap; margin-top: 8px; }
.stat { text-align:center; }
.stat .num { font-family:'Cormorant Garamond',serif; font-weight:600; font-size: clamp(2.4rem,5vw,3.4rem); color: var(--ink); line-height:1; }
.stat .num span { color: var(--gold-1); }
.stat .lab { margin-top: 8px; color: var(--ink-mute); font-family:'Marcellus',serif; text-transform:uppercase; letter-spacing:.2em; font-size:.68rem; }

/* CTA */
.cta { text-align:center; position:relative; z-index:1; padding: clamp(70px,10vw,120px) 0; }
.cta-panel {
  position: relative;
  border: 1px solid color-mix(in oklab, var(--gold-3) 50%, transparent);
  border-radius: 8px;
  padding: clamp(48px, 7vw, 84px) 32px;
  background:
    radial-gradient(100% 120% at 50% 0%, var(--gold-soft), transparent 55%),
    linear-gradient(180deg, color-mix(in oklab,var(--panel) 70%, transparent), transparent);
  overflow:hidden;
}
.cta-panel h2 { font-family:'Cormorant Garamond',serif; font-weight:600; font-size: clamp(2.4rem,6vw,4.2rem); margin: 18px 0 0; line-height:1; }
.cta-panel p { color: var(--ink-soft); margin: 18px auto 32px; max-width: 46ch; }

/* ============================================================
   FOOTER
   ============================================================ */
.footer { position: relative; z-index:1; border-top: 1px solid color-mix(in oklab,var(--line) 45%, transparent); padding: 64px 0 40px; }
.footer-top { display:grid; grid-template-columns: 1.4fr 1fr 1fr 1fr; gap: 32px; }
.footer .f-brand .wordmark { font-family:'Marcellus',serif; letter-spacing:.2em; text-transform:uppercase; font-size:1rem; }
.footer .f-brand .wordmark b { color: var(--gold-1); font-weight:400; }
.footer .f-brand p { color: var(--ink-mute); font-size:.86rem; max-width: 28ch; margin: 14px 0 0; }
.footer .f-col h5 { font-family:'Marcellus',serif; text-transform:uppercase; letter-spacing:.16em; font-size:.7rem; color: var(--gold-2); margin:0 0 16px; }
.footer .f-col a { display:block; color: var(--ink-soft); text-decoration:none; font-size:.88rem; margin-bottom:10px; transition:.2s; }
.footer .f-col a:hover { color: var(--gold-1); }
.footer-bottom { display:flex; align-items:center; justify-content:space-between; gap:16px; margin-top: 48px; padding-top: 24px; border-top: 1px solid color-mix(in oklab,var(--line) 30%, transparent); flex-wrap:wrap; }
.footer-bottom .copy { color: var(--ink-mute); font-size:.8rem; }
.footer-bottom .fleur { color: var(--gold-3); display:flex; gap:14px; align-items:center; }

/* ============================================================
   ANIMATIONS
   ============================================================ */
@keyframes floatY { 0%,100%{ transform: translateY(0);} 50%{ transform: translateY(-8px);} }
@keyframes spinSlow { to { transform: rotate(360deg); } }
@keyframes stampIn {
  0% { transform: scale(1.35) rotate(-4deg); filter: blur(5px); }
  60% { filter: blur(0); }
  100% { transform: scale(1) rotate(0); filter: blur(0); }
}
@keyframes riseIn {
  from { transform: translateY(16px); }
  to { transform: translateY(0); }
}
.rise { animation: riseIn .6s cubic-bezier(.2,.8,.2,1) both; }
.stamp { animation: stampIn .7s cubic-bezier(.2,.9,.25,1) both; }

/* watermark crown/fleur behind hero */
.watermark {
  position: absolute;
  z-index: 0;
  opacity: 0.05;
  color: var(--gold-1);
  pointer-events: none;
}
.royal-root[data-ornament='off'] .watermark { display: none; }

/* responsive */
@media (max-width: 820px) {
  .nav-links { display: none; }
  .feature-grid { grid-template-columns: 1fr; }
  .footer-top { grid-template-columns: 1fr 1fr; }
  .result { grid-template-columns: 1fr; }
  .input-row { flex-direction: column; }
}
@media (max-width: 520px) {
  .royal-shell { padding: 0 20px; }
  .footer-top { grid-template-columns: 1fr; }
}
"
