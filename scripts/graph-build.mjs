#!/usr/bin/env bun
/**
 * graph-build.mjs — derive src/data/graph.json from published blog posts.
 *
 * Nodes: every file in src/content/blog (id = filename stem, which is the
 * route slug). Title/tags come from posts-manifest.json (publish.py output),
 * falling back to the post's own frontmatter.
 *
 * Edges: internal links in post bodies, in whichever form they take —
 * rewritten (/blog/<slug>/) after a vault publish, or still raw Obsidian
 * links (notes/...md, [[wikilinks]]) in checked-in sources. Targets that
 * resolve to no published post become ghost nodes (ghost: true, no url) —
 * Obsidian-style placeholders for unpublished notes.
 *
 * publish.py emits an equivalent graph.json during the vault pipeline (CI);
 * run this script by hand to regenerate after editing posts locally:
 *
 *   bun scripts/graph-build.mjs
 */
import { readFileSync, readdirSync, writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';

const BLOG_DIR = 'src/content/blog';
const MANIFEST = 'src/data/posts-manifest.json';
const OUT = 'src/data/graph.json';

/** Minimal frontmatter reader: title line + tags block/inline list. */
function parseFrontmatter(text) {
	const m = text.match(/^---\r?\n([\s\S]*?)\r?\n---/);
	if (!m) return { title: '', tags: [], body: text };
	const fm = m[1];
	const body = text.slice(m[0].length);
	const title = (fm.match(/^title:[ \t]*(.*)$/m)?.[1] ?? '').trim();
	let tags = [];
	const block = fm.match(/^tags:[ \t]*\r?\n((?:[ \t]*-[ \t]*.*(?:\r?\n|$))+)/m);
	if (block) {
		tags = block[1].split('\n').map((l) => l.replace(/^\s*-\s*/, '').trim()).filter(Boolean);
	} else {
		const inline = fm.match(/^tags:[ \t]*\[([^\]]*)\]/m);
		if (inline) tags = inline[1].split(',').map((t) => t.trim().replace(/^["']|["']$/g, '')).filter(Boolean);
	}
	return { title, tags, body };
}

/** Mirror of publish.py's make_slug (Python \w ≈ unicode letters/digits/_). */
function makeSlug(stem) {
	return stem
		.replace(/\s+/g, '-')
		.replace(/[^\p{L}\p{N}_\-.]/gu, '');
}

/** Remove fenced code blocks and inline code spans so TOML `[[index]]` or
    quoted `` `[[wiki]]` `` literals never get mistaken for links. */
function stripCode(body) {
	return body
		.replace(/```[\s\S]*?```/g, '')
		.replace(/~~~[\s\S]*?~~~/g, '')
		.replace(/`[^`\n]*`/g, '');
}

/** Collect internal-link targets as raw (decoded) note stems + slugs. */
function extractLinkStems(body) {
	const src = stripCode(body);
	const out = new Set();
	// Rewritten form: (/blog/<slug>/...) — already a slug
	for (const m of src.matchAll(/\]\(\/blog\/([^)#\s/]+)[^)]*\)/g)) {
		out.add(JSON.stringify({ stem: decodeURIComponent(m[1]), slug: m[1] }));
	}
	// Raw markdown links to notes: (notes/AI/Some Name.md), skip http(s) and images
	for (const m of src.matchAll(/(?<!\!)\[[^\]]*\]\((?!https?:\/\/)([^)]+\.md)\)/g)) {
		const stem = decodeURIComponent(m[1]).split('/').pop().replace(/\.md$/, '');
		out.add(JSON.stringify({ stem, slug: makeSlug(stem) }));
	}
	// Raw wikilinks: [[Name]] / [[Name|display]] (not ![[embeds]])
	for (const m of src.matchAll(/(?<!!)\[\[([^\]|#]+)/g)) {
		const stem = m[1].trim();
		out.add(JSON.stringify({ stem, slug: makeSlug(stem) }));
	}
	return [...out].map(JSON.parse);
}

let manifest = {};
try {
	manifest = JSON.parse(readFileSync(MANIFEST, 'utf-8'));
} catch {
	console.warn(`warn: ${MANIFEST} missing/unreadable — titles fall back to frontmatter`);
}

const files = readdirSync(BLOG_DIR).filter((f) => f.endsWith('.md') || f.endsWith('.mdx'));
const nodes = [];
const links = [];

for (const file of files.sort()) {
	const id = file.replace(/\.(md|mdx)$/, '');
	const raw = readFileSync(join(BLOG_DIR, file), 'utf-8');
	const fm = parseFrontmatter(raw);
	const meta = manifest[id] ?? {};
	const title = meta.title || fm.title || id;
	const tags = meta.tags ?? fm.tags;
	nodes.push({
		id,
		title,
		group: ((tags ?? [])[0] ?? '').toLowerCase(),
		url: `/blog/${id}/`,
	});
	for (const target of extractLinkStems(fm.body)) {
		if (target.slug !== id) links.push({ source: id, target: target.slug });
	}
}

// Unresolved targets → ghost nodes (unpublished notes, Obsidian-style).
const ids = new Set(nodes.map((n) => n.id));
const unresolved = new Set(links.map((l) => l.target).filter((t) => !ids.has(t)));
// Ghost titles: recover the raw stem from whichever link mentioned it.
const ghostTitle = new Map();
for (const file of files.sort()) {
	const raw = readFileSync(join(BLOG_DIR, file), 'utf-8');
	for (const t of extractLinkStems(parseFrontmatter(raw).body)) {
		if (unresolved.has(t.slug) && !ghostTitle.has(t.slug)) ghostTitle.set(t.slug, t.stem);
	}
}
for (const t of unresolved) {
	nodes.push({ id: t, title: ghostTitle.get(t) ?? t, group: '', ghost: true });
}

// Deduplicate (a→b appearing twice in one body) via sorted pair key.
const seen = new Set();
const dedup = links.filter((l) => {
	const key = l.source < l.target ? `${l.source}→${l.target}` : `${l.target}→${l.source}`;
	if (seen.has(key)) return false;
	seen.add(key);
	return true;
});

mkdirSync('src/data', { recursive: true });
writeFileSync(OUT, JSON.stringify({ nodes, links: dedup }, null, 2) + '\n');
const ghosts = nodes.filter((n) => n.ghost).length;
console.log(`graph.json: ${nodes.length} nodes (${ghosts} ghost), ${dedup.length} links`);
