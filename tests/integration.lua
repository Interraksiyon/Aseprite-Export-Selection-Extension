-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Interaksiyon

-- Normal exports use real Aseprite sprites and encoders. Dialog input and
-- failure conditions are supplied by this harness. Run through test.ps1.
local realApp = app
local project = assert(app.params.project, "Missing project parameter")
local output = assert(app.params.output, "Missing output parameter")
local report = assert(io.open(app.fs.joinPath(output, "report.txt"), "w"))
local testsPassed = 0
local alerts = {}
local dialogInput = {}
local overwriteAnswer = 2
local dialogCount = 0

local function expect(value, message)
  if not value then error(message or "Expectation failed", 2) end
end

local function equal(actual, expected, message)
  expect(actual == expected,
    (message or "Values differ") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end

local function alertText()
  local text = alerts[#alerts] and alerts[#alerts].text or ""
  if type(text) == "table" then return table.concat(text, "\n") end
  return text
end

local proxy = setmetatable({
  alert = function(options)
    alerts[#alerts + 1] = options
    if options.buttons then return overwriteAnswer end
    return 1
  end
}, {
  __index = function(_, key) return realApp[key] end,
  __newindex = function(_, key, value) realApp[key] = value end
})

local environment = setmetatable({
  app = proxy,
  Dialog = function()
    dialogCount = dialogCount + 1
    local dialog = { data = dialogInput }
    function dialog:label(options) return self end
    function dialog:file(options) return self end
    function dialog:button(options) return self end
    function dialog:show(options) return self end
    return dialog
  end
}, { __index = _G })

local plugin = { preferences = {} }
function plugin:newCommand(command) self.command = command end

local function resetUI(data)
  alerts = {}
  dialogInput = data or {}
  overwriteAnswer = 2
  dialogCount = 0
end

local function test(name, callback)
  callback()
  testsPassed = testsPassed + 1
  report:write("PASS: " .. name .. "\n")
  report:flush()
end

local function path(name) return realApp.fs.joinPath(output, name) end

local function readBytes(filename)
  local handle = assert(io.open(filename, "rb"))
  local bytes = handle:read("a")
  handle:close()
  return bytes
end

local function noTemporaryFiles()
  for _, filename in ipairs(realApp.fs.listFiles(output)) do
    expect(not filename:find(".quick-export-", 1, true), "Temporary file leaked: " .. filename)
  end
end

local function withSaveHook(hook, callback)
  environment.Sprite = function(sprite)
    local copy = Sprite(sprite)
    if not copy then return nil end
    return setmetatable({
      saveCopyAs = function(_, filename) return hook(copy, filename) end
    }, {
      __index = function(_, key)
        local value = copy[key]
        if type(value) == "function" then
          return function(_, ...) return value(copy, ...) end
        end
        return value
      end
    })
  end
  local ok, message = xpcall(callback, debug.traceback)
  environment.Sprite = nil
  if not ok then error(message, 0) end
end

local function withRenameHook(hook, callback)
  environment.os = setmetatable({ rename = hook }, { __index = os })
  local ok, message = xpcall(callback, debug.traceback)
  environment.os = nil
  if not ok then error(message, 0) end
end

local function render(sprite, frame)
  local image = Image(sprite.spec)
  image:drawSprite(sprite, frame or 1)
  return image
end

local function snapshot(sprite)
  local frames = {}
  for i = 1, #sprite.frames do
    frames[i] = render(sprite, i).bytes
  end
  return {
    width = sprite.width,
    height = sprite.height,
    filename = sprite.filename,
    colorMode = sprite.colorMode,
    modified = sprite.isModified,
    frames = frames,
    layer = realApp.layer,
    frame = realApp.frame.frameNumber,
    undo = sprite.undoHistory.undoSteps,
    sprites = #realApp.sprites,
    selection = sprite.selection.bounds
  }
end

local function unchanged(sprite, before)
  equal(realApp.sprite, sprite, "Active sprite")
  equal(realApp.frame.frameNumber, before.frame, "Active frame")
  equal(realApp.layer, before.layer, "Active layer")
  equal(#realApp.sprites, before.sprites, "Temporary sprite leaked")
  equal(sprite.width, before.width, "Source width")
  equal(sprite.height, before.height, "Source height")
  equal(sprite.filename, before.filename, "Source filename")
  equal(sprite.colorMode, before.colorMode, "Source color mode")
  equal(sprite.isModified, before.modified, "Source saved state")
  equal(sprite.undoHistory.undoSteps, before.undo, "Source undo history")
  equal(#sprite.frames, #before.frames, "Source frame count")
  for i = 1, #before.frames do
    equal(render(sprite, i).bytes, before.frames[i], "Source pixels")
  end
  local bounds = sprite.selection.bounds
  equal(bounds.x, before.selection.x, "Selection X")
  equal(bounds.y, before.selection.y, "Selection Y")
  equal(bounds.width, before.selection.width, "Selection width")
  equal(bounds.height, before.selection.height, "Selection height")
end

local function invoke(filename)
  resetUI { ok = true, exportPath = filename }
  plugin.command.onclick()
end

local function openExport(filename)
  expect(realApp.fs.isFile(filename), "Export missing: " .. filename .. "\n" .. alertText())
  expect(alertText():find("Saved successfully", 1, true), "Export did not report success: " .. alertText())
  local sprite = Sprite { fromFile = filename }
  expect(sprite, "Cannot reopen export")
  return sprite
end

local function run()
  assert(loadfile(realApp.fs.joinPath(project, "main.lua"), "t", environment))()
  environment.init(plugin)
  equal(plugin.command.id, "ExportSelectionDialog", "Command ID")
  equal(plugin.command.title, "Export Selection", "Command title")
  equal(plugin.command.group, "file_export", "Menu group")

  test("No document and empty selection are handled", function()
    resetUI()
    expect(not plugin.command.onenabled())
    plugin.command.onclick()
    expect(alertText():find("No active sprite", 1, true))
    equal(dialogCount, 0)
    local empty = Sprite(8, 8)
    expect(not plugin.command.onenabled())
    plugin.command.onclick()
    expect(alertText():find("Please select an area", 1, true))
    equal(dialogCount, 0)
    empty:close()
  end)

  local source = Sprite(8, 6)
  local red = realApp.pixelColor.rgba(255, 0, 0, 255)
  local green = realApp.pixelColor.rgba(0, 255, 0, 255)
  local blue = realApp.pixelColor.rgba(0, 0, 255, 255)
  local firstImage = Image(source.spec)
  firstImage:clear(red)
  source:newCel(source.layers[1], 1, firstImage)
  source:newEmptyFrame(2)
  local secondImage = Image(source.spec)
  secondImage:clear(green)
  source:newCel(source.layers[1], 2, secondImage)
  source.frames[1].duration = 0.1
  source.frames[2].duration = 0.2
  local hidden = source:newLayer()
  local hiddenImage = Image(source.spec)
  hiddenImage:clear(blue)
  source:newCel(hidden, 1, hiddenImage)
  source:newCel(hidden, 2, hiddenImage)
  hidden.isVisible = false
  source:saveAs(path("source.aseprite"))
  realApp.frame = 2
  realApp.layer = source.layers[1]
  source.selection:select(Rectangle(2, 1, 3, 2))

  test("PNG crops active frame, excludes hidden layers, preserves source", function()
    expect(plugin.command.onenabled())
    local before = snapshot(source)
    invoke(path("active.png"))
    unchanged(source, before)
    local exported = openExport(path("active.png"))
    equal(exported.width, 3)
    equal(exported.height, 2)
    equal(#exported.frames, 1)
    equal(render(exported):getPixel(0, 0), green)
    exported:close()
    realApp.sprite = source
    realApp.frame = 2
    realApp.layer = before.layer
    equal(plugin.preferences.lastDirectory, output)
  end)

  test("GIF preserves all frames and their durations", function()
    local before = snapshot(source)
    invoke(path("animation.gif"))
    unchanged(source, before)
    local exported = openExport(path("animation.gif"))
    equal(exported.width, 3)
    equal(exported.height, 2)
    equal(#exported.frames, 2)
    expect(math.abs(exported.frames[1].duration - 0.1) < 0.001)
    expect(math.abs(exported.frames[2].duration - 0.2) < 0.001)
    -- GIF may load as indexed; convert only the reopened output for comparison.
    realApp.command.ChangePixelFormat { format = "rgb" }
    equal(render(exported, 1):getPixel(0, 0), red)
    equal(render(exported, 2):getPixel(0, 0), green)
    exported:close()
    realApp.sprite = source
    realApp.frame = 2
    realApp.layer = before.layer
  end)

  test("JPEG is a single cropped active frame", function()
    local before = snapshot(source)
    invoke(path("active.jpg"))
    unchanged(source, before)
    local exported = openExport(path("active.jpg"))
    equal(exported.width, 3)
    equal(exported.height, 2)
    equal(#exported.frames, 1)
    local pixel = render(exported):getPixel(0, 0)
    expect(realApp.pixelColor.rgbaG(pixel) > 240, "JPEG exported the wrong frame")
    exported:close()
    realApp.sprite = source
    realApp.frame = 2
    realApp.layer = before.layer
  end)

  test("Cancel does not create a file or a temporary document", function()
    local before = snapshot(source)
    resetUI { cancel = true, exportPath = path("cancelled.png") }
    plugin.command.onclick()
    unchanged(source, before)
    expect(not realApp.fs.isFile(path("cancelled.png")))
    equal(#alerts, 0)
  end)

  test("Invalid paths and unsupported formats are rejected", function()
    local before = snapshot(source)
    for _, filename in ipairs({ "", "   ", path("invalid.txt"), path("missing/file.png") }) do
      invoke(filename)
      unchanged(source, before)
      equal(#alerts, 1)
      expect(not alertText():find("Saved successfully", 1, true))
    end
  end)

  test("Missing extension defaults to PNG", function()
    local before = snapshot(source)
    invoke(path("without-extension"))
    unchanged(source, before)
    expect(realApp.fs.isFile(path("without-extension.png")))
    expect(not realApp.fs.isFile(path("without-extension")))
  end)

  test("Overwrite requires confirmation and accepts a confirmed overwrite", function()
    local before = snapshot(source)
    local filename = path("active.png")
    local handle = assert(io.open(filename, "rb"))
    local previousBytes = handle:read("a")
    handle:close()
    invoke(filename)
    unchanged(source, before)
    equal(#alerts, 1)
    handle = assert(io.open(filename, "rb"))
    equal(handle:read("a"), previousBytes, "Cancelled overwrite changed the file")
    handle:close()
    resetUI { ok = true, exportPath = filename }
    overwriteAnswer = 1
    plugin.command.onclick()
    unchanged(source, before)
    expect(alertText():find("Saved successfully", 1, true))
    noTemporaryFiles()
  end)

  test("Source image cannot be overwritten", function()
    source:saveAs(path("original.png"))
    local before = snapshot(source)
    invoke(source.filename)
    unchanged(source, before)
    expect(alertText():find("The original file cannot be overwritten", 1, true))
  end)

  test("Source overwrite protection resolves equivalent paths", function()
    local before = snapshot(source)
    local equivalentPaths = {
      path("./original.png"),
      path("../" .. realApp.fs.fileName(output) .. "/original.png"),
      realApp.fs.joinPath("tests", "output", realApp.fs.fileName(output), "original.png")
    }
    if realApp.fs.pathSeparator == "\\" then
      equivalentPaths[#equivalentPaths + 1] = source.filename:upper()
    end
    for _, filename in ipairs(equivalentPaths) do
      invoke(filename)
      unchanged(source, before)
      expect(alertText():find("The original file cannot be overwritten", 1, true), "Equivalent source path was not blocked: " .. filename)
    end
  end)

  test("Partially out-of-canvas selections are clipped", function()
    source.selection:select(Rectangle(-2, -1, 5, 4))
    local before = snapshot(source)
    invoke(path("clipped.png"))
    unchanged(source, before)
    local exported = openExport(path("clipped.png"))
    equal(exported.width, 3)
    equal(exported.height, 3)
    exported:close()
    realApp.sprite = source
    realApp.frame = 2
    realApp.layer = before.layer
  end)

  test("Fully out-of-canvas selections are rejected", function()
    source.selection:select(Rectangle(20, 20, 3, 2))
    expect(not plugin.command.onenabled(), "Out-of-canvas selection should disable the command")
    local before = snapshot(source)
    invoke(path("outside.png"))
    unchanged(source, before)
    equal(dialogCount, 0)
    expect(alertText():find("outside the canvas", 1, true))
    expect(not realApp.fs.isFile(path("outside.png")))
  end)

  test("Export failure closes the copy and restores the source", function()
    source.selection:select(Rectangle(2, 1, 3, 2))
    local before = snapshot(source)
    withSaveHook(function() error("Injected disk error", 0) end, function()
      invoke(path("failure.png"))
    end)
    unchanged(source, before)
    expect(alertText():find("Injected disk error", 1, true))
    expect(not realApp.fs.isFile(path("failure.png")))
    noTemporaryFiles()
  end)

  test("Directory paths are rejected before adding the default extension", function()
    local directory = path("folder")
    expect(realApp.fs.makeDirectory(directory))
    local before = snapshot(source)
    invoke(directory)
    unchanged(source, before)
    expect(alertText():find("This path is a folder", 1, true))
    expect(not realApp.fs.isFile(directory .. ".png"))
  end)

  test("A silent encoder failure cannot report an older output as success", function()
    local filename = path("active.png")
    local bytes = readBytes(filename)
    local before = snapshot(source)
    withSaveHook(function() return true end, function()
      resetUI { ok = true, exportPath = filename }
      overwriteAnswer = 1
      plugin.command.onclick()
    end)
    unchanged(source, before)
    equal(readBytes(filename), bytes, "Failed save changed the existing output")
    expect(alertText():find("Export failed", 1, true))
    noTemporaryFiles()
  end)

  test("Partial encoder output is cleaned up after failure", function()
    local before = snapshot(source)
    for _, reportedSuccess in ipairs({ false, true }) do
      withSaveHook(function(_, filename)
        local handle = assert(io.open(filename, "wb"))
        handle:write("partial output")
        handle:close()
        return reportedSuccess
      end, function()
        invoke(path("partial.png"))
      end)
      unchanged(source, before)
      expect(alertText():find("Export failed", 1, true))
      expect(not realApp.fs.isFile(path("partial.png")))
      noTemporaryFiles()
    end
  end)

  test("Failed replacement restores the previous output and removes staging files", function()
    local filename = path("active.png")
    local bytes = readBytes(filename)
    local before = snapshot(source)
    withRenameHook(function(from, to)
      if to == filename and realApp.fs.fileExtension(from) == "png" then
        return nil, "Injected replacement error"
      end
      return os.rename(from, to)
    end, function()
      resetUI { ok = true, exportPath = filename }
      overwriteAnswer = 1
      plugin.command.onclick()
    end)
    unchanged(source, before)
    equal(readBytes(filename), bytes, "The previous output was not restored")
    expect(alertText():find("Injected replacement error", 1, true))
    noTemporaryFiles()
  end)

  test("Failed backup leaves the previous output untouched", function()
    local filename = path("active.png")
    local bytes = readBytes(filename)
    local before = snapshot(source)
    withRenameHook(function(from, to)
      if from == filename then return nil, "Injected backup error" end
      return os.rename(from, to)
    end, function()
      resetUI { ok = true, exportPath = filename }
      overwriteAnswer = 1
      plugin.command.onclick()
    end)
    unchanged(source, before)
    equal(readBytes(filename), bytes, "Failed backup changed the existing output")
    expect(alertText():find("Injected backup error", 1, true))
    noTemporaryFiles()
  end)

  test("A file created during export requires a new overwrite confirmation", function()
    local filename = path("created-during-export.png")
    local before = snapshot(source)
    withSaveHook(function(copy, temporaryPath)
      local saved = copy:saveCopyAs(temporaryPath)
      local handle = assert(io.open(filename, "wb"))
      handle:write("created during export")
      handle:close()
      return saved
    end, function()
      invoke(filename)
    end)
    unchanged(source, before)
    equal(readBytes(filename), "created during export")
    expect(alertText():find("created while exporting", 1, true))
    noTemporaryFiles()
  end)

  test("PNG preserves transparent pixels", function()
    local transparent = Sprite(4, 3)
    local image = Image(transparent.spec)
    image:drawPixel(1, 1, red)
    transparent:newCel(transparent.layers[1], 1, image)
    transparent.selection:select(Rectangle(1, 0, 2, 3))
    local before = snapshot(transparent)
    invoke(path("transparent.png"))
    unchanged(transparent, before)
    local exported = openExport(path("transparent.png"))
    equal(realApp.pixelColor.rgbaA(render(exported):getPixel(0, 0)), 0)
    equal(render(exported):getPixel(0, 1), red)
    exported:close()
    transparent:close()
    realApp.sprite = source
    realApp.frame = 2
    realApp.layer = source.layers[1]
  end)

  test("Indexed and grayscale sprites export to PNG, JPEG and GIF", function()
    for _, mode in ipairs({ ColorMode.INDEXED, ColorMode.GRAY }) do
      local sprite = Sprite(4, 3, mode)
      local image = Image(sprite.spec)
      if mode == ColorMode.INDEXED then
        local palette = Palette(2)
        palette:setColor(0, Color { r = 0, g = 0, b = 0, a = 0 })
        palette:setColor(1, Color { r = 255, g = 0, b = 0, a = 255 })
        sprite:setPalette(palette)
        image:clear(1)
      else
        image:clear(realApp.pixelColor.graya(160, 255))
      end
      sprite:newCel(sprite.layers[1], 1, image)
      sprite.selection:select(Rectangle(1, 1, 2, 2))
      for _, extension in ipairs({ "png", "jpg", "gif" }) do
        local before = snapshot(sprite)
        local filename = path(tostring(mode) .. "." .. extension)
        invoke(filename)
        unchanged(sprite, before)
        local exported = openExport(filename)
        equal(exported.width, 2)
        equal(exported.height, 2)
        exported:close()
        realApp.sprite = sprite
        realApp.frame = 1
        realApp.layer = sprite.layers[1]
      end
      sprite:close()
      realApp.sprite = source
      realApp.frame = 2
      realApp.layer = source.layers[1]
    end
  end)

  source:close()
  environment.exit(plugin)
end

local ok, message = xpcall(run, debug.traceback)
if ok then
  report:write(string.format("%d tests passed on Aseprite %s\nRESULT: PASS\n", testsPassed, tostring(realApp.version)))
else
  report:write(tostring(message) .. "\nRESULT: FAIL\n")
end
report:close()
if not ok then error(message, 0) end
