#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$repo_dir"

theme_link="$repo_dir/lua/plugins/theme.lua"
theme_file=""

for candidate in \
	"$HOME/.local/state/omarchy/current/theme/neovim.lua" \
	"$HOME/.config/omarchy/current/theme/neovim.lua"; do
	if [[ -f "$candidate" ]]; then
		theme_file="$candidate"
		break
	fi
done

if command -v omarchy-nvim-setup >/dev/null 2>&1; then
	echo "Recriando o link do tema do Omarchy..."
	omarchy-nvim-setup
fi

if [[ -n "$theme_file" ]]; then
	link_target="$(readlink -f "$theme_link" 2>/dev/null || true)"
	theme_target="$(readlink -f "$theme_file" 2>/dev/null || true)"
	if [[ -n "$link_target" && "$link_target" == "$theme_target" ]]; then
		echo "Link do tema do Omarchy já está atualizado."
	else
		if [[ -e "$theme_link" && ! -L "$theme_link" ]]; then
			backup="${theme_link}.bak.$(date +%Y%m%d-%H%M%S)"
			mv "$theme_link" "$backup"
			echo "Backup do tema estático salvo em $backup"
		fi
		ln -sfn "$theme_file" "$theme_link"
		echo "Tema do Omarchy vinculado: $theme_file"
	fi
else
	echo "Tema do Omarchy não encontrado; pulando o tema."
fi

if ! command -v nvim >/dev/null 2>&1; then
	echo "Neovim não encontrado. Instale o Neovim antes de continuar." >&2
	exit 1
fi

echo "Restaurando plugins a partir do lazy-lock.json..."
nvim --headless "+Lazy! restore" +qa

echo "Concluído. Abra o nvim e rode :checkhealth."
