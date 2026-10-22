local M = {}

local dotnet = require("config.dotnet")

local type_options = {
  { label = "class", value = "class" },
  { label = "interface", value = "interface" },
  { label = "struct", value = "struct" },
  { label = "record", value = "record" },
  { label = "record struct", value = "record struct" },
  { label = "enum", value = "enum" },
}

local valid_types = {}
for _, option in ipairs(type_options) do
  valid_types[option.value] = true
end

local function notify(message, level)
  vim.notify("[csharp] " .. message, level or vim.log.levels.INFO)
end

local function directory_for(state)
  local node = state and state.tree and state.tree:get_node() or nil
  local path = node and node.path or (state and state.path)
  if not path or path == "" then
    return vim.fn.getcwd()
  end

  path = vim.fs.normalize(path)
  if vim.fn.isdirectory(path) == 1 then
    return path
  end
  return vim.fs.dirname(path)
end

local function sanitize_identifier(part)
  part = part:gsub("[^%w_]", "_")
  if part:match("^%d") then
    part = "_" .. part
  end
  return part
end

function M.namespace_for(dir)
  local info = dotnet.project_info(dir)
  if not info then
    return nil
  end

  dir = vim.fs.normalize(dir)
  if dir == info.project_dir then
    return info.root_namespace
  end

  local prefix = info.project_dir .. "/"
  if dir:sub(1, #prefix) ~= prefix then
    return info.root_namespace
  end

  local parts = {}
  for part in dir:sub(#prefix + 1):gmatch("[^/]+") do
    table.insert(parts, sanitize_identifier(part))
  end

  if #parts == 0 then
    return info.root_namespace
  end

  return info.root_namespace .. "." .. table.concat(parts, ".")
end

local function template(kind, name, namespace)
  local declaration = ({
    class = "public class " .. name,
    interface = "public interface " .. name,
    struct = "public struct " .. name,
    record = "public record " .. name .. ";",
    ["record struct"] = "public record struct " .. name,
    enum = "public enum " .. name,
  })[kind]

  local lines = {
    "namespace " .. namespace .. ";",
    "",
    declaration,
  }
  if kind ~= "record" then
    table.insert(lines, "{")
    table.insert(lines, "}")
  end

  return lines
end

function M.create_type(kind, name, dir, namespace)
  if not valid_types[kind] then
    return nil, "tipo C# inválido: " .. tostring(kind)
  end

  name = vim.trim(name or "")
  if name == "" then
    return nil, "o nome não pode ficar vazio"
  end
  if not name:match("^[A-Za-z_][A-Za-z0-9_]*$") then
    return nil, "nome inválido para um identificador C#: " .. name
  end

  dir = vim.fs.normalize(dir or "")
  if dir == "" or vim.fn.isdirectory(dir) == 0 then
    return nil, "a pasta de destino não existe: " .. dir
  end

  namespace = namespace or M.namespace_for(dir)
  if not namespace or namespace == "" then
    return nil, "não consegui determinar o namespace do projeto"
  end

  local path = dir .. "/" .. name .. ".cs"
  if vim.fn.filereadable(path) == 1 or vim.fn.isdirectory(path) == 1 then
    return nil, "o arquivo já existe: " .. path
  end

  if vim.fn.writefile(template(kind, name, namespace), path) ~= 0 then
    return nil, "não consegui escrever o arquivo: " .. path
  end

  return path
end

function M.new_type(state)
  local dir = directory_for(state)
  local info = dotnet.project_info(dir)
  if not info then
    notify("não encontrei um projeto C# (.csproj) a partir desta pasta.", vim.log.levels.WARN)
    return
  end

  local namespace = M.namespace_for(dir)

  vim.ui.select(type_options, {
    prompt = "Novo tipo C#",
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if not choice then
      return
    end

    local prompt = "Nome do " .. choice.label .. ": "
    if choice.value == "interface" then
      prompt = prompt .. "(ex.: IOrderService) "
    end

    vim.ui.input({ prompt = prompt }, function(name)
      if not name or name == "" then
        return
      end

      local path, err = M.create_type(choice.value, name, dir, namespace)
      if not path then
        notify(err, vim.log.levels.ERROR)
        return
      end

      local fs_commands = package.loaded["neo-tree.sources.filesystem.commands"]
      if fs_commands then
        fs_commands.refresh(state)
      end

      pcall(vim.cmd, "wincmd p")
      vim.cmd.edit(vim.fn.fnameescape(path))
    end)
  end)
end

M.types = type_options

return M
