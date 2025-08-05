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

    return content, image_paths


parser = argparse.ArgumentParser()
parser.add_argument(
    "--content",
    type=str,
    help="Content path (destination), used by hugo blog.",
    required=True,
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
    help="Page folder name (source) to determine which folder in Obsidian Vault should be compied as content/page.",
)

parser.add_argument(
    "--assets",
    type=str,
    default="assets",
    help="Assets folder name (source) to store images, audio, etc. Will be directly moved to hugo's `static/assets`",
)

args = parser.parse_args()

vault = Path(args.vault)
content = Path(args.content)
page = Path(args.page)
assets = Path(args.assets)


#! [DANGEROUS] Remove everything in original hugo/content folder
shutil.rmtree(content / "posts", ignore_errors=True)
shutil.rmtree(content / "page", ignore_errors=True)

#! Copy files from Obsidian vaults to content folder
(content / "posts").mkdir(parents=True, exist_ok=True)
(content / "page").mkdir(parents=True, exist_ok=True)

# copy profile pages
for item in (vault / page).iterdir():
    dst = content / "page" / item.name
    if item.is_dir():
        shutil.copytree(item, dst, dirs_exist_ok=True)
    else:
        shutil.copy2(item, dst)

# copy notes
for item in Path(vault).rglob("*.md"):
    if ".obsidian" in item.parts or page in item.parts:
        continue
    article = frontmatter.load(str(item))
    if "post" not in article or not article["post"]:
        continue

    dst = (content / "page") / item.relative_to(vault)
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(item, dst)
    article = frontmatter.load(dst)
    del article["post"]
    article.content = fix_paths(article.content)
    article["draft"] = False
    frontmatter.dump(article, dst)

# copy images in Obsidian's assets/ to /static/assets
shutil.copytree(vault / assets, "static")