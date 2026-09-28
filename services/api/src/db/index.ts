/**
 * Drizzle D1 Database Client Instance Helper
 * Monorepo: Dossier Cloudflare Edge Serverless API
 */

import { drizzle } from "drizzle-orm/d1";
import * as schema from "./schema";

export function getDb(d1: D1Database) {
  return drizzle(d1, { schema });
}

export * from "./schema";
