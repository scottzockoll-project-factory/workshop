import { NextRequest, NextResponse } from "next/server";
import { requireAuth } from "@/lib/auth";
import { getAccounts } from "@/lib/teller";
import { db } from "@/db";
import { tellerEnrollments } from "@/db/schema";

export async function POST(request: NextRequest) {
  await requireAuth();

  const { accessToken, enrollmentId, institutionName } = await request.json();

  if (!accessToken || !enrollmentId) {
    return NextResponse.json({ error: "accessToken and enrollmentId are required" }, { status: 400 });
  }

  // Verify token works before saving
  await getAccounts(accessToken);

  await db
    .insert(tellerEnrollments)
    .values({ enrollmentId, accessToken, institutionName: institutionName ?? null })
    .onConflictDoUpdate({
      target: tellerEnrollments.enrollmentId,
      set: { accessToken, updatedAt: new Date() },
    });

  return NextResponse.json({ success: true });
}
