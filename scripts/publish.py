import argparse
import re
import shutil
from pathlib import Path

import frontmatter

image_paths = set()


def fix_paths(content: str):
    # Helper to process attachment paths
    def process_attachment_path(match, group_num=1):
        # Remove 'attachments/' prefix and any leading/trailing whitespace
        path_str = match.group(group_num).strip()
        # Remove 'attachments/' prefix
        if path_str.startswith('attachments/'):
            rel_path = path_str[len('attachments/'):]
        else:
            rel_path = path_str
        # Add to image_paths with 'assets/' prefix
        image_paths.add(f"assets/{rel_path}")
        # Return with '/assets/' prefix
        return f"/assets/{rel_path}"
    
    # rule: ![](attachments/xxx.jpg) -> ![](/assets/xxx.jpg)
    content = re.sub(
        r"!\[.*?\]\((\s*attachments/[^)]+)\)",
        lambda m: f"![]({process_attachment_path(m)})",
        content,
    )

    # rule: <img src="attachments/xxx.jpg"> -> <img src="/assets/xxx.jpg">
    content = re.sub(
        r'<img([^>]+?)src="\s*(attachments/[^"]+)"',
        lambda m: f'<img{m.group(1)}src="{process_attachment_path(m, 2)}"',
        content,
    )

    # rule: ![[attachments/xxx.jpg]] -> ![](/assets/xxx.jpg)
    content = re.sub(
        r"!\[\[\s*attachments/([^\]]+?)\s*\]\]",
        lambda m: f"![]({process_attachment_path(m)})",
        content,
    )

    return content


def get_args():
    parser = argparse.ArgumentParser()
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
        help="Page folder name (source) to determine which folder in Obsidian Vault should be compied as content/page.",
    )

    parser.add_argument(
        "--assets",
        type=str,
        default="attachments",
        help="Assets folder name (source) to store images, audio, etc. Will be directly moved to hugo's `static/assets`",
    )

    return parser.parse_args()


def main():
    args = get_args()
    print(f"Vault path: {args.vault}")

    vault = Path(args.vault)
    vault_page = Path(args.page)
    vault_assets = Path(args.assets)

    #! [DANGEROUS] Remove everything in original hugo/content folder
    shutil.rmtree("content/posts", ignore_errors=True)

    #! Copy files from Obsidian vaults to content folder
    # copy profile pages
    # `content/page` will be overide
    if (vault / vault_page).exists():
        print(f"Copy page dir {(vault / vault_page).absolute()}")
        shutil.copytree(vault / vault_page, "content/page", dirs_exist_ok=True)

    # copy images in Obsidian's attachments/ to /static/assets
    if (vault / vault_assets).exists():
        print(f"Copy assets dir {(vault / vault_assets).absolute()}")
        shutil.copytree(vault / vault_assets, "static/assets", dirs_exist_ok=True)

    # copy notes to `content/posts`
    for item in vault.rglob("*.md"):
        if ".obsidian" in item.parts or vault_page in item.parts:
            continue
        article_fm = frontmatter.load(str(item))
        if "post" not in article_fm or not article_fm["post"]:
            continue

        print(f"Copy notes {item.name}")
        dst = Path("content/posts") / item.relative_to(vault)
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(item, dst)
        article_fm = frontmatter.load(dst)
        article_fm.content = fix_paths(article_fm.content)
        # trim the front matters: del `post`, change `title` to filename and `draft: false`
        del article_fm["post"]
        #! hugo does not support chinese path
        article_fm["title"] = dst.stem
        print(f"Note stem: {dst.stem}")
        article_fm["draft"] = False
        frontmatter.dump(article_fm, dst)

    # print(image_paths)
    # delete unused assets
    global image_paths
    image_paths = {Path(p) for p in image_paths}

    for item in Path("static/assets").iterdir():
        if item.relative_to(Path("static")) not in image_paths:
            item.unlink()  # delete item


if __name__ == "__main__":
    main()
