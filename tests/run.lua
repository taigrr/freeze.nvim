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
  local closed_handles = 0

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
      return {
        close = function()
          closed_handles = closed_handles + 1
        end,
      }
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
  assert_eq(closed_handles, 1, "freeze process handle should close")
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
    notifications[1].msg:find(target_file:match("(.+)/[^/]+$"), 1, true),
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

test("repeated setup refreshes command behavior and config", function()
  local tmp = vim.fn.tempname()
  local first_dir = tmp .. "/first"
  local second_dir = tmp .. "/second"
  local first_file = first_dir .. "/first.png"
  local second_file = second_dir .. "/second.png"
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

  freeze.setup({ output = first_dir, filename = "first.png" })
  freeze.setup({ output = second_dir, filename = "second.png" })
  vim.cmd("Freeze")
  vim.wait(50)

  assert_eq(#spawn_calls, 1, "Freeze command should run once")
  assert_truthy(
    vim.tbl_contains(spawn_calls[1].opts.args, second_file),
    "Freeze command should use refreshed config"
  )
  assert_truthy(
    not vim.tbl_contains(spawn_calls[1].opts.args, first_file),
    "Freeze command should not keep stale config"
  )
  assert_eq(#notifications, 1, "should notify once on success")

  vim.uv = original_uv
  vim.notify = original_notify
end)

test("clipboard closes wl-copy stdin pipe when spawn fails", function()
  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp, "p")
  local out_file = tmp .. "/shot.png"
  vim.fn.writefile({ "fake png bytes" }, out_file)

  local original_uv = vim.uv
  local original_notify = vim.notify
  local original_executable = vim.fn.executable
  local original_has = vim.fn.has
  local spawn_calls = {}
  local wl_stdin

  vim.notify = function() end
  vim.fn.has = function(feature)
    if feature == "mac" or feature == "wsl" then
      return 0
    end
    return original_has(feature)
  end
  vim.fn.executable = function(bin)
    if bin == "freeze" or bin == "wl-copy" then
      return 1
    end
    if bin == "xclip" or bin == "xsel" then
      return 0
    end
    return original_executable(bin)
  end
  vim.uv = {
    new_pipe = function()
      local pipe = stub_pipe()
      pipe.closed = 0
      pipe.close = function()
        pipe.closed = pipe.closed + 1
      end
      return pipe
    end,
    spawn = function(cmd, opts, cb)
      table.insert(spawn_calls, { cmd = cmd, opts = opts })
      if cmd == "wl-copy" then
        wl_stdin = opts.stdio[1]
        return nil
      end
      cb(0, 0)
      return {
        close = function() end,
      }
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

  freeze.setup({ output = tmp, filename = "shot.png", clipboard = true })
  freeze.freeze(1, 1)
  vim.wait(50)

  assert_truthy(wl_stdin, "wl-copy should have been spawned")
  assert_eq(wl_stdin.closed, 1, "wl-copy stdin pipe should close once on spawn failure")

  vim.uv = original_uv
  vim.notify = original_notify
  vim.fn.executable = original_executable
  vim.fn.has = original_has
end)

test("clipboard uses osascript PNG coercion on macOS", function()
  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp, "p")
  local out_file = tmp .. "/shot.png"
  vim.fn.writefile({ "fake png bytes" }, out_file)

  local original_uv = vim.uv
  local original_notify = vim.notify
  local original_has = vim.fn.has
  local spawn_calls = {}
  local closed_handles = 0

  vim.notify = function() end
  vim.fn.has = function(feature)
    if feature == "mac" then
      return 1
    end
    if feature == "wsl" then
      return 0
    end
    return original_has(feature)
  end
  vim.uv = {
    new_pipe = function()
      return stub_pipe()
    end,
    spawn = function(cmd, opts, cb)
      table.insert(spawn_calls, { cmd = cmd, opts = opts })
      cb(0, 0)
      return {
        close = function()
          closed_handles = closed_handles + 1
        end,
      }
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

  freeze.setup({ output = tmp, filename = "shot.png", clipboard = true })
  freeze.freeze(1, 1)
  vim.wait(50)

  assert_eq(#spawn_calls, 2, "freeze then clipboard should spawn")
  assert_eq(spawn_calls[2].cmd, "osascript", "macOS clipboard should use osascript")
  assert_truthy(
    vim.tbl_contains(spawn_calls[2].opts.args, "-e"),
    "osascript should receive an -e script"
  )
  local script = spawn_calls[2].opts.args[2]
  assert_truthy(script:find("PNGf", 1, true), "clipboard should coerce as PNG, not TIFF")
  assert_eq(closed_handles, 2, "both process handles should close")

  vim.uv = original_uv
  vim.notify = original_notify
  vim.fn.has = original_has
end)

for _, case in ipairs(results) do
  local ok, err = pcall(case.fn)
  if not ok then
    io.stderr:write("FAIL: " .. case.name .. "\n" .. tostring(err) .. "\n")
    os.exit(1)
  end
  print("PASS: " .. case.name)
end
