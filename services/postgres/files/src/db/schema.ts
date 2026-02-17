import {
  pgTable,
  serial,
  text,
  timestamp,
} from "drizzle-orm/pg-core";

// Example table - replace with your own schema
export const posts = pgTable("posts", {
  id: serial("id").primaryKey(),
  title: text("title").notNull(),
  content: text("content"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});
