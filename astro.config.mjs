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
import remarkMathFix from './src/plugins/remark-math-fix.ts';
import remarkCodeLang from './src/plugins/remark-code-lang.ts';

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
				// Scale code with the shared reading size on desktop and mobile.
				codeFontSize: 'calc(var(--reading-font-size) * 0.85)',
				codeLineHeight: '1.5',
			},
		}),
		mdx(),
		sitemap(),
		pagefind({
			indexConfig: {
				// Index page content only — keeps header nav, footers, and the
				// search modal itself out of excerpts and result titles.
				rootSelector: 'main',
			},
		})
	],
	markdown: {
		remarkPlugins: [remarkCallout, remarkMath, remarkMathFix, remarkCodeLang],
		rehypePlugins: [[rehypeKatex, { strict: false }], rehypeLinkCards],
	},
});
