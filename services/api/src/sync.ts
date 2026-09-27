import { Hono } from "hono";
import { verifyToken } from "./crypto";

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

export const syncRouter = new Hono<{ Bindings: Bindings; Variables: Variables }>();

// Authentication middleware for sync routes
syncRouter.use("/*", async (c, next) => {
  const authHeader = c.req.header("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return c.json({ success: false, error: "Unauthorized: Missing Bearer Token" }, 401);
  }

  const token = authHeader.substring(7);
  const session = await verifyToken(token);
  if (!session) {
    return c.json({ success: false, error: "Unauthorized: Invalid or expired token" }, 401);
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
        entityType: string;
        entityId: string;
        action: string;
        payload: any;
        clientTimestamp: string;
      }>;
    }>();

    const items = body.items || [];
    if (items.length === 0) {
      return c.json({ success: true, processedCount: 0, message: "No items to sync." });
    }

    const db = c.env.DB;
    const now = new Date().toISOString();
    let processed = 0;

    for (const item of items) {
      const payloadStr = typeof item.payload === "string" ? item.payload : JSON.stringify(item.payload);
      
      await db
        .prepare(
          "INSERT OR REPLACE INTO sync_items (id, user_id, entity_type, entity_id, action, payload, client_timestamp, server_timestamp) VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
        )
        .bind(
          item.id,
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

    return c.json({
      success: true,
      processedCount: processed,
      serverTimestamp: now,
    });
  } catch (error: any) {
    return c.json({ success: false, error: error.message || "Failed to push sync items." }, 500);
  }
});

// GET /api/v1/sync/pull - Fetch remote mutations since last sync timestamp
syncRouter.get("/pull", async (c) => {
  try {
    const session = c.get("jwtPayload");
    const since = c.req.query("since") || "1970-01-01T00:00:00.000Z";

    const db = c.env.DB;
    const { results } = await db
      .prepare(
        "SELECT * FROM sync_items WHERE user_id = ? AND server_timestamp > ? ORDER BY server_timestamp ASC LIMIT 100"
      )
      .bind(session.userId, since)
      .all();

    return c.json({
      success: true,
      items: results || [],
      serverTimestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    return c.json({ success: false, error: error.message || "Failed to pull sync items." }, 500);
  }
});
