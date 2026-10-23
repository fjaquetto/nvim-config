local M = {}

local item_options = {
  { label = "module", value = "module" },
  { label = "struct", value = "struct" },
  { label = "enum", value = "enum" },
  { label = "trait", value = "trait" },
}

local function notify(message, level)
  vim.notify("[rust] " .. message, level or vim.log.levels.INFO)
end

local function read_lines(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  return ok and lines or nil
end

local function file_exists(path)
  return vim.fn.filereadable(path) == 1
end

local function selected_dir(state)
  local node = state and state.tree and state.tree:get_node() or nil
  local path = node and node.path or (state and state.path)
  if not path or path == "" then
    return vim.fs.normalize(vim.fn.getcwd())
  end

  path = vim.fs.normalize(path)
  if vim.fn.isdirectory(path) == 1 then
    return path
  end
  return vim.fs.dirname(path)
end

local function find_cargo_root(dir)
  local cargo_toml = vim.fs.find("Cargo.toml", {
    upward = true,
    path = dir,
    type = "file",
  })[1]
  return cargo_toml and vim.fs.dirname(cargo_toml) or nil
end

function M.has_project(state)
  local dir = selected_dir(state)
  return dir ~= nil and find_cargo_root(dir) ~= nil
end

local function to_snake_case(name)
  local result = name:gsub("(%u)(%u%l)", "%1_%2")
  result = result:gsub("(%l)(%u)", "%1_%2")
  result = result:gsub("(%d)(%u)", "%1_%2")
  return result:lower()
end

local function is_mod_line(line)
  return line:match("^%s*mod%s+") ~= nil
    or line:match("^%s*pub%s+mod%s+") ~= nil
    or line:match("^%s*pub%b()%s+mod%s+") ~= nil
end

local function add_mod_declaration(parent_file, module_name)
  local lines = read_lines(parent_file)
  if not lines then
    return false
  end

  local escaped = vim.pesc(module_name)
  for _, line in ipairs(lines) do
    if line:match("mod%s+" .. escaped .. "%s*;") then
      return true
    end
  end

  local insert_at = #lines + 1
  for index, line in ipairs(lines) do
    if is_mod_line(line) then
      insert_at = index + 1
    end
  end

  local is_crate_root = vim.fs.basename(parent_file) == "lib.rs" and vim.fs.dirname(parent_file):match("/src$") ~= nil
  local keyword = is_crate_root and "pub mod " or "mod "
  if insert_at == #lines + 1 and #lines > 0 and lines[#lines] ~= "" then
    table.insert(lines, "")
  end
  table.insert(lines, insert_at, keyword .. module_name .. ";")

  return vim.fn.writefile(lines, parent_file) == 0
end

local function module_file_for_dir(dir, crate_root)
  local src = vim.fs.normalize(crate_root .. "/src")
  dir = vim.fs.normalize(dir)

  if dir == src then
    local lib = src .. "/lib.rs"
    local main = src .. "/main.rs"
    if file_exists(lib) then
      return lib
    end
    if file_exists(main) then
      return main
    end
    return nil
  end

  local mod_rs = dir .. "/mod.rs"
  if file_exists(mod_rs) then
    return mod_rs
  end

  local sibling = vim.fs.dirname(dir) .. "/" .. vim.fs.basename(dir) .. ".rs"
  if file_exists(sibling) then
    return sibling
  end

  return nil
end

local function ensure_module_file(dir, crate_root)
  local existing = module_file_for_dir(dir, crate_root)
  if existing then
    return existing
  end

  local src = vim.fs.normalize(crate_root .. "/src")
  dir = vim.fs.normalize(dir)
  if dir == src or dir:sub(1, #src + 1) ~= src .. "/" then
    return nil
  end

  local parent = vim.fs.dirname(dir)
  local parent_file = ensure_module_file(parent, crate_root)
  if not parent_file then
    return nil
  end

  local mod_rs = dir .. "/mod.rs"
  if not file_exists(mod_rs) then
    if vim.fn.writefile({ "//! " .. vim.fs.basename(dir) .. " module.", "" }, mod_rs) ~= 0 then
      return nil
    end
  end

  if not add_mod_declaration(parent_file, vim.fs.basename(dir)) then
    return nil
  end

  return mod_rs
end

local function template(kind, name)
  if kind == "module" then
    return { "//! " .. name .. " module.", "" }
  end
  if kind == "struct" then
    return { "#[derive(Debug)]", "pub struct " .. name .. " {", "}", "" }
  end
  if kind == "enum" then
    return { "#[derive(Debug)]", "pub enum " .. name .. " {", "}", "" }
  end
  if kind == "trait" then
    return { "pub trait " .. name .. " {", "}", "" }
  end
  return nil
end

function M.create_item(kind, name, dir)
  name = vim.trim(name or "")
  dir = vim.fs.normalize(dir or "")

  if kind ~= "module" and kind ~= "struct" and kind ~= "enum" and kind ~= "trait" then
    return nil, "tipo Rust inválido: " .. tostring(kind)
  end
  if dir == "" or vim.fn.isdirectory(dir) == 0 then
    return nil, "a pasta de destino não existe: " .. dir
  end

  local cargo_root = find_cargo_root(dir)
  if not cargo_root then
    return nil, "não encontrei um Cargo.toml a partir desta pasta"
  end

  local src = vim.fs.normalize(cargo_root .. "/src")
  if dir ~= src and dir:sub(1, #src + 1) ~= src .. "/" then
    return nil, "a pasta não está dentro de src/ da crate"
  end

  local module_name
  if kind == "module" then
    if not name:match("^[a-z_][a-z0-9_]*$") then
      return nil, "nome de módulo inválido (use snake_case): " .. name
    end
    module_name = name
  else
    if not name:match("^[A-Z][A-Za-z0-9_]*$") then
      return nil, "nome de tipo inválido (use PascalCase): " .. name
    end
    module_name = to_snake_case(name)
  end

  local parent_file = ensure_module_file(dir, cargo_root)
  if not parent_file then
    return nil, "não consegui determinar o arquivo do módulo pai"
  end

  local path = dir .. "/" .. module_name .. ".rs"
  if file_exists(path) then
    return nil, "o arquivo já existe: " .. path
  end

  local lines = template(kind, name)
  if not lines then
    return nil, "template não encontrado para " .. kind
  end
  if vim.fn.writefile(lines, path) ~= 0 then
    return nil, "não consegui escrever o arquivo: " .. path
  end
  if not add_mod_declaration(parent_file, module_name) then
    return nil, "arquivo criado, mas não consegui adicionar `mod " .. module_name .. ";` em " .. parent_file
  end

  return path
end

function M.new_item(state)
  local dir = selected_dir(state)
  local cargo_root = find_cargo_root(dir)
  if not cargo_root then
    notify("não encontrei um projeto Rust (Cargo.toml) a partir desta pasta.", vim.log.levels.WARN)
    return
  end

  vim.ui.select(item_options, {
    prompt = "Novo item Rust",
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if not choice then
      return
    end

    local prompt
    if choice.value == "module" then
      prompt = "Nome do módulo (snake_case): "
    else
      prompt = "Nome do " .. choice.label .. " (PascalCase): "
    end

    vim.ui.input({ prompt = prompt }, function(name)
      if not name or name == "" then
        return
      end

      local path, err = M.create_item(choice.value, name, dir)
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

return M
