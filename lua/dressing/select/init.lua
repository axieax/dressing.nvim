local global_config = require("dressing.config")
local patch = require("dressing.patch")

local function get_backend(config)
  local backends = config.backend
  if type(backends) ~= "table" then
    backends = { backends }
  end
  for _, backend in ipairs(backends) do
    local ok, mod = pcall(require, string.format("dressing.select.%s", backend))
    if ok and mod.is_supported() then
      return mod, backend
    end
  end
  return require("dressing.select.builtin"), "builtin"
end

-- use schedule_wrap to avoid a bug when vim opens
-- (see https://github.com/stevearc/dressing.nvim/issues/15)
return vim.schedule_wrap(function(items, opts, on_choice)
  vim.validate({
    items = {
      items,
      function(a)
        return type(a) == "table" and vim.tbl_islist(a)
      end,
      "list-like table",
    },
    on_choice = { on_choice, "function", false },
  })
  opts = opts or {}
  local config = global_config.get_mod_config("select", opts)

  if not config.enabled then
    return patch.original_mods.input(items, opts, on_choice)
  end

  opts.prompt = opts.prompt or "Select one of:"
  local format_override = config.format_item_override[opts.kind]
  if format_override then
    opts.format_item = format_override
  elseif opts.format_item then
    -- format_item doesn't *technically* have to return a string for the
    -- core implementation. We should maintain compatibility by wrapping the
    -- return value with tostring
    local format_item = opts.format_item
    opts.format_item = function(item)
      return tostring(format_item(item))
    end
  else
    opts.format_item = tostring
  end

  local backend, name = get_backend(config)
  backend.select(config[name], items, opts, on_choice)
end)
