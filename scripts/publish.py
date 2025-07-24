from pathlib import Path
import shutil
import frontmatter
import argparse

# 获取命令行参数
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

# 我还有把about等博客页面也用Obsidian管理的需求，放在Obsidian中的_page目录中。不需要的话删除跟page相关的代码即可
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

#! 危险操作：删除博客仓库中的原博客目录。然后将笔记目录中post字段为true的笔记，复制到博客仓库
# 这样设计的原因：如果有一部分博客想撤销发布，那不必手动修改博客目录，只需在笔记中把post字段删了，就会从博客目录中消失
shutil.rmtree(post_dest, ignore_errors=True)
shutil.rmtree(page_dest, ignore_errors=True)

# Copy files from Obsidian vaults to content folder
post_dest.mkdir(parents=True, exist_ok=True)
page_dest.mkdir(parents=True, exist_ok=True)

# 复制我的page页（不需要可以删了）
for item in (vault / page).iterdir():
    dst = page_dest / item.name
    if item.is_dir():
        shutil.copytree(item, dst, dirs_exist_ok=True)
    else:
        shutil.copy2(item, dst)

# 开始复制笔记
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
    del article[
        "post"
    ]  # 在博客仓库下，为了美观，删除笔记的post字段并保存（不删其实也可以）
    article["draft"] = False
    frontmatter.dump(article, dst)
