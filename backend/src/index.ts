import { Hono } from "hono";
import { cors } from "hono/cors";
import { authRouter } from "./auth";
import { syncRouter } from "./sync";

type Bindings = {
  DB: D1Database;
  ENVIRONMENT?: string;
  JWT_SECRET?: string;
};

const app = new Hono<{ Bindings: Bindings }>();

// Global CORS Middleware - allows Flutter Desktop, Mobile, and Web
app.use(
  "/*",
  cors({
    origin: "*",
    allowMethods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allowHeaders: ["Content-Type", "Authorization", "X-Dossier-Client", "X-Dossier-Version"],
    exposeHeaders: ["Content-Length"],
    maxAge: 86400,
  })
);

// Base health check
app.get("/", (c) => {
  return c.json({
    name: "Dossier Edge API",
    status: "healthy",
    engine: "Cloudflare Workers + D1 SQLite",
    docs: "/api/v1/auth/health",
  });
});

// Mount modular sub-routers
app.route("/api/v1/auth", authRouter);
app.route("/api/v1/sync", syncRouter);

// 404 handler
app.notFound((c) => {
  return c.json({ success: false, error: "Endpoint not found" }, 404);
});

// Global error handler
app.onError((err, c) => {
  console.error("Worker unhandled error:", err);
  return c.json({ success: false, error: err.message || "Internal Server Error" }, 500);
});

export default app;
