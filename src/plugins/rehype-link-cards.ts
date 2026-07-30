/**
 * rehype-link-cards — injects Tufte-style margin cards for every link.
 *
 * External links: favicon + link text + domain
 * Internal links (/blog/...): icon + title + description from posts-manifest.json
 *
 * Cards float right into the margin column, stacking vertically via clear:right.
 * Hidden on narrow viewports where the margin collapses.
 */
import { readFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { visit } from 'unist-util-visit';
import type { Element, Root, Content } from 'hast';

interface PostMeta {
	title: string;
	description?: string;
	tags?: string[];
}

type Manifest = Record<string, PostMeta>;

function loadManifest(): Manifest {
	const candidates = [
		resolve(process.cwd(), 'src/data/posts-manifest.json'),
		resolve(process.cwd(), '../src/data/posts-manifest.json'),
	];
	for (const p of candidates) {
		if (existsSync(p)) {
			return JSON.parse(readFileSync(p, 'utf-8')) as Manifest;
		}
	}
	return {};
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

function makeCard(opts: {
	isInternal: boolean;
	title: string;
	subtitle: string;
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
		tagName: 'span',
		properties: {
			className: ['link-card', opts.isInternal ? 'link-card--internal' : 'link-card--external'],
			'aria-hidden': 'true',
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
			const href = node.properties?.href;
			if (!href || typeof href !== 'string') return;
			if (href.startsWith('#')) return;

			const isExternal = href.startsWith('http://') || href.startsWith('https://');
			const isInternal = href.startsWith('/blog/');
			if (!isExternal && !isInternal) return;

			const linkText = getTextContent(node);
			if (!linkText) return;

			let card: Element;

			if (isInternal) {
				const slug = href.replace(/^\/blog\//, '').replace(/\/$/, '');
				const meta = manifest[slug];
				const title = meta?.title || linkText;
				const desc = meta?.description || '';
				const subtitle = desc.length > 80 ? desc.slice(0, 80) + '…' : (desc || 'Internal link');
				card = makeCard({ isInternal: true, title, subtitle });
			} else {
				let domain = '';
				try { domain = new URL(href).hostname; } catch { return; }
				card = makeCard({ isInternal: false, title: linkText, subtitle: domain, domain });
			}

			parent.children.splice(index + 1, 0, card);
		});
	};
}
