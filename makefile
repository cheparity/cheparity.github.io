#! Only for debug and run locally, not for github workflow usage

# Variables
VAULT_PATH = D:\Workspace\MirrorBasalt\MindHub
PYTHON = python
HUGO = hugo

# Default target
.PHONY: all
all: publish preview

# Publish Obsidian notes
.PHONY: publish
publish:
    uv run --no-project --with python-frontmatter ./scripts/publish.py --vault $(VAULT_PATH)

# Start Hugo preview server
.PHONY: preview
preview:
    $(HUGO) server

# Clean generated files (add specific paths if needed)
.PHONY: clean
clean:
    $(HUGO) clean

# Help target
.PHONY: help
help:
    @echo "Available targets:"
    @echo "  all     - Run publish and preview"
    @echo "  publish - Convert Obsidian notes"
    @echo "  preview - Start Hugo preview server"
    @echo "  clean   - Clean generated files"