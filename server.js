const http = require("http");
const fs = require("fs");
const path = require("path");
const { WebSocketServer, WebSocket } = require("ws");

const PORT = process.env.PORT || 3000;

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

    // Online User Count Endpoint
    if (req.method === "GET" && (req.url === "/api/online" || req.url === "/api/users")) {
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ count: wss.clients.size }));
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
                broadcast(data);
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
    broadcast({ type: "onlineCount", count: wss.clients.size });
}

wss.on("connection", (ws) => {
    console.log("[+] Client connected via WebSocket. Online:", wss.clients.size);
    broadcastOnlineCount();

    ws.on("message", (message) => {
        try {
            const data = JSON.parse(message.toString());
            if (data.type === "getOnline" || data.type === "ping") {
                ws.send(JSON.stringify({ type: "onlineCount", count: wss.clients.size }));
                return;
            }
            console.log("[>] Received payload:", data);
            // Broadcast received data to all connected clients (browsers & scripts)
            broadcast(data);
        } catch (e) {
            console.log("[!] Received non-JSON or raw text:", message.toString());
            broadcast({
                username: "Unknown",
                brainrotName: message.toString(),
                generation: "N/A",
                mutation: "Normal"
            });
        }
    });

    ws.on("close", () => {
        console.log("[-] Client disconnected. Online:", wss.clients.size);
        broadcastOnlineCount();
    });
});

server.listen(PORT, () => {
    console.log(`===========================================`);
    console.log(` Brainrot Stream Server Running!`);
    console.log(` Web View: http://localhost:${PORT}`);
    console.log(` WebSocket URL: ws://localhost:${PORT}/ws`);
    console.log(`===========================================`);
});
