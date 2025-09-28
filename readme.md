# README

## Obsidian notes publishing scripts

```bash
uv run --no-project --with python-frontmatter .\scripts\publish.py --vault D:\Workspace\MirrorBasalt\MindHub\                    
```

## Hugo

Preview:

```bash
hugo server
```

## Debugging notes

If met style error, you should check `config/_default/hugo.toml`:

```toml
#! Switching to "/" when debugging locally
baseURL = "https://cheparity.github.io/"
```
