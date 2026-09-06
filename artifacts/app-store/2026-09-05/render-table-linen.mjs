#!/usr/bin/env node
/**
 * Artifact-only implementation of Claude Fable 5.1's Table Linen direction.
 * Usage: node render-table-linen.mjs MANIFEST.json [OUTPUT_DIR]
 * Requires the existing Appshot Vite server at http://127.0.0.1:5173.
 * No product files, app pixels, simulator state, or App Store records are edited.
 * See renderer-README.md and table-linen.manifest.example.json for the contract.
 */
import { chromium } from '/Users/victorivanov/Code/personal/appshot/app/node_modules/@playwright/test/index.mjs';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { dirname, resolve, relative, extname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';

const root = dirname(fileURLToPath(import.meta.url));
const [manifestArgument, destination] = process.argv.slice(2);
if (!manifestArgument || process.argv.includes('--help')) {
  console.log('Usage: node render-table-linen.mjs MANIFEST.json [OUTPUT_DIR]');
  process.exit(manifestArgument ? 0 : 1);
}
const manifestPath = resolve(manifestArgument);
const manifestBytes = await readFile(manifestPath);
const manifest = JSON.parse(manifestBytes.toString('utf8'));
const manifestDirectory = dirname(manifestPath);
const output = resolve(destination || resolve(manifestDirectory, manifest.output || 'outputs/table-linen'));
if (relative(root, output).startsWith('..') || output === root) throw new Error('Output must be a subdirectory of this campaign artifact directory.');
if (manifest.version !== 1) throw new Error('Manifest version must be 1.');
if (!['smoke', 'draft', 'final'].includes(manifest.status)) throw new Error('Set manifest.status to smoke, draft, or final.');
if (manifest.status === 'smoke' && !relative(root, output).split('/').includes('smoke')) throw new Error('Smoke output must be inside outputs/smoke.');
if (!Array.isArray(manifest.slides) || manifest.slides.length < 1 || manifest.slides.length > 10) throw new Error('Provide 1–10 slides.');
if (manifest.status === 'final' && (manifest.slides.length < 5 || manifest.slides.length > 6)) throw new Error('Final campaigns must contain 5–6 slides; use draft for other counts.');
if (!['table-linen', 'linen-quiet'].includes(manifest.style || 'table-linen')) throw new Error('Unknown style.');
const ids = new Set();
for (const slide of manifest.slides) {
  if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(slide.id || '') || ids.has(slide.id)) throw new Error(`Slide IDs must be unique kebab-case: ${slide.id}`);
  ids.add(slide.id);
  if (!slide.image) throw new Error(`Missing image: ${slide.id}`);
  if (slide.theme !== undefined && !['cream', 'teal'].includes(slide.theme)) throw new Error(`${slide.id}: theme must be cream or teal.`);
  if (!Array.isArray(slide.headline) || !slide.headline.length || slide.headline.length > 2) throw new Error(`${slide.id}: headline must contain 1–2 explicit lines.`);
  if (!Array.isArray(slide.subtitle) || slide.subtitle.length > 2) throw new Error(`${slide.id}: subtitle must contain 0–2 explicit lines.`);
  if (slide.subtitle.some(line => typeof line !== 'string' || !line.trim())) throw new Error(`${slide.id}: empty subtitle line.`);
}
const sourcePaths = [...new Set([...manifest.slides.map(slide => slide.image), ...(manifest.panorama?.enabled && manifest.panorama?.image ? [manifest.panorama.image] : [])])];
const sourceList = await Promise.all(sourcePaths.map(async image => {
  const path = resolve(manifestDirectory, image);
  const bytes = await readFile(path);
  const extension = extname(path).toLowerCase();
  if (!['.png', '.jpg', '.jpeg'].includes(extension)) throw new Error(`Unsupported capture format: ${image}`);
  return { key: image, path, sha256: createHash('sha256').update(bytes).digest('hex'), bytes: bytes.length, data: `data:image/${extension === '.png' ? 'png' : 'jpeg'};base64,${bytes.toString('base64')}` };
}));
const italicPath = resolve(manifestDirectory, manifest.fonts?.italic || resolve(root, 'fonts/InstrumentSerif-Italic.ttf'));
const italicBytes = await readFile(italicPath);
const browser = await chromium.launch({ headless: true });
let result;
try {
  const page = await browser.newPage({ viewport: { width: 1440, height: 1000 }, deviceScaleFactor: 1 });
  await page.goto(manifest.server || 'http://127.0.0.1:5173', { waitUntil: 'domcontentloaded' });
  result = await page.evaluate(async ({ manifest, sources, italicFont }) => {
    const { canvasToPng, safeFilename } = await import('/src/lib/render/index.ts');
    const { createZip } = await import('/src/lib/render/zip.ts');
    const W = 1320, H = 2868;
    const warnings = [], slides = [], entries = [], panelCanvases = [], geometry = [], seams = [];
    const italic = new FontFace('Instrument Serif', `url(${italicFont})`, { style: 'italic', weight: '400' });
    document.fonts.add(await italic.load());
    await Promise.all([document.fonts.load('400 118px "Instrument Serif"'), document.fonts.load('italic 400 118px "Instrument Serif"'), document.fonts.load('400 44px "DM Sans"'), document.fonts.load('500 34px "DM Sans"')]);
    // FontFaceSet.check() answers true for families the page never registered, so verify the actual faces instead.
    const faceLoaded = (family, style) => [...document.fonts].some(face => face.family.replace(/^["']|["']$/g, '') === family && face.style === style && face.status === 'loaded');
    if (!faceLoaded('Instrument Serif', 'normal') || !faceLoaded('Instrument Serif', 'italic') || !faceLoaded('DM Sans', 'normal')) throw new Error('Required font face is not loaded; text would fall back to a system font.');
    const images = new Map(await Promise.all(sources.map(async source => {
      const image = new Image(); image.src = source.data; await image.decode();
      return [source.key, image];
    })));
    const dimensions = [...new Set(manifest.slides.map(slide => `${images.get(slide.image).naturalWidth}x${images.get(slide.image).naturalHeight}`))];
    if (dimensions.length > 1) warnings.push(`Captures have mixed pixel dimensions (${dimensions.join(', ')}); phone width will differ between frames.`);
    const makeCanvas = (width = W, height = H) => {
      const canvas = document.createElement('canvas'); canvas.width = width; canvas.height = height;
      const ctx = canvas.getContext('2d', { alpha: false, colorSpace: 'srgb' });
      if (!ctx) throw new Error('Canvas unavailable.');
      ctx.imageSmoothingEnabled = true; ctx.imageSmoothingQuality = 'high';
      return [canvas, ctx];
    };
    const palette = (slide, index) => {
      const dark = (slide.theme || ((index === 0 || index === manifest.slides.length - 1) ? 'teal' : 'cream')) === 'teal' && manifest.style !== 'linen-quiet';
      return {
        canvas: dark ? '#2A736E' : '#FBF6EF', band: dark ? '#24645F' : '#F1E2D2',
        headline: dark ? '#FBF6EF' : '#2C2C2C', accent: dark ? '#D4A843' : '#2A736E',
        subtitle: dark ? '#CFE3E0' : '#4C5B6B', wordmark: dark ? '#FBF6EF' : '#2C2C2C',
        dot: '#D4A843', shell: '#292C2C', shellEdge: '#515A59',
        shadow: dark ? 'rgba(0,0,0,0.30)' : 'rgba(42,115,110,0.18)',
        ...(manifest.colors || {}), ...(slide.colors || {})
      };
    };
    const layout = slide => ({
      margin: 96, wordmarkTop: 128, headlineTop: 248, headlineWidth: 1128,
      headlineSize: 118, headlineLeading: 120, headlineTracking: -1.77,
      subtitleTop: 528, subtitleWidth: 1000, subtitleSize: 44, subtitleLeading: 57,
      bandTop: 2040, ...(manifest.layout || {}), ...(slide.layout || {})
    });
    const roundRect = (ctx, x, y, w, h, r) => { ctx.beginPath(); ctx.roundRect(x, y, w, h, Math.max(0, Math.min(r, w / 2, h / 2))); };
    function background(ctx, slide, index, offset = 0) {
      const c = palette(slide, index), l = layout(slide);
      ctx.fillStyle = c.canvas; ctx.fillRect(offset, 0, W, H);
      if (manifest.style !== 'linen-quiet' && slide.band !== false) { ctx.fillStyle = c.band; ctx.fillRect(offset, l.bandTop, W, H - l.bandTop); }
    }
    function copy(ctx, slide, index, offset = 0) {
      const c = palette(slide, index), l = layout(slide);
      if (!('letterSpacing' in ctx)) throw new Error('Canvas letterSpacing is unsupported in this browser; tracking would be silently dropped.');
      if (l.subtitleTop < l.headlineTop + slide.headline.length * l.headlineLeading) throw new Error(`${slide.id}: subtitle block starts inside the headline block; adjust layout.`);
      ctx.save(); ctx.translate(offset, 0); ctx.textAlign = 'left'; ctx.textBaseline = 'top';
      ctx.fillStyle = c.dot; ctx.beginPath(); ctx.arc(l.margin + 6, l.wordmarkTop + 21, 6, 0, 2 * Math.PI); ctx.fill();
      ctx.font = '500 34px "DM Sans"'; ctx.letterSpacing = '0.68px'; ctx.fillStyle = c.wordmark;
      ctx.fillText(manifest.name || 'Billington', l.margin + 32, l.wordmarkTop);
      for (const [lineIndex, line] of slide.headline.entries()) {
        if (typeof line !== 'string' || !line.trim()) throw new Error(`${slide.id}: empty headline line.`);
        const parts = line.split('*');
        if (parts.length % 2 === 0) throw new Error(`${slide.id}: unbalanced italic markers.`);
        let x = l.margin;
        ctx.letterSpacing = `${l.headlineTracking}px`;
        for (const [partIndex, text] of parts.entries()) {
          ctx.font = `${partIndex % 2 ? 'italic ' : ''}400 ${l.headlineSize}px "Instrument Serif"`;
          ctx.fillStyle = partIndex % 2 ? c.accent : c.headline;
          const width = ctx.measureText(text).width;
          if (x + width > l.margin + l.headlineWidth + 0.5) throw new Error(`${slide.id}: headline line ${lineIndex + 1} overflows; shorten copy.`);
          ctx.fillText(text, x, l.headlineTop + lineIndex * l.headlineLeading); x += width;
        }
      }
      ctx.letterSpacing = '0px'; ctx.font = `400 ${l.subtitleSize}px "DM Sans"`; ctx.fillStyle = c.subtitle;
      for (const [lineIndex, text] of slide.subtitle.entries()) {
        if (ctx.measureText(text).width > l.subtitleWidth) throw new Error(`${slide.id}: subtitle line ${lineIndex + 1} overflows; shorten copy.`);
        ctx.fillText(text, l.margin, l.subtitleTop + lineIndex * l.subtitleLeading);
      }
      ctx.restore();
    }
    const round1 = value => Math.round(value * 10) / 10;
    function phone(ctx, image, slide, index, { width = W, shared = false, override = {}, copySlides = [slide], id = slide.id, seamX = null, clearance = [] } = {}) {
      const c = palette(slide, index);
      const p = { mode: 'full', top: 760, bottom: 2740, maxWidth: 1038, centerX: width / 2, shell: 24, radius: 60, frameless: false, shadow: true, rotation: 0, ...(manifest.phone || {}), ...(slide.phone || {}), ...override };
      if (!['full', 'bottom-crop'].includes(p.mode)) throw new Error(`${slide.id}: invalid phone.mode.`);
      if (p.mode === 'bottom-crop' && !p.cropReason) throw new Error(`${slide.id}: intentional bottom crop requires phone.cropReason.`);
      if (typeof p.rotation !== 'number' || !Number.isFinite(p.rotation) || Math.abs(p.rotation) > 8) throw new Error(`${id}: phone.rotation must be a finite number of degrees within ±8.`);
      // Hardware API (agreed with the native Appshot owner). Absent phone.hardware keeps the legacy flat shell byte-for-byte.
      if (p.hardware !== undefined && p.hardware !== 'iphone-17-pro-max') throw new Error(`${id}: phone.hardware must be omitted or 'iphone-17-pro-max'.`);
      const islandMode = p.dynamicIsland === undefined ? 'source' : p.dynamicIsland;
      if (!['draw', 'source'].includes(islandMode)) throw new Error(`${id}: phone.dynamicIsland must be 'draw' or 'source'.`);
      if (p.hardwareButtons !== undefined && typeof p.hardwareButtons !== 'boolean') throw new Error(`${id}: phone.hardwareButtons must be boolean.`);
      const hardwareModel = p.hardware || null;
      const border = p.frameless ? 0 : p.shell;
      const ratio = image.naturalWidth / image.naturalHeight;
      const screenWidth = p.mode === 'full' ? Math.min(p.maxWidth, (p.bottom - p.top) * ratio) : p.maxWidth;
      const screenHeight = screenWidth / ratio;
      const scale = screenWidth / image.naturalWidth;
      // Unrotated layout boxes (the manifest contract). The whole device is then rotated as one rigid body about the screen centre.
      const x = p.centerX - screenWidth / 2, y = p.top;
      const shell = { x: x - border, y: y - border, width: screenWidth + border * 2, height: screenHeight + border * 2 };
      const theta = p.rotation * Math.PI / 180, cos = Math.cos(theta), sin = Math.sin(theta);
      const center = { x: p.centerX, y: y + screenHeight / 2 };
      // Same matrix the canvas applies: translate(center) · rotate(theta). Negative degrees tilt the top of the phone to the left.
      const toWorld = (lx, ly) => ({ x: center.x + lx * cos - ly * sin, y: center.y + lx * sin + ly * cos });
      const boundsOf = (halfW, halfH) => {
        const corners = [[-halfW, -halfH], [halfW, -halfH], [halfW, halfH], [-halfW, halfH]].map(([lx, ly]) => toWorld(lx, ly));
        return { left: Math.min(...corners.map(k => k.x)), right: Math.max(...corners.map(k => k.x)), top: Math.min(...corners.map(k => k.y)), bottom: Math.max(...corners.map(k => k.y)) };
      };
      const bounds = boundsOf(shell.width / 2, shell.height / 2), screenBounds = boundsOf(screenWidth / 2, screenHeight / 2);
      // iPhone 17 Pro Max custom hardware (code-native, not Apple artwork). Constants are NATIVE capture pixels, scaled with the source.
      // Body bounds are unchanged from the legacy shell; the shell band is divided into a silver rim (outside) and black glass bezel (inside).
      const HW = hardwareModel ? { displayRadiusNative: 150, rimNative: 8, buttonProjectionNative: 2.5, island: { x: 472, y: 42, width: 376, height: 110, radius: 55 }, referenceSize: { width: 1320, height: 2868 } } : null;
      const hw = HW ? (() => {
        const kx = screenWidth / HW.referenceSize.width, ky = screenHeight / HW.referenceSize.height; // reference-native → output, proportional to image.naturalWidth/1320 and naturalHeight/2868 then scale
        const displayRadius = HW.displayRadiusNative * scale, rim = Math.min(border, HW.rimNative * scale), projection = HW.buttonProjectionNative * scale;
        const sx = -screenWidth / 2, sy = -screenHeight / 2, bx = sx - border, by = sy - border;
        const worldBox = (lx, ly, w, h) => { const k = [[lx, ly], [lx + w, ly], [lx + w, ly + h], [lx, ly + h]].map(([a, b]) => toWorld(a, b)); return { left: Math.min(...k.map(q => q.x)), right: Math.max(...k.map(q => q.x)), top: Math.min(...k.map(q => q.y)), bottom: Math.max(...k.map(q => q.y)) }; };
        // Side buttons: rows in reference-native screen coordinates; each projects `projection` beyond the body edge and tucks 3px under it.
        const buttonSpecs = p.hardwareButtons === true ? [['action', 'left', 300, 400], ['volume-up', 'left', 505, 700], ['volume-down', 'left', 745, 940], ['power', 'right', 585, 865], ['camera-control', 'right', 1540, 1720]] : [];
        const buttons = buttonSpecs.map(([label, side, rowStart, rowEnd]) => {
          const thickness = projection + 3, local = { x: side === 'left' ? bx - projection : bx + shell.width - 3, y: sy + rowStart * ky, width: thickness, height: (rowEnd - rowStart) * ky };
          return { label, side, sourceRows: [rowStart, rowEnd], projectionNative: HW.buttonProjectionNative, local, bounds: worldBox(local.x, local.y, local.width, local.height) };
        });
        const islandLocal = { x: sx + HW.island.x * kx, y: sy + HW.island.y * ky, width: HW.island.width * kx, height: HW.island.height * ky, radius: HW.island.radius * ky };
        let islandDrawn = islandMode === 'draw';
        if (islandDrawn) { // Trivial guard only: a capture that already carries a real black island is not doubled. Explicit mode remains the contract.
          const probe = document.createElement('canvas'); probe.width = probe.height = 1; const pc = probe.getContext('2d');
          pc.drawImage(image, Math.round(660 * image.naturalWidth / HW.referenceSize.width), Math.round(97 * image.naturalHeight / HW.referenceSize.height), 1, 1, 0, 0, 1, 1);
          const [r, g, b] = pc.getImageData(0, 0, 1, 1).data;
          if (r + g + b < 120) { islandDrawn = false; warnings.push(`${id}: dynamicIsland 'draw' skipped; capture already dark at island centre (${r},${g},${b}).`); }
        }
        return { model: hardwareModel, kx, ky, displayRadius, bodyRadius: displayRadius + border, rim, glassBezel: border - rim, projection, buttons, islandLocal, islandDrawn, islandMode, bx, by, outerBounds: boundsOf(shell.width / 2 + (buttons.length ? projection : 0), shell.height / 2) };
      })() : null;
      const fitBounds = hw ? hw.outerBounds : bounds;
      if (screenWidth <= 0 || screenHeight <= 0 || fitBounds.left < 0 || fitBounds.right > width || fitBounds.top < 0 || (p.mode === 'full' && fitBounds.bottom > H)) throw new Error(`${id}: full phone (rotated bounds ${JSON.stringify(fitBounds)}) does not fit the canvas.`);
      // A seam-straddling phone sits under both panels' copy, so every panel it touches is checked against the transformed top edge.
      const copyBottom = Math.max(...copySlides.map(s => layout(s).subtitleTop + s.subtitle.length * layout(s).subtitleLeading));
      if (bounds.top < copyBottom + 36) throw new Error(`${id}: phone collides with copy.`);
      ctx.save();
      ctx.translate(center.x, center.y); if (theta) ctx.rotate(theta);
      const sx = -screenWidth / 2, sy = -screenHeight / 2;
      if (hw) {
        // Hardware mode: every part (buttons, body, glass, display mask, capture, island) shares the one rigid translate·rotate above.
        ctx.lineWidth = 1; ctx.fillStyle = '#B7BABE'; ctx.strokeStyle = 'rgba(58,62,66,0.55)';
        for (const b of hw.buttons) { roundRect(ctx, b.local.x, b.local.y, b.local.width, b.local.height, 1.5); ctx.fill(); ctx.stroke(); }
        if (p.shadow) { ctx.shadowColor = c.shadow; ctx.shadowBlur = 80; ctx.shadowOffsetY = 40; }
        roundRect(ctx, hw.bx, hw.by, shell.width, shell.height, hw.bodyRadius);
        const metal = ctx.createLinearGradient(hw.bx, hw.by, hw.bx, hw.by + shell.height);
        metal.addColorStop(0, '#DADCDF'); metal.addColorStop(0.5, '#C3C6CA'); metal.addColorStop(1, '#D3D5D8');
        ctx.fillStyle = metal; ctx.fill();
        ctx.shadowColor = 'transparent'; ctx.shadowBlur = 0; ctx.shadowOffsetY = 0;
        ctx.strokeStyle = 'rgba(64,68,72,0.6)'; ctx.stroke();
        roundRect(ctx, hw.bx + hw.rim, hw.by + hw.rim, shell.width - 2 * hw.rim, shell.height - 2 * hw.rim, hw.bodyRadius - hw.rim);
        ctx.fillStyle = '#0A0B0C'; ctx.fill(); ctx.strokeStyle = 'rgba(255,255,255,0.12)'; ctx.stroke();
        // Display mask blanks corner pixels only; the capture itself is drawn unmodified under the same transform.
        roundRect(ctx, sx, sy, screenWidth, screenHeight, hw.displayRadius); ctx.clip();
        ctx.drawImage(image, sx, sy, screenWidth, screenHeight);
        if (hw.islandDrawn) { const i = hw.islandLocal; roundRect(ctx, i.x, i.y, i.width, i.height, i.radius); ctx.fillStyle = '#000000'; ctx.fill(); }
        ctx.restore();
      } else {
      if (p.shadow) { ctx.shadowColor = c.shadow; ctx.shadowBlur = 80; ctx.shadowOffsetY = 40; }
      roundRect(ctx, sx - border, sy - border, shell.width, shell.height, p.radius + border);
      ctx.fillStyle = p.frameless ? c.canvas : c.shell; ctx.fill();
      ctx.shadowColor = 'transparent'; ctx.shadowBlur = 0; ctx.shadowOffsetY = 0;
      if (!p.frameless) { ctx.lineWidth = 2; ctx.strokeStyle = c.shellEdge; ctx.stroke(); }
      // The complete capture is uniformly scaled under the same single affine transform as the shell. No UI contents are redrawn or recolored.
      // Rounded display masking affects only corner background pixels; set radius:0 to retain every corner.
      roundRect(ctx, sx, sy, screenWidth, screenHeight, p.radius); ctx.clip();
      ctx.drawImage(image, sx, sy, screenWidth, screenHeight); ctx.restore();
      }
      let seam = null;
      if (seamX !== null) {
        if (!(bounds.left < seamX && seamX < bounds.right)) throw new Error(`${id}: the single phone does not cross the panel seam at x=${seamX}.`);
        // Source column the vertical world seam crosses at a given source row: solve center.x + lx·cos − ly·sin = seamX.
        const columnAt = row => { const ly = (row - image.naturalHeight / 2) * scale; return image.naturalWidth / 2 + ((seamX - center.x + ly * sin) / cos) / scale; };
        const checks = clearance.map(check => {
          const column = columnAt(check.sourceRow), ok = column >= check.min && column <= check.max;
          if (!ok) throw new Error(`${id}: seam clearance "${check.label}" failed; seam crosses source column ${round1(column)} at row ${check.sourceRow}, allowed ${check.min}–${check.max}.`);
          return { ...check, seamSourceColumn: round1(column), ok };
        });
        seam = { worldX: seamX, sourceColumnAtTop: round1(columnAt(0)), sourceColumnAtBottom: round1(columnAt(image.naturalHeight)), screenWidthFractionLeftOfSeam: round1(100 * (seamX - screenBounds.left) / (screenBounds.right - screenBounds.left)) / 100, clearance: checks };
      }
      return { id, sourceWidth: image.naturalWidth, sourceHeight: image.naturalHeight, scale: round1(scale * 10000) / 10000, rotationDegrees: p.rotation, center, screen: { x, y, width: screenWidth, height: screenHeight }, shell, bounds, screenBounds, mode: p.mode, visibleScreenFraction: Math.min(1, (H - screenBounds.top) / (screenBounds.bottom - screenBounds.top)), cropReason: p.cropReason || null, roundedCornerRadius: hw ? round1(hw.displayRadius) : p.radius, hardware: hw ? { model: hw.model, dynamicIsland: hw.islandMode, islandDrawn: hw.islandDrawn, islandSourceRect: { ...HW.island, referenceSize: HW.referenceSize, center: { x: 660, y: 97 } }, islandOutputRect: { x: round1(hw.islandLocal.x), y: round1(hw.islandLocal.y), width: round1(hw.islandLocal.width), height: round1(hw.islandLocal.height), radius: round1(hw.islandLocal.radius), coordinateSpace: 'local (screen centre origin, pre-rotation)' }, displayCornerRadius: { native: HW.displayRadiusNative, output: round1(hw.displayRadius) }, bodyCornerRadiusOutput: round1(hw.bodyRadius), metalRim: { native: HW.rimNative, output: round1(hw.rim) }, glassBezelOutput: round1(hw.glassBezel), shellOutput: border, buttons: hw.buttons.map(b => ({ label: b.label, side: b.side, sourceRows: b.sourceRows, projectionNative: b.projectionNative, projectionOutput: round1(hw.projection), bounds: b.bounds })), boundsWithButtons: hw.outerBounds } : null, shared, ...(seam ? { seam } : {}) };
    }
    async function base64(bytes) { return new Promise((resolve, reject) => { const reader = new FileReader(); reader.onload = () => resolve(String(reader.result).split(',')[1]); reader.onerror = reject; reader.readAsDataURL(new Blob([bytes])); }); }
    async function exportCanvas(canvas, name, inZip = true) {
      const bytes = new Uint8Array(await (await canvasToPng(canvas)).arrayBuffer());
      const header = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
      if (String.fromCharCode(...bytes.subarray(12, 16)) !== 'IHDR' || header.getUint32(16) !== canvas.width || header.getUint32(20) !== canvas.height || bytes[24] !== 8) throw new Error(`${name}: PNG header does not match ${canvas.width}×${canvas.height} 8-bit.`);
      if (bytes[25] !== 2) throw new Error(`${name}: browser encoded PNG color type ${bytes[25]}; RGB PNG required.`);
      if (inZip) entries.push({ name, data: bytes });
      const exported = { name, width: canvas.width, height: canvas.height, colorType: bytes[25], data: await base64(bytes) };
      slides.push(exported); return exported;
    }
    // Panorama contract. Optional (legacy): standalone panels stay primary and a connected/ preview is exported separately.
    // panorama.primary: the two adjacent slides are NOT rendered standalone; their panel canvases, primary PNGs,
    // contact-sheet cells, and ZIP entries are literal 1320-wide crops of ONE 2640×2868 master with one physical phone.
    let pano = null;
    if (manifest.panorama?.enabled) {
      const p = manifest.panorama;
      const leftIndex = manifest.slides.findIndex(slide => slide.id === p.leftId);
      const rightIndex = manifest.slides.findIndex(slide => slide.id === p.rightId);
      if (leftIndex < 0 || rightIndex < 0) throw new Error('Panorama must reference existing leftId/rightId slides.');
      if (!images.has(p.image)) throw new Error('Panorama needs its own source image key.');
      const primary = p.primary === true;
      if (primary && rightIndex !== leftIndex + 1) throw new Error(`panorama.primary requires adjacent ordered slides; ${p.leftId} is panel ${leftIndex + 1} and ${p.rightId} is panel ${rightIndex + 1}.`);
      if (p.seamClearance !== undefined && (!Array.isArray(p.seamClearance) || p.seamClearance.some(check => typeof check.label !== 'string' || ![check.sourceRow, check.min, check.max].every(Number.isFinite) || check.min >= check.max))) throw new Error('panorama.seamClearance entries need label, sourceRow, min < max.');
      const left = manifest.slides[leftIndex], right = manifest.slides[rightIndex];
      for (const slide of primary ? [left, right] : []) if (slide.image !== p.image) warnings.push(`${slide.id}: slide.image differs from panorama.image; the primary connected pair renders panorama.image only.`);
      pano = { ...p, primary, leftIndex, rightIndex, left, right, masterName: `connected/master-${W * 2}x${H}.png` };
    }
    function renderPanorama(p) {
      const { left, right, leftIndex, rightIndex } = p;
      const [master, ctx] = makeCanvas(W * 2, H);
      background(ctx, left, leftIndex); background(ctx, right, rightIndex, W);
      copy(ctx, left, leftIndex); copy(ctx, right, rightIndex, W);
      const shared = phone(ctx, images.get(p.image), left, leftIndex, { width: W * 2, shared: true, seamX: W, clearance: p.seamClearance || [], override: { centerX: W, ...(p.phone || {}) }, copySlides: [left, right], id: `${left.id}+${right.id}` });
      const pair = [];
      for (let i = 0; i < 2; i++) { const [canvas, crop] = makeCanvas(); crop.drawImage(master, i * W, 0, W, H, 0, 0, W, H); pair.push(canvas); }
      let differences = 0;
      for (let i = 0; i < 2; i++) {
        const expected = ctx.getImageData(i * W, 0, W, H).data;
        const actual = pair[i].getContext('2d').getImageData(0, 0, W, H).data;
        for (let byte = 0; byte < expected.length; byte++) if (expected[byte] !== actual[byte]) differences++;
      }
      if (differences) throw new Error(`Panorama pixel equality failed: ${differences}.`);
      seams.push({ masterWidth: W * 2, panelWidth: W, seamX: W, differingChannelValues: differences, singlePhone: true, primary: p.primary, leftId: left.id, rightId: right.id, panelNumbers: [leftIndex + 1, rightIndex + 1] });
      // Per-panel view of the one shared phone, in that panel's own 1320-wide coordinates.
      const clip = (box, offset) => ({ left: Math.max(0, box.left - offset), right: Math.min(W, box.right - offset), top: box.top, bottom: Math.min(H, box.bottom) });
      const panels = [left, right].map((slide, i) => {
        const shell = clip(shared.bounds, i * W), screen = clip(shared.screenBounds, i * W);
        if (shell.right <= shell.left) throw new Error(`${slide.id}: the shared phone does not reach this panel.`);
        return { panelNumber: leftIndex + i + 1, id: slide.id, masterOffsetX: i * W, shellBounds: shell, screenBounds: screen, screenWidthInPanel: round1(Math.max(0, screen.right - screen.left)) };
      });
      return { master, pair, geometry: { ...shared, primary: p.primary, master: p.masterName, panels } };
    }
    const primaryPanorama = pano?.primary ? renderPanorama(pano) : null;
    for (const [index, slide] of manifest.slides.entries()) {
      const name = `${String(index + 1).padStart(2, '0')}-${slide.id}-${W}x${H}.png`;
      if (primaryPanorama && (index === pano.leftIndex || index === pano.rightIndex)) {
        // Primary connected pair: no standalone panel exists for these slides, so no standalone geometry is recorded either.
        const canvas = primaryPanorama.pair[index - pano.leftIndex];
        panelCanvases.push(canvas);
        if (index === pano.leftIndex) geometry.push(primaryPanorama.geometry);
        await exportCanvas(canvas, name);
        continue;
      }
      const [canvas, ctx] = makeCanvas(); background(ctx, slide, index); copy(ctx, slide, index);
      geometry.push(phone(ctx, images.get(slide.image), slide, index)); panelCanvases.push(canvas);
      await exportCanvas(canvas, name);
    }
    if (pano && !pano.primary) {
      const optional = renderPanorama(pano);
      geometry.push(optional.geometry);
      for (let i = 0; i < 2; i++) await exportCanvas(optional.pair[i], `connected/${i + 1}-${i ? pano.right.id : pano.left.id}-${W}x${H}.png`, false);
      await exportCanvas(optional.master, pano.masterName, false);
    }
    if (primaryPanorama) await exportCanvas(primaryPanorama.master, pano.masterName, false);
    const contactWidth = 360, gap = 24, pad = 60, columns = Math.min(6, panelCanvases.length);
    const contactHeight = Math.round(contactWidth * H / W), rows = Math.ceil(panelCanvases.length / columns);
    const [contact, contactCtx] = makeCanvas(pad * 2 + columns * contactWidth + (columns - 1) * gap, 164 + rows * (contactHeight + 48) + pad);
    contactCtx.fillStyle = '#FBF6EF'; contactCtx.fillRect(0, 0, contact.width, contact.height);
    contactCtx.fillStyle = '#2C2C2C'; contactCtx.font = '400 46px "Instrument Serif"';
    contactCtx.fillText(`${manifest.name || 'Billington'} — ${manifest.style === 'linen-quiet' ? 'Linen Quiet' : 'Table Linen'}`, pad, 77);
    contactCtx.font = '400 18px "DM Sans"'; contactCtx.fillStyle = '#4C5B6B';
    contactCtx.fillText(manifest.status === 'smoke' ? 'SMOKE TEST · HISTORICAL CAPTURES · NOT FINAL CAMPAIGN' : `${manifest.status.toUpperCase()} PREVIEW · ${panelCanvases.length} frames · 1320 × 2868 pixels`, pad, 116);
    for (const [index, canvas] of panelCanvases.entries()) {
      const x = pad + (index % columns) * (contactWidth + gap), y = 150 + Math.floor(index / columns) * (contactHeight + 48);
      contactCtx.drawImage(canvas, x, y, contactWidth, contactHeight);
      contactCtx.fillStyle = '#4C5B6B'; contactCtx.font = '400 16px "DM Sans"';
      const sharedNote = primaryPanorama && (index === pano.leftIndex || index === pano.rightIndex) ? ` · one phone across ${String(pano.leftIndex + 1).padStart(2, '0')}–${String(pano.rightIndex + 1).padStart(2, '0')}` : '';
      contactCtx.fillText(`${String(index + 1).padStart(2, '0')}  ${manifest.slides[index].label || manifest.slides[index].id}${sharedNote}`, x, y + contactHeight + 28);
    }
    await exportCanvas(contact, 'contact-sheet.png', false);
    const panoramaSummary = pano ? { mode: pano.primary ? 'primary' : 'optional', leftId: pano.left.id, rightId: pano.right.id, panelNumbers: [pano.leftIndex + 1, pano.rightIndex + 1], image: pano.image, master: pano.masterName, primaryPanelsAreMasterCrops: pano.primary, note: pano.primary ? 'Panels listed are literal crops of the master; their primary PNGs, contact-sheet cells and ZIP entries share one phone. No standalone render exists for them.' : 'Standalone panels remain primary; connected/ is a separate optional preview.' } : null;
    const validation = { width: W, height: H, status: manifest.status, style: manifest.style || 'table-linen', fonts: { serif: 'Instrument Serif regular + real italic', sans: 'DM Sans' }, renderMethod: 'Native Canvas 2D; existing Appshot PNG and ZIP encoders', panorama: panoramaSummary, geometry, seams, warnings };
    entries.push({ name: 'validation.json', data: new TextEncoder().encode(JSON.stringify(validation, null, 2)) });
    const zip = createZip(entries);
    return { files: slides, zip: await base64(zip), zipName: `${safeFilename(manifest.name || 'Billington')}-${manifest.style || 'table-linen'}-${manifest.status}.zip`, validation };
  }, { manifest, sources: sourceList, italicFont: `data:font/ttf;base64,${italicBytes.toString('base64')}` });
} finally { await browser.close(); }

await mkdir(output, { recursive: true });
for (const file of result.files) {
  const path = resolve(output, file.name); await mkdir(dirname(path), { recursive: true });
  await writeFile(path, Buffer.from(file.data, 'base64'));
}
await writeFile(resolve(output, result.zipName), Buffer.from(result.zip, 'base64'));
const validation = { ...result.validation, manifest: { path: manifestPath, sha256: createHash('sha256').update(manifestBytes).digest('hex') }, capturedSources: sourceList.map(({ data, key, ...source }) => ({ imageKey: key, ...source })), italicFont: { path: italicPath, sha256: createHash('sha256').update(italicBytes).digest('hex') }, exportedFiles: result.files.map(({ data, ...file }) => file) };
await writeFile(resolve(output, 'validation.json'), JSON.stringify(validation, null, 2) + '\n');
await writeFile(resolve(output, 'manifest.resolved.json'), JSON.stringify({ ...manifest, fonts: { ...(manifest.fonts || {}), italic: italicPath }, slides: manifest.slides.map(slide => ({ ...slide, image: resolve(manifestDirectory, slide.image) })), ...(manifest.panorama?.image ? { panorama: { ...manifest.panorama, image: resolve(manifestDirectory, manifest.panorama.image) } } : {}) }, null, 2) + '\n');
console.log(JSON.stringify({ output, status: manifest.status, pngCount: result.files.length, zip: result.zipName, panorama: validation.panorama, geometry: validation.geometry.map(({ id, visibleScreenFraction, shared, primary, rotationDegrees, seam, panels }) => ({ id, visibleScreenFraction, shared, ...(shared ? { primary: primary === true, rotationDegrees, seam, panels } : {}) })), seams: validation.seams, warnings: validation.warnings }, null, 2));
