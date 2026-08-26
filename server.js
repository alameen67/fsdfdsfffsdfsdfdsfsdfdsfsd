// ============================================================================
// 🛡️ ACE DUELS PROXY BRIDGE (Protects User IPs)
// ============================================================================
const ACE_RELAY_URL = "wss://aceduelsfinder.kellygrant0527.workers.dev/ws";
let aceWs = null;

function connectAceDuelsRelay() {
    try {
        aceWs = new WebSocket(ACE_RELAY_URL);

        aceWs.on("open", () => {
            console.log("[+] [Proxy] Connected to Ace Duels Relay from Render Server!");
        });

        aceWs.on("message", (raw) => {
            try {
                const data = JSON.parse(raw.toString());
                
                // Identify with Ace Duels if welcomed
                if (data.type === "connect_ok") {
                    aceWs.send(JSON.stringify({
                        type: "identify",
                        name: "VampireXHookRelay",
                        username: "VampireXHookRelay",
                        displayName: "Vampire X Hook",
                        userId: 11014601239
                    }));
                } 
                // Forward listings from Ace Duels down to YOUR users
                else if (data.type === "listings" && Array.isArray(data.data)) {
                    data.data.forEach(item => {
                        broadcast({
                            id: item.listingId,
                            username: item.username || "Unknown",
                            brainrotName: item.itemDisplay || item.item || "Unknown",
                            generation: item.valueText || "",
                            mutation: item.mutation || "None",
                            source: "Ace Duels",
                            timestamp: Date.now()
                        });
                    });
                }
            } catch (e) {}
        });

        aceWs.on("close", () => {
            console.log("[-] [Proxy] Ace Duels disconnected. Reconnecting in 5s...");
            setTimeout(connectAceDuelsRelay, 5000);
        });

        aceWs.on("error", () => {});
    } catch (e) {
        setTimeout(connectAceDuelsRelay, 5000);
    }
}

connectAceDuelsRelay();
