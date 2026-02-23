import https from "node:https";

const TELLER_API = "https://api.teller.io";

function getAgent() {
  const cert = process.env.TELLER_CERT;
  const key = process.env.TELLER_PRIVATE_KEY;
  if (!cert || !key) throw new Error("TELLER_CERT and TELLER_PRIVATE_KEY are required");

  return new https.Agent({
    cert: Buffer.from(cert, "base64").toString("utf8"),
    key: Buffer.from(key, "base64").toString("utf8"),
  });
}

async function tellerFetch<T>(path: string, accessToken: string): Promise<T> {
  const agent = getAgent();
  const credentials = Buffer.from(`${accessToken}:`).toString("base64");

  const res = await fetch(`${TELLER_API}${path}`, {
    headers: { Authorization: `Basic ${credentials}` },
    // @ts-expect-error - Node.js fetch supports agent via dispatcher, using undici
    agent,
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Teller API error ${res.status}: ${text}`);
  }

  return res.json();
}

export type TellerAccount = {
  id: string;
  enrollment_id: string;
  name: string;
  type: string;
  subtype: string;
  institution: { name: string };
  currency: string;
  last_four: string;
};

export type TellerTransaction = {
  id: string;
  account_id: string;
  date: string;
  description: string;
  amount: string;
  status: "posted" | "pending";
  type: string;
  details: {
    category: string | null;
    counterparty: { name: string; type: string } | null;
  };
};

export type TellerBalance = {
  account_id: string;
  available: string | null;
  ledger: string;
};

export async function getAccounts(accessToken: string): Promise<TellerAccount[]> {
  return tellerFetch("/accounts", accessToken);
}

export async function getTransactions(accessToken: string, accountId: string): Promise<TellerTransaction[]> {
  return tellerFetch(`/accounts/${accountId}/transactions`, accessToken);
}

export async function getBalance(accessToken: string, accountId: string): Promise<TellerBalance> {
  return tellerFetch(`/accounts/${accountId}/balances`, accessToken);
}
