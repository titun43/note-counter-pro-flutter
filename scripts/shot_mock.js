// Screenshot the mockup HTML for visual verification.
const { chromium } = require('playwright');
const path = require('path');

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1180, height: 900 } });
  const file = 'file://' + path.resolve('/home/z/my-project/download/mock_group_split_redesign.html');
  await page.goto(file, { waitUntil: 'networkidle' });
  // give fonts/layout a beat
  await page.waitForTimeout(400);
  await page.screenshot({ path: '/tmp/render/mock.png', fullPage: true });
  console.log('saved /tmp/render/mock.png');
  await browser.close();
})();
