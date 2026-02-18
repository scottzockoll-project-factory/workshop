import { NextRequest, NextResponse } from "next/server";
import { SignJWT } from "jose";
import { Resend } from "resend";
import { isWhitelisted } from "@/lib/auth";

const resend = new Resend(process.env.RESEND_API_KEY);

export async function POST(request: NextRequest) {
  const { email } = await request.json();

  if (!email || typeof email !== "string") {
    return NextResponse.json({ error: "Email required" }, { status: 400 });
  }

  const normalizedEmail = email.trim().toLowerCase();

  // Always respond the same way to prevent enumeration
  const successResponse = NextResponse.json({ ok: true });

  if (!isWhitelisted(normalizedEmail)) {
    return successResponse;
  }

  // Generate magic link token (15 min expiry)
  const secret = new TextEncoder().encode(process.env.JWT_SECRET);
  const magicToken = await new SignJWT({ email: normalizedEmail, purpose: "magic-link" })
    .setProtectedHeader({ alg: "HS256" })
    .setExpirationTime("15m")
    .sign(secret);

  const baseUrl = request.nextUrl.origin;
  const magicLink = `${baseUrl}/api/auth/verify?token=${magicToken}`;

  await resend.emails.send({
    from: "noreply@auth.scottzockoll.com",
    to: normalizedEmail,
    subject: "Your sign-in link",
    html: `
      <p>Click the link below to sign in:</p>
      <p><a href="${magicLink}">Sign in</a></p>
      <p>This link expires in 15 minutes.</p>
    `,
  });

  return successResponse;
}
