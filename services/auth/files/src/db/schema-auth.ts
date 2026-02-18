import {
  pgTable,
  serial,
  text,
  timestamp,
} from "drizzle-orm/pg-core";

export const sessions = pgTable("sessions", {
  id: serial("id").primaryKey(),
  email: text("email").notNull(),
  tokenHash: text("token_hash").notNull(),
  userAgent: text("user_agent"),
  ip: text("ip"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  lastSeen: timestamp("last_seen").defaultNow().notNull(),
});
