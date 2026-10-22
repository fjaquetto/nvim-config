local ok, dap = pcall(require, "dap")
if not ok then
  return
end

local netcoredbg = vim.fn.exepath("netcoredbg")
if netcoredbg == "" then
  netcoredbg = vim.fn.stdpath("data") .. "/mason/bin/netcoredbg"
end

if vim.fn.executable(netcoredbg) ~= 1 then
  return
end

dap.adapters.netcoredbg = {
  type = "executable",
  command = netcoredbg,
  args = { "--interpreter=vscode" },
  options = {
    detached = false,
  },
}

dap.configurations.cs = {
  {
    type = "netcoredbg",
    name = "Launch .NET project (build)",
    request = "launch",
    program = function()
      local dll = require("config.dotnet").build_and_get_dll()
      return dll or dap.ABORT
    end,
    cwd = function()
      return require("config.dotnet").project_dir() or vim.fn.getcwd()
    end,
    env = {
      ASPNETCORE_ENVIRONMENT = "Development",
      DOTNET_ENVIRONMENT = "Development",
    },
    stopOnEntry = false,
  },
  {
    type = "netcoredbg",
    name = "Attach to .NET process",
    request = "attach",
    processId = function()
      return require("dap.utils").pick_process()
    end,
  },
}
