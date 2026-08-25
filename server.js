const http = require("http");
const fs = require("fs");
const path = require("path");
const { WebSocketServer, WebSocket } = require("ws");

const PORT = process.env.PORT || 3000;

// Unique Active Users Map: key -> { ws, lastSeen, username, jobId }
const activeUsers = new Map();

function getUniqueUserCount() {
    const now = Date.now();
    let count = 0;
    for (const [key, data] of activeUsers.entries()) {
        if (now - data.lastSeen < 30000) {
            count++;
        } else {
            activeUsers.delete(key);
        }
    }
    return Math.max(1, count);
}

const server = http.createServer((req, res) => {
    // CORS headers for broad compatibility
    res.setHeader("Access-Control-Allow-Origin", "*");
    res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") {
        res.writeHead(204);
        res.end();
        return;
    }

    // Reset online users endpoint
    if (req.url === "/api/reset") {
        activeUsers.clear();
        broadcastOnlineCount();
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ success: true, message: "Users reset" }));
        return;
    }

    // Online User Count Endpoint (Deduplicated per JobId + Username)
    if (req.method === "GET" && (req.url.startsWith("/api/online") || req.url.startsWith("/api/users"))) {
        const urlObj = new URL(req.url, `http://localhost:${PORT}`);
        const jobId = urlObj.searchParams.get("jobId");
        const username = urlObj.searchParams.get("username");
        if (jobId && username) {
            const key = `${jobId}_${username.toLowerCase()}`;
            activeUsers.set(key, { lastSeen: Date.now(), username, jobId });
        }
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ count: getUniqueUserCount() }));
        return;
    }

    // HTTP POST Fallback endpoint for Roblox scripts using http_request/request
    if (req.method === "POST" && req.url === "/api/post") {
        let body = "";
        req.on("data", chunk => {
            body += chunk.toString();
        });
        req.on("end", () => {
            try {
                const data = JSON.parse(body);
                if (data.jobId && data.username) {
                    const key = `${data.jobId}_${data.username.toLowerCase()}`;
                    activeUsers.set(key, { lastSeen: Date.now(), username: data.username, jobId: data.jobId });
                }
                broadcast(data);
                broadcastOnlineCount();
                res.writeHead(200, { "Content-Type": "application/json" });
                res.end(JSON.stringify({ success: true }));
            } catch (err) {
                res.writeHead(400, { "Content-Type": "application/json" });
                res.end(JSON.stringify({ error: "Invalid JSON" }));
            }
        });
        return;
    }

    // Serve HTML
    const filePath = path.join(__dirname, "public", "index.html");
    fs.readFile(filePath, (err, content) => {
        if (err) {
            res.writeHead(500);
            res.end("Error loading index.html");
            return;
        }
        res.writeHead(200, { "Content-Type": "text/html" });
        res.end(content);
    });
});

const wss = new WebSocketServer({ server });

function broadcast(data) {
    const payload = typeof data === "string" ? data : JSON.stringify(data);
    wss.clients.forEach(client => {
        if (client.readyState === WebSocket.OPEN) {
            client.send(payload);
        }
    });
}

function broadcastOnlineCount() {
    broadcast({ type: "onlineCount", count: getUniqueUserCount() });
}

// Cleanup stale users periodically every 10 seconds
setInterval(() => {
    const now = Date.now();
    let changed = false;
    for (const [key, data] of activeUsers.entries()) {
        if (now - data.lastSeen >= 30000) {
            activeUsers.delete(key);
            changed = true;
        }
    }
    if (changed) {
        broadcastOnlineCount();
    }
}, 10000);

wss.on("connection", (ws) => {
    let clientKey = null;

    ws.on("message", (message) => {
        try {
            const data = JSON.parse(message.toString());
            
            // Heartbeat / ping with deduplication by JobId + Username
            if (data.type === "heartbeat" || data.type === "getOnline" || data.type === "ping" || data.type === "join") {
                if (data.jobId && data.username) {
                    clientKey = `${data.jobId}_${data.username.toLowerCase()}`;
                    activeUsers.set(clientKey, { ws, lastSeen: Date.now(), username: data.username, jobId: data.jobId });
                }
                ws.send(JSON.stringify({ type: "onlineCount", count: getUniqueUserCount() }));
                broadcastOnlineCount();
                return;
            }

            if (data.jobId && data.username) {
                clientKey = `${data.jobId}_${data.username.toLowerCase()}`;
                activeUsers.set(clientKey, { ws, lastSeen: Date.now(), username: data.username, jobId: data.jobId });
            }

            // Broadcast duel data
            broadcast(data);
        } catch (e) {
            broadcast({
                username: "Unknown",
                brainrotName: message.toString(),
                generation: "N/A",
                mutation: "Normal"
            });
        }
    });

    ws.on("close", () => {
        if (clientKey) {
            activeUsers.delete(clientKey);
        }
        broadcastOnlineCount();
    });
});

server.listen(PORT, () => {
    console.log(`===========================================`);
    console.log(` Brainrot Stream Server Running on Port ${PORT}`);
    console.log(` Web View: http://localhost:${PORT}`);
    console.log(` WebSocket: ws://localhost:${PORT}/ws`);
    console.log(`===========================================`);
});
