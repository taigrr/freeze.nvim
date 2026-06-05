package.path = table.concat({
  "./lua/?.lua",
  "./lua/?/init.lua",
  package.path,
}, ";")

local function assert_eq(actual, expected, message)
  if actual ~= expected then
    error(
      (message or "assertion failed")
        .. ": expected "
        .. vim.inspect(expected)
        .. ", got "
        .. vim.inspect(actual)
    )
  end
end

local function assert_truthy(value, message)
  if not value then
    error(message or "expected truthy value")
  end
end

local results = {}
local function test(name, fn)
  table.insert(results, { name = name, fn = fn })
end

local function reset_module()
  package.loaded["freeze"] = nil
  package.loaded["freeze.init"] = nil
  return require("freeze")
end

local function stub_pipe()
  return {
    read_stop = function() end,
    close = function() end,
    write = function(_, _, cb)
      if cb then
        cb()
      end
    end,
    shutdown = function(_, cb)
      if cb then
        cb()
      end
    end,
  }
end

test("freeze creates missing output directory before spawning freeze", function()
  local tmp = vim.fn.tempname()
  local target_dir = tmp .. "/nested/screens"
  local target_file = target_dir .. "/shot.png"
  local original_uv = vim.uv
  local original_notify = vim.notify
  local original_executable = vim.fn.executable
  local notifications = {}
  local spawn_calls = {}

  vim.notify = function(msg, level, opts)
    table.insert(notifications, { msg = msg, level = level, opts = opts })
  end
  vim.fn.executable = function(bin)
    if bin == "freeze" then
      return 1
    end
    return original_executable(bin)
  end
  vim.uv = {
    new_pipe = function()
      return stub_pipe()
    end,
    spawn = function(cmd, opts, cb)
      table.insert(spawn_calls, { cmd = cmd, opts = opts })
      cb(0, 0)
      return {}
    end,
    read_start = function(_, cb)
      cb(nil, nil)
    end,
  }

  local freeze = reset_module()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_name(buf, tmp .. "/source.lua")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "print('hi')" })
  vim.bo[buf].modified = false
  vim.bo[buf].filetype = "lua"

  freeze.setup({ output = target_dir, filename = "shot.png" })
  freeze.freeze(1, 1)
  vim.wait(50)

  assert_eq(vim.fn.isdirectory(target_dir), 1, "output directory should exist")
  assert_eq(#spawn_calls, 1, "freeze should spawn once")
  assert_eq(spawn_calls[1].cmd, "freeze")
  assert_truthy(
    vim.tbl_contains(spawn_calls[1].opts.args, target_file),
    "output path should be passed to freeze"
  )
  assert_eq(#notifications, 1, "should notify once on success")

  vim.uv = original_uv
  vim.notify = original_notify
  vim.fn.executable = original_executable
end)

test("freeze aborts when output directory creation fails", function()
  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp, "p")
  local blocked_parent = tmp .. "/blocked"
  local target_dir = blocked_parent .. "/nested"
  local target_file = target_dir .. "/shot.png"
  vim.fn.writefile({ "not a directory" }, blocked_parent)

  local original_uv = vim.uv
  local original_notify = vim.notify
  local notifications = {}
  local spawn_calls = {}

  vim.notify = function(msg, level, opts)
    table.insert(notifications, { msg = msg, level = level, opts = opts })
  end
  vim.uv = {
    new_pipe = function()
      return stub_pipe()
    end,
    spawn = function(cmd, opts, cb)
      table.insert(spawn_calls, { cmd = cmd, opts = opts })
      cb(0, 0)
      return {}
    end,
    read_start = function(_, cb)
      cb(nil, nil)
    end,
  }

  local freeze = reset_module()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_name(buf, tmp .. "/source.lua")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "print('hi')" })
  vim.bo[buf].modified = false
  vim.bo[buf].filetype = "lua"

  freeze.setup({ output = target_dir, filename = "shot.png" })
  freeze.freeze(1, 1)
  vim.wait(20)

  assert_eq(vim.fn.isdirectory(target_dir), 0, "nested target directory should not exist")
  assert_eq(#spawn_calls, 0, "freeze should not spawn when mkdir fails")
  assert_eq(#notifications, 1, "should notify about mkdir failure")
  assert_truthy(
    notifications[1].msg:match(target_file:match("(.+)/[^/]+$")),
    "error should mention directory"
  )

  vim.uv = original_uv
  vim.notify = original_notify
end)

test("setup can be called multiple times", function()
  local freeze = reset_module()

  freeze.setup({ filename = "first.png" })
  local ok, err = pcall(freeze.setup, { filename = "second.png" })

  assert_truthy(ok, "setup should be idempotent: " .. tostring(err))
end)

for _, case in ipairs(results) do
  local ok, err = pcall(case.fn)
  if not ok then
    io.stderr:write("FAIL: " .. case.name .. "\n" .. tostring(err) .. "\n")
    os.exit(1)
  end
  print("PASS: " .. case.name)
end
