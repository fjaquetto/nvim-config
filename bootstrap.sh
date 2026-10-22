#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$repo_dir"

if command -v omarchy-nvim-setup >/dev/null 2>&1; then
	echo "Recriando o link do tema do Omarchy..."
	omarchy-nvim-setup
else
	echo "omarchy-nvim-setup não encontrado; pulando o tema do Omarchy."
fi

if ! command -v nvim >/dev/null 2>&1; then
	echo "Neovim não encontrado. Instale o Neovim antes de continuar." >&2
	exit 1
fi

echo "Restaurando plugins a partir do lazy-lock.json..."
nvim --headless "+Lazy! restore" +qa

echo "Concluído. Abra o nvim e rode :checkhealth."
