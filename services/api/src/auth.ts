import { Hono } from "hono";
import { hashPin, verifyPin, generateToken, verifyToken } from "./crypto";

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
    version: "1.1.0",
  });
});

// POST /api/v1/auth/activate - Admin registers/authenticates to activate software on device
authRouter.post("/activate", async (c) => {
  try {
    const body = await c.req.json<{
      email?: string;
      mobile?: string;
      password?: string;
      pin?: string;
      kioskName?: string;
      kioskAddress?: string;
      merchantUpiVpa?: string;
      isNewRegistration?: boolean;
      adminName?: string;
    }>();

    const db = c.env.DB;
    const now = new Date().toISOString();

    if (body.isNewRegistration) {
      // 1. New Admin Sign-Up & Kiosk Registration
      const name = body.adminName?.trim() || "Admin";
      const email = body.email?.trim().toLowerCase();
      const mobile = body.mobile?.trim();
      const pin = body.pin?.trim();
      const kioskName = body.kioskName?.trim() || "Main Kiosk Center";

      if (!pin || pin.length !== 4) {
        return c.json({ success: false, error: "4-digit numeric PIN is required." }, 400);
      }

      if (email) {
        const existing = await db.prepare("SELECT id FROM users WHERE email = ?").bind(email).first();
        if (existing) {
          return c.json({ success: false, error: "An account with this email already exists." }, 409);
        }
      }

      const adminId = `usr_${crypto.randomUUID()}`;
      const kioskId = `ksk_${crypto.randomUUID()}`;
      const pinHashed = await hashPin(pin);

      // Create Kiosk record
      await db
        .prepare(
          "INSERT INTO kiosks (id, name, owner_id, address, phone, upi_vpa, license_key, is_active, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, ?)"
        )
        .bind(kioskId, kioskName, adminId, body.kioskAddress || null, mobile || null, body.merchantUpiVpa || null, `LIC-${crypto.randomUUID().substring(0, 8).toUpperCase()}`, now, now)
        .run();

      // Create Admin User
      await db
        .prepare(
          "INSERT INTO users (id, kiosk_id, name, email, mobile, role, pin_hash, is_active, created_at, updated_at) VALUES (?, ?, ?, ?, ?, 'admin', ?, 1, ?, ?)"
        )
        .bind(adminId, kioskId, name, email || null, mobile || null, pinHashed, now, now)
        .run();

      const token = await generateToken({ userId: adminId, role: "admin", email });

      return c.json({
        success: true,
        isActivated: true,
        activationToken: token,
        kiosk: {
          id: kioskId,
          name: kioskName,
          address: body.kioskAddress || "",
          phone: mobile || "",
          merchantUpiVpa: body.merchantUpiVpa || "",
        },
        admin: {
          id: adminId,
          name,
          email: email || "",
          mobile: mobile || "",
          role: "admin",
        },
        operators: [
          {
            id: adminId,
            name,
            email: email || "",
            mobile: mobile || "",
            role: "admin",
            pin: pin,
          }
        ],
        message: "Kiosk software activated successfully.",
      });
    } else {
      // 2. Existing Admin Sign-In & Activation
      const email = body.email?.trim().toLowerCase();
      const mobile = body.mobile?.trim();
      const pin = body.pin?.trim();

      if (!pin) {
        return c.json({ success: false, error: "4-digit PIN is required." }, 400);
      }

      let userRecord: any = null;
      if (email) {
        userRecord = await db.prepare("SELECT * FROM users WHERE email = ? AND is_active = 1").bind(email).first();
      } else if (mobile) {
        userRecord = await db.prepare("SELECT * FROM users WHERE mobile = ? AND is_active = 1").bind(mobile).first();
      }

      if (!userRecord) {
        return c.json({ success: false, error: "Admin account not found." }, 404);
      }

      const isValid = await verifyPin(pin, userRecord.pin_hash);
      if (!isValid) {
        return c.json({ success: false, error: "Invalid PIN." }, 401);
      }

      const kiosk = await db.prepare("SELECT * FROM kiosks WHERE id = ?").bind(userRecord.kiosk_id || "").first();
      const { results: operators } = await db.prepare("SELECT id, name, email, mobile, role FROM users WHERE kiosk_id = ? AND is_active = 1").bind(userRecord.kiosk_id || "").all();

      const token = await generateToken({ userId: userRecord.id, role: userRecord.role, email: userRecord.email || undefined });

      return c.json({
        success: true,
        isActivated: true,
        activationToken: token,
        kiosk: kiosk || {
          id: userRecord.kiosk_id || "default",
          name: "Dossier Kiosk",
        },
        admin: {
          id: userRecord.id,
          name: userRecord.name,
          email: userRecord.email || "",
          mobile: userRecord.mobile || "",
          role: userRecord.role,
        },
        operators: operators || [],
        message: "Software activated on device.",
      });
    }
  } catch (error: any) {
    return c.json({ success: false, error: error.message || "Failed to activate software." }, 500);
  }
});

// GET /api/v1/auth/operators - Fetch all operators for active kiosk
authRouter.get("/operators", async (c) => {
  try {
    const authHeader = c.req.header("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return c.json({ success: false, error: "Unauthorized" }, 401);
    }

    const token = authHeader.substring(7);
    const session = await verifyToken(token);
    if (!session) {
      return c.json({ success: false, error: "Invalid session token." }, 401);
    }

    const db = c.env.DB;
    const user = await db.prepare("SELECT kiosk_id FROM users WHERE id = ?").bind(session.userId).first<any>();
    if (!user || !user.kiosk_id) {
      return c.json({ success: false, error: "No kiosk associated with user." }, 404);
    }

    const { results: operators } = await db
      .prepare("SELECT id, name, email, mobile, role, is_active, created_at FROM users WHERE kiosk_id = ? AND is_active = 1")
      .bind(user.kiosk_id)
      .all();

    return c.json({
      success: true,
      operators: operators || [],
    });
  } catch (error: any) {
    return c.json({ success: false, error: error.message || "Failed to fetch operators." }, 500);
  }
});

// POST /api/v1/auth/operators - Admin provisions a new operator on server
authRouter.post("/operators", async (c) => {
  try {
    const authHeader = c.req.header("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return c.json({ success: false, error: "Unauthorized" }, 401);
    }

    const token = authHeader.substring(7);
    const session = await verifyToken(token);
    if (!session || (session.role !== "admin" && session.role !== "manager")) {
      return c.json({ success: false, error: "Only Admin/Manager can create operators." }, 403);
    }

    const body = await c.req.json<{
      name?: string;
      pin?: string;
      role?: string;
      mobile?: string;
      email?: string;
    }>();

    const name = body.name?.trim();
    const pin = body.pin?.trim();
    const role = body.role?.trim() || "operator";
    const mobile = body.mobile?.trim();
    const email = body.email?.trim().toLowerCase();

    if (!name || name.length < 2) {
      return c.json({ success: false, error: "Operator name must be at least 2 characters." }, 400);
    }
    if (!pin || pin.length !== 4) {
      return c.json({ success: false, error: "4-digit numeric PIN is required." }, 400);
    }

    const db = c.env.DB;
    const adminUser = await db.prepare("SELECT kiosk_id FROM users WHERE id = ?").bind(session.userId).first<any>();
    if (!adminUser || !adminUser.kiosk_id) {
      return c.json({ success: false, error: "Kiosk not found for admin." }, 404);
    }

    const operatorId = `usr_${crypto.randomUUID()}`;
    const pinHashed = await hashPin(pin);
    const now = new Date().toISOString();

    await db
      .prepare(
        "INSERT INTO users (id, kiosk_id, name, email, mobile, role, pin_hash, is_active, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, ?)"
      )
      .bind(operatorId, adminUser.kiosk_id, name, email || null, mobile || null, role, pinHashed, now, now)
      .run();

    return c.json({
      success: true,
      operator: {
        id: operatorId,
        kioskId: adminUser.kiosk_id,
        name,
        role,
        mobile: mobile || "",
        email: email || "",
      },
      message: "Operator created successfully on server.",
    });
  } catch (error: any) {
    return c.json({ success: false, error: error.message || "Failed to create operator." }, 500);
  }
});

// POST /api/v1/auth/operator-login - Quick operator shift login with PIN
authRouter.post("/operator-login", async (c) => {
  try {
    const body = await c.req.json<{
      operatorId?: string;
      pin?: string;
    }>();

    const operatorId = body.operatorId?.trim();
    const pin = body.pin?.trim();

    if (!operatorId || !pin) {
      return c.json({ success: false, error: "Operator ID and PIN are required." }, 400);
    }

    const db = c.env.DB;
    const user = await db.prepare("SELECT * FROM users WHERE id = ? AND is_active = 1").bind(operatorId).first<any>();
    if (!user) {
      return c.json({ success: false, error: "Operator not found." }, 404);
    }

    const isValid = await verifyPin(pin, user.pin_hash);
    if (!isValid) {
      return c.json({ success: false, error: "Incorrect PIN." }, 401);
    }

    const token = await generateToken({ userId: user.id, role: user.role, email: user.email || undefined });

    return c.json({
      success: true,
      token,
      operator: {
        id: user.id,
        name: user.name,
        role: user.role,
        mobile: user.mobile || "",
        email: user.email || "",
      },
    });
  } catch (error: any) {
    return c.json({ success: false, error: error.message || "Operator login failed." }, 500);
  }
});

// POST /api/v1/auth/signup (Direct signup compatibility)
authRouter.post("/signup", async (c) => {
  return c.redirect("/api/v1/auth/activate", 307);
});

// POST /api/v1/auth/signin (Direct signin compatibility)
authRouter.post("/signin", async (c) => {
  return c.redirect("/api/v1/auth/activate", 307);
});

// POST /api/v1/auth/verify-pin
authRouter.post("/verify-pin", async (c) => {
  try {
    const body = await c.req.json<{ userId?: string; pin?: string }>();
    const userId = body.userId?.trim();
    const pin = body.pin?.trim();

    if (!userId || !pin) {
      return c.json({ success: false, error: "User ID and PIN are required." }, 400);
    }

    const db = c.env.DB;
    const userRecord = await db.prepare("SELECT * FROM users WHERE id = ? AND is_active = 1").bind(userId).first<any>();
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
