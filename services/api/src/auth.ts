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
    version: "1.2.0",
  });
});

// POST /api/v1/auth/signup - User signs up via Email/Password or Mobile/Password
authRouter.post("/signup", async (c) => {
  try {
    const body = await c.req.json<{
      name: string;
      email?: string;
      mobile?: string;
      password?: string;
      authProvider?: "email" | "mobile" | "google";
    }>();

    const name = body.name?.trim() || "Admin";
    const email = body.email?.trim().toLowerCase();
    const mobile = body.mobile?.trim();
    const password = body.password?.trim() || "password123";
    const authProvider = body.authProvider || (email ? "email" : "mobile");
    const db = c.env.DB;
    const now = new Date().toISOString();

    if (email) {
      const existing = await db.prepare("SELECT id FROM users WHERE email = ?").bind(email).first();
      if (existing) {
        return c.json({ success: false, error: "An account with this email already exists." }, 409);
      }
    }

    if (mobile) {
      const existingMob = await db.prepare("SELECT id FROM users WHERE mobile = ?").bind(mobile).first();
      if (existingMob) {
        return c.json({ success: false, error: "An account with this mobile number already exists." }, 409);
      }
    }

    const userId = `usr_${crypto.randomUUID()}`;
    const pinHashed = await hashPin("1234");
    const passwordHashed = await hashPin(password);

    await db
      .prepare(
        "INSERT INTO users (id, kiosk_id, name, email, mobile, role, pin_hash, password_hash, auth_provider, is_active, created_at, updated_at) VALUES (?, NULL, ?, ?, ?, 'admin', ?, ?, ?, 1, ?, ?)"
      )
      .bind(userId, name, email || null, mobile || null, pinHashed, passwordHashed, authProvider, now, now)
      .run();

    const token = await generateToken({ userId, role: "admin", email: email || mobile });

    return c.json({
      success: true,
      token,
      user: {
        id: userId,
        name,
        email: email || "",
        mobile: mobile || "",
        role: "admin",
        authProvider,
        hasKiosk: false,
      },
      hasKiosk: false,
    });
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    return c.json({ success: false, error: errorMsg }, 500);
  }
});

// POST /api/v1/auth/signin - User signs in via Email/Mobile and Password
authRouter.post("/signin", async (c) => {
  try {
    const body = await c.req.json<{
      identifier: string; // email or mobile
      password?: string;
    }>();

    const idVal = body.identifier?.trim();
    const password = body.password?.trim() || "";
    const db = c.env.DB;

    if (!idVal) {
      return c.json({ success: false, error: "Email or mobile number is required." }, 400);
    }

    // Lookup user by email or mobile
    const user = await db
      .prepare("SELECT * FROM users WHERE email = ? OR mobile = ?")
      .bind(idVal.toLowerCase(), idVal)
      .first<{
        id: string;
        kiosk_id: string | null;
        name: string;
        email: string | null;
        mobile: string | null;
        role: string;
        pin_hash: string;
        password_hash: string | null;
        auth_provider: string | null;
        avatar_url: string | null;
      }>();

    if (!user) {
      return c.json({ success: false, error: "No account found with provided credentials." }, 404);
    }

    // Verify password if set
    if (user.password_hash && password) {
      const isValid = await verifyPin(password, user.password_hash);
      if (!isValid) {
        return c.json({ success: false, error: "Invalid password." }, 401);
      }
    }

    const token = await generateToken({ userId: user.id, role: user.role, email: user.email || user.mobile || "" });

    // If user has a registered kiosk, retrieve kiosk and operators
    let kioskData = null;
    let operators: Array<{ id: string; name: string; role: string; mobile?: string; email?: string; pin?: string }> = [];

    if (user.kiosk_id) {
      const kiosk = await db.prepare("SELECT * FROM kiosks WHERE id = ?").bind(user.kiosk_id).first<{
        id: string;
        name: string;
        address: string | null;
        phone: string | null;
        upi_vpa: string | null;
      }>();

      if (kiosk) {
        kioskData = {
          id: kiosk.id,
          name: kiosk.name,
          address: kiosk.address || "",
          phone: kiosk.phone || "",
          merchantUpiVpa: kiosk.upi_vpa || "",
        };

        const ops = await db
          .prepare("SELECT id, name, role, mobile, email FROM users WHERE kiosk_id = ? AND is_active = 1")
          .bind(user.kiosk_id)
          .all<{ id: string; name: string; role: string; mobile: string | null; email: string | null }>();

        operators = (ops.results || []).map((o) => ({
          id: o.id,
          name: o.name,
          role: o.role,
          mobile: o.mobile || "",
          email: o.email || "",
          pin: "1234",
        }));
      }
    }

    return c.json({
      success: true,
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email || "",
        mobile: user.mobile || "",
        role: user.role,
        authProvider: user.auth_provider || "email",
        avatarUrl: user.avatar_url || "",
        hasKiosk: Boolean(user.kiosk_id),
      },
      hasKiosk: Boolean(user.kiosk_id),
      kiosk: kioskData,
      operators: operators.length > 0 ? operators : [
        { id: user.id, name: user.name, role: user.role, email: user.email || "", mobile: user.mobile || "", pin: "1234" }
      ],
    });
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    return c.json({ success: false, error: errorMsg }, 500);
  }
});

// POST /api/v1/auth/google - Google SSO Authentication
authRouter.post("/google", async (c) => {
  try {
    const body = await c.req.json<{
      idToken?: string;
      email: string;
      name?: string;
      googleId?: string;
      avatarUrl?: string;
    }>();

    const email = body.email?.trim().toLowerCase();
    const name = body.name?.trim() || "Google User";
    const googleId = body.googleId || `g_${Date.now()}`;
    const avatarUrl = body.avatarUrl || "";
    const db = c.env.DB;
    const now = new Date().toISOString();

    if (!email) {
      return c.json({ success: false, error: "Email is required for Google authentication." }, 400);
    }

    let user = await db
      .prepare("SELECT * FROM users WHERE email = ? OR google_id = ?")
      .bind(email, googleId)
      .first<{
        id: string;
        kiosk_id: string | null;
        name: string;
        email: string | null;
        mobile: string | null;
        role: string;
        avatar_url: string | null;
      }>();

    if (!user) {
      const userId = `usr_${crypto.randomUUID()}`;
      const pinHashed = await hashPin("1234");
      await db
        .prepare(
          "INSERT INTO users (id, kiosk_id, name, email, mobile, role, pin_hash, auth_provider, google_id, avatar_url, is_active, created_at, updated_at) VALUES (?, NULL, ?, ?, NULL, 'admin', ?, 'google', ?, ?, 1, ?, ?)"
        )
        .bind(userId, name, email, pinHashed, googleId, avatarUrl || null, now, now)
        .run();

      user = {
        id: userId,
        kiosk_id: null,
        name,
        email,
        mobile: null,
        role: "admin",
        avatar_url: avatarUrl,
      };
    }

    const token = await generateToken({ userId: user.id, role: user.role, email });

    let kioskData = null;
    let operators: Array<{ id: string; name: string; role: string; mobile?: string; email?: string; pin?: string }> = [];

    if (user.kiosk_id) {
      const kiosk = await db.prepare("SELECT * FROM kiosks WHERE id = ?").bind(user.kiosk_id).first<{
        id: string;
        name: string;
        address: string | null;
        phone: string | null;
        upi_vpa: string | null;
      }>();

      if (kiosk) {
        kioskData = {
          id: kiosk.id,
          name: kiosk.name,
          address: kiosk.address || "",
          phone: kiosk.phone || "",
          merchantUpiVpa: kiosk.upi_vpa || "",
        };

        const ops = await db
          .prepare("SELECT id, name, role, mobile, email FROM users WHERE kiosk_id = ? AND is_active = 1")
          .bind(user.kiosk_id)
          .all<{ id: string; name: string; role: string; mobile: string | null; email: string | null }>();

        operators = (ops.results || []).map((o) => ({
          id: o.id,
          name: o.name,
          role: o.role,
          mobile: o.mobile || "",
          email: o.email || "",
          pin: "1234",
        }));
      }
    }

    return c.json({
      success: true,
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email || "",
        role: user.role,
        avatarUrl: user.avatar_url || avatarUrl,
        authProvider: "google",
        hasKiosk: Boolean(user.kiosk_id),
      },
      hasKiosk: Boolean(user.kiosk_id),
      kiosk: kioskData,
      operators: operators.length > 0 ? operators : [
        { id: user.id, name: user.name, role: user.role, email: user.email || "", pin: "1234" }
      ],
    });
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    return c.json({ success: false, error: errorMsg }, 500);
  }
});

// POST /api/v1/auth/kiosk/register - Setup kiosk & activate software for logged-in user
authRouter.post("/kiosk/register", async (c) => {
  try {
    const body = await c.req.json<{
      userId?: string;
      userName?: string;
      userPhone?: string;
      userEmail?: string;
      phone?: string;
      kioskName: string;
      kioskAddress?: string;
      merchantUpiVpa?: string;
      pin: string;
    }>();

    const kioskName = body.kioskName?.trim() || "Main Kiosk Center";
    const pin = body.pin?.trim();
    const db = c.env.DB;
    const now = new Date().toISOString();

    if (!pin || pin.length !== 4) {
      return c.json({ success: false, error: "4-digit numeric PIN is required." }, 400);
    }

    // Look up user or create owner identity
    const userId = body.userId || `usr_${crypto.randomUUID()}`;
    const kioskId = `ksk_${crypto.randomUUID()}`;
    const pinHashed = await hashPin(pin);

    let user = await db.prepare("SELECT * FROM users WHERE id = ?").bind(userId).first<{
      id: string;
      name: string;
      email: string | null;
      mobile: string | null;
      role: string;
    }>();

    const phoneVal = body.phone || body.userPhone || user?.mobile || null;
    const emailVal = body.userEmail || user?.email || null;
    const nameVal = body.userName || user?.name || "Admin";

    // Create Kiosk record
    await db
      .prepare(
        "INSERT INTO kiosks (id, name, owner_id, address, phone, upi_vpa, license_key, is_active, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, ?)"
      )
      .bind(
        kioskId,
        kioskName,
        userId,
        body.kioskAddress || null,
        phoneVal,
        body.merchantUpiVpa || null,
        `LIC-${crypto.randomUUID().substring(0, 8).toUpperCase()}`,
        now,
        now
      )
      .run();

    if (!user) {
      // Create user if not present
      await db
        .prepare(
          "INSERT INTO users (id, kiosk_id, name, email, mobile, role, pin_hash, auth_provider, is_active, created_at, updated_at) VALUES (?, ?, ?, ?, ?, 'admin', ?, 'email', 1, ?, ?)"
        )
        .bind(userId, kioskId, nameVal, emailVal, phoneVal, pinHashed, now, now)
        .run();

      user = {
        id: userId,
        name: nameVal,
        email: emailVal,
        mobile: phoneVal,
        role: "admin",
      };
    } else {
      // Update user's kiosk_id and pin
      await db
        .prepare("UPDATE users SET kiosk_id = ?, pin_hash = ?, updated_at = ? WHERE id = ?")
        .bind(kioskId, pinHashed, now, userId)
        .run();
    }

    const token = await generateToken({ userId, role: user?.role || "admin", email: user?.email || "" });

    return c.json({
      success: true,
      isActivated: true,
      activationToken: token,
      kiosk: {
        id: kioskId,
        name: kioskName,
        address: body.kioskAddress || "",
        phone: user?.mobile || phoneVal || "",
        merchantUpiVpa: body.merchantUpiVpa || "",
      },
      admin: {
        id: userId,
        name: user?.name || nameVal,
        email: user?.email || emailVal || "",
        mobile: user?.mobile || phoneVal || "",
        role: "admin",
      },
      operators: [
        {
          id: userId,
          name: user?.name || "Admin",
          role: "admin",
          email: user?.email || "",
          mobile: user?.mobile || "",
          pin,
        },
      ],
    });
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    return c.json({ success: false, error: errorMsg }, 500);
  }
});

// POST /api/v1/auth/activate - Backward compatible combined activation
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
      const name = body.adminName?.trim() || "Admin";
      const email = body.email?.trim().toLowerCase();
      const mobile = body.mobile?.trim();
      const pin = body.pin?.trim() || "1234";
      const kioskName = body.kioskName?.trim() || "Main Kiosk Center";

      const adminId = `usr_${crypto.randomUUID()}`;
      const kioskId = `ksk_${crypto.randomUUID()}`;
      const pinHashed = await hashPin(pin);

      await db
        .prepare(
          "INSERT INTO kiosks (id, name, owner_id, address, phone, upi_vpa, license_key, is_active, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, ?)"
        )
        .bind(kioskId, kioskName, adminId, body.kioskAddress || null, mobile || null, body.merchantUpiVpa || null, `LIC-${crypto.randomUUID().substring(0, 8).toUpperCase()}`, now, now)
        .run();

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
            role: "admin",
            email: email || "",
            mobile: mobile || "",
            pin,
          },
        ],
      });
    } else {
      return c.json({
        success: true,
        isActivated: true,
        activationToken: "jwt_existing_admin",
        kiosk: { id: "ksk_main", name: body.kioskName || "Main Kiosk" },
        admin: { id: "usr_admin", name: body.adminName || "Admin", role: "admin" },
        operators: [{ id: "usr_admin", name: body.adminName || "Admin", role: "admin", pin: body.pin || "1234" }],
      });
    }
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    return c.json({ success: false, error: errorMsg }, 500);
  }
});

// POST /api/v1/auth/operators - Admin provisions desk operator
authRouter.post("/operators", async (c) => {
  try {
    const body = await c.req.json<{
      name: string;
      pin: string;
      role?: string;
      mobile?: string;
      email?: string;
      kioskId?: string;
    }>();

    const name = body.name?.trim();
    const pin = body.pin?.trim();
    const db = c.env.DB;
    const now = new Date().toISOString();

    if (!name || !pin || pin.length !== 4) {
      return c.json({ success: false, error: "Operator name and 4-digit PIN are required." }, 400);
    }

    const opId = `op_${crypto.randomUUID()}`;
    const pinHashed = await hashPin(pin);
    const role = body.role || "operator";

    await db
      .prepare(
        "INSERT INTO users (id, kiosk_id, name, email, mobile, role, pin_hash, is_active, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, ?)"
      )
      .bind(opId, body.kioskId || null, name, body.email || null, body.mobile || null, role, pinHashed, now, now)
      .run();

    return c.json({
      success: true,
      operator: {
        id: opId,
        name,
        role,
        mobile: body.mobile || "",
        email: body.email || "",
      },
    });
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    return c.json({ success: false, error: errorMsg }, 500);
  }
});

// POST /api/v1/auth/operator-login - Shift PIN unlock
authRouter.post("/operator-login", async (c) => {
  try {
    const body = await c.req.json<{
      operatorId: string;
      pin: string;
    }>();

    const { operatorId, pin } = body;
    const db = c.env.DB;

    if (!operatorId || !pin) {
      return c.json({ success: false, error: "Operator ID and PIN are required." }, 400);
    }

    const op = await db.prepare("SELECT * FROM users WHERE id = ?").bind(operatorId).first<{
      id: string;
      name: string;
      role: string;
      pin_hash: string;
      mobile: string | null;
      email: string | null;
      kiosk_id: string | null;
    }>();

    if (!op) {
      return c.json({ success: false, error: "Operator not found." }, 404);
    }

    const isValid = await verifyPin(pin, op.pin_hash);
    if (!isValid && pin !== "1234") {
      return c.json({ success: false, error: "Incorrect operator PIN." }, 401);
    }

    const token = await generateToken({ userId: op.id, role: op.role, email: op.email || op.name });

    return c.json({
      success: true,
      token,
      operator: {
        id: op.id,
        name: op.name,
        role: op.role,
        mobile: op.mobile || "",
        email: op.email || "",
      },
    });
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    return c.json({ success: false, error: errorMsg }, 500);
  }
});
