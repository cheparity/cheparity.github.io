// Lifecycle helper for Astro View Transitions.
//
// A component <script> is a bundled module: it executes once and is NOT
// re-run on VT navigation — yet the DOM it wired up is discarded on every
// page swap. `onPage` runs `init` on the first load and after each
// navigation, handing it an AbortSignal that is aborted right before the
// *next* swap. Any listener registered with that signal is therefore torn
// down automatically, so N navigations never stack N listeners, and there
// is no manual bookkeeping (no per-component AbortController, no global
// "already registered" flag — the module running once already guarantees
// the page-load listener is registered exactly once).
export function onPage(init: (signal: AbortSignal) => void): void {
	let ac: AbortController | null = null;
	document.addEventListener('astro:page-load', () => {
		ac?.abort();
		ac = new AbortController();
		init(ac.signal);
	});
}
