import { NextRequest, NextResponse } from "next/server";
import { jwtVerify } from "jose";
import { db } from "@/db";
import { sessions } from "@/db/schema-auth";
import { eq } from "drizzle-orm";
import { clearAuthCookie } from "@/lib/auth";

export async function POST(request: NextRequest) {
  const cookieHeader = request.headers.get("cookie") ?? "";
  const match = cookieHeader.match(/(?:^|;\s*)auth_token=([^;]+)/);

  if (match) {
    try {
      const secret = new TextEncoder().encode(process.env.JWT_SECRET);
      const { payload } = await jwtVerify(match[1], secret);
      const sessionId = payload.sessionId as number;

      // Delete session from DB
      await db.delete(sessions).where(eq(sessions.id, sessionId));
    } catch {
      // Token invalid — just clear the cookie
    }
  }

  const response = NextResponse.redirect(new URL("/login", request.url));
  clearAuthCookie(response);
  return response;
}
