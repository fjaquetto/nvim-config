local M = {}

local client_name = "csharp_ls"

local function notify(message, level)
  vim.notify("[csharp] " .. message, level or vim.log.levels.INFO)
end

---@param bufnr integer
---@return vim.lsp.Client?
local function get_client(bufnr)
  local clients = vim.lsp.get_clients({ bufnr = bufnr, name = client_name })
  for _, client in ipairs(clients) do
    if not client:is_stopped() then
      return client
    end
  end
  return nil
end

---@param buf integer
local function map_buffer(buf)
  local keys = {
    { "gd", M.definition, "Goto Definition" },
    { "gI", M.implementation, "Goto Implementation" },
    { "gy", M.type_definition, "Goto T[y]pe Definition" },
  }

  for _, key in ipairs(keys) do
    vim.keymap.set("n", key[1], key[2], { buffer = buf, desc = key[3], silent = true })
  end
end

---@param result any
---@return { uri: string, range: lsp.Range }[]
local function normalize_locations(result)
  if result == nil or result == vim.NIL then
    return {}
  end

  local list = vim.islist(result) and result or { result }
  local locations = {}
  for _, loc in ipairs(list) do
    if type(loc) == "table" then
      local uri = loc.uri or loc.targetUri
      local range = loc.range or loc.targetSelectionRange
      if type(uri) == "string" and type(range) == "table" and range.start and range["end"] then
        locations[#locations + 1] = { uri = uri, range = range }
      end
    end
  end
  return locations
end

---@param name string
---@return integer?
local function find_buffer(name)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf) == name then
      return buf
    end
  end
  return nil
end

---@param buf integer
---@param position lsp.Position
---@param encoding string
---@return integer
local function position_col(buf, position, encoding)
  local ok, col = pcall(vim.lsp.util._get_line_byte_from_position, buf, position, encoding)
  if ok and type(col) == "number" then
    return col
  end
  return position.character or 0
end

---@param client vim.lsp.Client
---@param uri string
---@param source string
---@return integer?
---@return string?
local function ensure_buffer(client, uri, source)
  source = source:gsub("\r\n", "\n"):gsub("\n$", "")
  local lines = vim.split(source, "\n", { plain = true })

  local buf = find_buffer(uri)
  if not buf then
    buf = vim.api.nvim_create_buf(true, true)
    local ok = pcall(vim.api.nvim_buf_set_name, buf, uri)
    if not ok then
      return nil, "não foi possível nomear o buffer descompilado"
    end
  elseif not vim.api.nvim_buf_is_loaded(buf) then
    local ok = pcall(vim.fn.bufload, buf)
    if not ok or not vim.api.nvim_buf_is_loaded(buf) then
      return nil, "não foi possível carregar o buffer descompilado"
    end
  end

  local current = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  if not vim.deep_equal(current, lines) then
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  end

  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true
  vim.bo[buf].modified = false
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.bo[buf].buflisted = true
  if vim.bo[buf].filetype ~= "cs" then
    vim.bo[buf].filetype = "cs"
  end

  if not vim.lsp.buf_is_attached(buf, client.id) then
    local attached = vim.lsp.buf_attach_client(buf, client.id)
    if not attached then
      return nil, "não foi possível anexar o csharp-ls ao buffer descompilado"
    end
  end

  map_buffer(buf)
  -- O LazyVim aplica os keymaps de LSP com debounce depois do LspAttach.
  -- Reaplica os mapas locais para manter este handler nos buffers virtualizados.
  vim.defer_fn(function()
    if vim.api.nvim_buf_is_valid(buf) then
      map_buffer(buf)
    end
  end, 150)

  return buf
end

---@param client vim.lsp.Client
---@param location { uri: string, range: lsp.Range }
---@param bufnr integer
---@param callback fun(err: string?, result: table?)
local function fetch_metadata(client, location, bufnr, callback)
  local done = false
  local timer

  local function finish(err, result)
    if done then
      return
    end
    done = true
    if timer then
      pcall(timer.stop, timer)
    end
    callback(err, result)
  end

  timer = vim.defer_fn(function()
    finish("timeout ao consultar csharp/metadata")
  end, 15000)

  local ok = client:request("csharp/metadata", { textDocument = { uri = location.uri } }, function(err, result)
    vim.schedule(function()
      if err then
        local message = type(err) == "table" and (err.message or "erro desconhecido") or tostring(err)
        finish("falha ao consultar csharp/metadata: " .. message)
      elseif type(result) ~= "table" or result == vim.NIL or type(result.source) ~= "string" or result.source == "" then
        finish("o servidor não retornou o código descompilado")
      else
        finish(nil, result)
      end
    end)
  end, bufnr)

  if not ok then
    finish("cliente LSP indisponível")
  end
end

---@param client vim.lsp.Client
---@param normal_locations { uri: string, range: lsp.Range }[]
---@param normal_items vim.quickfix.entry[]
---@param metadata_locations { uri: string, range: lsp.Range }[]
---@param metadata_items vim.quickfix.entry[]
local function show_results(client, normal_locations, normal_items, metadata_locations, metadata_items)
  local total = #normal_items + #metadata_items
  if total == 0 then
    notify("nenhuma localização encontrada", vim.log.levels.INFO)
    return
  end

  if total > 1 then
    local items = {}
    vim.list_extend(items, normal_items)
    vim.list_extend(items, metadata_items)
    vim.fn.setqflist({}, " ", { title = "csharp-ls", items = items })
    vim.cmd("botright copen")
    return
  end

  local location = normal_locations[1] or metadata_locations[1]
  if location then
    vim.lsp.util.show_document(location, client.offset_encoding, { focus = true })
    return
  end

  local item = normal_items[1] or metadata_items[1]
  if item then
    local buf = item.bufnr or vim.fn.bufadd(item.filename)
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_win_set_cursor(0, { item.lnum, math.max(item.col - 1, 0) })
  end
end

---@param client vim.lsp.Client
---@param locations { uri: string, range: lsp.Range }[]
---@param bufnr integer
local function present(client, locations, bufnr)
  local normal_locations = {}
  local metadata_locations = {}

  for _, location in ipairs(locations) do
    if location.uri:match("^csharp:") then
      metadata_locations[#metadata_locations + 1] = location
    else
      normal_locations[#normal_locations + 1] = location
    end
  end

  local normal_items = #normal_locations > 0
      and vim.lsp.util.locations_to_items(normal_locations, client.offset_encoding)
    or {}

  if #metadata_locations == 0 then
    show_results(client, normal_locations, normal_items, {}, {})
    return
  end

  local pending = #metadata_locations
  local rendered_locations = {}
  local metadata_items = {}
  local errors = {}

  for _, location in ipairs(metadata_locations) do
    fetch_metadata(client, location, bufnr, function(err, result)
      if err then
        errors[#errors + 1] = err
      elseif result then
        local buf, buf_err = ensure_buffer(client, location.uri, result.source)
        if buf then
          rendered_locations[#rendered_locations + 1] = location
          metadata_items[#metadata_items + 1] = {
            bufnr = buf,
            lnum = location.range.start.line + 1,
            col = position_col(buf, location.range.start, client.offset_encoding) + 1,
            text = type(result.symbolName) == "string" and result.symbolName or vim.fs.basename(location.uri),
          }
        else
          errors[#errors + 1] = buf_err or "não foi possível criar o buffer descompilado"
        end
      end

      pending = pending - 1
      if pending == 0 then
        vim.schedule(function()
          if #errors > 0 and #metadata_items == 0 and #normal_items == 0 then
            notify(
              "não foi possível abrir o código descompilado: " .. table.concat(errors, "; "),
              vim.log.levels.ERROR
            )
            return
          end
          if #errors > 0 then
            notify("algumas localizações não puderam ser abertas", vim.log.levels.WARN)
          end
          show_results(client, normal_locations, normal_items, rendered_locations, metadata_items)
        end)
      end
    end)
  end
end

---@param method string
function M.goto_location(method)
  local bufnr = vim.api.nvim_get_current_buf()
  local client = get_client(bufnr)
  if not client then
    notify("nenhum cliente csharp_ls anexado ao buffer", vim.log.levels.WARN)
    return
  end

  local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
  local ok = client:request(method, params, function(err, result)
    vim.schedule(function()
      if err then
        local message = type(err) == "table" and (err.message or "erro desconhecido") or tostring(err)
        notify("falha ao consultar " .. method .. ": " .. message, vim.log.levels.ERROR)
        return
      end

      local locations = normalize_locations(result)
      if #locations == 0 then
        notify("nenhuma localização encontrada", vim.log.levels.INFO)
        return
      end

      present(client, locations, bufnr)
    end)
  end, bufnr)

  if not ok then
    notify("não foi possível enviar a requisição ao csharp-ls", vim.log.levels.ERROR)
  end
end

function M.definition()
  M.goto_location("textDocument/definition")
end

function M.implementation()
  M.goto_location("textDocument/implementation")
end

function M.type_definition()
  M.goto_location("textDocument/typeDefinition")
end

return M
