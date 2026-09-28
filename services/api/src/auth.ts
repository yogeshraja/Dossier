import { Hono } from "hono";
import { hashPin, verifyPin, generateToken } from "./crypto";

type Bindings = {
  DB: D1Database;
  JWT_SECRET?: string;
};

export const authRouter = new Hono<{ Bindings: Bindings }>();

// GET /api/v1/auth/health
authRouter.get("/health", async (c) => {
  return c.json({
    status: "online",
    server: "Dossier Cloudflare Edge",
    timestamp: new Date().toISOString(),
    version: "1.0.0",
  });
});

// POST /api/v1/auth/signup
authRouter.post("/signup", async (c) => {
  try {
    const body = await c.req.json<{
      name?: string;
      email?: string;
      mobile?: string;
      pin?: string;
      role?: string;
    }>();

    const name = body.name?.trim();
    const email = body.email?.trim().toLowerCase();
    const mobile = body.mobile?.trim();
    const pin = body.pin?.trim();
    const role = body.role?.trim() || "operator";

    if (!name || name.length < 2) {
      return c.json({ success: false, error: "Operator name must be at least 2 characters." }, 400);
    }
    if (!pin || pin.length !== 4 || !/^\d{4}$/.test(pin)) {
      return c.json({ success: false, error: "A 4-digit numeric PIN is required." }, 400);
    }

    const db = c.env.DB;

    // Check if email already registered
    if (email) {
      const existing = await db
        .prepare("SELECT id FROM users WHERE email = ?")
        .bind(email)
        .first();

      if (existing) {
        return c.json({ success: false, error: "An account with this email already exists." }, 409);
      }
    }

    const userId = `usr_${crypto.randomUUID()}`;
    const now = new Date().toISOString();
    const pinHashed = await hashPin(pin);

    // Insert new operator in D1
    await db
      .prepare(
        "INSERT INTO users (id, name, email, mobile, role, pin_hash, is_active, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?)"
      )
      .bind(userId, name, email || null, mobile || null, role, pinHashed, now, now)
      .run();

    const token = await generateToken({ userId, role, email });
    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();

    // Record session
    const sessionId = `ses_${crypto.randomUUID()}`;
    await db
      .prepare("INSERT INTO sessions (id, user_id, token, expires_at, created_at) VALUES (?, ?, ?, ?, ?)")
      .bind(sessionId, userId, token, expiresAt, now)
      .run();

    return c.json({
      success: true,
      token,
      user: {
        id: userId,
        name,
        email: email || "",
        mobile: mobile || "",
        role,
      },
      message: "Operator account created successfully.",
    });
  } catch (error: any) {
    return c.json({ success: false, error: error.message || "Failed to create account." }, 500);
  }
});

// POST /api/v1/auth/signin
authRouter.post("/signin", async (c) => {
  try {
    const body = await c.req.json<{
      email?: string;
      mobile?: string;
      pin?: string;
    }>();

    const email = body.email?.trim().toLowerCase();
    const mobile = body.mobile?.trim();
    const pin = body.pin?.trim();

    if (!pin) {
      return c.json({ success: false, error: "4-digit PIN is required." }, 400);
    }
    if (!email && !mobile) {
      return c.json({ success: false, error: "Email or mobile number is required to sign in." }, 400);
    }

    const db = c.env.DB;
    let userRecord: any = null;

    if (email) {
      userRecord = await db
        .prepare("SELECT * FROM users WHERE email = ? AND is_active = 1")
        .bind(email)
        .first();
    } else if (mobile) {
      userRecord = await db
        .prepare("SELECT * FROM users WHERE mobile = ? AND is_active = 1")
        .bind(mobile)
        .first();
    }

    if (!userRecord) {
      return c.json({ success: false, error: "Account not found or inactive." }, 404);
    }

    const isValid = await verifyPin(pin, userRecord.pin_hash);
    if (!isValid) {
      return c.json({ success: false, error: "Invalid PIN." }, 401);
    }

    const token = await generateToken({
      userId: userRecord.id,
      role: userRecord.role,
      email: userRecord.email || undefined,
    });

    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();
    const sessionId = `ses_${crypto.randomUUID()}`;
    const now = new Date().toISOString();

    await db
      .prepare("INSERT INTO sessions (id, user_id, token, expires_at, created_at) VALUES (?, ?, ?, ?, ?)")
      .bind(sessionId, userRecord.id, token, expiresAt, now)
      .run();

    return c.json({
      success: true,
      token,
      user: {
        id: userRecord.id,
        name: userRecord.name,
        email: userRecord.email || "",
        mobile: userRecord.mobile || "",
        role: userRecord.role,
      },
    });
  } catch (error: any) {
    return c.json({ success: false, error: error.message || "Sign-in failed." }, 500);
  }
});

// POST /api/v1/auth/verify-pin
authRouter.post("/verify-pin", async (c) => {
  try {
    const body = await c.req.json<{
      userId?: string;
      pin?: string;
    }>();

    const userId = body.userId?.trim();
    const pin = body.pin?.trim();

    if (!userId || !pin) {
      return c.json({ success: false, error: "User ID and PIN are required." }, 400);
    }

    const db = c.env.DB;
    const userRecord: any = await db
      .prepare("SELECT * FROM users WHERE id = ? AND is_active = 1")
      .bind(userId)
      .first();

    if (!userRecord) {
      return c.json({ success: false, error: "User not found." }, 404);
    }

    const isValid = await verifyPin(pin, userRecord.pin_hash);
    if (!isValid) {
      return c.json({ success: false, error: "Invalid PIN." }, 401);
    }

    return c.json({
      success: true,
      user: {
        id: userRecord.id,
        name: userRecord.name,
        role: userRecord.role,
        email: userRecord.email || "",
      },
    });
  } catch (error: any) {
    return c.json({ success: false, error: error.message || "PIN verification failed." }, 500);
  }
});
