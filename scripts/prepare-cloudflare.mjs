import { readdir, readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

// Astro generates component script tags, so their attributes cannot be set in
// the .astro files. Rocket Loader delays these modules until after the router's
// initial astro:page-load event, leaving page controls uninitialised. Exclude
// site scripts from Rocket Loader while retaining Astro's normal script order.
const outputDir = fileURLToPath(new URL('../dist/', import.meta.url));
const scriptTag = /<script\b[^>]*>/g;
let updatedPages = 0;
let updatedScripts = 0;

async function visit(directory) {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) {
      await visit(path);
    } else if (entry.name.endsWith('.html')) {
      const html = await readFile(path, 'utf8');
      const updated = html.replace(scriptTag, (tag) => {
        if (tag.includes('data-cfasync=')) return tag;
        updatedScripts++;
        return tag.replace('<script', '<script data-cfasync="false"');
      });
      if (updated !== html) {
        await writeFile(path, updated);
        updatedPages++;
      }
    }
  }
}

await visit(outputDir);
if (updatedPages === 0) {
  throw new Error('No scripts were marked for Cloudflare');
}
console.log(`Marked ${updatedScripts} scripts on ${updatedPages} pages for Cloudflare`);
