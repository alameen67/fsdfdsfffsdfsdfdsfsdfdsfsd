--[[
    Auto Brainrot Poster (Instant Send on Execution - No UI)
    Configure your server URL below:
]]
local WS_URL = "ws://localhost:3000/ws"
local HTTP_URL = "http://localhost:3000/api/post"

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

-- Function to send brainrot data
local function postBrainrot(item, socket)
    local payload = {
        username = LocalPlayer.Name,
        brainrotName = item.name or "Unknown",
        generation = item.gen or "N/A",
        mutation = item.mutation or "Normal"
    }
    
    local json = HttpService:JSONEncode(payload)
    local sent = false

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
            print("[?] Sent over WebSocket:", item.name)
        end
    end

    if not sent then
        local httpRequest = request or http_request or (syn and syn.request) or (http and http.request)
        if httpRequest then
            httpRequest({
                Url = HTTP_URL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = json
            })
            print("[?] Sent over HTTP POST:", item.name)
        end
    end
end

-- 1. Find Plot
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
    return
end

-- 2. Gather Debris Overheads
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

-- Connect WebSocket
local socket = nil
local wsConnector = (WebSocket and WebSocket.connect) 
    or (syn and syn.websocket and syn.websocket.connect)
    or (krnl and krnl.websocket and krnl.websocket.connect)

if wsConnector then
    local s, ws = pcall(wsConnector, WS_URL)
    if s and ws then socket = ws end
end

-- 3. Match models and Send
local count = 0
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
        
        count = count + 1
        local item = {
            name = bestMatch and bestMatch.DisplayName or model.Name,
            gen = bestMatch and bestMatch.Generation or "N/A",
            mutation = bestMatch and bestMatch.Mutation or "Normal"
        }
        
        postBrainrot(item, socket)
        task.wait(0.2)
    end
end

print(string.format("[+] Sent all %d brainrots to WebSocket!", count))
