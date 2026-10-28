-- Options are automatically loaded before lazy.nvim startup.
require("config.remote_clipboard").setup()

vim.opt.relativenumber = false
vim.g.autoformat = true

-- Side-by-side diffs by default (Gitsigns, :diffsplit, nvim -d)
vim.opt.diffopt:append("vertical")
vim.opt.diffopt:append("algorithm:histogram")
