import { NextRequest, NextResponse } from "next/server";
import { verifyAuth } from "@/lib/auth";

const PUBLIC_PATHS = ["/login", "/api/auth/"];

export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  // Skip auth for public paths and static assets
  if (
    PUBLIC_PATHS.some((p) => pathname.startsWith(p)) ||
    pathname.startsWith("/_next/") ||
    pathname.startsWith("/favicon") ||
    pathname.includes(".")
  ) {
    return NextResponse.next();
  }

  const user = await verifyAuth(request);

  if (!user) {
    const loginUrl = new URL("/login", request.url);
    return NextResponse.redirect(loginUrl);
  }

  return NextResponse.next();
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico).*)"],
};
