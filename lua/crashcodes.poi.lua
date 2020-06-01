-- see: https://shroudmods.com/index.php?apireferences
-- without these calls, whatever script that is called after or mayber before will get the call extra times.

-- function ShroudOnStart() end
-- function ShroudOnUpdate() end
-- function ShroudOnGUI() end
-- function ShroudOnConsoleInput(type, sourcePlayer, message)  end


-- results of ShroudLoadTexture("crashcodes.poi/images/blue_1x1.png")
local textures = {}

-- all the labels to be rendered in ShroudOnGUI()
local labels = {}

-- things that know how to draw themselves
-- { {visible, draw}... }
local drawables = {}

-- labels or drawables that can be dragged
local draggables = {}

-- active point of interest, the place you marked with the mark button
-- {name, scene, x, y, z}
local poi

-- get the name of the current scene so we can track when it changes
local currentSceneName = ""


-- all the different commands that the user can input
local commands = {
  help = {
    helpText = '[EF1BEF]!ccpoihelp[-] to list commands.',
    isMatch = function(message) 
      return message == ("!ccpoihelp")
    end,
    onMatch = function(message)
      showHelp()
    end
  },
  mark = {
    helpText = '[EF1BEF]!mark[-] [1BEFEF]<name>[-] to create a poi from the current location, where [1BEFEF]<name>[-] is what you want to name the location.',
    isMatch = function(message) 
      return message:startsWith("!mark ")
    end,
    onMatch = function(message) 
      local name = message:sub(7)
      mark(name)
    end
  },
  markCoords = {
    helpText = '[EF1BEF]!markcoords[-] [1BEFEF]<coords>[-] [1BEFEF]<name>[-] to create a poi from the [1BEFEF]<coords>[-] (x,y,z) , where [1BEFEF]<name>[-] is what you want to name the location.',
    isMatch = function(message) 
      return message:startsWith("!markcoords ")
    end,
    onMatch = function(message) 
      local params = message:sub(13)
      local xyz, name = params:match("^(%S*) (.*)$")
      ConsoleLog("  params="..params)
      ConsoleLog("  xyz="..xyz)
      ConsoleLog("  name="..name)
      local x, y, z = xyz:match("(.*),(.*),(.*)")
      
      ConsoleLog("  x="..x)
      ConsoleLog("  y="..y)
      ConsoleLog("  z="..z)

      markCoords(tonumber(x), tonumber(y), tonumber(z), name)
    end
  },
  unmark = {
    helpText = '[EF1BEF]!unmark[-] [1BEFEF]<name>[-] to remove a poi from this scene, where [1BEFEF]<name>[-] is the name of the poi you want to remove.',
    isMatch = function(message) 
      return message:startsWith("!unmark ")
    end,
    onMatch = function(message) 
      local name = message:sub(9)
      unmark(name)
    end
  },
  listpois = {
    helpText = '[EF1BEF]!listpois[-] to list all the points of interest.',
    isMatch = function(message) 
      return message == ("!listpois")
    end,
    onMatch = function(message) 
      printPOIs()
    end
  },
  pois = {
    helpText = '[EF1BEF]!pois[-] to show the POIs window.',
    isMatch = function(message) 
      return message == ("!pois")
    end,
    onMatch = function(message) 
      drawables.pois.visible = true
    end
  }
}

-- scenes with pois in them
-- { {invertCoords, pois} }
local scenes = {}

-- heading related info
local heading = {
  invertCoords = false
}

-- I'm going to assume a local copy of the player name 
-- is more performant than calling ShroudGetPlayerName()
local playerName

-- some of the update stuff only want to do it so frequently
-- when did we last run updates, well really a subset of the updates
-- ShroudOnUpdate()
local lastProcessUpdate = 0

-- has ShroudOnStart happened yet
local started = false

-- forward slashes are ok for textures, but not for io.open() paths
-- w:gsub("\\", "/") for *nix style paths
-- gonna put the ShroudLuaPath on this during startup
-- used in saveSettings() and loadSettings()
local settingsFileName = "\\crashcodes.poi\\settings.json"


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- ShroudOnStart()
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function ShroudOnStart()
  playerName = ShroudGetPlayerName()  

  settingsFileName = ShroudLuaPath .. settingsFileName

  textures.blue = ShroudLoadTexture("crashcodes.poi/images/blue_1x1.png")
  textures.mark = ShroudLoadTexture("crashcodes.poi/images/mark.png") -- 44x44
  textures.clearPOI = ShroudLoadTexture("crashcodes.poi/images/clear_poi.png") -- 44x44
  textures.coords = ShroudLoadTexture("crashcodes.poi/images/coords.png") -- 44x44
  textures.coordsInverted = ShroudLoadTexture("crashcodes.poi/images/coords_inverted.png") -- 44x44


  textures.close = ShroudLoadTexture("crashcodes.poi/images/close.png") --18x18
  textures.up = ShroudLoadTexture("crashcodes.poi/images/up.png") --18x18
  textures.down = ShroudLoadTexture("crashcodes.poi/images/down.png") --18x18

  -- the image param is required to draw buttons
  -- don't always want to show an image
  textures.transparent = ShroudLoadTexture("crashcodes.poi/images/transparent_1x1.png")


  labels.heading = {
    visible = false, -- this is for debugging
    x = 1300,
    y = ShroudGetScreenY() / 2 - 100,
    width = 100,
    height = 350,
    text = "HEADING"
  }
  table.insert(draggables, labels.heading)

  labels.toNorth = {
    visible = true,
    startX = ShroudGetScreenX() / 2 - 5,
    startY = ShroudGetScreenY() / 2 - 10,
    x = ShroudGetScreenX() / 2 - 5,
    y = ShroudGetScreenY() / 2 - 10,
    width = 10,
    height = 20,
    text = "N"
  }
  

  drawables.toPOI = {
    visible = false,
    width = 40,
    height = 80,
    text = "0.0",
    draw = function(self)
      
      ShroudDrawTexture(
        self.x, 
        self.y, 
        40, 
        40, 
        textures.mark, 
        StretchToFit
      )

      -- let the text run beyond our specified width
      ShroudGUILabel(self.x, self.y + 40, 100, 40, self.text)
    end
  }
  drawables.toPOI.startX = ShroudGetScreenX() / 2 - drawables.toPOI.width / 2 
  drawables.toPOI.startY = ShroudGetScreenY() / 2 - drawables.toPOI.height / 2
  drawables.toPOI.x = drawables.toPOI.startX
  drawables.toPOI.y = drawables.toPOI.startY


  drawables.pois = {
    visible = true,
    x = 270,
    y = 130,
    width = 302,
    height = 500,
    dragging = false,
    showBody = true, 

    -- for footer
    buttons = {
      invertCoords = {
        visible = true,
        text = "", -- "invert\ncoords",
        tooltip = "some zones have an inverted coordinate system",

        -- should show what is, or what would change to if clicked?
        -- since the image doesn't really portray an action, then I'll have it show the state
        image = textures.coords,
        onClick = function()          
          setInvertCoords(not heading.invertCoords)

          -- TODO doing this in two places
          -- create the scene if needed
          if not scenes[currentSceneName] then
            scenes[currentSceneName] = {pois={}}
          end

          scenes[currentSceneName].invertCoords = heading.invertCoords
          saveSettings()
        end
      },
      mark = {
        visible = true,
        text = "",
        tooltip = "remember your location",
        image = textures.mark,
        onClick = function(self)
          if poi == nil then
            mark()
          else
            -- if the poi didn't have a name then lets make sure it get's removed from the list
            if poi.name then
              usePOI(nil)
            else              
              unmark()
            end
          end
        end
      },
      toggleNorth = {
        visible = true,
        text = "toggle\nNorth",
        tooltip = "Show North indicator",
        image = textures.transparent,
        onClick = function()
          labels.toNorth.visible = not labels.toNorth.visible
          saveSettings()
        end
      },
      help = {
        visible = true,
        text = "?",
        tooltip = "show help",
        image = textures.transparent,
        onClick = showHelp
      }
    },


    draw = function(self)
      local title = "POIs - " .. currentSceneName
      local titleHeight = 22
      local border = 10
      local x = self.x + border
      local bodyWidth = self.width - (border * 2)
      local padding = 2
      local footerHeight = 68
      local bodyHeight = self.height - titleHeight - footerHeight - border - padding
      
      ShroudDrawTexture(
        self.x, 
        self.y, 
        self.width, 
        self.height, 
        textures.blue, 
        StretchToFit
      )

      local close = {
        x = self.x + self.width - 20 - padding,
        y = self.y + 1,
        width = 20,
        height = 20,
        texture = textures.close
      }
      
      if ShroudButton(
          close.x,
          close.y,
          close.width,
          close.height,
          close.texture,
          "", "") then
        self.visible = false
        ConsoleLog("You have closed the POIs window. In Local chat type:")
        ConsoleLog("  " .. commands.pois.helpText)
      end

      local minimize = {
        x = self.x + self.width - 20 - 20 - padding - padding,
        y = self.y + 1,
        width = 20,
        height = 20,        
        texture = self.showBody and textures.down or textures.up
      }      
      
      if ShroudButton(
          minimize.x,
          minimize.y,
          minimize.width,
          minimize.height,
          self.showBody and textures.down or textures.up ,
          "", "") then
        self.showBody = not self.showBody

        if self.showBody then
          self.y = self.y - self.restoreBodyHeight
          self.height = self.height + self.restoreBodyHeight
        else
          self.restoreBodyHeight = bodyHeight
          self.y = self.y + bodyHeight
          self.height = self.height - bodyHeight
        end
      end


      -- title
      ShroudGUILabel(x, self.y, bodyWidth, titleHeight, title)

      -- body
      if self.showBody then
        ShroudDrawTexture(
          x, 
          self.y + titleHeight, 
          bodyWidth, 
          bodyHeight, 
          textures.blue, 
          StretchToFit
        )
      end

      -- add a little padding
      x = x + padding
      bodyWidth = bodyWidth - (padding * 2)
      local y = self.y + titleHeight + padding

      if self.showBody then
        if scenes[currentSceneName] then
          local rowHeight = 22
          for name, p in pairs(scenes[currentSceneName].pois) do
            if poi == p then
              ShroudDrawTexture(x, y, 20, 20, textures.mark, StretchToFit)
            else
              if ShroudButton(x, y, 20, 20, textures.transparent, "", "") then
                usePOI(p)
              end
            end
            ShroudGUILabel(x + 22, y, bodyWidth - 22, rowHeight, formatPOI(p))
            y = y + rowHeight
          end
        end
      end -- implied else, we don't wanna draw any of the body


      -- footer buttons
      y = self.y + self.height - border - footerHeight
      local buttonSize = 68 -- used for width and height
      for i,button in pairs(self.buttons) do
        if button.visible then
          if ShroudButton(x, y, buttonSize, buttonSize, button.image, button.text, button.tooltip) and button.onClick then
            button.onClick(button)
          end
          x = x + buttonSize + 2
        end
      end
    end
  }
  table.insert(draggables, drawables.pois)

  loadSettings()
  ConsoleLog("[EF1BEF]crashcodes.poi[-] loaded.")
  ConsoleLog('  as player '..playerName) -- DEBUG
  showHelp()

  started = true
end


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- ShroudOnGUI()
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function ShroudOnGUI()
  if not started then return end

  for i,label in pairs(labels) do
    if label.visible then
      ShroudDrawTexture(label.x, label.y, label.width, label.height, textures.blue, StretchToFit)
      ShroudGUILabel(label.x, label.y, label.width, label.height, label.text)
    end
  end
  
  for i,drawable in pairs(drawables) do
    if drawable.visible then
      drawable.draw(drawable)
    end
  end

end


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- ShroudOnUpdate()
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function ShroudOnUpdate()
  if not started then return end

  -- ShroudGetPlayerName() may return "none" when initially loading into the game
  if playerName == "none" then
    playerName = ShroudGetPlayerName()
    if playerName ~= "none" then
      ConsoleLog("  now player "..playerName)
    end
  end

  -- handle dragging
  if ShroudGetOnKeyDown("Mouse0") then
    for i, draggable in pairs(draggables) do
      if isInRect(ShroudMouseX, ShroudMouseY, draggable) then
        beginDragging(draggable)

        -- only drag one at a time
        if i ~= 1 then
          table.insert(draggables, 1, table.remove(draggables, i))
        end
        break
      end
    end
  end
  if draggables[1] and draggables[1].dragging then
    if ShroudGetOnKeyUp("Mouse0") then
      endDragging(ShroudGetScreenX(), ShroudGetScreenY(), draggables[1])
    else
      drag(draggables[1])
    end
  end


  -- every one second
  local time = os.time()
  if time - lastProcessUpdate >= 1 then
    updateHeading()
    
    if ShroudGetCurrentSceneName() ~= currentSceneName then
      currentSceneName = ShroudGetCurrentSceneName()
      usePOI(nil)
      setInvertCoords(scenes[currentSceneName] and scenes[currentSceneName].invertCoords)
    end

  end
end


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- ShroudOnConsoleInput(string type, string sourcePlayer, string message)
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function ShroudOnConsoleInput(type, sourcePlayer, fullMessage)
  if not started then return end
  local message = string.sub(fullMessage, string.find(fullMessage, ":") + 2)

  if sourcePlayer == playerName then
    for i, command in pairs(commands) do
      if command.isMatch(message) then
        command.onMatch(message)
        break
      end
    end
  end
end


function updateHeading()

  -- not ready to set the heading
  if ShroudPlayerX == nil or ShroudPlayerY == nil then
    return
  end

  -- set the heading for the first time
  if heading.location == nil then
    heading.location = {
      x = ShroudPlayerX, 
      y = ShroudPlayerY, 
      z = ShroudPlayerZ
    }
    return
  end


  -- check heading changed, we don't care about elevation (y) atm
  if ShroudPlayerX ~= heading.location.x or ShroudPlayerZ ~= heading.location.z then
    heading.prevLocation = heading.location
    heading.location = {
      x = ShroudPlayerX, 
      y = ShroudPlayerY, 
      z = ShroudPlayerZ
    }

    heading.diff = {
      x = heading.location.x - heading.prevLocation.x,
      y = heading.location.y - heading.prevLocation.y,
      z = heading.location.z - heading.prevLocation.z
    }

    -- we are going to use the current and previous locations 
    -- to figure out which way we are facing. 
    -- TODO: it's not great cuss what if run any direction other than forward?
    
    -- do a triangle thing
    local a = heading.diff.x
    local b = heading.diff.z
    local c = math.sqrt(a * a + b * b)
    local angleB = math.acos((b*b + c*c - a*a) / (2 * b * c) )

    -- in the Whiteguard foothills
    -- x rises towards the west
    -- z rises towards the north
    -- in novia 
    -- x rises towards the east
    -- z rises towards the north

    -- The direction should have north be at 0/2pi and rotate clockwise      
    -- angleB ends up rising as you turn left or right towards south (non-inverted maps)
    -- this means both east and west would end up being the same! Doh.
    -- we can adjust this easily enough by adding or subtracting multiples of pi
    -- the possiblity of inverted coordinates and an extra wrinkle ot deal with
    -- the direction is in radians
    local direction
    if heading.invertCoords then
      if a > 0 then
        direction = math.pi + angleB
      else 
        direction = math.pi - angleB
      end
    else
      if a > 0 then
        direction = angleB
      else 
        direction = 2 * math.pi - angleB
      end
    end

    -- labels.heading.text = string.format(
    --   "CURR LOC\nx=%.4f\ny=%.4f\nz=%.4f\n" ..
    --   "PREV LOC\nx=%.4f\ny=%.4f\nz=%.4f\n" ..
    --   "DIFF\nx=%.4f\ny=%.4f\nz=%.4f\n" ..
    --   "rad %.4f\ndeg %.4f\n"..
    --   "DIRECTION\n"..
    --   "rad %.4f\ndeg %.4f\n", 
    --   ShroudPlayerX, ShroudPlayerY, ShroudPlayerZ,
    --   heading.prevLocation.x, heading.prevLocation.y, heading.prevLocation.z,
    --   heading.diff.x, heading.diff.y, heading.diff.z,
    --   angleB, math.deg(angleB),
    --   direction, math.deg(direction)
    -- )

    -- todo: lookup the symbol for degrees
    labels.heading.text = string.format("HEADING\n%.0f degrees\n", math.deg(direction))

    -- do some more triangle stuff
    c = -75
    local angleC = math.pi / 2 -- 90
    angleB = direction
    local angleA = math.pi - angleB - angleC
    a = c * (math.sin(angleA) / math.sin(angleC) )
    b = c * (math.sin(angleB) / math.sin(angleC) )

    labels.toNorth.x = labels.toNorth.startX + b
    labels.toNorth.y = labels.toNorth.startY + a

    if poi then

      -- do some more triangle stuff
      a = poi.x - heading.location.x
      b = poi.z - heading.location.z
      c = math.sqrt(a * a + b * b)
      local poiDistance = c
      
      if poiDistance <= 1 then
        -- don't bother telling which way when we are this close

        drawables.toPOI.x = drawables.toPOI.startX
        drawables.toPOI.y = drawables.toPOI.startY
        
        drawables.toPOI.text = string.format("%.1f\n%s", poiDistance, poi.name or "")
      else
        angleB = math.acos((b*b + c*c - a*a) / (2 * b * c) )

        local poiDirection
        if heading.invertCoords then
          if a > 0 then
            poiDirection = math.pi + angleB
          else 
            poiDirection = math.pi - angleB
          end
        else
          if a > 0 then
            poiDirection = angleB
          else 
            poiDirection = 2 * math.pi - angleB
          end
        end

        c = -100
        -- local angleC = math.pi / 2 -- 90
        angleA = direction - poiDirection
        angleB = math.pi - angleA - angleC
        a = c * (math.sin(angleA) / math.sin(angleC) )
        b = c * (math.sin(angleB) / math.sin(angleC) )

        drawables.toPOI.x = drawables.toPOI.startX + a
        drawables.toPOI.y = drawables.toPOI.startY + b
        drawables.toPOI.text = string.format("%.1f\n%s", poiDistance, poi.name or "")
        
        labels.heading.text = labels.heading.text ..
          string.format(
            "\nPOI\nrad %.4f\ndeg %.4f\n" ..
            "poi dist %.1f", 
            poiDirection, math.deg(poiDirection),
            poiDistance
          )
      end

    end
  end
end


function showHelp()
  ConsoleLog("In Local chat type:")
  for name,command in pairs(commands) do
    ConsoleLog("  " .. command.helpText)
  end
end

function markCoords(x, y, z, name)
  local sceneName = ShroudGetCurrentSceneName()
  if not scenes[sceneName] then
    scenes[sceneName] = {pois = {}}
  end
  local pois = scenes[sceneName].pois
  local poi = {
    name = name,
    -- scene = sceneName,
    x = x,
    y = y,
    z = z
  }
  -- use "[none]" for the key, but don't display on toPOI
  if name == nil then
    name = "[none]"
  end
  pois[name] = poi

  usePOI(pois[name])
  saveSettings()
end

function mark(name)
  markCoords(ShroudPlayerX, ShroudPlayerY, ShroudPlayerZ, name)
end


function unmark(name)
  local sceneName = ShroudGetCurrentSceneName()
  if not scenes[sceneName] then
    ConsoleLog("No POIs for this scene," .. sceneName .." to unmark.")
    return 
  end

  if name == nil then
    name = "[none]"
  end
  if scenes[sceneName].pois[name] then
    scenes[sceneName].pois[name] = nil
  else
    ConsoleLog('No POIs by the name "' .. name .. '"')
  end

  usePOI(nil)
  saveSettings()
end


function usePOI(poiToUse)
  if poiToUse then
    drawables.toPOI.visible = true
    drawables.pois.buttons.mark.image = textures.clearPOI
  else
    drawables.toPOI.visible = false
    drawables.pois.buttons.mark.image = textures.mark
  end
  poi = poiToUse
end


function printPOIs()
  ConsoleLog("[EF1BEF]!pois[-]")
  for sceneName,scene in pairs(scenes) do
    ConsoleLog(sceneName)
    for poiName,poi in pairs(scene.pois) do
      ConsoleLog("  " .. formatPOI(poi))
    end
  end
end


function formatPOI(poi)
  return string.format("%s @ %.0f,%.0f,%.0f", poi.name or "[none]", poi.x, poi.y, poi.z)
end


function setInvertCoords(invertCoords)
  heading.invertCoords = invertCoords
  if heading.invertCoords then
    drawables.pois.buttons.invertCoords.image = textures.coordsInverted
    ConsoleLog("Coordinate system inverted. z grows as it approaches South, and x grows as it approaches East")
  else
    drawables.pois.buttons.invertCoords.image = textures.coords
    ConsoleLog("Coordinate system set to normal. z grows as it approaches North, and x grows as it approaches West")
  end
end


function beginDragging(window)
  window.dragging = {
    mouseStart = {
      x = ShroudMouseX,
      y = ShroudMouseY
    },
    windowStart = {
      x = window.x,
      y = window.y
    }
  }
end


function drag(window)
  local dragging = window.dragging
  window.x = dragging.windowStart.x + ShroudMouseX - dragging.mouseStart.x
  window.y = dragging.windowStart.y + ShroudMouseY - dragging.mouseStart.y
end


local onScreenMin = 50
function endDragging(screenX, screenY, window)
  window.dragging = false
  forceWindowOnScreen(screenX, screenY, window)
  saveSettings()
end

function forceWindowOnScreen(screenX, screenY, window)

  -- left
  if window.x + window.width <  onScreenMin then
    window.x = onScreenMin - window.width
  end

  -- right
  if window.x > screenX - onScreenMin then
    window.x = screenX - onScreenMin
  end

  -- top
  if window.y + window.height <  onScreenMin then
    window.y = onScreenMin - window.height
  end

  -- bottom
  if window.y > screenY - 50 then
    window.y = screenY - 50
  end
end




-- https://github.com/moonsharp-devs/moonsharp/issues?q=is%3Aissue+json+negative+is%3Aclosed
-- can't parse negatives
-- so I guess we can convert them to strings, then back
function stringifySomeSettings(settings) 
  local result = deepCopy(settings)
  for sceneName, scene in pairs(result.scenes) do
    for poiName, poi in pairs(scene.pois) do
      result.scenes[sceneName].pois[poiName].x = tostring(poi.x)
      result.scenes[sceneName].pois[poiName].y = tostring(poi.y)
      result.scenes[sceneName].pois[poiName].z = tostring(poi.z)
    end 
  end
  
  result.poisWindow.x = tostring(result.poisWindow.x)
  result.poisWindow.y = tostring(result.poisWindow.y)
  result.poisWindow.height = tostring(result.poisWindow.height)
  if settings.poisWindow.restoreBodyHeight then
    settings.restoreBodyHeight = tostring(settings.poisWindow.restoreBodyHeight)
  end

  return result
end


function unstringifySomeSettings(settings)
  local result = deepCopy(settings)
  for sceneName, scene in pairs(result.scenes) do
    for poiName, poi in pairs(scene.pois) do
      result.scenes[sceneName].pois[poiName].x = tonumber(poi.x)
      result.scenes[sceneName].pois[poiName].y = tonumber(poi.y)
      result.scenes[sceneName].pois[poiName].z = tonumber(poi.z)
    end 
  end

  result.poisWindow.x = tonumber(result.poisWindow.x)
  result.poisWindow.y = tonumber(result.poisWindow.y)
  result.poisWindow.height = tonumber(result.poisWindow.height)
  if settings.poisWindow.restoreBodyHeight then
    settings.restoreBodyHeight = tonumber(settings.poisWindow.restoreBodyHeight)
  end

  return result
end


function saveSettings()
  local settings = {
    scenes = scenes,
    poisWindow = {
      visible = drawables.pois.visible,
      x = drawables.pois.x,
      y = drawables.pois.y,
      height = drawables.pois.height,
      showBody = drawables.pois.showBody,
    },
    toNorth = {
      visible = labels.toNorth.visible
    }
  }
  if not drawables.pois.showBody then
    settings.poisWindow.restoreBodyHeight = drawables.pois.restoreBodyHeight
  end

  local file = io.open(settingsFileName, "w")  
  file:write(json.serialize(stringifySomeSettings(settings)))
  file:close()
end


function loadSettings()
  ConsoleLog("loading settings")
  local file = io.open(settingsFileName, "r")
  local fileAsJSON = file:read("*a")  
  file:close()

  local settings = unstringifySomeSettings(json.parse(fileAsJSON))

  scenes = settings.scenes
  
  drawables.pois.visible = settings.poisWindow.visible
  drawables.pois.x = settings.poisWindow.x
  drawables.pois.y = settings.poisWindow.y
  drawables.pois.height = settings.poisWindow.height
  drawables.pois.showBody = settings.poisWindow.showBody
  if not drawables.pois.showBody then
    drawables.pois.restoreBodyHeight = settings.poisWindow.restoreBodyHeight
  end
  
  forceWindowOnScreen(ShroudGetScreenX(), ShroudGetScreenY(),  drawables.pois)

  labels.toNorth.visible = settings.toNorth and settings.toNorth.visible

  -- if we loadSettings() outside of ShroudOnStart below will be necessary
  -- until then we are counting on the initial scene switching logic to set the invertCoords

  -- currentSceneName may not have been set yet.
  -- don't want to set it here though because that may interfere with scene switching logic
  -- local sceneName = ShroudGetCurrentSceneName()
  -- local invertCoords = scenes[sceneName] and scenes[sceneName].invertCoords
  -- if invertCoords ~= heading.invertCoords then
  --   ConsoleLog("loadSetttings setting invertCoords")
  --   setInvertCoords(invertCoords)
  -- end

end


function isInRect(x, y, rect)
  return x >= rect.x 
    and x <= rect.x + rect.width
    and y >= rect.y
    and y <= rect.y + rect.height
end


function table.tostring(t)
  -- todo: make recursive
  local result = "{\n"
  for key,value in pairs(t) do
    -- key .. "," .. tostring(value)
    result = result .. "\t" .. key .. ":\"" .. tostring(value) .. "\",\n"
  end
  return result .. "}"
end

-- make a copy of the source
-- mostly pointless if not starting with a table
function deepCopy(source)
  local result
  if type(source) == "table" then
    result = {}
    for key,value in pairs(source) do
      result[key] = deepCopy(value)
    end
  else 
    result = source
  end

  return result
end

