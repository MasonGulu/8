--- This script will effectively protect selected files and directories from being viewed or edited.
-- This script is not fullproof.
-- The easiest bypass is to put the computer in a disk drive (so I've been told).

-- MIT License; see LICENSE
-- Copyright (c) 2022 Mason Gulu

--- This code is executed before all the global overrides. You also have UNPROTECTED file access, meaning you may open and execute other protected files and THEY may open other unprotected files.
local function beforeOverride()

end

-- Hide errors in beforeOverride() from the user
local hideBeforeErrors = true

--- This code is executed after the global overrides.
-- fs is overwritten, and you have no access to the protected files
local function afterOverride()
  -- local bfs = nil -- uncomment this to disable bfs access in this function
end

-- Hide errors in afterOverride() from the user
local hideAfterErrors = true

--- List of files to disallow the user from accessing (absolute paths)
local protectedFiles = { "startup.lua", "startup" }
-- List of pattern matched absolute paths (ie "hi/folder/*")
-- recommended to place path of folder into protectedFiles too (ie "hi/folder")
local protectedPaths = {}

--- List of settings to disallow the user to change.
local blacklist = {
  ["shell.allow_disk_startup"] = true,
  ["shell.allow_startup"] = true,
}

--- Set this to a passcode that will allow access to the protected files.
-- leave nil to disable.
-- this is not secure.
local unlockPass = nil


local function isProtected(path, unlockCode)
  path = fs.combine(path)
  if type(unlockPass) ~= "nil" and unlockCode == unlockPass then
    return false
  end
  for k, v in pairs(protectedFiles) do
    if (path == v) then
      return true
    end
  end
  for k, v in pairs(protectedPaths) do
    if string.match(path, v) then
      return true
    end
  end
  return false
end

local function errHide(func, ...)
  local function a()
    return func(table.unpack(arg))
  end

  local p = { pcall(a) }
  if p[1] then
    -- success
    return table.unpack(p, 2)
  else
    -- failed
    p[2] = string.sub(p[2], 17)
    error(p[2], 3)
  end
end

local function fsOverwrite()
  local bfs = {}

  bfs.exists = fs.exists
  function fs.exists(path, unlockCode)
    if isProtected(path, unlockCode) then
      return false
    end
    return errHide(bfs.exists, path)
  end

  bfs.getSize = fs.getSize
  function fs.getSize(path, unlockCode)
    if isProtected(path, unlockCode) then
      error(string.format("%s: No such file", path), 2)
    end
    return errHide(bfs.getSize, path)
  end

  bfs.list = fs.list
  function fs.list(path, unlockCode)
    local list = errHide(bfs.list, path)
    local key = {}
    for k, v in ipairs(list) do
      if isProtected(v, unlockCode) then
        key[#key + 1] = k
      end
    end
    for k = #key, 1, -1 do
      table.remove(list, key[k])
    end
    return list
  end

  bfs.open = fs.open
  function fs.open(path, mode, unlockCode)
    if isProtected(path, unlockCode) then
      return nil, "Access denied"
    end
    return errHide(bfs.open, path, mode)
  end

  bfs.isReadOnly = fs.isReadOnly
  function fs.isReadOnly(path, unlockCode)
    return isProtected(path, unlockCode) or errHide(bfs.isReadOnly, path)
  end

  bfs.isDir = fs.isDir
  function fs.isDir(path, unlockCode)
    return (not isProtected(path, unlockCode)) and bfs.isDir(path)
  end

  bfs.attributes = fs.attributes
  function fs.attributes(path, unlockCode)
    local attributes = errHide(bfs.attributes, path)
    if isProtected(path, unlockCode) then
      error(string.format("%s: no such file", path), 2)
    end
    return attributes
  end

  bfs.delete = fs.delete
  function fs.delete(path, unlockCode)
    if isProtected(path, unlockCode) then
      return
    end
    bfs.delete(path)
  end

  bfs.move = fs.move
  function fs.move(path, dest, unlockCode)
    if isProtected(path, unlockCode) or isProtected(dest, unlockCode) then
      error(string.format("%s: no such file", path), 2)
    end
    errHide(bfs.move, path, dest)
  end

  bfs.copy = fs.copy
  function fs.copy(path, dest, unlockCode)
    if isProtected(path, unlockCode) or isProtected(dest, unlockCode) then
      error(string.format("%s: no such file", path), 2)
    end
    errHide(bfs.copy, path, dest)
  end
end

local function settingsOverwrite()
  local bsettings = {}
  settings.set("shell.allow_disk_startup", false)

  bsettings.set = settings.set
  function settings.set(name, value)
    if not blacklist[name] then
      bsettings.set(name, value)
    end
  end

  bsettings.unset = settings.unset
  function settings.unset(name)
    if not blacklist[name] then
      bsettings.unset(name)
    end
  end
end

if hideBeforeErrors then
  pcall(beforeOverride)
else
  beforeOverride()
end

fsOverwrite()
settingsOverwrite()

if hideAfterErrors then
  pcall(afterOverride)
else
  afterOverride()
end
