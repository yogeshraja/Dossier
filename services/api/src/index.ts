/**
 * Dossier Cloudflare Edge Serverless API Root Entrypoint
 * Monorepo: Dossier Cloudflare Edge Serverless API
 */

import { Hono } from "hono";
import { cors } from "hono/cors";
import { authRouter } from "./auth";
import { syncRouter } from "./sync";
import { HTTP_STATUS } from "./constants";

type Bindings = {
  DB: D1Database;
  ENVIRONMENT?: string;
  JWT_SECRET?: string;
};

const CORS_MAX_AGE_SECONDS = 86400;

const app = new Hono<{ Bindings: Bindings }>();

// Global CORS Middleware - allows Flutter Desktop, Mobile, and Web
app.use(
  "/*",
  cors({
    origin: "*",
    allowMethods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allowHeaders: ["Content-Type", "Authorization", "X-Dossier-Client", "X-Dossier-Version"],
    exposeHeaders: ["Content-Length"],
    maxAge: CORS_MAX_AGE_SECONDS,
  })
);

// Base health check
app.get("/", (c) => {
  return c.json(
    {
      name: "Dossier Edge API",
      status: "healthy",
      engine: "Cloudflare Workers + D1 SQLite",
      docs: "/api/v1/auth/health",
    },
    HTTP_STATUS.OK
  );
});

// Mount modular sub-routers
app.route("/api/v1/auth", authRouter);
app.route("/api/v1/sync", syncRouter);

// 404 handler
app.notFound((c) => {
  return c.json({ success: false, error: "Endpoint not found" }, HTTP_STATUS.NOT_FOUND);
});

// Global error handler
app.onError((err, c) => {
  console.error("Worker unhandled error:", err);
  return c.json({ success: false, error: err.message || "Internal Server Error" }, HTTP_STATUS.INTERNAL_SERVER_ERROR);
});

export default app;
