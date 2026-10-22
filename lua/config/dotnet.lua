local M = {}

local function notify(message, level)
  vim.notify("[dotnet] " .. message, level or vim.log.levels.INFO)
end

local function read_file(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end
  local content = file:read("*a")
  file:close()
  return content
end

local function xml_value(content, tag)
  local value = content:match("<" .. tag .. ">%s*([^<]-)%s*</" .. tag .. ">")
  if not value then
    return nil
  end
  value = vim.trim(value)
  return value ~= "" and value or nil
end

local function current_start()
  local file = vim.api.nvim_buf_get_name(0)
  if file ~= "" and vim.fn.filereadable(file) == 1 then
    return vim.fs.dirname(file)
  end
  return vim.fn.getcwd()
end

function M.find_project(start)
  start = start or current_start()
  start = vim.fs.normalize(start)
  if vim.fn.isdirectory(start) == 0 then
    start = vim.fs.dirname(start)
  end

  return vim.fs.find(function(name)
    return name:match("%.csproj$") ~= nil
  end, {
    upward = true,
    path = start,
    type = "file",
  })[1]
end

function M.project_info(start)
  local csproj = M.find_project(start)
  if not csproj then
    return nil
  end

  local content = read_file(csproj) or ""
  local project_dir = vim.fs.dirname(csproj)
  local assembly = xml_value(content, "AssemblyName") or vim.fs.basename(csproj):gsub("%.csproj$", "")
  local root_namespace = xml_value(content, "RootNamespace") or assembly
  local target_framework = xml_value(content, "TargetFramework")
  if not target_framework then
    local frameworks = xml_value(content, "TargetFrameworks")
    if frameworks then
      target_framework = vim.split(frameworks, ";", { plain = true })[1]
    end
  end

  return {
    csproj = csproj,
    project_dir = project_dir,
    assembly = assembly,
    root_namespace = root_namespace,
    target_framework = target_framework,
  }
end

local function detect_target_framework(project_dir)
  local candidates = vim.fn.globpath(project_dir .. "/bin/Debug", "net*", false, true)
  table.sort(candidates)
  for i = #candidates, 1, -1 do
    if vim.fn.isdirectory(candidates[i]) == 1 then
      return vim.fs.basename(candidates[i])
    end
  end

  local sdk = vim.fn.system({ "dotnet", "--version" }):gsub("%s+$", "")
  local major = sdk:match("^(%d+)")
  return "net" .. (major or "10") .. ".0"
end

function M.project_dir(start)
  local info = M.project_info(start)
  return info and info.project_dir or nil
end

function M.build_and_get_dll(start)
  local info = M.project_info(start)
  if not info then
    notify("não encontrei um arquivo .csproj a partir daqui.", vim.log.levels.ERROR)
    return nil
  end

  local target_framework = info.target_framework or detect_target_framework(info.project_dir)
  notify("compilando " .. vim.fs.basename(info.csproj) .. " (" .. target_framework .. ")...")

  local output = vim.fn.system({ "dotnet", "build", info.csproj, "-c", "Debug", "--nologo" })
  if vim.v.shell_error ~= 0 then
    notify("falha ao compilar:\n" .. output, vim.log.levels.ERROR)
    return nil
  end

  local dll = info.project_dir .. "/bin/Debug/" .. target_framework .. "/" .. info.assembly .. ".dll"
  if vim.fn.filereadable(dll) == 0 then
    notify("DLL não encontrada em " .. dll, vim.log.levels.ERROR)
    return nil
  end

  return dll
end

return M
