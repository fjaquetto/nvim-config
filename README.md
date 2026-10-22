# nvim-config

Configuração pessoal do Neovim baseada em LazyVim + Omarchy, com Diffview e
`nvimdiff` para diffs lado a lado.

## Requisitos

- Neovim 0.11 ou mais recente (validado com 0.12.6)
- Git
- `ripgrep`
- `fd`
- `lazygit`
- Uma Nerd Font (o Omarchy já usa JetBrainsMono Nerd Font)
- Opcional: Omarchy, para o tema integrado

## Instalação em outra máquina

```bash
# 1. Preserve o config existente
mv ~/.config/nvim ~/.config/nvim.backup.$(date +%Y%m%d-%H%M%S)

# 2. Clone este repositório
git clone https://github.com/Fjaquetto/nvim-config.git ~/.config/nvim

# 3. Execute o bootstrap
cd ~/.config/nvim
./bootstrap.sh
```

O `bootstrap.sh`:

- recria o symlink do tema do Omarchy, quando disponível;
- instala os plugins nas versões fixadas em `lazy-lock.json`;
- deixa o Neovim pronto para o primeiro `:checkhealth`.

Depois abra o Neovim e rode:

```vim
:checkhealth
```

## Tema do Omarchy

O arquivo `lua/plugins/theme.lua` é um symlink específico da máquina e **não** é
versionado. Em uma máquina Omarchy, ele é recriado por:

```bash
omarchy-nvim-setup
```

Não use `omarchy-nvim-refresh` para isso: ele é destrutivo e sobrescreve o
config atual com o padrão do Omarchy.

## Servidores LSP

Os pacotes do Mason não são versionados pelo `lazy-lock.json`. Nesta máquina
estão instalados:

- `csharp-language-server`
- `lua-language-server`
- `rust-analyzer`
- `shfmt`
- `stylua`

No outro computador, instale pelo `:Mason` ou por:

```vim
:MasonInstall csharp-language-server lua-language-server rust-analyzer shfmt stylua
```

## Atualização

```bash
cd ~/.config/nvim
git pull
nvim --headless "+Lazy! restore" +qa
```

Se quiser atualizar os plugins de propósito:

```vim
:Lazy update
```

Depois confira o `lazy-lock.json` e faça um commit das versões novas.

## Rollback

Ver o estado atual:

```bash
cd ~/.config/nvim
git status
git log --oneline --decorate
```

Desfazer alterações locais:

```bash
git restore .
```

Voltar para uma tag estável:

```bash
git reset --hard stable-2026-10-21
nvim --headless "+Lazy! restore" +qa
```

Desfazer um commit sem apagar o histórico:

```bash
git revert <hash>
```

Testar uma versão antiga sem mexer na `main`:

```bash
git switch -c teste-config stable-2026-10-21
nvim
git switch main
git branch -D teste-config
```

Emergência, se o Neovim não abrir:

```bash
nvim -u NONE
```

## O que não é versionado

- `lua/plugins/theme.lua` (symlink gerado pelo Omarchy)
- Plugins em `~/.local/share/nvim/lazy`
- Pacotes do Mason em `~/.local/share/nvim/mason`
- Cache, shada e arquivos de swap
- Backups locais `*.bak.*`

## Atalhos úteis

| Atalho | Ação |
|---|---|
| `<leader>ghd` | Diff side-by-side do arquivo atual (Gitsigns) |
| `<leader>gv` | Diffview da working tree |
| `<leader>gV` | Diffview do último commit |
| `<leader>gH` | Histórico do arquivo atual |
| `<leader>gg` | LazyGit dentro do Neovim |

No LazyGit, `ctrl+t` abre o `nvimdiff` para o arquivo selecionado.
