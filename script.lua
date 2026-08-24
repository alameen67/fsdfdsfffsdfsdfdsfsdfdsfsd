--[[
    Brainrot Chooser & WebSocket Sender
    Configure server URL if needed:
]]
local WS_URL = "ws://localhost:3000/ws"
local HTTP_URL = "http://localhost:3000/api/post"

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

-- Initialize WebSocket
local socket = nil
local function initWebSocket()
    local wsConnector = (WebSocket and WebSocket.connect) 
        or (syn and syn.websocket and syn.websocket.connect)
        or (krnl and krnl.websocket and krnl.websocket.connect)

    if wsConnector then
        local success, ws = pcall(wsConnector, WS_URL)
        if success and ws then
            socket = ws
            print("[+] Connected to WebSocket:", WS_URL)
        end
    end
end
initWebSocket()

-- Post Function
local function postBrainrot(item)
    if not item then return false, "No brainrot selected" end

    local payload = {
        username = LocalPlayer.Name,
        brainrotName = item.name or "Unknown",
        generation = item.gen or "N/A",
        mutation = item.mutation or "Normal"
    }
    
    local json = HttpService:JSONEncode(payload)
    local sent = false

    -- 1. Try WebSocket
    if socket then
        local success = pcall(function()
            if socket.Send then
                socket:Send(json)
            elseif socket.send then
                socket:send(json)
            end
        end)
        if success then
            sent = true
            print("[?] Sent to WebSocket:", item.name)
        end
    end

    -- 2. Fallback to HTTP POST
    if not sent then
        local httpRequest = request or http_request or (syn and syn.request) or (http and http.request)
        if httpRequest then
            task.spawn(function()
                httpRequest({
                    Url = HTTP_URL,
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = json
                })
                print("[?] Sent to HTTP POST:", item.name)
            end)
            sent = true
        end
    end

    return sent
end

-- 1. Plot Scanner
local function scanBrainrots()
    local myPlot = nil
    local plotsFolder = Workspace:FindFirstChild("Plots")

    if plotsFolder then
        for _, plot in ipairs(plotsFolder:GetChildren()) do
            local sign = plot:FindFirstChild("PlotSign")
            if sign then
                for _, d in ipairs(sign:GetDescendants()) do
                    if d:IsA("TextLabel") then
                        local txt = d.Text:lower()
                        if txt:find(LocalPlayer.Name:lower()) or txt:find(LocalPlayer.DisplayName:lower()) or (txt:find("your base") and not txt:find("empty base")) then
                            myPlot = plot
                            break
                        end
                    end
                end
            end
            if myPlot then break end
        end
    end

    if not myPlot then
        warn("[!] Could not locate your plot.")
        return {}
    end

    -- 2. Gather FastOverheadTemplates from Workspace.Debris
    local debris = Workspace:FindFirstChild("Debris")
    local debrisOverheads = {}

    if debris then
        for _, item in ipairs(debris:GetChildren()) do
            local overhead = item:FindFirstChild("AnimalOverhead")
            if overhead then
                local data = {}
                for _, d in ipairs(overhead:GetDescendants()) do
                    if d:IsA("TextLabel") and d.Text and #d.Text > 0 then
                        data[d.Name] = d.Text
                    end
                end
                if data.DisplayName or data.Generation then
                    table.insert(debrisOverheads, {
                        pos = item.Position,
                        data = data
                    })
                end
            end
        end
    end

    -- 3. Match models on your plot
    local list = {}
    for _, model in ipairs(myPlot:GetChildren()) do
        if model:IsA("Model") and model.Name ~= "Cash" and model.Name ~= "FriendPanel" then
            local modelPos = model:GetPivot().Position
            local bestMatch = nil
            local bestDist = math.huge
            
            for _, oh in ipairs(debrisOverheads) do
                local dist = (oh.pos - modelPos).Magnitude
                if oh.data.DisplayName and (oh.data.DisplayName:lower() == model.Name:lower() or model.Name:lower():find(oh.data.DisplayName:lower())) then
                    if dist < bestDist then
                        bestDist = dist
                        bestMatch = oh.data
                    end
                elseif dist < 15 and dist < bestDist then
                    bestDist = dist
                    bestMatch = oh.data
                end
            end
            
            local name = bestMatch and bestMatch.DisplayName or model.Name
            local gen = bestMatch and bestMatch.Generation or "N/A"
            local mutation = bestMatch and bestMatch.Mutation or "Normal"
            local rarity = bestMatch and bestMatch.Rarity or "Unknown"
            local price = bestMatch and bestMatch.Price or "N/A"
            
            table.insert(list, {
                name = name,
                gen = gen,
                mutation = mutation,
                rarity = rarity,
                price = price
            })
        end
    end

    return list
end

-- 4. In-Game Chooser UI
local existingGui = CoreGui:FindFirstChild("BrainrotChooserGui") or (LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("BrainrotChooserGui"))
if existingGui then existingGui:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BrainrotChooserGui"
screenGui.ResetOnSpawn = false

pcall(function() screenGui.Parent = CoreGui end)
if not screenGui.Parent then screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- Main Window
local main = Instance.new("Frame")
main.Size = UDim2.new(0, 360, 0, 460)
main.Position = UDim2.new(0.5, -180, 0.5, -230)
main.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 10)
mainCorner.Parent = main

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(45, 45, 55)
mainStroke.Thickness = 1.5
mainStroke.Parent = main

-- Top Bar
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 40)
topBar.BackgroundTransparency = 1
topBar.Parent = main

local headerText = Instance.new("TextLabel")
headerText.Size = UDim2.new(1, -80, 1, 0)
headerText.Position = UDim2.new(0, 14, 0, 0)
headerText.BackgroundTransparency = 1
headerText.Text = "Brainrot Chooser"
headerText.TextColor3 = Color3.fromRGB(255, 255, 255)
headerText.Font = Enum.Font.SourceSansBold
headerText.TextSize = 17
headerText.TextXAlignment = Enum.TextXAlignment.Left
headerText.Parent = topBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -36, 0, 6)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Text = "?"
closeBtn.Font = Enum.Font.SourceSansBold
closeBtn.TextSize = 14
closeBtn.Parent = topBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function()
    screenGui:Destroy()
end)

-- Selected Item Preview Box
local previewBox = Instance.new("Frame")
previewBox.Size = UDim2.new(1, -24, 0, 95)
previewBox.Position = UDim2.new(0, 12, 0, 42)
previewBox.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
previewBox.BorderSizePixel = 0
previewBox.Parent = main

local previewCorner = Instance.new("UICorner")
previewCorner.CornerRadius = UDim.new(0, 8)
previewCorner.Parent = previewBox

local previewStroke = Instance.new("UIStroke")
previewStroke.Color = Color3.fromRGB(50, 50, 65)
previewStroke.Parent = previewBox

local selectedTitle = Instance.new("TextLabel")
selectedTitle.Size = UDim2.new(1, -16, 0, 22)
selectedTitle.Position = UDim2.new(0, 8, 0, 6)
selectedTitle.BackgroundTransparency = 1
selectedTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
selectedTitle.Text = "Selected: None"
selectedTitle.Font = Enum.Font.SourceSansBold
selectedTitle.TextSize = 15
selectedTitle.TextXAlignment = Enum.TextXAlignment.Left
selectedTitle.Parent = previewBox

local selectedStats = Instance.new("TextLabel")
selectedStats.Size = UDim2.new(1, -16, 0, 55)
selectedStats.Position = UDim2.new(0, 8, 0, 30)
selectedStats.BackgroundTransparency = 1
selectedStats.TextColor3 = Color3.fromRGB(200, 200, 210)
selectedStats.Text = "Click a Brainrot from the list below to select it."
selectedStats.Font = Enum.Font.SourceSans
selectedStats.TextSize = 13
selectedStats.TextXAlignment = Enum.TextXAlignment.Left
selectedStats.TextYAlignment = Enum.TextYAlignment.Top
selectedStats.Parent = previewBox

-- Scroll List for Brainrots
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -24, 0, 215)
scroll.Position = UDim2.new(0, 12, 0, 145)
scroll.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = main

local scrollCorner = Instance.new("UICorner")
scrollCorner.CornerRadius = UDim.new(0, 8)
scrollCorner.Parent = scroll

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.Parent = scroll

local listPadding = Instance.new("UIPadding")
listPadding.PaddingTop = UDim.new(0, 6)
listPadding.PaddingBottom = UDim.new(0, 6)
listPadding.PaddingLeft = UDim.new(0, 6)
listPadding.PaddingRight = UDim.new(0, 6)
listPadding.Parent = scroll

-- Bottom Buttons (SEND & REFRESH)
local sendBtn = Instance.new("TextButton")
sendBtn.Size = UDim2.new(1, -130, 0, 42)
sendBtn.Position = UDim2.new(0, 12, 1, -54)
sendBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 255)
sendBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
sendBtn.Text = "SEND TO WEB"
sendBtn.Font = Enum.Font.SourceSansBold
sendBtn.TextSize = 16
sendBtn.Parent = main

local sendCorner = Instance.new("UICorner")
sendCorner.CornerRadius = UDim.new(0, 8)
sendCorner.Parent = sendBtn

local refreshBtn = Instance.new("TextButton")
refreshBtn.Size = UDim2.new(0, 100, 0, 42)
refreshBtn.Position = UDim2.new(1, -112, 1, -54)
refreshBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
refreshBtn.TextColor3 = Color3.fromRGB(220, 220, 230)
refreshBtn.Text = "? REFRESH"
refreshBtn.Font = Enum.Font.SourceSansBold
refreshBtn.TextSize = 14
refreshBtn.Parent = main

local refreshCorner = Instance.new("UICorner")
refreshCorner.CornerRadius = UDim.new(0, 8)
refreshCorner.Parent = refreshBtn

-- State
local currentSelection = nil
local itemCards = {}

local function updatePreview(item)
    currentSelection = item
    if item then
        selectedTitle.Text = "Selected: " .. item.name
        selectedStats.Text = string.format("Generation: %s\nMutation: %s\nRarity: %s", item.gen, item.mutation, item.rarity or "Unknown")
        selectedStats.TextColor3 = Color3.fromRGB(240, 240, 240)
    else
        selectedTitle.Text = "Selected: None"
        selectedStats.Text = "Click a Brainrot from the list below to select it."
        selectedStats.TextColor3 = Color3.fromRGB(150, 150, 160)
    end
end

local function populateList()
    for _, c in ipairs(itemCards) do
        c:Destroy()
    end
    itemCards = {}
    currentSelection = nil
    updatePreview(nil)

    local list = scanBrainrots()

    if #list == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, 0, 0, 40)
        empty.BackgroundTransparency = 1
        empty.TextColor3 = Color3.fromRGB(150, 150, 160)
        empty.Text = "No brainrots found on your plot."
        empty.Font = Enum.Font.SourceSansItalic
        empty.TextSize = 14
        empty.Parent = scroll
        table.insert(itemCards, empty)
        return
    end

    for idx, item in ipairs(list) do
        local card = Instance.new("TextButton")
        card.Size = UDim2.new(1, 0, 0, 46)
        card.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
        card.BorderSizePixel = 0
        card.AutoButtonColor = false
        card.Text = ""
        card.Parent = scroll

        local cardCorner = Instance.new("UICorner")
        cardCorner.CornerRadius = UDim.new(0, 6)
        cardCorner.Parent = card

        local cardStroke = Instance.new("UIStroke")
        cardStroke.Color = Color3.fromRGB(45, 45, 55)
        cardStroke.Thickness = 1
        cardStroke.Parent = card

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -12, 0, 20)
        title.Position = UDim2.new(0, 8, 0, 4)
        title.BackgroundTransparency = 1
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.Text = string.format("%d. %s", idx, item.name)
        title.Font = Enum.Font.SourceSansBold
        title.TextSize = 14
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = card

        local sub = Instance.new("TextLabel")
        sub.Size = UDim2.new(1, -12, 0, 18)
        sub.Position = UDim2.new(0, 8, 0, 23)
        sub.BackgroundTransparency = 1
        sub.TextColor3 = Color3.fromRGB(160, 160, 175)
        sub.Text = string.format("Gen: %s  |  Mut: %s", item.gen, item.mutation)
        sub.Font = Enum.Font.SourceSans
        sub.TextSize = 12
        sub.TextXAlignment = Enum.TextXAlignment.Left
        sub.Parent = card

        card.MouseButton1Click:Connect(function()
            -- Unhighlight others
            for _, other in ipairs(itemCards) do
                if other:IsA("TextButton") then
                    other.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
                    local s = other:FindFirstChildOfClass("UIStroke")
                    if s then s.Color = Color3.fromRGB(45, 45, 55) end
                end
            end

            -- Highlight selected
            card.BackgroundColor3 = Color3.fromRGB(40, 50, 75)
            cardStroke.Color = Color3.fromRGB(0, 140, 255)
            updatePreview(item)
        end)

        table.insert(itemCards, card)
    end

    -- Automatically select the first one if available
    if #list > 0 then
        itemCards[1].BackgroundColor3 = Color3.fromRGB(40, 50, 75)
        local s = itemCards[1]:FindFirstChildOfClass("UIStroke")
        if s then s.Color = Color3.fromRGB(0, 140, 255) end
        updatePreview(list[1])
    end
end

populateList()

-- Event Listeners
refreshBtn.MouseButton1Click:Connect(function()
    refreshBtn.Text = "..."
    populateList()
    task.wait(0.3)
    refreshBtn.Text = "? REFRESH"
end)

sendBtn.MouseButton1Click:Connect(function()
    if not currentSelection then
        sendBtn.Text = "SELECT ONE FIRST!"
        sendBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
        task.wait(1)
        sendBtn.Text = "SEND TO WEB"
        sendBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 255)
        return
    end

    sendBtn.Text = "SENDING..."
    sendBtn.BackgroundColor3 = Color3.fromRGB(220, 160, 20)

    local ok = postBrainrot(currentSelection)

    if ok then
        sendBtn.Text = "SENT! (15s on Web)"
        sendBtn.BackgroundColor3 = Color3.fromRGB(30, 180, 80)
    else
        sendBtn.Text = "FAILED TO SEND"
        sendBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    end

    task.wait(1.5)
    sendBtn.Text = "SEND TO WEB"
    sendBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 255)
end)

print("[+] Brainrot Chooser loaded successfully.")
