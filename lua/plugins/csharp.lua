return {
  {
    "seblyng/roslyn.nvim",
    enabled = false,
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      -- Teste: csharp-ls também fornece inlay hints. Se o erro de extmark
      -- continuar, o problema é do runtime do Neovim, não do servidor.
      inlay_hints = {
        exclude = { "vue" },
      },
      servers = {
        csharp_ls = {
          cmd = (function()
            local global = vim.fn.expand("~/.dotnet/tools/csharp-ls")
            if vim.fn.executable(global) == 1 then
              return { global }
            end
            return { "csharp-ls" }
          end)(),
          -- csharp-ls only publishes inlayHintProvider when the client
          -- does not advertise dynamic registration for inlay hints.
          capabilities = (function()
            local override = {
              textDocument = {
                inlayHint = { dynamicRegistration = false },
              },
            }
            local ok, blink = pcall(require, "blink.cmp")
            if ok then
              return blink.get_lsp_capabilities(override)
            end
            return vim.tbl_deep_extend("force", vim.lsp.protocol.make_client_capabilities(), override)
          end)(),
          init_options = {
            AutomaticWorkspaceInit = true,
          },
        },
        roslyn_ls = { enabled = false },
        omnisharp = { enabled = false },
      },
    },
  },
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      for _, package in ipairs({ "netcoredbg", "csharp-language-server" }) do
        if not vim.tbl_contains(opts.ensure_installed, package) then
          table.insert(opts.ensure_installed, package)
        end
      end
      return opts
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      if not vim.tbl_contains(opts.ensure_installed, "c_sharp") then
        table.insert(opts.ensure_installed, "c_sharp")
      end
      return opts
    end,
  },
}
