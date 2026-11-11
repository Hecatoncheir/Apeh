local base, head = arg[1], arg[2]
assert(base and head, 'Укажите базовую и проверяемую ревизии Git.')

require('cyclomatic.config').setup({ nested_functions = 'inline' })
local analyzer = require('cyclomatic.analyzer')
assert(analyzer.get_query('dart'), 'Парсер или запросы для Dart недоступны.')

local function git(...)
  local command = { 'git', ... }
  local result = vim.system(command):wait()
  assert(result.code == 0, result.stderr)
  return result.stdout
end

local function is_dart(path)
  return path:match('%.dart$') and not vim.startswith(path, 'lib/l10n/generated/')
end

local function changed_files()
  local diff = git('diff', '--name-status', '-z', '--find-renames', '--diff-filter=AMRT', base, head)
  local fields = vim.split(diff, '\0', { trimempty = true })
  local files = {}
  local index = 1
  while index < #fields do
    local status, path = fields[index], fields[index + 1]
    local previous = status ~= 'A' and path or nil
    index = index + 2
    if status:sub(1, 1) == 'R' then
      path = fields[index]
      index = index + 1
    end
    if is_dart(path) then
      files[#files + 1] = { path = path, previous = previous and is_dart(previous) and previous }
    end
  end
  return files
end

local owner_types = {
  class_definition = true,
  enum_declaration = true,
  extension_declaration = true,
  extension_type_declaration = true,
  mixin_declaration = true,
}

local function qualified_name(entry, root, source, lines)
  -- В одном файле могут быть десятки методов build у разных классов.
  local column = (lines[entry.row + 1]:find('%S') or 1) - 1
  local node = root:named_descendant_for_range(entry.row, column, entry.row, column)
  local label = entry.name
  while node do
    if node:type() == 'function_signature' then
      local name = node:field('name')[1]
      if name then
        label = vim.treesitter.get_node_text(name, source)
      end
    end
    if owner_types[node:type()] then
      local name = node:field('name')[1] or node:field('class')[1]
      if node:type() == 'mixin_declaration' then
        for child in node:iter_children() do
          if child:type() == 'identifier' then
            name = child
            break
          end
        end
      end
      if name then
        return vim.treesitter.get_node_text(name, source) .. '.' .. label
      end
    end
    node = node:parent()
  end
  return label
end

local function measure(revision, path)
  if not path then
    return {}
  end
  local source = git('show', revision .. ':' .. path):gsub('\r\n', '\n')
  local result, err = analyzer.analyze_string(source, 'dart')
  assert(result, path .. ': ' .. tostring(err))
  local root = vim.treesitter.get_string_parser(source, 'dart'):parse()[1]:root()
  local lines = vim.split(source, '\n', { plain = true })
  for _, entry in ipairs(result.entries) do
    entry.name = qualified_name(entry, root, source, lines)
  end
  return result.entries
end

local function increases(files)
  local changes = {}
  for _, file in ipairs(files) do
    local previous = {}
    for _, entry in ipairs(measure(base, file.previous)) do
      local scores = previous[entry.name] or {}
      scores[#scores + 1] = entry.cognitive
      previous[entry.name] = scores
    end
    for _, entry in ipairs(measure(head, file.path)) do
      local scores = previous[entry.name]
      local before = scores and table.remove(scores, 1)
      local delta = entry.cognitive - (before or 0)
      if delta > 0 then
        changes[#changes + 1] = {
          path = file.path,
          line = entry.row + 1,
          name = entry.name,
          before = before,
          after = entry.cognitive,
          delta = delta,
        }
      end
    end
  end
  return changes
end

local function escape_command(value)
  return (value:gsub('%%', '%%25'):gsub('\r', '%%0D'):gsub('\n', '%%0A'))
end

local function report(files, changes)
  local summary = {
    '## Когнитивная сложность Dart',
    '',
    ('Проверено файлов: %d. Функций с ростом сложности: %d.'):format(#files, #changes),
  }
  if #changes > 0 then
    vim.list_extend(summary, {
      '',
      '| Файл и строка | Функция | Было | Стало | Рост |',
      '| --- | --- | ---: | ---: | ---: |',
    })
  end
  for index, change in ipairs(changes) do
    local before = change.before or 'новая'
    local path = escape_command(change.path):gsub(',', '%%2C'):gsub(':', '%%3A')
    local message = ('%s: %s → %d (+%d)'):format(change.name, before, change.after, change.delta)
    if index <= 10 then
      io.stdout:write(('::warning file=%s,line=%d::%s\n'):format(path, change.line, escape_command(message)))
    end
    summary[#summary + 1] = ('| `%s:%d` | `%s` | %s | %d | +%d |'):format(
      change.path:gsub('|', '\\|'), change.line, change.name:gsub('|', '\\|'),
      before, change.after, change.delta
    )
  end
  local destination = vim.env.GITHUB_STEP_SUMMARY
  if destination then
    vim.fn.writefile(summary, destination, 'a')
  else
    io.stdout:write(table.concat(summary, '\n') .. '\n')
  end
end

local files = changed_files()
local changes = increases(files)
table.sort(changes, function(a, b)
  if a.delta ~= b.delta then
    return a.delta > b.delta
  end
  if a.path ~= b.path then
    return a.path < b.path
  end
  return a.line < b.line
end)
report(files, changes)
