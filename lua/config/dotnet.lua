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

local function normalize_path(path)
  return vim.fs.normalize((path:gsub("\\", "/")))
end

local function current_start()
  local file = vim.api.nvim_buf_get_name(0)
  if file ~= "" and vim.fn.filereadable(file) == 1 then
    return vim.fs.dirname(file)
  end
  return vim.fn.getcwd()
end

local function info_for_csproj(csproj)
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

  local project_references = {}
  for include in content:gmatch("<ProjectReference[^>]-Include=[\"']([^\"']+)[\"']") do
    table.insert(project_references, normalize_path(project_dir .. "/" .. include))
  end

  return {
    csproj = csproj,
    project_dir = project_dir,
    assembly = assembly,
    root_namespace = root_namespace,
    target_framework = target_framework,
    output_type = (xml_value(content, "OutputType") or "Library"):lower(),
    project_references = project_references,
  }
end

local function is_executable(info)
  return info.output_type == "exe" or info.output_type == "winexe"
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

function M.find_solution(start)
  start = start or current_start()
  start = vim.fs.normalize(start)
  if vim.fn.isdirectory(start) == 0 then
    start = vim.fs.dirname(start)
  end

  return vim.fs.find(function(name)
    return name:match("%.sln$") ~= nil or name:match("%.slnx$") ~= nil
  end, {
    upward = true,
    path = start,
    type = "file",
  })[1]
end

local function all_projects(root)
  return vim.fs.find(function(name)
    return name:match("%.csproj$") ~= nil
  end, {
    path = root,
    type = "file",
    limit = math.huge,
  })
end

function M.project_info(start)
  local csproj = M.find_project(start)
  return csproj and info_for_csproj(csproj) or nil
end

function M.launch_project_info(start)
  start = start or current_start()
  local nearest = M.project_info(start)
  if not nearest then
    return nil
  end

  if is_executable(nearest) then
    return nearest
  end

  local solution = M.find_solution(start)
  local root = solution and vim.fs.dirname(solution) or nearest.project_dir
  local projects = all_projects(root)
  local candidates = {}

  for _, csproj in ipairs(projects) do
    local info = info_for_csproj(csproj)
    if is_executable(info) and vim.tbl_contains(info.project_references, nearest.csproj) then
      table.insert(candidates, info)
    end
  end

  if #candidates == 0 then
    for _, csproj in ipairs(projects) do
      local info = info_for_csproj(csproj)
      if is_executable(info) then
        table.insert(candidates, info)
      end
    end
  end

  local non_test_candidates = vim.tbl_filter(function(info)
    local name = vim.fs.basename(info.csproj):lower()
    return not name:match("test")
  end, candidates)
  if #non_test_candidates > 0 then
    candidates = non_test_candidates
  end

  if #candidates == 0 then
    return nearest
  end

  for _, info in ipairs(candidates) do
    if info.output_type == "winexe" then
      return info
    end
  end

  return candidates[1]
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
  local info = M.launch_project_info(start)
  return info and info.project_dir or nil
end

function M.build_and_get_dll(start)
  local info = M.launch_project_info(start)
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
