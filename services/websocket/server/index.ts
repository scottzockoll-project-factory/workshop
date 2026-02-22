import { createServer, IncomingMessage } from "node:http";
import { timingSafeEqual } from "node:crypto";
import { WebSocketServer, WebSocket } from "ws";

const PORT = parseInt(process.env.PORT || "8080", 10);
const API_KEY = process.env.WS_API_KEY;

if (!API_KEY) {
  console.error("WS_API_KEY environment variable is required");
  process.exit(1);
}

// --- Room management ---

const rooms = new Map<string, Set<WebSocket>>();
const clientRooms = new Map<WebSocket, Set<string>>();

function addToRoom(ws: WebSocket, room: string) {
  if (!rooms.has(room)) rooms.set(room, new Set());
  rooms.get(room)!.add(ws);

  if (!clientRooms.has(ws)) clientRooms.set(ws, new Set());
  clientRooms.get(ws)!.add(room);
}

function removeFromRoom(ws: WebSocket, room: string) {
  rooms.get(room)?.delete(ws);
  if (rooms.get(room)?.size === 0) rooms.delete(room);
  clientRooms.get(ws)?.delete(room);
}

function removeFromAllRooms(ws: WebSocket) {
  const joined = clientRooms.get(ws);
  if (joined) {
    for (const room of joined) {
      rooms.get(room)?.delete(ws);
      if (rooms.get(room)?.size === 0) rooms.delete(room);
    }
  }
  clientRooms.delete(ws);
}

function broadcast(ws: WebSocket, room: string, event: string, data: unknown) {
  const members = rooms.get(room);
  if (!members) return;

  const payload = JSON.stringify({ event, data });
  for (const client of members) {
    if (client !== ws && client.readyState === WebSocket.OPEN) {
      client.send(payload);
    }
  }
}

// --- HTTP + WebSocket server ---

const server = createServer((req, res) => {
  if (req.method === "GET" && req.url === "/") {
    res.writeHead(200, { "Content-Type": "text/plain" });
    res.end("ok");
    return;
  }
  res.writeHead(404);
  res.end();
});

const wss = new WebSocketServer({ noServer: true });

// Ping every 30s; terminate if no pong comes back before the next ping.
const PING_INTERVAL_MS = 30_000;

server.on("upgrade", (req: IncomingMessage, socket, head) => {
  const url = new URL(req.url || "/", `http://${req.headers.host}`);
  const key = url.searchParams.get("key");

  const valid =
    key !== null &&
    key.length === API_KEY!.length &&
    timingSafeEqual(Buffer.from(key), Buffer.from(API_KEY!));

  if (!valid) {
    socket.write("HTTP/1.1 401 Unauthorized\r\n\r\n");
    socket.destroy();
    return;
  }

  wss.handleUpgrade(req, socket, head, (ws) => {
    wss.emit("connection", ws, req);
  });
});

wss.on("connection", (ws: WebSocket) => {
  let isAlive = true;

  ws.on("pong", () => {
    isAlive = true;
  });

  const pingTimer = setInterval(() => {
    if (!isAlive) {
      ws.terminate();
      return;
    }
    isAlive = false;
    ws.ping();
  }, PING_INTERVAL_MS);

  ws.on("message", (raw: Buffer) => {
    let msg: { room?: string; event?: string; data?: unknown };
    try {
      msg = JSON.parse(raw.toString());
    } catch {
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
    clearInterval(pingTimer);
    removeFromAllRooms(ws);
  });
});

server.listen(PORT, () => {
  console.log(`WebSocket server listening on port ${PORT}`);
});
