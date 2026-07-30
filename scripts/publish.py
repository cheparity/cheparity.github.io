"""
publish.py — Obsidian vault → Astro blog content pipeline.

Reads notes from an Obsidian vault, filters by `post: true` frontmatter,
transforms frontmatter to match Astro's content schema, extracts the title
from the H1 heading, synthesizes a teaser when description is empty,
rewrites image paths, and copies attachments to public/assets/.
"""

import argparse
import re
import shutil
import urllib.parse
from pathlib import Path

import frontmatter
import json

# Collected image paths referenced in post bodies (for unused-asset cleanup).
image_paths: set[str] = set()


# ---------------------------------------------------------------------------
# Image path rewriting
# ---------------------------------------------------------------------------

def fix_paths(content: str) -> str:
    """Rewrite Obsidian attachment references to /assets/ public paths."""

    def process_attachment_path(match: re.Match, group_num: int = 1) -> str:
        path_str = match.group(group_num).strip()
        if path_str.startswith("attachments/"):
            rel_path = path_str[len("attachments/"):]
        else:
            rel_path = path_str
        image_paths.add(f"assets/{rel_path}")
        return f"/assets/{rel_path}"

    # ![](attachments/xxx.jpg) → ![](/assets/xxx.jpg)
    content = re.sub(
        r"!\[.*?\]\((\s*attachments/[^)]+)\)",
        lambda m: f"![]({process_attachment_path(m)})",
        content,
    )

    # <img src="attachments/xxx.jpg"> → <img src="/assets/xxx.jpg">
    content = re.sub(
        r'(<img[^>]+src=["\'])(attachments/[^"\']+)(["\'])',
        lambda m: f'{m.group(1)}{process_attachment_path(m, 2)}{m.group(3)}',
        content,
    )

    # ![[attachments/xxx.jpg]] → ![](/assets/xxx.jpg)
    content = re.sub(
        r"!\[\[(attachments/[^\]]+)\]\]",
        lambda m: f"![]({process_attachment_path(m)})",
        content,
    )

    return content


# ---------------------------------------------------------------------------
# Internal link rewriting
# ---------------------------------------------------------------------------

def make_slug(stem: str) -> str:
    """Generate a URL-friendly slug from a note filename stem."""
    slug = re.sub(r"\s+", "-", stem)
    slug = re.sub(r"[^\w\-.一-鿿]", "", slug)
    return slug


def fix_internal_links(
    content: str,
    slug_map: dict[str, str],
    note_dir: Path,
    vault: Path,
) -> str:
    """Rewrite Obsidian internal links to blog URLs.

    Handles:
      [text](relative/path.md)  — relative markdown links
      [[Note Name]]             — wikilinks (non-embed)

    Links to unpublished notes are degraded to plain text.
    """

    def resolve_path(raw: str) -> str | None:
        """Resolve a link target to a slug, or None if unpublished.

        Tries vault-root-relative first (Obsidian default), then
        note-directory-relative (for ./ or ../ links).
        """
        decoded = urllib.parse.unquote(raw.strip())
        decoded = decoded.lstrip("./")
        vault_root = vault.resolve()
        # Try vault-root-relative
        candidate = (vault_root / decoded).resolve()
        try:
            rel = candidate.relative_to(vault_root)
            slug = slug_map.get(rel.as_posix())
            if slug:
                return slug
        except ValueError:
            pass
        # Try note-directory-relative
        candidate = (note_dir / decoded).resolve()
        try:
            rel = candidate.relative_to(vault_root)
            return slug_map.get(rel.as_posix())
        except ValueError:
            return None

    # [text](xxx.md) — skip external URLs and image embeds
    def replace_md_link(m: re.Match) -> str:
        text, target = m.group(1), m.group(2)
        slug = resolve_path(target)
        if slug:
            return f"[{text}](/blog/{slug}/)"
        return text

    content = re.sub(
        r"\[([^\]]+)\]\((?!https?://)([^)]+\.md)\)",
        replace_md_link,
        content,
    )

    # [[Note Name]] or [[Note Name|display text]] — non-embed wikilinks
    def replace_wikilink(m: re.Match) -> str:
        target = m.group(1)
        display = m.group(2) if m.group(2) else target
        # Wikilinks use note name without path; search slug_map by stem
        for vault_rel, slug in slug_map.items():
            if Path(vault_rel).stem == target:
                return f"[{display}](/blog/{slug}/)"
        return display

    content = re.sub(
        r"(?<!!)\[\[([^\]|]+)(?:\|([^\]]+))?\]\]",
        replace_wikilink,
        content,
    )

    return content


# ---------------------------------------------------------------------------
# Title extraction from H1
# ---------------------------------------------------------------------------

_H1_RE = re.compile(r"^#\s+(.+)$", re.MULTILINE)


def extract_title_and_strip_h1(body: str) -> tuple[str, str]:
    """Return (title, body_without_h1). Falls back to empty string if no H1."""
    m = _H1_RE.search(body)
    if m:
        title = m.group(1).strip()
        # Remove the H1 line from the body
        body = body[:m.start()] + body[m.end():]
        # Clean up leading blank lines left behind
        body = body.lstrip("\n")
        return title, body
    return "", body


# ---------------------------------------------------------------------------
# Teaser synthesis
# ---------------------------------------------------------------------------

# Lines that are NOT prose paragraphs
_SKIP_PREFIXES = ("#", "|", ">", "!", "[[", "-", "*", "```", "<", "$$")
_SKIP_EXACT = ("---", "***", "___")
_LEADIN_SUFFIXES = (":", "：")
_MIN_TEASER_LEN = 20
_MAX_TEASER_LEN = 160
_SENTENCE_ENDS = ("。", "！", "？", ".", "!", "?")
_MAX_SCAN_BLOCKS = 6


def _is_prose_line(line: str) -> bool:
    """Check if a line looks like a prose paragraph (not structural)."""
    stripped = line.strip()
    if not stripped:
        return False
    if stripped in _SKIP_EXACT:
        return False
    for prefix in _SKIP_PREFIXES:
        if stripped.startswith(prefix):
            return False
    # Numbered list items: "1. ", "2) ", etc.
    if re.match(r"^\d+[.)]\s", stripped):
        return False
    return True


def synthesize_teaser(body: str) -> str:
    """Extract a teaser from the first qualifying prose paragraph in body."""
    lines = body.split("\n")
    blocks_scanned = 0
    current_para: list[str] = []
    in_math_block = False
    in_code_fence = False

    for line in lines:
        stripped = line.strip()

        # Track multi-line block boundaries
        if stripped.startswith("$$"):
            if in_math_block:
                in_math_block = False  # closing $$
            else:
                in_math_block = True   # opening $$
                # Flush current para if any
                if current_para:
                    blocks_scanned += 1
                    para_text = " ".join(current_para).strip()
                    current_para = []
                    if (
                        len(para_text) >= _MIN_TEASER_LEN
                        and not para_text.endswith(_LEADIN_SUFFIXES)
                    ):
                        return _truncate_teaser(para_text)
                    if blocks_scanned >= _MAX_SCAN_BLOCKS:
                        return ""
            continue

        if stripped.startswith("```"):
            in_code_fence = not in_code_fence
            if current_para:
                blocks_scanned += 1
                para_text = " ".join(current_para).strip()
                current_para = []
                if (
                    len(para_text) >= _MIN_TEASER_LEN
                    and not para_text.endswith(_LEADIN_SUFFIXES)
                ):
                    return _truncate_teaser(para_text)
                if blocks_scanned >= _MAX_SCAN_BLOCKS:
                    return ""
            continue

        # Skip lines inside multi-line blocks
        if in_math_block or in_code_fence:
            continue

        # Blank line = paragraph boundary
        if not stripped:
            if current_para:
                blocks_scanned += 1
                para_text = " ".join(current_para).strip()
                current_para = []
                if (
                    len(para_text) >= _MIN_TEASER_LEN
                    and not para_text.endswith(_LEADIN_SUFFIXES)
                ):
                    return _truncate_teaser(para_text)
                if blocks_scanned >= _MAX_SCAN_BLOCKS:
                    return ""
            continue

        if _is_prose_line(line):
            current_para.append(stripped)
        else:
            # Non-prose line breaks current paragraph accumulation
            if current_para:
                blocks_scanned += 1
                para_text = " ".join(current_para).strip()
                current_para = []
                if (
                    len(para_text) >= _MIN_TEASER_LEN
                    and not para_text.endswith(_LEADIN_SUFFIXES)
                ):
                    return _truncate_teaser(para_text)
                if blocks_scanned >= _MAX_SCAN_BLOCKS:
                    return ""

    # Handle last paragraph if file doesn't end with blank line
    if current_para:
        para_text = " ".join(current_para).strip()
        if (
            len(para_text) >= _MIN_TEASER_LEN
            and not para_text.endswith(_LEADIN_SUFFIXES)
        ):
            return _truncate_teaser(para_text)

    return ""


def _truncate_teaser(text: str) -> str:
    """Truncate to ~160 chars at nearest sentence terminator in the tail."""
    if len(text) <= _MAX_TEASER_LEN:
        return text
    # Look for a sentence end within the last 40 chars of the window
    window = text[:_MAX_TEASER_LEN]
    best = -1
    for i in range(len(window) - 1, max(len(window) - 40, 0), -1):
        if window[i] in _SENTENCE_ENDS:
            best = i
            break
    if best > 0:
        return window[: best + 1]
    return window + "…"


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def get_args():
    parser = argparse.ArgumentParser(
        description="Publish Obsidian notes to Astro blog content."
    )
    parser.add_argument(
        "--vault",
        type=str,
        help="Vault path (source) of Obsidian articles.",
        required=True,
    )
    parser.add_argument(
        "--page",
        type=str,
        default="pages",
        help="Page folder name in vault to skip (not copied to Astro).",
    )
    parser.add_argument(
        "--assets",
        type=str,
        default="attachments",
        help="Assets folder name in vault. Copied to public/assets/.",
    )
    return parser.parse_args()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    args = get_args()
    print(f"Vault path: {args.vault}")

    vault = Path(args.vault)
    vault_page = Path(args.page)
    vault_assets = Path(args.assets)

    # Astro output paths
    blog_dir = Path("src/content/blog")
    assets_dir = Path("public/assets")

    # Clean previous generated content
    shutil.rmtree(blog_dir, ignore_errors=True)
    blog_dir.mkdir(parents=True, exist_ok=True)

    # Copy attachments → public/assets/
    if (vault / vault_assets).exists():
        print(f"Copy assets dir {(vault / vault_assets).absolute()}")
        shutil.rmtree(assets_dir, ignore_errors=True)
        shutil.copytree(vault / vault_assets, assets_dir, dirs_exist_ok=True)

    # --- Pass 1: collect publishable notes and build slug map ---
    slug_map: dict[str, str] = {}  # vault-relative POSIX path → slug
    notes: list[tuple[Path, object]] = []  # (file_path, parsed_frontmatter)

    for item in vault.rglob("*.md"):
        if ".obsidian" in item.parts or vault_page in item.parts:
            continue
        article_fm = frontmatter.load(str(item))
        if "post" not in article_fm or not article_fm["post"]:
            continue
        rel = item.relative_to(vault).as_posix()
        slug_map[rel] = make_slug(item.stem)
        notes.append((item, article_fm))

    print(f"Found {len(notes)} publishable note(s), slug map has {len(slug_map)} entries")

    # --- Pass 2: transform and write each note ---
    for item, article_fm in notes:
        print(f"Processing note: {item.name}")

        # --- Body transformations ---
        body = article_fm.content

        # Extract title from H1
        title, body = extract_title_and_strip_h1(body)
        if not title:
            title = item.stem
            print(f"  No H1 found, using filename stem: {title}")

        # Fix image paths
        body = fix_paths(body)

        # Fix internal links (relative .md links and wikilinks)
        body = fix_internal_links(body, slug_map, item.parent, vault)

        # --- Frontmatter mapping ---
        new_meta: dict = {}

        new_meta["title"] = title

        # description: use vault value if present, else synthesize
        vault_desc = article_fm.get("description", "")
        if vault_desc and str(vault_desc).strip():
            new_meta["description"] = str(vault_desc).strip()
        else:
            teaser = synthesize_teaser(body)
            if teaser:
                new_meta["description"] = teaser
                print(f"  Synthesized teaser: {teaser[:60]}…")

        # pubDate from vault `date`
        if "date" in article_fm and article_fm["date"]:
            new_meta["pubDate"] = article_fm["date"]
        else:
            import datetime
            new_meta["pubDate"] = datetime.datetime.fromtimestamp(
                item.stat().st_mtime
            ).isoformat()
            print(f"  No date in frontmatter, using mtime")

        # updatedDate from vault `modified`
        if "modified" in article_fm and article_fm["modified"]:
            new_meta["updatedDate"] = article_fm["modified"]

        # tags: pass through
        if "tags" in article_fm and article_fm["tags"]:
            tags = article_fm["tags"]
            if isinstance(tags, str):
                tags = [t.strip() for t in tags.split(",") if t.strip()]
            new_meta["tags"] = tags

        # --- Write output file ---
        slug = slug_map[item.relative_to(vault).as_posix()]
        dst = blog_dir / f"{slug}.md"

        # Handle duplicate slugs
        counter = 1
        while dst.exists():
            dst = blog_dir / f"{slug}-{counter}.md"
            counter += 1

        # Build the final frontmatter + body
        post = frontmatter.Post(body, **new_meta)
        with open(dst, "w", encoding="utf-8") as f:
            frontmatter.dump(post, f)

        print(f"  → {dst}")

    # --- Emit posts-manifest.json for rehype-link-cards ---
    data_dir = Path("src/data")
    data_dir.mkdir(parents=True, exist_ok=True)
    manifest: dict[str, dict] = {}
    for item, article_fm in notes:
        slug = slug_map[item.relative_to(vault).as_posix()]
        title, _ = extract_title_and_strip_h1(article_fm.content)
        if not title:
            title = item.stem
        desc = str(article_fm.get("description", "") or "").strip()
        if not desc:
            desc = synthesize_teaser(article_fm.content)
        entry: dict[str, object] = {"title": title}
        if desc:
            entry["description"] = desc
        tags = article_fm.get("tags")
        if tags:
            if isinstance(tags, str):
                tags = [t.strip() for t in tags.split(",") if t.strip()]
            entry["tags"] = tags
        manifest[slug] = entry
    with open(data_dir / "posts-manifest.json", "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
    print(f"Wrote posts-manifest.json ({len(manifest)} entries)")

    # --- Clean unused assets ---
    global image_paths
    image_paths = {Path(p) for p in image_paths}

    if assets_dir.exists():
        removed = 0
        for item in assets_dir.rglob("*"):
            if item.is_file():
                rel = item.relative_to(assets_dir.parent)  # relative to public/
                if rel not in image_paths:
                    item.unlink()
                    removed += 1
        if removed:
            print(f"Removed {removed} unused asset(s)")

    print("Done.")


if __name__ == "__main__":
    main()
