// @ts-check

import mdx from '@astrojs/mdx';
import sitemap from '@astrojs/sitemap';
import tailwind from '@astrojs/tailwind';
import { defineConfig } from 'astro/config';
import remarkCallout from '@r4ai/remark-callout';
import remarkMath from 'remark-math';
import rehypeKatex from 'rehype-katex';
import expressiveCode from 'astro-expressive-code';
import pagefind from 'astro-pagefind';
import rehypeLinkCards from './src/plugins/rehype-link-cards.ts';

// https://astro.build/config
export default defineConfig({
	site: 'https://niyuta.eu.org',
	integrations: [
		tailwind({
			nesting: true,
		}),
		expressiveCode({
			themes: ['github-dark'],
			styleOverrides: {
				// Route code blocks through the site's --font-mono var so the
				// chosen mono face (see global.css) applies to highlighted code.
				codeFontFamily: 'var(--font-mono), ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace',
				// EC's default 0.85rem renders ~11px at our 13px root — too small
				// beside the 1.4rem prose. Lift block code to a comfortable size.
				codeFontSize: '1.1rem',
				codeLineHeight: '1.5',
			},
		}),
		mdx(),
		sitemap(),
		pagefind()
	],
	markdown: {
		remarkPlugins: [remarkCallout, remarkMath],
		rehypePlugins: [rehypeKatex, rehypeLinkCards],
	},
});
