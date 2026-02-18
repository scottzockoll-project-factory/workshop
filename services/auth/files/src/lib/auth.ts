import { SignJWT, jwtVerify } from "jose";
import { db } from "@/db";
import { sessions } from "@/db/schema-auth";
import { eq } from "drizzle-orm";
import { cookies } from "next/headers";

const COOKIE_NAME = "auth_token";
const COOKIE_DOMAIN = ".scottzockoll.com";
const SESSION_MAX_AGE = 90 * 24 * 60 * 60; // 90 days in seconds

function getJwtSecret() {
  const secret = process.env.JWT_SECRET;
  if (!secret) throw new Error("JWT_SECRET environment variable is not set");
  return new TextEncoder().encode(secret);
}

async function hashTokenAsync(token: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(token);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}

export function isWhitelisted(email: string): boolean {
  const allowed = process.env.ALLOWED_EMAILS ?? "";
  const emails = allowed
    .split(",")
    .map((e) => e.trim().toLowerCase())
    .filter(Boolean);
  return emails.includes(email.toLowerCase());
}

export async function createSession(
  email: string,
  request: Request
): Promise<{ token: string; sessionId: number }> {
  const token = crypto.randomUUID();
  const tokenHash = await hashTokenAsync(token);
  const userAgent = request.headers.get("user-agent") ?? undefined;
  const ip =
    request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? undefined;

  const [session] = await db
    .insert(sessions)
    .values({ email, tokenHash, userAgent, ip })
    .returning({ id: sessions.id });

  const jwt = await new SignJWT({ email, sessionId: session.id, tokenHash })
    .setProtectedHeader({ alg: "HS256" })
    .setExpirationTime(`${SESSION_MAX_AGE}s`)
    .sign(getJwtSecret());

  return { token: jwt, sessionId: session.id };
}

export async function verifyAuth(
  request: Request
): Promise<{ email: string; sessionId: number } | null> {
  const cookieHeader = request.headers.get("cookie") ?? "";
  const match = cookieHeader.match(
    new RegExp(`(?:^|;\\s*)${COOKIE_NAME}=([^;]+)`)
  );
  if (!match) return null;

  try {
    const { payload } = await jwtVerify(match[1], getJwtSecret());
    const email = payload.email as string;
    const sessionId = payload.sessionId as number;
    const tokenHash = payload.tokenHash as string;

    if (!isWhitelisted(email)) return null;

    // Check session exists in DB (deleted row = revoked)
    const [session] = await db
      .select()
      .from(sessions)
      .where(eq(sessions.id, sessionId));
    if (!session || session.tokenHash !== tokenHash) return null;

    // Update lastSeen for sliding window (fire and forget)
    db.update(sessions)
      .set({ lastSeen: new Date() })
      .where(eq(sessions.id, sessionId))
      .then(() => {});

    return { email, sessionId };
  } catch {
    return null;
  }
}

export async function requireAuth(): Promise<{
  email: string;
  sessionId: number;
}> {
  const cookieStore = await cookies();
  const token = cookieStore.get(COOKIE_NAME)?.value;
  if (!token) {
    throw new Response("Unauthorized", { status: 401 });
  }

  try {
    const { payload } = await jwtVerify(token, getJwtSecret());
    const email = payload.email as string;
    const sessionId = payload.sessionId as number;
    const tokenHash = payload.tokenHash as string;

    if (!isWhitelisted(email)) {
      throw new Response("Forbidden", { status: 403 });
    }

    const [session] = await db
      .select()
      .from(sessions)
      .where(eq(sessions.id, sessionId));
    if (!session || session.tokenHash !== tokenHash) {
      throw new Response("Session revoked", { status: 401 });
    }

    // Update lastSeen
    db.update(sessions)
      .set({ lastSeen: new Date() })
      .where(eq(sessions.id, sessionId))
      .then(() => {});

    return { email, sessionId };
  } catch (e) {
    if (e instanceof Response) throw e;
    throw new Response("Unauthorized", { status: 401 });
  }
}

export function setAuthCookie(response: Response, token: string): Response {
  response.headers.append(
    "Set-Cookie",
    `${COOKIE_NAME}=${token}; HttpOnly; Secure; SameSite=Lax; Domain=${COOKIE_DOMAIN}; Path=/; Max-Age=${SESSION_MAX_AGE}`
  );
  return response;
}

export function clearAuthCookie(response: Response): Response {
  response.headers.append(
    "Set-Cookie",
    `${COOKIE_NAME}=; HttpOnly; Secure; SameSite=Lax; Domain=${COOKIE_DOMAIN}; Path=/; Max-Age=0`
  );
  return response;
}
