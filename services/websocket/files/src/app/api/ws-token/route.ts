import { createHmac } from "node:crypto";
import { NextResponse } from "next/server";
import { requireAuth } from "@/lib/auth";

function base64UrlEncode(data: Buffer | string): string {
  const buf = typeof data === "string" ? Buffer.from(data) : data;
  return buf.toString("base64").replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function signJWT(secret: string, expiresInSeconds: number): string {
  const header = base64UrlEncode(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const payload = base64UrlEncode(
    JSON.stringify({
      iat: Math.floor(Date.now() / 1000),
      exp: Math.floor(Date.now() / 1000) + expiresInSeconds,
    })
  );

  const signature = createHmac("sha256", secret)
    .update(`${header}.${payload}`)
    .digest();

  return `${header}.${payload}.${base64UrlEncode(signature)}`;
}

export async function GET() {
  await requireAuth();

  const secret = process.env.WS_API_KEY;
  if (!secret) {
    return NextResponse.json({ error: "WebSocket not configured" }, { status: 500 });
  }

  const token = signJWT(secret, 60);
  return NextResponse.json({ token });
}
