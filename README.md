# Brainrot WebSocket Streamer

A lightweight, completely free WebSocket server and Roblox Luau executor script to stream your Brainrot stats to a barebones web page in real-time.

## Features
- **Zero bloat webpage**: No titles, no CSS styling, just the raw text fields.
- **15-Second Auto-Disappear**: Each entry automatically deletes itself 15 seconds after appearing.
- **Interactive & Headless Lua Scripts**:
  - `script.lua`: In-game GUI to click "POST" on any brainrot or "POST ALL".
  - `auto_script.lua`: Instantly sends all brainrots upon execution with no UI.
- **WebSocket + HTTP Fallback**: Works with any executor (Delta, Wave, Solara, Codex, Macsploit, Synapse, etc.).

---

## 1. How to Run the Website (Locally - 100% Free)

1. Open PowerShell or Command Prompt in this folder:
   ```bash
   cd "C:\Users\Creed Ameen\.gemini\antigravity\scratch\brainrot-stream"
   ```
2. Start the server:
   ```bash
   node server.js
   ```
3. Open your browser to:
   ```
   http://localhost:3000
   ```

---

## 2. Free Online Hosting (Optional)
If your Roblox executor is on another device (like mobile) or you want a public link:
- **Render.com / Glitch.com / Railway.app**: Upload `server.js`, `package.json`, and `public/index.html` as a free web service.
- **ngrok / localtunnel**: Run `npx localtunnel --port 3000` on your PC to get an instant free public URL like `https://xyz.loca.lt`. Change `WS_URL` in the Lua script to `wss://xyz.loca.lt/ws`.

---

## 3. How to Execute in Roblox

1. Copy the contents of `script.lua` (or `auto_script.lua`).
2. Paste it into your executor in Roblox.
3. Click Execute.
4. Select which Brainrot to post, or click **POST ALL TO WEB**!
