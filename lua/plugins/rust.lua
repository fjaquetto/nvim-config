return {
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      for _, package in ipairs({ "rust-analyzer", "codelldb" }) do
        if not vim.tbl_contains(opts.ensure_installed, package) then
          table.insert(opts.ensure_installed, package)
        end
      end
      return opts
    end,
  },
  {
    "mrcjkb/rustaceanvim",
    opts = function(_, opts)
      opts.server = opts.server or {}
      local original_on_attach = opts.server.on_attach
      opts.server.on_attach = function(client, bufnr)
        if original_on_attach then
          original_on_attach(client, bufnr)
        end

        -- LazyVim maps Rust debuggables to <leader>dr, but that key is
        -- the DAP REPL for every other language. Use <leader>dc here so
        -- the debug workflow matches C# and <leader>dr stays the REPL.
        pcall(vim.keymap.del, "n", "<leader>dr", { buffer = bufnr })
        vim.keymap.set("n", "<leader>dc", function()
          vim.cmd.RustLsp("debuggables")
        end, { buffer = bufnr, desc = "Rust Debuggables" })
      end
      return opts
    end,
  },
}
