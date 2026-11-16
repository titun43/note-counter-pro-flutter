// Analyze the user's uploaded app screenshots with the z-ai vision model.
// We can't view images directly, so this lets us "see" the app's UI.
import ZAI from 'z-ai-web-dev-sdk';
import { readFileSync } from 'fs';
import { extname } from 'path';

const IMAGES = [
  { path: 'upload/unnamed.pnghh.jpg', label: 'Main screenshot (4096x2304)' },
  { path: 'upload/unnamed.png', label: 'Icon 512x512' },
  { path: 'upload/945dd0e6-e36c-4825-bb9f-699068ac0958.png', label: 'Icon 1254x1254' },
];

const MIME = {
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.png': 'image/png',
  '.webp': 'image/webp',
};

function toDataUrl(filePath) {
  const buf = readFileSync(filePath);
  const mime = MIME[extname(filePath).toLowerCase()] || 'image/png';
  return `data:${mime};base64,${buf.toString('base64')}`;
}

async function analyze(zai, img) {
  const prompt = img.label.includes('Icon')
    ? 'Describe this app icon: what it shows, colors, style, and what app category it suggests. Be concise (under 120 words).'
    : 'This is a screenshot of a mobile app called "Note Counter Pro". Describe in detail what UI elements, screens, tabs, text, colors, and layout you see. List each visible screen/section. Note any app name, tagline, or subtitle text visible. Be thorough but structured (under 300 words).';
  const messages = [
    { role: 'assistant', content: [{ type: 'text', text: 'Output only plain text, no markdown.' }] },
    { role: 'user', content: [
      { type: 'text', text: prompt },
      { type: 'image_url', image_url: { url: toDataUrl(img.path) } },
    ] },
  ];
  const res = await zai.chat.completions.createVision({
    model: 'glm-4.6v',
    messages,
    thinking: { type: 'disabled' },
  });
  console.log(`\n========== ${img.label} (${img.path}) ==========`);
  console.log(res.choices?.[0]?.message?.content ?? JSON.stringify(res, null, 2));
}

async function main() {
  const zai = await ZAI.create();
  for (const img of IMAGES) {
    try { await analyze(zai, img); }
    catch (e) { console.error(`FAIL ${img.path}:`, e?.message || e); }
  }
}
main();
