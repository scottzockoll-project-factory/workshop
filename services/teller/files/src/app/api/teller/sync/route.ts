import { NextRequest, NextResponse } from "next/server";
import { requireAuth } from "@/lib/auth";
import { getAccounts, getTransactions, getBalance } from "@/lib/teller";
import { db } from "@/db";
import { tellerEnrollments, transactions, accounts } from "@/db/schema";
import { eq } from "drizzle-orm";

export async function POST(request: NextRequest) {
  await requireAuth();

  const enrollments = await db.select().from(tellerEnrollments);

  for (const enrollment of enrollments) {
    const tellerAccounts = await getAccounts(enrollment.accessToken);

    for (const account of tellerAccounts) {
      // Sync balance
      try {
        const balance = await getBalance(enrollment.accessToken, account.id);
        await db
          .insert(accounts)
          .values({
            tellerAccountId: account.id,
            enrollmentId: enrollment.enrollmentId,
            name: account.name,
            type: account.type,
            subtype: account.subtype,
            institutionName: account.institution.name,
            lastFour: account.last_four,
            currentBalance: balance.ledger,
            availableBalance: balance.available ?? null,
            isoCurrencyCode: account.currency,
          })
          .onConflictDoUpdate({
            target: accounts.tellerAccountId,
            set: {
              currentBalance: balance.ledger,
              availableBalance: balance.available ?? null,
              updatedAt: new Date(),
            },
          });
      } catch {
        // Balance unavailable for some account types — continue
      }

      // Sync transactions
      const txns = await getTransactions(enrollment.accessToken, account.id);

      for (const txn of txns) {
        // Teller: negative amount = credit (money in), positive = debit (money out)
        await db
          .insert(transactions)
          .values({
            tellerTransactionId: txn.id,
            enrollmentId: enrollment.enrollmentId,
            accountId: txn.account_id,
            amount: txn.amount,
            date: txn.date,
            description: txn.description,
            merchantName: txn.details.counterparty?.name ?? null,
            category: txn.details.category ?? null,
            pending: txn.status === "pending",
          })
          .onConflictDoUpdate({
            target: transactions.tellerTransactionId,
            set: {
              amount: txn.amount,
              description: txn.description,
              merchantName: txn.details.counterparty?.name ?? null,
              category: txn.details.category ?? null,
              pending: txn.status === "pending",
              updatedAt: new Date(),
            },
          });
      }
    }

    await db
      .update(tellerEnrollments)
      .set({ lastSyncedAt: new Date() })
      .where(eq(tellerEnrollments.enrollmentId, enrollment.enrollmentId));
  }

  return NextResponse.json({ success: true });
}
