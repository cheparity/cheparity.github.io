from pathlib import Path
import shutil
import frontmatter
import argparse

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
    default="_pages",
    help="Page folder name (source) to determine which folder in Obsidian Vault should be compied as content/page.",
)
args = parser.parse_args()

vault = Path(args.vault)
content = Path(args.content)
page = Path(args.page)

post_dest = content / "posts"
page_dest = content / "page"

# Delete content folder
shutil.rmtree(post_dest, ignore_errors=True)
shutil.rmtree(page_dest, ignore_errors=True)

# Copy files from Obsidian vaults to content folder
post_dest.mkdir(parents=True, exist_ok=True)
page_dest.mkdir(parents=True, exist_ok=True)
for item in (vault / page).iterdir():
    dst = page_dest / item.name
    if item.is_dir():
        shutil.copytree(item, dst, dirs_exist_ok=True)
    else:
        shutil.copy2(item, dst)

for root in Path(vault).rglob("*.md"):
    if ".obsidian" in root.parts or page in root.parts:
        continue
    article = frontmatter.load(str(root))
    if "post" not in article.keys() or article["post"] == False:
        continue

    dst = post_dest / root.relative_to(vault)
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(root, dst)
    article = frontmatter.load(dst)
    del article["post"]
    article["draft"] = False
    frontmatter.dump(article, dst)
