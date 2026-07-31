/**
 * remark-math-fix — sanitize math node source so KaTeX renders cleanly.
 *
 * Three fixes applied to every math node in the mdast tree:
 *
 * 1. Strip invisible / zero-width code points (U+200B, U+2009, U+200C, U+200D,
 *    U+2060) that KaTeX reports as unknownSymbol.
 *
 * 2. Rewrite the Unicode double vertical bar ∥ (U+2225, used for norms) to the
 *    LaTeX control sequence \Vert so norms render as a double bar instead of a
 *    missing-glyph box.
 *
 * 3. Promote inline math ($…$) that contains a block-level environment
 *    (\begin{pmatrix}, \begin{cases}, etc.) to display mode.  Without this, a
 *    multi-row matrix inside inline math stretches the text line and strands
 *    surrounding prose at the formula's vertical middle.
 *
 * IMPORTANT: remark-math stamps the hast shape onto node.data at parse time
 * (hName, hProperties, hChildren).  mdast-util-to-hast honours data.h* OVER
 * node.type, and rehype-katex reads the rendered text from the hast element
 * (via toText), not from node.value.  So every mutation must touch both
 * node.value AND the corresponding data.h* fields.
 *
 * CJK prose written inside math (e.g. `$H_0$:犯罪嫌疑人无罪$`) is left as-is;
 * KaTeX is configured with `strict: false` so it renders via the text font
 * without build-time warnings.
 *
 * Patterns are built from code points (not literal chars or \u escapes) so the
 * source stays plain ASCII and is immune to editor / transport re-encoding.
 */
import { visit } from 'unist-util-visit';

interface HastText {
	type: 'text';
	value: string;
}

interface HastElement {
	type: 'element';
	tagName: string;
	properties: Record<string, unknown>;
	children: HastText[];
}

interface MathNode {
	type: string;
	value: string;
	data?: {
		hName?: string;
		hProperties?: { className?: string[] };
		hChildren?: (HastText | HastElement)[];
	};
}

// Invisible / zero-width code points: meaningless in math, reported by KaTeX as
// unknownSymbol. Stripping them is always safe.
//   U+200B ZWSP, U+2009 THIN SPACE, U+200C ZWNJ, U+200D ZWJ, U+2060 WJ
const INVISIBLE_CHARS = [0x200b, 0x2009, 0x200c, 0x200d, 0x2060]
	.map((cp) => String.fromCodePoint(cp))
	.join('');
const INVISIBLE_RE = new RegExp(`[${INVISIBLE_CHARS}]`, 'g');

// U+2225 PARALLEL TO (∥) → LaTeX \Vert (double vertical bar, i.e. norm).
const NORM = String.fromCodePoint(0x2225);
const VERT = String.fromCharCode(92) + 'Vert '; // \Vert + space (CS terminator)

// Block-level math environments. When one of these sits inside *inline* math
// ($…$) the rendered matrix / cases is several rows tall, which stretches the
// text line and strands the surrounding prose at the formula's vertical middle
// (open paren top, close paren bottom, text floating in the gap). A matrix is a
// block object, so we promote such a node inlineMath → math (display mode).
const DISPLAY_ENV_RE =
	/\\begin\{(pmatrix|bmatrix|vmatrix|Vmatrix|Bmatrix|matrix|cases|aligned|align|array|gathered|split)\}/;

export default function remarkMathFix() {
	return (tree: unknown) => {
		visit(tree, (node: MathNode) => {
			if (
				(node.type === 'math' || node.type === 'inlineMath') &&
				typeof node.value === 'string'
			) {
				// --- Clean invisible chars and rewrite ∥ → \Vert ---
				const cleaned = node.value
					.replace(INVISIBLE_RE, '')
					.split(NORM)
					.join(VERT);

				if (cleaned !== node.value) {
					node.value = cleaned;
					// Sync to hast children — mdast-util-to-hast reads from
					// data.hChildren, not node.value.
					const hc = node.data?.hChildren;
					if (hc && hc.length > 0 && hc[0].type === 'text') {
						(hc[0] as HastText).value = cleaned;
					}
				}

				// --- Promote inline math with block envs to display mode ---
				if (node.type === 'inlineMath' && DISPLAY_ENV_RE.test(node.value)) {
					node.type = 'math';
					// Rewrite the hast shape from inline (<code class="math-inline">)
					// to display (<pre><code class="math-display">).  rehype-katex
					// keys displayMode on the math-display class.
					node.data = {
						hName: 'pre',
						hChildren: [
							{
								type: 'element',
								tagName: 'code',
								properties: {
									className: ['language-math', 'math-display'],
								},
								children: [{ type: 'text', value: node.value }],
							},
						],
					};
				}
			}
		});
	};
}
