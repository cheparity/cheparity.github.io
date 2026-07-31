/**
 * remark-code-lang — alias fenced-code languages the highlighter doesn't ship.
 *
 * astro-expressive-code (Shiki) has no `tmux` grammar; an unknown lang makes it
 * fall back to plain text *and* emit a build warning. tmux config is shell-like,
 * so aliasing it to `bash` both silences the warning and gives real highlighting.
 *
 * Runs as a user remark plugin, i.e. before the integration's highlighter, so the
 * rewritten lang is what gets highlighted.
 */
import { visit } from 'unist-util-visit';

interface CodeNode {
	type: string;
	lang: string | null;
}

const LANG_ALIAS: Record<string, string> = {
	tmux: 'bash',
};

export default function remarkCodeLang() {
	return (tree: unknown) => {
		visit(tree, 'code', (node: CodeNode) => {
			if (node.lang && node.lang in LANG_ALIAS) {
				node.lang = LANG_ALIAS[node.lang];
			}
		});
	};
}
