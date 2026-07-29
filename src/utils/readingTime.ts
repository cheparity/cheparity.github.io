import { readFileSync } from 'node:fs';
import { join } from 'node:path';

// Reading-speed constants. English is measured in words, CJK in characters,
// because a CJK character carries far more meaning than a Latin word.
const CJK_RE = /[一-鿿-ヿ가-]/g;
const EN_WPM = 200; // english words per minute
const CJK_CPM = 400; // CJK characters per minute

function minutesFromSource(text: string): number {
	// Drop YAML frontmatter so metadata never inflates the count.
	const body = text.replace(/^---[\s\S]*?---/, '');
	const cjk = (body.match(CJK_RE) || []).length;
	const enWords = body
		.replace(CJK_RE, ' ') // blank CJK so it doesn't form latin "words"
		.replace(/```[\s\S]*?```/g, ' ') // de-weight fenced code
		.replace(/!?\[[^\]]*\]\([^)]*\)/g, ' ') // drop link / image markup
		.replace(/[#>*_`~\-|]/g, ' ') // strip markdown punctuation
		.split(/\s+/)
		.filter(Boolean).length;
	const minutes = enWords / EN_WPM + cjk / CJK_CPM;
	return Math.max(1, Math.round(minutes));
}

// Resolve a post's source file by slug and estimate reading time. Runs at
// build time only. Falls back to 1 minute if the file can't be read.
export function readingMinutes(slug: string): number {
	const base = join(process.cwd(), 'src', 'content', 'blog', slug);
	for (const ext of ['.mdx', '.md', '.markdown']) {
		try {
			return minutesFromSource(readFileSync(base + ext, 'utf8'));
		} catch {
			// try the next extension
		}
	}
	return 1;
}
