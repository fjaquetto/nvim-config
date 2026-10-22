return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = function(_, opts)
    opts.filesystem = opts.filesystem or {}
    opts.filesystem.window = opts.filesystem.window or {}
    opts.filesystem.window.mappings = opts.filesystem.window.mappings or {}
    opts.filesystem.window.mappings["N"] = function(state)
      require("config.csharp").new_type(state)
    end
    return opts
  end,
}
