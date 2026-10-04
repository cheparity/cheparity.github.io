import { readdir, readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

// Astro generates the ClientRouter script tag, so its attributes cannot be
// set in BaseHead. Keep Rocket Loader from delaying the router until after
// page paint, which would turn internal links into full-page navigations.
const outputDir = fileURLToPath(new URL('../dist/', import.meta.url));
const routerScript = /<script(?=[^>]*\bsrc="\/_astro\/ClientRouter[^"]*\.js")[^>]*>/g;
let updatedPages = 0;

async function visit(directory) {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) {
      await visit(path);
    } else if (entry.name.endsWith('.html')) {
      const html = await readFile(path, 'utf8');
      const updated = html.replace(routerScript, (tag) =>
        tag.includes('data-cfasync=') ? tag : tag.replace('<script', '<script data-cfasync="false"'),
      );
      if (updated !== html) {
        await writeFile(path, updated);
        updatedPages++;
      }
    }
  }
}

await visit(outputDir);
if (updatedPages === 0) {
  throw new Error('No ClientRouter scripts were marked for Cloudflare');
}
console.log(`Marked ClientRouter on ${updatedPages} pages for Cloudflare`);
