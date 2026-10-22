return {
  {
    "seblyng/roslyn.nvim",
    ft = "cs",
    opts = {},
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      -- Roslyn can report inlay hint columns past the end of a line while the
      -- buffer is being edited, which makes Neovim 0.12 throw an extmark error.
      -- Disable C# inlay hints until the server/runtime combination is fixed.
      inlay_hints = {
        exclude = { "vue", "cs" },
      },
      servers = {
        csharp_ls = { enabled = false },
        omnisharp = { enabled = false },
      },
    },
  },
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      for _, package in ipairs({ "netcoredbg", "roslyn-language-server" }) do
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
