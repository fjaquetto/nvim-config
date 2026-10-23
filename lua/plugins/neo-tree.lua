local function project_kind(state)
  local node = state and state.tree and state.tree:get_node() or nil
  local path = node and node.path or vim.fn.getcwd()
  if not path or path == "" then
    path = vim.fn.getcwd()
  end
  path = vim.fs.normalize(path)
  local dir = vim.fn.isdirectory(path) == 1 and path or vim.fs.dirname(path)

  if vim.bo.filetype == "rust" then
    return "rust"
  end
  if vim.bo.filetype == "cs" then
    return "csharp"
  end

  local cargo = vim.fs.find("Cargo.toml", {
    upward = true,
    path = dir,
    type = "file",
  })[1]
  local csproj = vim.fs.find(function(name)
    return name:match("%.csproj$") ~= nil
  end, {
    upward = true,
    path = dir,
    type = "file",
  })[1]

  if cargo and csproj then
    return #cargo <= #csproj and "rust" or "csharp"
  end
  if cargo then
    return "rust"
  end
  if csproj then
    return "csharp"
  end
  return nil
end

return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = function(_, opts)
    opts.filesystem = opts.filesystem or {}
    opts.filesystem.window = opts.filesystem.window or {}
    opts.filesystem.window.mappings = opts.filesystem.window.mappings or {}
    opts.filesystem.window.mappings["N"] = function(state)
      local kind = project_kind(state)
      if kind == "rust" then
        require("config.rust").new_item(state)
      elseif kind == "csharp" then
        require("config.csharp").new_type(state)
      else
        vim.notify("[neo-tree] nenhum projeto C# (.csproj) ou Rust (Cargo.toml) encontrado", vim.log.levels.WARN)
      end
    end
    return opts
  end,
}
