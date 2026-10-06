-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Interaksiyon

local TITLE = "Export Selection"
local SUPPORTED_FORMATS = { png = true, gif = true, jpg = true, jpeg = true }
local temporaryFileNumber = 0

local function alert(text)
  app.alert { title = TITLE, text = text }
end

local function defaultFilename(sprite, preferences)
  local directory = preferences.lastDirectory
  if type(directory) ~= "string" or not app.fs.isDirectory(directory) then
    directory = app.fs.filePath(sprite.filename)
  end
  if directory == "" or not app.fs.isDirectory(directory) then
    directory = app.fs.userDocsPath
  end

  local name = app.fs.fileTitle(sprite.filename)
  if name == "" then name = "export" end
  return app.fs.joinPath(directory, name .. "-selection.png")
end

local function clippedBounds(sprite)
  local bounds = sprite.selection.bounds
  local x = math.max(0, bounds.x)
  local y = math.max(0, bounds.y)
  local right = math.min(sprite.width, bounds.x + bounds.width)
  local bottom = math.min(sprite.height, bounds.y + bounds.height)
  if right <= x or bottom <= y then return nil end
  return Rectangle(x, y, right - x, bottom - y)
end

local function absolutePath(filename)
  if app.fs.pathSeparator == "\\" then
    if filename:match("^[\\/][^\\/]") then
      -- A Windows path starting with one slash is rooted on the current drive.
      filename = (app.fs.currentPath:match("^%a:") or "") .. filename
    elseif not filename:match("^%a:[\\/]") and not filename:match("^[\\/][\\/]") then
      filename = app.fs.joinPath(app.fs.currentPath, filename)
    end
  elseif filename:sub(1, 1) ~= "/" then
    filename = app.fs.joinPath(app.fs.currentPath, filename)
  end
  return app.fs.normalizePath(filename)
end

local function validatePath(filename)
  if type(filename) ~= "string" or filename:match("^%s*$") then
    return nil, "Please choose a file name."
  end
  if app.fs.pathSeparator == "\\" and (filename:match("^%a:$") or filename:match("^%a:[^\\/]")) then
    return nil, "Please use a path separator after the drive letter (e.g. C:\\folder\\image.png)."
  end
  filename = absolutePath(filename)
  if app.fs.isDirectory(filename) then
    return nil, "This path is a folder. Please choose a file name."
  end

  local extension = app.fs.fileExtension(filename):lower()
  if extension == "" then
    filename = filename .. ".png"
    extension = "png"
  end
  if not SUPPORTED_FORMATS[extension] then
    return nil, "Supported formats: PNG, GIF, JPG, and JPEG."
  end

  local directory = app.fs.filePath(filename)
  if directory ~= "" and not app.fs.isDirectory(directory) then
    return nil, "Export folder not found. Please choose an existing folder."
  end
  if app.fs.isDirectory(filename) then
    return nil, "This path is a folder. Please choose a file name."
  end
  return filename, extension
end

local function samePath(first, second)
  first = absolutePath(first)
  second = absolutePath(second)
  if app.fs.pathSeparator == "\\" then
    first = first:lower()
    second = second:lower()
  end
  return first == second
end

local function unusedTemporaryPath(filename, extension)
  local directory = app.fs.filePath(filename)
  local candidate
  repeat
    temporaryFileNumber = temporaryFileNumber + 1
    candidate = app.fs.joinPath(directory,
      string.format(".quick-export-%d-%d.%s", os.time(), temporaryFileNumber, extension))
  until not app.fs.isFile(candidate) and not app.fs.isDirectory(candidate)
  return candidate
end

local function renameFile(source, destination)
  local ok, result, message = pcall(os.rename, source, destination)
  if not ok then return nil, tostring(result) end
  return result, message
end

local function removeFile(filename)
  local ok, result, message = pcall(os.remove, filename)
  if not ok then return nil, tostring(result) end
  return result, message
end

local function verifyExport(filename, width, height)
  local exported
  local ok, message = pcall(function()
    exported = Sprite { fromFile = filename }
    if not exported or exported.width ~= width or exported.height ~= height then
      error("The exported file could not be read back with the expected dimensions.", 0)
    end
  end)
  local closed, closeMessage = pcall(function()
    if exported and exported.isValid then exported:close() end
  end)
  if not ok then error(tostring(message), 0) end
  if not closed then error(tostring(closeMessage), 0) end
end

local function commitExport(temporaryPath, filename, overwriteAllowed)
  local backupPath
  if app.fs.isFile(filename) then
    if not overwriteAllowed then
      error("The output file was created while exporting. Please try again and confirm overwriting it.", 0)
    end
    backupPath = unusedTemporaryPath(filename, "bak")
    local renamed, message = renameFile(filename, backupPath)
    if not renamed then
      error("Could not replace the existing file: " .. tostring(message), 0)
    end
  end

  local renamed, message = renameFile(temporaryPath, filename)
  if not renamed then
    if backupPath then
      local restored, restoreMessage = renameFile(backupPath, filename)
      if not restored then
        error("Could not finish exporting or restore the previous output. Your previous file is at:\n"
          .. backupPath .. "\n" .. tostring(restoreMessage), 0)
      end
    end
    error("Could not move the exported file into place: " .. tostring(message), 0)
  end

  if backupPath then
    local removed = removeFile(backupPath)
    if not removed then
      return "The previous output's backup could not be removed:\n" .. backupPath
    end
  end
end

local function saveSelection(sprite, bounds, frameNumber, filename, extension, overwriteAllowed)
  local originalLayer = app.layer
  local temporaryPath = unusedTemporaryPath(filename, extension)
  local copy
  local warning
  local ok, result = pcall(function()
    copy = Sprite(sprite)
    copy:crop(bounds)
    copy.selection:deselect()

    -- Still images must not turn a multi-frame sprite into a file sequence.
    -- Delete backwards so that the original frame index stays meaningful.
    if extension ~= "gif" then
      for i = #copy.frames, 1, -1 do
        if i ~= frameNumber then
          copy:deleteFrame(copy.frames[i])
        end
      end
    end

    -- JPEG cannot encode indexed pixels; GIF cannot encode grayscale pixels.
    -- Convert only the disposable copy, keeping the source palette and mode.
    if ((extension == "jpg" or extension == "jpeg") and copy.colorMode == ColorMode.INDEXED)
      or (extension == "gif" and copy.colorMode == ColorMode.GRAY) then
      app.sprite = copy
      app.command.ChangePixelFormat { format = "rgb" }
    end

    -- Aseprite can return success even when its encoder did not write a file.
    -- Save to a fresh path so an older output cannot conceal a failed save.
    local saved = copy:saveCopyAs(temporaryPath)
    if saved == false or not app.fs.isFile(temporaryPath) or app.fs.fileSize(temporaryPath) == 0 then
      error("Aseprite could not save the file.", 0)
    end
    verifyExport(temporaryPath, bounds.width, bounds.height)
    warning = commitExport(temporaryPath, filename, overwriteAllowed)
  end)

  -- Always dispose of the temporary document, including after an export error.
  local closed, closeError = pcall(function()
    if copy and copy.isValid then copy:close() end
  end)
  local restored, restoreError = pcall(function()
    if sprite.isValid then
      app.sprite = sprite
      app.frame = frameNumber
      if originalLayer then app.layer = originalLayer end
    end
  end)
  if app.fs.isFile(temporaryPath) then
    local removed, message = removeFile(temporaryPath)
    if not removed then
      result = tostring(result) .. "\nTemporary output could not be removed:\n"
        .. temporaryPath .. "\n" .. tostring(message)
      ok = false
    end
  end

  if not ok then return false, tostring(result) end
  if not closed then return false, tostring(closeError) end
  if not restored then return false, tostring(restoreError) end
  return true, warning
end

local function exportSelection(plugin)
  local sprite = app.sprite
  if not sprite then
    alert("No active sprite.")
    return
  end
  if sprite.selection.isEmpty then
    alert("Please select an area to export first.")
    return
  end

  local bounds = clippedBounds(sprite)
  if not bounds then
    alert("The selection is outside the canvas. Please select an area inside the canvas.")
    return
  end
  local frameNumber = app.frame.frameNumber
  local dlg = Dialog(TITLE)
  if not dlg then return end

  dlg:label {
    label = "Area:",
    text = string.format("%d × %d px", bounds.width, bounds.height)
  }
  dlg:file {
    id = "exportPath",
    label = "Save to:",
    title = "Save Selection As",
    open = false,
    save = true,
    entry = true,
    filename = defaultFilename(sprite, plugin.preferences),
    filetypes = { "png", "gif", "jpg", "jpeg" }
  }
  dlg:label { text = "PNG/JPEG: active frame • GIF: all frames" }
  dlg:label { text = "Exports the rectangle surrounding the selection." }
  dlg:button { id = "ok", text = "Save", focus = true }
  dlg:button { id = "cancel", text = "Cancel" }
  dlg:show { wait = true }

  local data = dlg.data
  if not data.ok then return end
  local filename, extension = validatePath(data.exportPath)
  if not filename then
    alert(extension)
    return
  end
  if samePath(filename, sprite.filename) then
    alert("The original file cannot be overwritten. Please choose a different file name.")
    return
  end
  local overwriteAllowed = false
  if app.fs.isFile(filename) then
    local answer = app.alert {
      title = TITLE,
      text = { "File already exists. Overwrite it?", filename },
      buttons = { "Overwrite", "Cancel" }
    }
    if answer ~= 1 then return end
    overwriteAllowed = true
  end

  local ok, message = saveSelection(sprite, bounds, frameNumber, filename, extension, overwriteAllowed)
  if not ok then
    alert { "Export failed:", message }
    return
  end

  plugin.preferences.lastDirectory = app.fs.filePath(filename)
  local successMessage = { "Saved successfully:", filename }
  if message then successMessage[#successMessage + 1] = message end
  alert(successMessage)
end

function init(plugin)
  plugin:newCommand {
    id = "ExportSelectionDialog",
    title = TITLE,
    group = "file_export",
    onenabled = function()
      local sprite = app.sprite
      return sprite ~= nil and not sprite.selection.isEmpty and clippedBounds(sprite) ~= nil
    end,
    onclick = function() exportSelection(plugin) end
  }
end

function exit(plugin)
  -- Aseprite persists plugin.preferences and removes the registered command.
end
