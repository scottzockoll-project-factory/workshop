type EventCallback = (data: unknown) => void;

interface WSClient {
  send: (event: string, data?: unknown) => void;
  on: (event: string, callback: EventCallback) => void;
  off: (event: string, callback: EventCallback) => void;
  close: () => void;
}

const WS_URL = process.env.NEXT_PUBLIC_WS_URL;
const WS_API_KEY = process.env.NEXT_PUBLIC_WS_API_KEY;

export function createWSClient(room: string): WSClient {
  if (!WS_URL) throw new Error("NEXT_PUBLIC_WS_URL is not configured");
  if (!WS_API_KEY) throw new Error("NEXT_PUBLIC_WS_API_KEY is not configured");

  const listeners = new Map<string, Set<EventCallback>>();
  let ws: WebSocket | null = null;
  let closed = false;
  let reconnectDelay = 500;
  const MAX_RECONNECT_DELAY = 30_000;
  let reconnectTimer: ReturnType<typeof setTimeout> | null = null;

  function connect() {
    if (closed) return;

    ws = new WebSocket(`${WS_URL}?key=${WS_API_KEY}`);

    ws.onopen = () => {
      reconnectDelay = 500;
      ws!.send(JSON.stringify({ event: "join", room }));
    };

    ws.onmessage = (e) => {
      let msg: { event?: string; data?: unknown };
      try {
        msg = JSON.parse(typeof e.data === "string" ? e.data : "");
      } catch {
        return;
      }
      if (!msg.event) return;

      const callbacks = listeners.get(msg.event);
      if (callbacks) {
        for (const cb of callbacks) cb(msg.data);
      }
    };

    ws.onclose = () => {
      if (closed) return;
      reconnectTimer = setTimeout(() => {
        reconnectDelay = Math.min(reconnectDelay * 2, MAX_RECONNECT_DELAY);
        connect();
      }, reconnectDelay);
    };

    ws.onerror = () => {
      ws?.close();
    };
  }

  connect();

  return {
    send(event: string, data?: unknown) {
      if (ws?.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ room, event, data }));
      }
    },

    on(event: string, callback: EventCallback) {
      if (!listeners.has(event)) listeners.set(event, new Set());
      listeners.get(event)!.add(callback);
    },

    off(event: string, callback: EventCallback) {
      listeners.get(event)?.delete(callback);
    },

    close() {
      closed = true;
      if (reconnectTimer) clearTimeout(reconnectTimer);
      ws?.close();
    },
  };
}
