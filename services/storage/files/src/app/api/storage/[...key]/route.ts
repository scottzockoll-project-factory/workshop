import { NextRequest, NextResponse } from "next/server";
import { generatePresignedGetUrl } from "@/lib/storage";
import { jwtVerify } from "jose";

export async function GET(
  req: NextRequest,
  { params }: { params: Promise<{ key: string[] }> }
) {
  // Optional auth gate
  if (process.env.STORAGE_REQUIRE_AUTH === "true") {
    const cookie = req.cookies.get("session")?.value;
    if (!cookie) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }
    try {
      const secret = new TextEncoder().encode(process.env.JWT_SECRET!);
      await jwtVerify(cookie, secret);
    } catch {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }
  }

  const { key: keyParts } = await params;
  const key = keyParts.join("/");

  const url = await generatePresignedGetUrl(key, 3600);
  return NextResponse.redirect(url, { status: 302 });
}
