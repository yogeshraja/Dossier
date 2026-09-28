/**
 * Sync Router for Offline-First Outbox Synchronization
 * Monorepo: Dossier Cloudflare Edge Serverless API
 * Dual-ID Pattern:
 * - Internal `id` (INTEGER AUTOINCREMENT)
 * - Public `public_id` and `user_public_id` (TEXT)
 */

import { Hono } from "hono";
import { verifyToken } from "./crypto";
import { HTTP_STATUS, SYNC_CONSTANTS } from "./constants";

type Bindings = {
  DB: D1Database;
};

type Variables = {
  jwtPayload: {
    userId: string;
    role: string;
    email?: string;
  };
};

const EPOCH_START_ISO = "1970-01-01T00:00:00.000Z";

export const syncRouter = new Hono<{ Bindings: Bindings; Variables: Variables }>();

// Authentication middleware for sync routes
syncRouter.use("/*", async (c, next) => {
  const authHeader = c.req.header("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return c.json({ success: false, error: "Unauthorized: Missing Bearer Token" }, HTTP_STATUS.UNAUTHORIZED);
  }

  const token = authHeader.substring(7);
  const session = await verifyToken(token);
  if (!session) {
    return c.json({ success: false, error: "Unauthorized: Invalid or expired token" }, HTTP_STATUS.UNAUTHORIZED);
  }

  c.set("jwtPayload", session);
  await next();
});

// POST /api/v1/sync/push - Batch upload offline outbox queue items
syncRouter.post("/push", async (c) => {
  try {
    const session = c.get("jwtPayload");
    const body = await c.req.json<{
      items?: Array<{
        id: string;
        publicId?: string;
        entityType: string;
        entityId: string;
        action: string;
        payload: unknown;
        clientTimestamp: string;
      }>;
    }>();

    const items = body.items || [];
    if (items.length === 0) {
      return c.json({ success: true, processedCount: 0, message: "No items to sync." }, HTTP_STATUS.OK);
    }

    const db = c.env.DB;
    const now = new Date().toISOString();
    let processed = 0;

    for (const item of items) {
      const payloadStr = typeof item.payload === "string" ? item.payload : JSON.stringify(item.payload);
      const syncPublicId = item.publicId || item.id || `sync_${crypto.randomUUID()}`;

      await db
        .prepare(
          "INSERT OR REPLACE INTO sync_items (public_id, user_public_id, entity_type, entity_id, action, payload, client_timestamp, server_timestamp) VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
        )
        .bind(
          syncPublicId,
          session.userId,
          item.entityType,
          item.entityId,
          item.action,
          payloadStr,
          item.clientTimestamp,
          now
        )
        .run();

      processed++;
    }

    return c.json(
      {
        success: true,
        processedCount: processed,
        serverTimestamp: now,
      },
      HTTP_STATUS.OK
    );
  } catch (error: unknown) {
    const errorMsg = error instanceof Error ? error.message : "Failed to push sync items.";
    return c.json({ success: false, error: errorMsg }, HTTP_STATUS.INTERNAL_SERVER_ERROR);
  }
});

// GET /api/v1/sync/pull - Fetch remote mutations since last sync timestamp
syncRouter.get("/pull", async (c) => {
  try {
    const session = c.get("jwtPayload");
    const since = c.req.query("since") || EPOCH_START_ISO;
    const limitQuery = c.req.query("limit");
    const limit = limitQuery ? Math.min(parseInt(limitQuery, 10), SYNC_CONSTANTS.MAX_SYNC_BATCH_SIZE) : SYNC_CONSTANTS.DEFAULT_PAGE_SIZE;

    const db = c.env.DB;
    const { results } = await db
      .prepare(
        "SELECT id, public_id, user_public_id, entity_type, entity_id, action, payload, client_timestamp, server_timestamp FROM sync_items WHERE user_public_id = ? AND server_timestamp > ? ORDER BY id ASC LIMIT ?"
      )
      .bind(session.userId, since, limit)
      .all();

    const formattedResults = (results || []).map((r: any) => ({
      id: r.public_id || String(r.id),
      publicId: r.public_id,
      dbId: r.id,
      entityType: r.entity_type,
      entityId: r.entity_id,
      action: r.action,
      payload: r.payload,
      clientTimestamp: r.client_timestamp,
      serverTimestamp: r.server_timestamp,
    }));

    return c.json(
      {
        success: true,
        items: formattedResults,
        count: formattedResults.length,
        syncTimestamp: new Date().toISOString(),
      },
      HTTP_STATUS.OK
    );
  } catch (error: unknown) {
    const errorMsg = error instanceof Error ? error.message : "Failed to pull sync items.";
    return c.json({ success: false, error: errorMsg }, HTTP_STATUS.INTERNAL_SERVER_ERROR);
  }
});
