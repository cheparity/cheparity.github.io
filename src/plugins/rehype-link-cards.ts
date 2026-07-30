/**
 * rehype-link-cards — injects Tufte-style margin cards for every link.
 *
 * External links: favicon + link text + domain
 * Internal links (published /blog/... or raw Obsidian notes/...md): icon + title + description from posts-manifest.json
 *
 * Cards float right into the margin column, stacking vertically via clear:right.
 * Hidden on narrow viewports where the margin collapses.
 */
import { readFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { visit, SKIP } from 'unist-util-visit';
import type { Element, Root, Content } from 'hast';

interface PostMeta {
	title: string;
	description?: string;
	tags?: string[];
}

type Manifest = Record<string, PostMeta>;

function loadManifest(): Manifest {
	// process.cwd() is the repo root in both Astro's config load and the Vite
	// SSR worker; walk up defensively in case a runner relocates it.
	let dir = process.cwd();
	for (;;) {
		const p = resolve(dir, 'src/data/posts-manifest.json');
		if (existsSync(p)) {
			return JSON.parse(readFileSync(p, 'utf-8')) as Manifest;
		}
		const parent = resolve(dir, '..');
		if (parent === dir) return {};
		dir = parent;
	}
}

function getTextContent(node: Element): string {
	const parts: string[] = [];
	const walk = (n: Content) => {
		if (n.type === 'text') parts.push(n.value);
		if ('children' in n) (n.children as Content[]).forEach(walk);
	};
	walk(node as Content);
	return parts.join('').trim();
}

function cleanDesc(s: string): string {
	return s
		.replace(/\$\$[\s\S]*?\$\$/g, ' ')
		.replace(/\$[^$\n]*\$/g, ' ')
		.replace(/\$[^$\n]*$/g, ' ')
		.replace(/\[([^\]]*)\]\([^)]*\)/g, '$1')
		.replace(/\[\[([^\]|]*)(?:\|([^\]]*))?\]\]/g, (_, _t, a) => a ?? _t)
		.replace(/[*_`~]/g, '')
		.replace(/\s+/g, ' ')
		.replace(/\s+([，。、；：！？.,;:!?])/g, '$1')
		.replace(/([，。、；：！？.,;:!?])\1+/g, '$1')
		.replace(/^[，。、；：！？.,;:!\s]+/, '')
		.trim();
}

function makeCard(opts: {
	isInternal: boolean;
	title: string;
	subtitle: string;
	href: string;
	domain?: string;
}): Element {
	const iconOrFavicon: Element = opts.isInternal
		? {
			type: 'element',
			tagName: 'span',
			properties: { className: ['link-card-icon'], 'aria-hidden': 'true' },
			children: [{ type: 'text', value: '§' }],
		}
		: {
			type: 'element',
			tagName: 'img',
			properties: {
				className: ['link-card-favicon'],
				src: `https://www.google.com/s2/favicons?domain=${opts.domain}&sz=32`,
				alt: '',
				width: 16,
				height: 16,
				loading: 'lazy',
				decoding: 'async',
			},
			children: [],
		};

	return {
		type: 'element',
		tagName: 'a',
		properties: {
			className: ['link-card', opts.isInternal ? 'link-card--internal' : 'link-card--external'],
			href: opts.href,
			target: opts.isInternal ? undefined : '_blank',
			rel: opts.isInternal ? undefined : 'noopener noreferrer',
		},
		children: [
			iconOrFavicon,
			{
				type: 'element',
				tagName: 'span',
				properties: { className: ['link-card-body'] },
				children: [
					{
						type: 'element',
						tagName: 'span',
						properties: { className: ['link-card-title'] },
						children: [{ type: 'text', value: opts.title }],
					},
					{
						type: 'element',
						tagName: 'span',
						properties: { className: ['link-card-subtitle'] },
						children: [{ type: 'text', value: opts.subtitle }],
					},
				],
			},
		],
	};
}

export default function rehypeLinkCards() {
	const manifest = loadManifest();

	return (tree: Root) => {
		visit(tree, 'element', (node, index, parent) => {
			if (node.tagName !== 'a' || !parent || index == null) return;
			const cls = node.properties?.className;
			if (Array.isArray(cls) && cls.includes('link-card')) return SKIP;
			const href = node.properties?.href;
			if (!href || typeof href !== 'string') return;
			if (href.startsWith('#')) return;

			const isExternal = href.startsWith('http://') || href.startsWith('https://');
			const isInternal = href.startsWith('/blog/') || href.startsWith('notes/');
			if (!isExternal && !isInternal) return;

			const linkText = getTextContent(node);
			if (!linkText) return;

			let card: Element;

			if (isInternal) {
				// Reduce the href to a note stem, then resolve it against the manifest
				// case-insensitively. The manifest key is the canonical slug (written by
				// publish.py alongside the post files), so linking to it always hits a route.
				const stem = href.startsWith('/blog/')
					? href.replace(/^\/blog\//, '').replace(/\/$/, '')
					: decodeURIComponent(href).split('/').pop()!.replace(/\.md$/, '');
				const norm = stem.replace(/\s+/g, '-').toLowerCase();
				const key = Object.keys(manifest).find((k) => k.toLowerCase() === norm);
				const meta = key ? manifest[key] : undefined;
				const target = key ? `/blog/${key}/` : href;
				const title = meta?.title || linkText;
				const desc = cleanDesc(meta?.description || '');
				const subtitle = desc.length > 120 ? desc.slice(0, 120).trimEnd() + '…' : (desc || '内部笔记');
				card = makeCard({ isInternal: true, title, subtitle, href: target });
			} else {
				let domain = '';
				try { domain = new URL(href).hostname; } catch { return; }
				card = makeCard({ isInternal: false, title: linkText, subtitle: domain, domain, href });
			}

			parent.children.splice(index + 1, 0, card);
			return [SKIP, index + 2];
		});
	};
}
