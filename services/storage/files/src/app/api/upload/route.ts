import { NextRequest, NextResponse } from "next/server";
import { generatePresignedPutUrl } from "@/lib/storage";

export async function POST(req: NextRequest) {
  const { filename, contentType } = await req.json();

  if (!filename || !contentType) {
    return NextResponse.json(
      { error: "filename and contentType are required" },
      { status: 400 }
    );
  }

  const sanitized = filename.replace(/[^a-zA-Z0-9._-]/g, "_");
  const key = `uploads/${Date.now()}-${sanitized}`;

  const uploadUrl = await generatePresignedPutUrl(key, contentType);

  return NextResponse.json({ uploadUrl, key });
}
