"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const node_http_1 = require("node:http");
const node_crypto_1 = require("node:crypto");
const ws_1 = require("ws");
const PORT = parseInt(process.env.PORT || "8080", 10);
const API_KEY = process.env.WS_API_KEY;
if (!API_KEY) {
    console.error("WS_API_KEY environment variable is required");
    process.exit(1);
}
// --- JWT verification (HS256 only, no external deps) ---
function base64UrlDecode(str) {
    const padded = str.replace(/-/g, "+").replace(/_/g, "/");
    return Buffer.from(padded, "base64");
}
function verifyJWT(token, secret) {
    const parts = token.split(".");
    if (parts.length !== 3)
        return { valid: false };
    const [header, payload, signature] = parts;
    try {
        const headerObj = JSON.parse(base64UrlDecode(header).toString());
        if (headerObj.alg !== "HS256")
            return { valid: false };
    }
    catch {
        return { valid: false };
    }
    const expected = (0, node_crypto_1.createHmac)("sha256", secret)
        .update(`${header}.${payload}`)
        .digest();
    const actual = base64UrlDecode(signature);
    if (actual.length !== expected.length || !(0, node_crypto_1.timingSafeEqual)(actual, expected)) {
        return { valid: false };
    }
    try {
        const payloadObj = JSON.parse(base64UrlDecode(payload).toString());
        if (payloadObj.exp && typeof payloadObj.exp === "number") {
            if (Math.floor(Date.now() / 1000) > payloadObj.exp) {
                return { valid: false };
            }
        }
        return { valid: true, payload: payloadObj };
    }
    catch {
        return { valid: false };
    }
}
// --- Room management ---
const rooms = new Map();
const clientRooms = new Map();
function addToRoom(ws, room) {
    if (!rooms.has(room))
        rooms.set(room, new Set());
    rooms.get(room).add(ws);
    if (!clientRooms.has(ws))
        clientRooms.set(ws, new Set());
    clientRooms.get(ws).add(room);
}
function removeFromRoom(ws, room) {
    rooms.get(room)?.delete(ws);
    if (rooms.get(room)?.size === 0)
        rooms.delete(room);
    clientRooms.get(ws)?.delete(room);
}
function removeFromAllRooms(ws) {
    const joined = clientRooms.get(ws);
    if (joined) {
        for (const room of joined) {
            rooms.get(room)?.delete(ws);
            if (rooms.get(room)?.size === 0)
                rooms.delete(room);
        }
    }
    clientRooms.delete(ws);
}
function broadcast(ws, room, event, data) {
    const members = rooms.get(room);
    if (!members)
        return;
    const payload = JSON.stringify({ event, data });
    for (const client of members) {
        if (client !== ws && client.readyState === ws_1.WebSocket.OPEN) {
            client.send(payload);
        }
    }
}
// --- HTTP + WebSocket server ---
const server = (0, node_http_1.createServer)((req, res) => {
    if (req.method === "GET" && req.url === "/") {
        res.writeHead(200, { "Content-Type": "text/plain" });
        res.end("ok");
        return;
    }
    res.writeHead(404);
    res.end();
});
const wss = new ws_1.WebSocketServer({ noServer: true });
server.on("upgrade", (req, socket, head) => {
    const url = new URL(req.url || "/", `http://${req.headers.host}`);
    const token = url.searchParams.get("token");
    if (!token || !verifyJWT(token, API_KEY).valid) {
        socket.write("HTTP/1.1 401 Unauthorized\r\n\r\n");
        socket.destroy();
        return;
    }
    wss.handleUpgrade(req, socket, head, (ws) => {
        wss.emit("connection", ws, req);
    });
});
wss.on("connection", (ws) => {
    ws.on("message", (raw) => {
        let msg;
        try {
            msg = JSON.parse(raw.toString());
        }
        catch {
            ws.send(JSON.stringify({ event: "error", data: "Invalid JSON" }));
            return;
        }
        const { room, event, data } = msg;
        if (!event) {
            ws.send(JSON.stringify({ event: "error", data: "Missing event field" }));
            return;
        }
        if (event === "join") {
            if (!room) {
                ws.send(JSON.stringify({ event: "error", data: "Missing room field" }));
                return;
            }
            addToRoom(ws, room);
            ws.send(JSON.stringify({ event: "joined", data: { room } }));
            return;
        }
        if (event === "leave") {
            if (!room) {
                ws.send(JSON.stringify({ event: "error", data: "Missing room field" }));
                return;
            }
            removeFromRoom(ws, room);
            ws.send(JSON.stringify({ event: "left", data: { room } }));
            return;
        }
        if (!room) {
            ws.send(JSON.stringify({ event: "error", data: "Missing room field" }));
            return;
        }
        broadcast(ws, room, event, data);
    });
    ws.on("close", () => {
        removeFromAllRooms(ws);
    });
});
server.listen(PORT, () => {
    console.log(`WebSocket server listening on port ${PORT}`);
});
