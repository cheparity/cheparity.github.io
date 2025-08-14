import argparse
import re
import shutil
from pathlib import Path

import frontmatter

image_paths = set()


def fix_paths(content: str):
    # rule: ![](assets/xxx.jpg) -> ![](/assets/xxx.jpg)
    content = re.sub(
        r"!\[.*?\]\((\s*assets/[^)]+)\)",
        lambda m: image_paths.add(m.group(1).strip()) or f"![](/{m.group(1).strip()})",
        content,
    )

    # rule: <img src="assets/xxx.jpg"> -> <img src="/assets/xxx.jpg">
    content = re.sub(
        r'<img([^>]+?)src="\s*(assets/[^"]+)"',
        lambda m: image_paths.add(m.group(2).strip())
        or f'<img{m.group(1)}src="/{m.group(2).strip()}"',
        content,
    )

    # rule: ![[assets/xxx.jpg]] -> ![](/assets/xxx.jpg)
    content = re.sub(
        r"!\[\[\s*assets/([^\]]+?)\s*\]\]",
        lambda m: image_paths.add(f"assets/{m.group(1).strip()}")
        or f"![](/assets/{m.group(1).strip()})",
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

    # copy images in Obsidian's assets/ to /static/assets
    if (vault / vault_assets).exists():
        print(f"Copy assets dir {(vault / vault_page).absolute()}")
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
    Path("static/assets").mkdir(parents=True, exist_ok=True)
    for item in Path("static/assets").iterdir():
        if str(item.relative_to(Path("static"))) not in image_paths:
            item.unlink()  # delete item


if __name__ == "__main__":
    main()
