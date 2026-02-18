import { NextRequest, NextResponse } from "next/server";
import { jwtVerify } from "jose";
import { Resend } from "resend";
import { createSession, setAuthCookie, isWhitelisted } from "@/lib/auth";

const resend = new Resend(process.env.RESEND_API_KEY);

export async function GET(request: NextRequest) {
  const token = request.nextUrl.searchParams.get("token");

  if (!token) {
    return NextResponse.redirect(new URL("/login", request.url));
  }

  try {
    const secret = new TextEncoder().encode(process.env.JWT_SECRET);
    const { payload } = await jwtVerify(token, secret);

    if (payload.purpose !== "magic-link") {
      return NextResponse.redirect(new URL("/login", request.url));
    }

    const email = payload.email as string;

    if (!isWhitelisted(email)) {
      return NextResponse.redirect(new URL("/login", request.url));
    }

    // Create session
    const { token: authToken } = await createSession(email, request);

    // Send notification to admin
    const adminEmail = process.env.ADMIN_EMAIL;
    if (adminEmail) {
      const userAgent = request.headers.get("user-agent") ?? "Unknown";
      const ip =
        request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ??
        "Unknown";

      await resend.emails.send({
        from: "noreply@auth.scottzockoll.com",
        to: adminEmail,
        subject: `New login: ${email}`,
        html: `
          <p><strong>New login</strong></p>
          <ul>
            <li><strong>Email:</strong> ${email}</li>
            <li><strong>Device:</strong> ${userAgent}</li>
            <li><strong>IP:</strong> ${ip}</li>
            <li><strong>Time:</strong> ${new Date().toISOString()}</li>
          </ul>
        `,
      });
    }

    // Set cookie and redirect to home
    const response = NextResponse.redirect(new URL("/", request.url));
    setAuthCookie(response, authToken);
    return response;
  } catch {
    return NextResponse.redirect(new URL("/login", request.url));
  }
}
