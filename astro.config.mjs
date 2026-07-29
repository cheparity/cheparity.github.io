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

// https://astro.build/config
export default defineConfig({
	site: 'https://niyuta.eu.org',
	integrations: [
		tailwind({
			nesting: true, // Enable nested CSS syntax for callout styles
		}),
		expressiveCode({
			// Use only GitHub Dark theme for all code blocks
			themes: ['github-dark'],
		}),
		mdx(),
		sitemap(),
		pagefind()
	],
	markdown: {
		// Add remark plugins for Obsidian callout support
		remarkPlugins: [remarkCallout, remarkMath],
		rehypePlugins: [rehypeKatex],
	},
});
