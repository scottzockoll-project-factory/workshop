---
auto_invoke:
  description: "Adding WebSocket / real-time communication to a project"
---

# Set Up WebSocket Client

Add real-time WebSocket communication to the current project using the shared WebSocket server on Fly.io.

## Steps

1. Copy all files from `/Users/scottzockoll/projects/workshop/services/websocket/files/` into the project root, preserving directory structure:
   - `src/lib/ws.ts` — WebSocket client helper with auto-reconnect
   - `src/app/api/ws-token/route.ts` — API route that mints short-lived JWTs (requires user auth)

2. Add WebSocket env vars to `.env.local` (create the file if it doesn't exist):
   ```
   NEXT_PUBLIC_WS_URL=wss://scottzockoll-ws.fly.dev
   WS_API_KEY=<get from workshop secrets.env>
   ```
   Note: `NEXT_PUBLIC_WS_URL` is public (just the server address). `WS_API_KEY` is server-side only — never expose it to the client.

3. Update or create `services.json` in the project root. If it exists, add `"websocket"` to the array. If not, create it with `["websocket"]`.

4. Tell the user:
   - Connect to a room: `const client = createWSClient('my-room')`
   - Send events: `client.send('event-name', { data })`
   - Listen for events: `client.on('event-name', (data) => { ... })`
   - Clean up: `client.close()`
   - Room names can be namespaced with colons: `chess:lobby`, `chess:game-123`
   - The client auto-reconnects with exponential backoff
   - Auth is automatic — the client fetches a 60-second JWT from `/api/ws-token` before connecting
