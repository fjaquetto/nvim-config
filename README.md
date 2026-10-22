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
- .NET SDK 10 (para os recursos de C#)
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

## C# no NeoTree

Com um `.csproj` no projeto:

1. Selecione a pasta onde o arquivo deve ficar.
2. Pressione `N` no NeoTree.
3. Escolha o tipo: `class`, `interface`, `struct`, `record`, `record struct`
   ou `enum`.
4. Digite o nome do tipo.

O arquivo é criado na pasta selecionada. O namespace é calculado a partir do
`<RootNamespace>` do `.csproj` mais o caminho relativo da pasta. Exemplo:

```csharp
namespace MyApp.Features.Orders;

public class OrderService
{
}
```

O comando só funciona dentro de um projeto C#. Se você estiver na raiz de uma
solution com vários projetos, selecione uma pasta dentro do projeto desejado.

## Debug de .NET

O debug usa:

- `nvim-dap`
- `nvim-dap-ui`
- `nvim-dap-virtual-text`
- `netcoredbg`

Fluxo:

1. Abra um arquivo `.cs` do projeto.
2. `<leader>db` marca um breakpoint.
3. `<leader>dc` inicia o debug.
4. A configuração `Launch .NET project (build)` executa `dotnet build -c Debug`,
   localiza a DLL e inicia o `netcoredbg`. Se você iniciar o debug a partir de
   uma biblioteca, ela procura o projeto executável que referencia essa
   biblioteca e usa a DLL dele.
5. `<leader>du` mostra/esconde o DAP UI.
6. `<leader>dr` abre o REPL.
7. `<leader>dt` encerra a sessão.

Também existe a configuração `Attach to .NET process` para anexar a um processo
já em execução. Arquivos `.vscode/launch.json` também são lidos pelo `nvim-dap`.

## Servidores LSP e ferramentas

Os pacotes do Mason não são versionados pelo `lazy-lock.json`. Nesta máquina
estão instalados:

- `roslyn-language-server` (C#)
- `netcoredbg` (debug .NET)
- `lua-language-server`
- `rust-analyzer`
- `shfmt`
- `stylua`

No outro computador, instale pelo `:Mason` ou por:

```vim
:MasonInstall roslyn-language-server netcoredbg lua-language-server rust-analyzer shfmt stylua
```

O `roslyn-language-server` substitui o antigo `csharp-language-server` e o
OmniSharp na configuração atual.

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
git reset --hard stable-2026-10-22.1
nvim --headless "+Lazy! restore" +qa
```

Desfazer um commit sem apagar o histórico:

```bash
git revert <hash>
```

Testar uma versão antiga sem mexer na `main`:

```bash
git switch -c teste-config stable-2026-10-22.1
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
| `N` no NeoTree | Criar classe/interface/struct/record/enum C# |
| `<leader>db` | Alternar breakpoint |
| `<leader>dc` | Iniciar/continuar debug |
| `<leader>di` | Step into |
| `<leader>do` | Step out |
| `<leader>dO` | Step over |
| `<leader>du` | Mostrar/esconder DAP UI |
| `<leader>dr` | Abrir REPL do debug |
| `<leader>dt` | Encerrar sessão de debug |

No LazyGit, `ctrl+t` abre o `nvimdiff` para o arquivo selecionado.
