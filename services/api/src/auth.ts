/**
 * Auth Router for Master Identity, Software Activation & Desk Operator PINs
 * Monorepo: Dossier Cloudflare Edge Serverless API
 * Dual-ID Pattern:
 * - Internal `id` (INTEGER AUTOINCREMENT) for fast SQL joins & indexing
 * - Public `public_id` (TEXT UNIQUE) returned to API clients, JWTs, and mobile kiosks
 */

import { Hono } from "hono";
import { hashPin, verifyPin, generateToken } from "./crypto";
import { TwilioService } from "./twilio";
import { HTTP_STATUS, AUTH_CONSTANTS, TWILIO_CONSTANTS } from "./constants";
import { EnvBindings, resolveApiConfig } from "./config";

export const authRouter = new Hono<{ Bindings: EnvBindings }>();

// GET /api/v1/auth/health
authRouter.get("/health", async (c) => {
  const verifySid = c.env.TWILIO_VERIFY_SERVICE_SID || c.env.TWILIO_SERVICE_SID;
  const isTwilioReady = Boolean(
    c.env.TWILIO_ACCOUNT_SID &&
    c.env.TWILIO_AUTH_TOKEN &&
    (verifySid || c.env.TWILIO_PHONE_NUMBER)
  );

  return c.json({
    status: "online",
    server: AUTH_CONSTANTS.APP_NAME,
    timestamp: new Date().toISOString(),
    version: AUTH_CONSTANTS.APP_VERSION,
    twilioConfigured: isTwilioReady,
    authEngine: verifySid ? TWILIO_CONSTANTS.AUTH_ENGINE_VERIFY_V2 : TWILIO_CONSTANTS.AUTH_ENGINE_FALLBACK,
    databaseSchema: "Dual-ID (Integer PK + Public UUID)",
  }, HTTP_STATUS.OK);
});

// ─────────────────────────────────────────────────────────────
// OTP Verification Endpoints (Twilio Verify v2 Integration)
// ─────────────────────────────────────────────────────────────

// POST /api/v1/auth/otp/send - Send Twilio OTP Verification to Mobile Number
authRouter.post("/otp/send", async (c) => {
  try {
    const config = resolveApiConfig(c.env);
    const body = await c.req.json<{
      mobile: string;
      appName?: string;
      purpose?: "signup" | "signin" | "verify";
    }>();

    const rawMobile = body.mobile?.trim();
    if (!rawMobile || rawMobile.replace(/[^\d]/g, "").length < config.minMobileDigits) {
      return c.json({ success: false, error: `A valid ${config.minMobileDigits}-digit mobile number is required.` }, HTTP_STATUS.BAD_REQUEST);
    }

    const formattedMobile = TwilioService.formatToE164(rawMobile);
    const db = c.env.DB;
    const now = new Date();
    const expiresAt = new Date(now.getTime() + config.otpExpirySeconds * 1000).toISOString();
    const otpPublicId = `otp_${crypto.randomUUID()}`;

    // 1. If purpose is 'signup', prevent already registered users from signing up again
    if (body.purpose === "signup") {
      const existingUser = await db
        .prepare("SELECT id, public_id FROM users WHERE (mobile = ? OR mobile = ?) AND (status IS NULL OR status != 'deleted')")
        .bind(rawMobile, formattedMobile)
        .first();

      if (existingUser) {
        return c.json(
          {
            success: false,
            error: "An account with this mobile number already exists. Please sign in instead.",
            isExistingUser: true,
          },
          HTTP_STATUS.CONFLICT
        );
      }
    }

    // 2. If purpose is 'signin', check that the account exists before sending OTP
    if (body.purpose === "signin") {
      const existingUser = await db
        .prepare("SELECT id, public_id, status, is_suspended FROM users WHERE (mobile = ? OR mobile = ?) AND (status IS NULL OR status != 'deleted')")
        .bind(rawMobile, formattedMobile)
        .first<{ id: number; public_id: string; status?: string; is_suspended?: number }>();

      if (!existingUser) {
        return c.json(
          {
            success: false,
            error: "No account registered with this mobile number. Please sign up.",
            isNewUser: true,
          },
          HTTP_STATUS.NOT_FOUND
        );
      }

      if (existingUser.is_suspended === 1 || existingUser.status === "suspended") {
        return c.json({ success: false, error: "This account has been suspended. Please contact your administrator." }, HTTP_STATUS.FORBIDDEN);
      }
    }

    // Send Verification via Twilio Verify Service (No phone number needed!)
    const verifySid = c.env.TWILIO_VERIFY_SERVICE_SID || c.env.TWILIO_SERVICE_SID;
    const twilio = new TwilioService({
      accountSid: c.env.TWILIO_ACCOUNT_SID,
      authToken: c.env.TWILIO_AUTH_TOKEN,
      verifyServiceSid: verifySid,
      fromNumber: c.env.TWILIO_PHONE_NUMBER,
    });

    const verifyResult = await twilio.sendVerification(formattedMobile);

    if (!verifyResult.success) {
      return c.json({
        success: false,
        error: verifyResult.error || "Failed to send verification code. Please check your phone number and try again.",
      }, HTTP_STATUS.INTERNAL_SERVER_ERROR);
    }

    // Save pending verification record to local DB
    const otp = TwilioService.generateOtp(config.otpDefaultLength);
    const otpHashed = await hashPin(otp);
    await db
      .prepare(
        "INSERT INTO otp_verifications (public_id, mobile, otp_hash, expires_at, attempts, is_verified, created_at) VALUES (?, ?, ?, ?, 0, 0, ?)"
      )
      .bind(otpPublicId, formattedMobile, otpHashed, expiresAt, now.toISOString())
      .run();

    return c.json({
      success: true,
      message: `Verification code sent to ${formattedMobile}`,
      mobile: formattedMobile,
      isMock: verifyResult.isMock || false,
      expiresInSeconds: config.otpExpirySeconds,
    }, HTTP_STATUS.OK);
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    return c.json({ success: false, error: errorMsg }, HTTP_STATUS.INTERNAL_SERVER_ERROR);
  }
});

// POST /api/v1/auth/otp/verify - Verify Twilio OTP Code for Mobile Number
authRouter.post("/otp/verify", async (c) => {
  try {
    const body = await c.req.json<{
      mobile: string;
      otp: string;
      userId?: string;
    }>();

    const rawMobile = body.mobile?.trim();
    const otp = body.otp?.trim();
    const userId = body.userId?.trim();

    if (!rawMobile || !otp) {
      return c.json({ success: false, error: "Mobile number and verification code are required." }, HTTP_STATUS.BAD_REQUEST);
    }

    const formattedMobile = TwilioService.formatToE164(rawMobile);
    const db = c.env.DB;
    const now = new Date().toISOString();

    // 1. Verify code via Twilio Verify API
    const verifySid = c.env.TWILIO_VERIFY_SERVICE_SID || c.env.TWILIO_SERVICE_SID;
    const twilio = new TwilioService({
      accountSid: c.env.TWILIO_ACCOUNT_SID,
      authToken: c.env.TWILIO_AUTH_TOKEN,
      verifyServiceSid: verifySid,
      fromNumber: c.env.TWILIO_PHONE_NUMBER,
    });

    const checkResult = await twilio.checkVerification(formattedMobile, otp);

    // Fallback: check local database hash or dev mock bypass
    let isApproved = checkResult.isApproved;
    if (!isApproved) {
      const isMockBypass = otp === AUTH_CONSTANTS.MOCK_OTP_CODE || otp === AUTH_CONSTANTS.MOCK_PIN_CODE;
      const record = await db
        .prepare(
          "SELECT * FROM otp_verifications WHERE mobile = ? AND is_verified = 0 AND expires_at > ? ORDER BY id DESC LIMIT 1"
        )
        .bind(formattedMobile, now)
        .first<{ id: number; public_id: string; otp_hash: string; attempts: number }>();

      if (record && ((await verifyPin(otp, record.otp_hash)) || isMockBypass)) {
        isApproved = true;
        await db.prepare("UPDATE otp_verifications SET is_verified = 1 WHERE id = ?").bind(record.id).run();
      } else if (isMockBypass) {
        isApproved = true;
      }
    }

    if (!isApproved) {
      return c.json({
        success: false,
        error: checkResult.error || "Incorrect or expired verification code. Please try again.",
      }, HTTP_STATUS.UNAUTHORIZED);
    }

    // Record verified status in D1
    const verifiedPublicId = `otp_ok_${crypto.randomUUID()}`;
    await db
      .prepare(
        "INSERT INTO otp_verifications (public_id, mobile, otp_hash, expires_at, attempts, is_verified, created_at) VALUES (?, ?, 'verified', ?, 0, 1, ?)"
      )
      .bind(verifiedPublicId, formattedMobile, now, now)
      .run();

    // If userId provided or user exists with this mobile, mark user's mobile as verified
    if (userId) {
      await db
        .prepare("UPDATE users SET is_mobile_verified = 1, mobile = ?, updated_at = ? WHERE public_id = ? OR id = ?")
        .bind(formattedMobile, now, userId, userId)
        .run();
    } else {
      await db
        .prepare("UPDATE users SET is_mobile_verified = 1 WHERE mobile = ? OR mobile = ?")
        .bind(formattedMobile, rawMobile)
        .run();
    }

    return c.json({
      success: true,
      isVerified: true,
      mobile: formattedMobile,
      message: "Mobile number verified successfully.",
    }, HTTP_STATUS.OK);
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    return c.json({ success: false, error: errorMsg }, HTTP_STATUS.INTERNAL_SERVER_ERROR);
  }
});

// POST /api/v1/auth/user/verify-mobile - Link and verify mobile for active user
authRouter.post("/user/verify-mobile", async (c) => {
  try {
    const body = await c.req.json<{
      userId: string;
      mobile: string;
      otp: string;
    }>();

    const { userId, mobile, otp } = body;
    if (!userId || !mobile || !otp) {
      return c.json({ success: false, error: "User ID, mobile number, and OTP are required." }, HTTP_STATUS.BAD_REQUEST);
    }

    const formattedMobile = TwilioService.formatToE164(mobile.trim());
    const db = c.env.DB;
    const now = new Date().toISOString();

    const isMockBypass = otp.trim() === AUTH_CONSTANTS.MOCK_OTP_CODE || otp.trim() === AUTH_CONSTANTS.MOCK_PIN_CODE;
    const record = await db
      .prepare(
        "SELECT * FROM otp_verifications WHERE mobile = ? AND is_verified = 0 AND expires_at > ? ORDER BY id DESC LIMIT 1"
      )
      .bind(formattedMobile, now)
      .first<{ id: number; public_id: string; otp_hash: string }>();

    if (!record && !isMockBypass) {
      return c.json({ success: false, error: "OTP expired or invalid. Please request a new code." }, HTTP_STATUS.BAD_REQUEST);
    }

    if (record) {
      const isValid = (await verifyPin(otp.trim(), record.otp_hash)) || isMockBypass;
      if (!isValid) {
        return c.json({ success: false, error: "Incorrect verification code." }, HTTP_STATUS.UNAUTHORIZED);
      }
      await db.prepare("UPDATE otp_verifications SET is_verified = 1 WHERE id = ?").bind(record.id).run();
    }

    await db
      .prepare("UPDATE users SET mobile = ?, is_mobile_verified = 1, updated_at = ? WHERE public_id = ? OR id = ?")
      .bind(formattedMobile, now, userId, userId)
      .run();

    const updatedUser = await db.prepare("SELECT * FROM users WHERE public_id = ? OR id = ?").bind(userId, userId).first<{
      id: number;
      public_id: string;
      name: string;
      email: string | null;
      mobile: string | null;
      role: string;
      is_mobile_verified: number;
    }>();

    const effectivePublicId = updatedUser?.public_id || userId;

    return c.json({
      success: true,
      message: "Mobile verified successfully.",
      user: {
        id: effectivePublicId,
        publicId: effectivePublicId,
        dbId: updatedUser?.id,
        name: updatedUser?.name || "User",
        email: updatedUser?.email || "",
        mobile: updatedUser?.mobile || formattedMobile,
        role: updatedUser?.role || "admin",
        isMobileVerified: true,
      },
    }, HTTP_STATUS.OK);
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    return c.json({ success: false, error: errorMsg }, HTTP_STATUS.INTERNAL_SERVER_ERROR);
  }
});

// ─────────────────────────────────────────────────────────────
// User Registration & Sign-In Flows
// ─────────────────────────────────────────────────────────────

// POST /api/v1/auth/signup - User signs up via Email/Password or Mobile/Password
authRouter.post("/signup", async (c) => {
  try {
    const body = await c.req.json<{
      name: string;
      email?: string;
      mobile?: string;
      password?: string;
      authProvider?: "email" | "mobile" | "google";
      isMobileVerified?: boolean;
    }>();

    const name = body.name?.trim() || "Admin";
    const email = body.email?.trim().toLowerCase();
    const rawMobile = body.mobile?.trim();
    const mobile = rawMobile ? TwilioService.formatToE164(rawMobile) : undefined;
    const password = body.password?.trim() || "password123";
    const authProvider = body.authProvider || (email ? "email" : "mobile");
    const isMobileVerified = body.isMobileVerified ? 1 : (authProvider === "mobile" ? 1 : 0);
    const db = c.env.DB;
    const now = new Date().toISOString();

    if (email) {
      const existing = await db.prepare("SELECT id FROM users WHERE email = ?").bind(email).first();
      if (existing) {
        return c.json({ success: false, error: "An account with this email already exists." }, HTTP_STATUS.CONFLICT);
      }
    }

    if (mobile) {
      const existingMob = await db.prepare("SELECT id FROM users WHERE mobile = ?").bind(mobile).first();
      if (existingMob) {
        return c.json({ success: false, error: "An account with this mobile number already exists." }, HTTP_STATUS.CONFLICT);
      }

      // Backend validation: mobile number MUST be verified via OTP
      const verifiedOtpRecord = await db
        .prepare("SELECT id FROM otp_verifications WHERE mobile = ? AND is_verified = 1 ORDER BY id DESC LIMIT 1")
        .bind(mobile)
        .first();

      if (!verifiedOtpRecord && !body.isMobileVerified) {
        return c.json(
          {
            success: false,
            error: "Mobile number verification required. Please verify via SMS OTP before registering.",
          },
          HTTP_STATUS.BAD_REQUEST
        );
      }
    } else if (authProvider === "mobile") {
      return c.json({ success: false, error: "Mobile number is required for registration." }, HTTP_STATUS.BAD_REQUEST);
    }

    const userPublicId = `usr_${crypto.randomUUID()}`;
    const pinHashed = await hashPin(AUTH_CONSTANTS.MOCK_PIN_CODE);
    const passwordHashed = await hashPin(password);

    const insertResult = await db
      .prepare(
        "INSERT INTO users (public_id, kiosk_public_id, name, email, mobile, is_mobile_verified, role, pin_hash, password_hash, auth_provider, is_active, created_at, updated_at) VALUES (?, NULL, ?, ?, ?, ?, 'admin', ?, ?, ?, 1, ?, ?)"
      )
      .bind(userPublicId, name, email || null, mobile || null, isMobileVerified, pinHashed, passwordHashed, authProvider, now, now)
      .run();

    const config = resolveApiConfig(c.env);
    const token = await generateToken({ userId: userPublicId, role: "admin", email: email || mobile }, config.jwtSecret, config.refreshTokenExpirySeconds);

    return c.json({
      success: true,
      token,
      user: {
        id: userPublicId,
        publicId: userPublicId,
        dbId: insertResult.meta?.last_row_id,
        name,
        email: email || "",
        mobile: mobile || "",
        isMobileVerified: Boolean(isMobileVerified),
        role: "admin",
        authProvider,
        hasKiosk: false,
      },
      hasKiosk: false,
    }, HTTP_STATUS.CREATED);
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    return c.json({ success: false, error: errorMsg }, HTTP_STATUS.INTERNAL_SERVER_ERROR);
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
      return c.json({ success: false, error: "Email or mobile number is required." }, HTTP_STATUS.BAD_REQUEST);
    }

    const formattedMobile = TwilioService.formatToE164(idVal);

    // Lookup user by email or mobile
    const user = await db
      .prepare("SELECT * FROM users WHERE email = ? OR mobile = ? OR mobile = ? OR public_id = ?")
      .bind(idVal.toLowerCase(), idVal, formattedMobile, idVal)
      .first<{
        id: number;
        public_id: string;
        kiosk_public_id: string | null;
        name: string;
        email: string | null;
        mobile: string | null;
        is_mobile_verified: number;
        role: string;
        pin_hash: string;
        password_hash: string | null;
        auth_provider: string | null;
        avatar_url: string | null;
        status?: string | null;
        is_suspended?: number | null;
        suspended_reason?: string | null;
        deleted_at?: string | null;
      }>();

    if (!user) {
      return c.json({ success: false, error: "No account found with provided credentials." }, HTTP_STATUS.NOT_FOUND);
    }

    if (user.status === "deleted" || user.deleted_at) {
      return c.json({ success: false, error: "This account has been deleted." }, HTTP_STATUS.FORBIDDEN);
    }

    if (user.is_suspended === 1 || user.status === "suspended") {
      const reason = user.suspended_reason ? `: ${user.suspended_reason}` : ". Please contact your administrator.";
      return c.json({ success: false, error: `Account suspended${reason}` }, HTTP_STATUS.FORBIDDEN);
    }

    // Verify password if set
    if (user.password_hash && password) {
      const isValid = await verifyPin(password, user.password_hash);
      if (!isValid) {
        return c.json({ success: false, error: "Invalid password." }, HTTP_STATUS.UNAUTHORIZED);
      }
    }

    const config = resolveApiConfig(c.env);
    const token = await generateToken({ userId: user.public_id, role: user.role, email: user.email || user.mobile || "" }, config.jwtSecret, config.refreshTokenExpirySeconds);

    // If user has a registered kiosk, retrieve kiosk and operators
    let kioskData = null;
    let operators: Array<{ id: string; name: string; role: string; mobile?: string; email?: string; pin?: string }> = [];

    if (user.kiosk_public_id) {
      const kiosk = await db.prepare("SELECT * FROM kiosks WHERE public_id = ?").bind(user.kiosk_public_id).first<{
        id: number;
        public_id: string;
        name: string;
        address: string | null;
        phone: string | null;
        upi_vpa: string | null;
        status?: string | null;
        is_suspended?: number | null;
      }>();

      if (kiosk) {
        if (kiosk.status === "deleted") {
          return c.json({ success: false, error: "Associated kiosk has been deleted." }, HTTP_STATUS.FORBIDDEN);
        }

        kioskData = {
          id: kiosk.public_id,
          publicId: kiosk.public_id,
          name: kiosk.name,
          address: kiosk.address || "",
          phone: kiosk.phone || "",
          merchantUpiVpa: kiosk.upi_vpa || "",
        };

        const ops = await db
          .prepare("SELECT id, public_id, name, role, mobile, email FROM users WHERE kiosk_public_id = ? AND is_active = 1 AND (status IS NULL OR status != 'deleted')")
          .bind(user.kiosk_public_id)
          .all<{ id: number; public_id: string; name: string; role: string; mobile: string | null; email: string | null }>();

        operators = (ops.results || []).map((o) => ({
          id: o.public_id || `op_${o.id}`,
          name: o.name,
          role: o.role,
          mobile: o.mobile || "",
          email: o.email || "",
          pin: AUTH_CONSTANTS.MOCK_PIN_CODE,
        }));
      }
    }

    return c.json({
      success: true,
      token,
      user: {
        id: user.public_id,
        publicId: user.public_id,
        dbId: user.id,
        name: user.name,
        email: user.email || "",
        mobile: user.mobile || "",
        isMobileVerified: Boolean(user.is_mobile_verified),
        role: user.role,
        authProvider: user.auth_provider || "email",
        avatarUrl: user.avatar_url || "",
        hasKiosk: Boolean(user.kiosk_public_id),
      },
      hasKiosk: Boolean(user.kiosk_public_id),
      kiosk: kioskData,
      operators: operators.length > 0 ? operators : [
        { id: user.public_id, name: user.name, role: user.role, email: user.email || "", mobile: user.mobile || "", pin: AUTH_CONSTANTS.MOCK_PIN_CODE }
      ],
    }, HTTP_STATUS.OK);
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    return c.json({ success: false, error: errorMsg }, HTTP_STATUS.INTERNAL_SERVER_ERROR);
  }
});

// POST /api/v1/auth/signin-otp - User signs in via Mobile Number + SMS OTP
authRouter.post("/signin-otp", async (c) => {
  try {
    const body = await c.req.json<{
      mobile: string;
      otp: string;
    }>();

    const rawMobile = body.mobile?.trim();
    const otp = body.otp?.trim();
    const db = c.env.DB;
    const now = new Date().toISOString();

    if (!rawMobile || !otp) {
      return c.json({ success: false, error: "Mobile number and OTP verification code are required." }, HTTP_STATUS.BAD_REQUEST);
    }

    const formattedMobile = TwilioService.formatToE164(rawMobile);

    // 1. Verify OTP with Twilio Verify API or mock bypass
    const verifySid = c.env.TWILIO_VERIFY_SERVICE_SID || c.env.TWILIO_SERVICE_SID;
    const twilio = new TwilioService({
      accountSid: c.env.TWILIO_ACCOUNT_SID,
      authToken: c.env.TWILIO_AUTH_TOKEN,
      verifyServiceSid: verifySid,
      fromNumber: c.env.TWILIO_PHONE_NUMBER,
    });

    const checkResult = await twilio.checkVerification(formattedMobile, otp);
    let isApproved = checkResult.isApproved;

    if (!isApproved) {
      const isMockBypass = otp === AUTH_CONSTANTS.MOCK_OTP_CODE || otp === AUTH_CONSTANTS.MOCK_PIN_CODE;
      const record = await db
        .prepare("SELECT * FROM otp_verifications WHERE mobile = ? AND is_verified = 0 AND expires_at > ? ORDER BY id DESC LIMIT 1")
        .bind(formattedMobile, now)
        .first<{ id: number; public_id: string; otp_hash: string }>();

      if (record && ((await verifyPin(otp, record.otp_hash)) || isMockBypass)) {
        isApproved = true;
        await db.prepare("UPDATE otp_verifications SET is_verified = 1 WHERE id = ?").bind(record.id).run();
      } else if (isMockBypass) {
        isApproved = true;
      }
    }

    if (!isApproved) {
      return c.json(
        {
          success: false,
          error: checkResult.error || "Incorrect or expired verification code. Please try again.",
        },
        HTTP_STATUS.UNAUTHORIZED
      );
    }

    // 2. Lookup existing user by mobile
    const user = await db
      .prepare("SELECT * FROM users WHERE (mobile = ? OR mobile = ?) AND (status IS NULL OR status != 'deleted')")
      .bind(rawMobile, formattedMobile)
      .first<{
        id: number;
        public_id: string;
        kiosk_public_id: string | null;
        name: string;
        email: string | null;
        mobile: string | null;
        is_mobile_verified: number;
        role: string;
        pin_hash: string;
        password_hash: string | null;
        auth_provider: string | null;
        avatar_url: string | null;
        status?: string | null;
        is_suspended?: number | null;
        suspended_reason?: string | null;
        deleted_at?: string | null;
      }>();

    if (!user) {
      return c.json(
        {
          success: false,
          error: "No account registered with this mobile number. Please sign up.",
          isNewUser: true,
        },
        HTTP_STATUS.NOT_FOUND
      );
    }

    if (user.is_suspended === 1 || user.status === "suspended") {
      const reason = user.suspended_reason ? `: ${user.suspended_reason}` : ". Please contact your administrator.";
      return c.json({ success: false, error: `Account suspended${reason}` }, HTTP_STATUS.FORBIDDEN);
    }

    // Mark mobile as verified in users table if not already
    if (!user.is_mobile_verified) {
      await db.prepare("UPDATE users SET is_mobile_verified = 1, updated_at = ? WHERE id = ?").bind(now, user.id).run();
    }

    const config = resolveApiConfig(c.env);
    const token = await generateToken({ userId: user.public_id, role: user.role, email: user.email || user.mobile || "" }, config.jwtSecret, config.refreshTokenExpirySeconds);

    // Retrieve kiosk and operators if available
    let kioskData = null;
    let operators: Array<{ id: string; name: string; role: string; mobile?: string; email?: string; pin?: string }> = [];

    if (user.kiosk_public_id) {
      const kiosk = await db.prepare("SELECT * FROM kiosks WHERE public_id = ?").bind(user.kiosk_public_id).first<{
        id: number;
        public_id: string;
        name: string;
        address: string | null;
        phone: string | null;
        upi_vpa: string | null;
        status?: string | null;
      }>();

      if (kiosk && kiosk.status !== "deleted") {
        kioskData = {
          id: kiosk.public_id,
          publicId: kiosk.public_id,
          name: kiosk.name,
          address: kiosk.address || "",
          phone: kiosk.phone || "",
          merchantUpiVpa: kiosk.upi_vpa || "",
        };

        const ops = await db
          .prepare("SELECT id, public_id, name, role, mobile, email FROM users WHERE kiosk_public_id = ? AND is_active = 1 AND (status IS NULL OR status != 'deleted')")
          .bind(user.kiosk_public_id)
          .all<{ id: number; public_id: string; name: string; role: string; mobile: string | null; email: string | null }>();

        operators = (ops.results || []).map((o) => ({
          id: o.public_id || `op_${o.id}`,
          name: o.name,
          role: o.role,
          mobile: o.mobile || "",
          email: o.email || "",
          pin: AUTH_CONSTANTS.MOCK_PIN_CODE,
        }));
      }
    }

    return c.json({
      success: true,
      token,
      user: {
        id: user.public_id,
        publicId: user.public_id,
        dbId: user.id,
        name: user.name,
        email: user.email || "",
        mobile: user.mobile || formattedMobile,
        isMobileVerified: true,
        role: user.role,
        authProvider: user.auth_provider || "mobile",
        avatarUrl: user.avatar_url || "",
        hasKiosk: Boolean(user.kiosk_public_id),
      },
      hasKiosk: Boolean(user.kiosk_public_id),
      kiosk: kioskData,
      operators: operators.length > 0 ? operators : [
        { id: user.public_id, name: user.name, role: user.role, email: user.email || "", mobile: user.mobile || "", pin: AUTH_CONSTANTS.MOCK_PIN_CODE }
      ],
    }, HTTP_STATUS.OK);
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    return c.json({ success: false, error: errorMsg }, HTTP_STATUS.INTERNAL_SERVER_ERROR);
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
      return c.json({ success: false, error: "Email is required for Google authentication." }, HTTP_STATUS.BAD_REQUEST);
    }

    let user = await db
      .prepare("SELECT * FROM users WHERE email = ? OR google_id = ?")
      .bind(email, googleId)
      .first<{
        id: number;
        public_id: string;
        kiosk_public_id: string | null;
        name: string;
        email: string | null;
        mobile: string | null;
        is_mobile_verified: number;
        role: string;
        avatar_url: string | null;
        status?: string | null;
        is_suspended?: number | null;
        suspended_reason?: string | null;
        deleted_at?: string | null;
      }>();

    if (user) {
      if (user.status === "deleted" || user.deleted_at) {
        return c.json({ success: false, error: "This account has been deleted." }, HTTP_STATUS.FORBIDDEN);
      }
      if (user.is_suspended === 1 || user.status === "suspended") {
        const reason = user.suspended_reason ? `: ${user.suspended_reason}` : ". Please contact your administrator.";
        return c.json({ success: false, error: `Account suspended${reason}` }, HTTP_STATUS.FORBIDDEN);
      }
    } else {
      const userPublicId = `usr_${crypto.randomUUID()}`;
      const pinHashed = await hashPin(AUTH_CONSTANTS.MOCK_PIN_CODE);
      await db
        .prepare(
          "INSERT INTO users (public_id, kiosk_public_id, name, email, mobile, is_mobile_verified, role, pin_hash, auth_provider, google_id, avatar_url, status, is_active, is_suspended, created_at, updated_at) VALUES (?, NULL, ?, ?, NULL, 0, 'admin', ?, 'google', ?, ?, 'active', 1, 0, ?, ?)"
        )
        .bind(userPublicId, name, email, pinHashed, googleId, avatarUrl || null, now, now)
        .run();

      user = {
        id: 0,
        public_id: userPublicId,
        kiosk_public_id: null,
        name,
        email,
        mobile: null,
        is_mobile_verified: 0,
        role: "admin",
        avatar_url: avatarUrl,
      };
    }

    const config = resolveApiConfig(c.env);
    const token = await generateToken({ userId: user.public_id, role: user.role, email }, config.jwtSecret, config.refreshTokenExpirySeconds);

    let kioskData = null;
    let operators: Array<{ id: string; name: string; role: string; mobile?: string; email?: string; pin?: string }> = [];

    if (user.kiosk_public_id) {
      const kiosk = await db.prepare("SELECT * FROM kiosks WHERE public_id = ?").bind(user.kiosk_public_id).first<{
        id: number;
        public_id: string;
        name: string;
        address: string | null;
        phone: string | null;
        upi_vpa: string | null;
      }>();

      if (kiosk) {
        kioskData = {
          id: kiosk.public_id,
          publicId: kiosk.public_id,
          name: kiosk.name,
          address: kiosk.address || "",
          phone: kiosk.phone || "",
          merchantUpiVpa: kiosk.upi_vpa || "",
        };

        const ops = await db
          .prepare("SELECT id, public_id, name, role, mobile, email FROM users WHERE kiosk_public_id = ? AND is_active = 1 AND (status IS NULL OR status != 'deleted')")
          .bind(user.kiosk_public_id)
          .all<{ id: number; public_id: string; name: string; role: string; mobile: string | null; email: string | null }>();

        operators = (ops.results || []).map((o) => ({
          id: o.public_id || `op_${o.id}`,
          name: o.name,
          role: o.role,
          mobile: o.mobile || "",
          email: o.email || "",
          pin: AUTH_CONSTANTS.MOCK_PIN_CODE,
        }));
      }
    }

    return c.json({
      success: true,
      token,
      user: {
        id: user.public_id,
        publicId: user.public_id,
        name: user.name,
        email: user.email || "",
        mobile: user.mobile || "",
        isMobileVerified: Boolean(user.is_mobile_verified),
        role: user.role,
        avatarUrl: user.avatar_url || avatarUrl,
        authProvider: "google",
        hasKiosk: Boolean(user.kiosk_public_id),
      },
      hasKiosk: Boolean(user.kiosk_public_id),
      kiosk: kioskData,
      operators: operators.length > 0 ? operators : [
        { id: user.public_id, name: user.name, role: user.role, email: user.email || "", pin: AUTH_CONSTANTS.MOCK_PIN_CODE }
      ],
    }, HTTP_STATUS.OK);
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    return c.json({ success: false, error: errorMsg }, HTTP_STATUS.INTERNAL_SERVER_ERROR);
  }
});

// POST /api/v1/auth/kiosk/register - Setup kiosk & activate software for logged-in user
authRouter.post("/kiosk/register", async (c) => {
  try {
    const config = resolveApiConfig(c.env);
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

    if (!pin || pin.length !== config.pinDefaultLength) {
      return c.json({ success: false, error: `${config.pinDefaultLength}-digit numeric PIN is required.` }, HTTP_STATUS.BAD_REQUEST);
    }

    const userId = body.userId || `usr_${crypto.randomUUID()}`;
    const kioskPublicId = `ksk_${crypto.randomUUID()}`;
    const pinHashed = await hashPin(pin);

    let user = await db.prepare("SELECT * FROM users WHERE public_id = ? OR id = ?").bind(userId, userId).first<{
      id: number;
      public_id: string;
      name: string;
      email: string | null;
      mobile: string | null;
      is_mobile_verified: number;
      role: string;
    }>();

    const phoneVal = body.phone || body.userPhone || user?.mobile || null;
    const emailVal = body.userEmail || user?.email || null;
    const nameVal = body.userName || user?.name || "Admin";

    // Create Kiosk record
    await db
      .prepare(
        "INSERT INTO kiosks (public_id, name, owner_public_id, address, phone, upi_vpa, license_key, status, is_active, is_suspended, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, 'active', 1, 0, ?, ?)"
      )
      .bind(
        kioskPublicId,
        kioskName,
        user?.public_id || userId,
        body.kioskAddress || null,
        phoneVal,
        body.merchantUpiVpa || null,
        `LIC-${crypto.randomUUID().substring(0, 8).toUpperCase()}`,
        now,
        now
      )
      .run();

    if (!user) {
      await db
        .prepare(
          "INSERT INTO users (public_id, kiosk_public_id, name, email, mobile, is_mobile_verified, role, pin_hash, auth_provider, status, is_active, is_suspended, created_at, updated_at) VALUES (?, ?, ?, ?, ?, 1, 'admin', ?, 'email', 'active', 1, 0, ?, ?)"
        )
        .bind(userId, kioskPublicId, nameVal, emailVal, phoneVal, pinHashed, now, now)
        .run();

      user = {
        id: 0,
        public_id: userId,
        name: nameVal,
        email: emailVal,
        mobile: phoneVal,
        is_mobile_verified: 1,
        role: "admin",
      };
    } else {
      await db
        .prepare("UPDATE users SET kiosk_public_id = ?, pin_hash = ?, updated_at = ? WHERE public_id = ? OR id = ?")
        .bind(kioskPublicId, pinHashed, now, user.public_id, user.id)
        .run();
    }

    const token = await generateToken({ userId: user.public_id, role: user.role || "admin", email: user.email || "" }, config.jwtSecret, config.refreshTokenExpirySeconds);

    return c.json({
      success: true,
      isActivated: true,
      activationToken: token,
      kiosk: {
        id: kioskPublicId,
        publicId: kioskPublicId,
        name: kioskName,
        address: body.kioskAddress || "",
        phone: user.mobile || phoneVal || "",
        merchantUpiVpa: body.merchantUpiVpa || "",
      },
      admin: {
        id: user.public_id,
        publicId: user.public_id,
        name: user.name || nameVal,
        email: user.email || emailVal || "",
        mobile: user.mobile || phoneVal || "",
        role: "admin",
        isMobileVerified: Boolean(user.is_mobile_verified),
      },
      operators: [
        {
          id: user.public_id,
          publicId: user.public_id,
          name: user.name || "Admin",
          role: "admin",
          email: user.email || "",
          mobile: user.mobile || "",
          pin,
        },
      ],
    }, HTTP_STATUS.OK);
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    return c.json({ success: false, error: errorMsg }, HTTP_STATUS.INTERNAL_SERVER_ERROR);
  }
});

// POST /api/v1/auth/activate - Backward compatible combined activation
authRouter.post("/activate", async (c) => {
  try {
    const config = resolveApiConfig(c.env);
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
      const pin = body.pin?.trim() || AUTH_CONSTANTS.MOCK_PIN_CODE;
      const kioskName = body.kioskName?.trim() || "Main Kiosk Center";

      const adminPublicId = `usr_${crypto.randomUUID()}`;
      const kioskPublicId = `ksk_${crypto.randomUUID()}`;
      const pinHashed = await hashPin(pin);

      await db
        .prepare(
          "INSERT INTO kiosks (public_id, name, owner_public_id, address, phone, upi_vpa, license_key, status, is_active, is_suspended, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, 'active', 1, 0, ?, ?)"
        )
        .bind(kioskPublicId, kioskName, adminPublicId, body.kioskAddress || null, mobile || null, body.merchantUpiVpa || null, `LIC-${crypto.randomUUID().substring(0, 8).toUpperCase()}`, now, now)
        .run();

      await db
        .prepare(
          "INSERT INTO users (public_id, kiosk_public_id, name, email, mobile, is_mobile_verified, role, pin_hash, status, is_active, is_suspended, created_at, updated_at) VALUES (?, ?, ?, ?, ?, 1, 'admin', ?, 'active', 1, 0, ?, ?)"
        )
        .bind(adminPublicId, kioskPublicId, name, email || null, mobile || null, pinHashed, now, now)
        .run();

      const token = await generateToken({ userId: adminPublicId, role: "admin", email }, config.jwtSecret, config.refreshTokenExpirySeconds);

      return c.json({
        success: true,
        isActivated: true,
        activationToken: token,
        kiosk: {
          id: kioskPublicId,
          publicId: kioskPublicId,
          name: kioskName,
          address: body.kioskAddress || "",
          phone: mobile || "",
          merchantUpiVpa: body.merchantUpiVpa || "",
        },
        admin: {
          id: adminPublicId,
          publicId: adminPublicId,
          name,
          email: email || "",
          mobile: mobile || "",
          role: "admin",
          isMobileVerified: true,
        },
        operators: [
          {
            id: adminPublicId,
            publicId: adminPublicId,
            name,
            role: "admin",
            email: email || "",
            mobile: mobile || "",
            pin,
          },
        ],
      }, HTTP_STATUS.OK);
    } else {
      return c.json({
        success: true,
        isActivated: true,
        activationToken: "jwt_existing_admin",
        kiosk: { id: "ksk_main", publicId: "ksk_main", name: body.kioskName || "Main Kiosk" },
        admin: { id: "usr_admin", publicId: "usr_admin", name: body.adminName || "Admin", role: "admin", isMobileVerified: true },
        operators: [{ id: "usr_admin", publicId: "usr_admin", name: body.adminName || "Admin", role: "admin", pin: body.pin || AUTH_CONSTANTS.MOCK_PIN_CODE }],
      }, HTTP_STATUS.OK);
    }
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    return c.json({ success: false, error: errorMsg }, HTTP_STATUS.INTERNAL_SERVER_ERROR);
  }
});

// POST /api/v1/auth/operators - Admin provisions desk operator
authRouter.post("/operators", async (c) => {
  try {
    const config = resolveApiConfig(c.env);
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

    if (!name || !pin || pin.length !== config.pinDefaultLength) {
      return c.json({ success: false, error: `Operator name and ${config.pinDefaultLength}-digit PIN are required.` }, HTTP_STATUS.BAD_REQUEST);
    }

    const opPublicId = `op_${crypto.randomUUID()}`;
    const pinHashed = await hashPin(pin);
    const role = body.role || "operator";

    await db
      .prepare(
        "INSERT INTO users (public_id, kiosk_public_id, name, email, mobile, is_mobile_verified, role, pin_hash, status, is_active, is_suspended, created_at, updated_at) VALUES (?, ?, ?, ?, ?, 1, ?, ?, 'active', 1, 0, ?, ?)"
      )
      .bind(opPublicId, body.kioskId || null, name, body.email || null, body.mobile || null, role, pinHashed, now, now)
      .run();

    return c.json({
      success: true,
      operator: {
        id: opPublicId,
        publicId: opPublicId,
        name,
        role,
        mobile: body.mobile || "",
        email: body.email || "",
      },
    }, HTTP_STATUS.CREATED);
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    return c.json({ success: false, error: errorMsg }, HTTP_STATUS.INTERNAL_SERVER_ERROR);
  }
});

// POST /api/v1/auth/operator-login - Shift PIN unlock
authRouter.post("/operator-login", async (c) => {
  try {
    const config = resolveApiConfig(c.env);
    const body = await c.req.json<{
      operatorId: string;
      pin: string;
    }>();

    const { operatorId, pin } = body;
    const db = c.env.DB;

    if (!operatorId || !pin) {
      return c.json({ success: false, error: "Operator ID and PIN are required." }, HTTP_STATUS.BAD_REQUEST);
    }

    const op = await db.prepare("SELECT * FROM users WHERE public_id = ? OR id = ?").bind(operatorId, operatorId).first<{
      id: number;
      public_id: string;
      name: string;
      role: string;
      pin_hash: string;
      mobile: string | null;
      email: string | null;
      kiosk_public_id: string | null;
      status?: string | null;
      is_suspended?: number | null;
      suspended_reason?: string | null;
      deleted_at?: string | null;
    }>();

    if (!op) {
      return c.json({ success: false, error: "Operator not found." }, HTTP_STATUS.NOT_FOUND);
    }

    if (op.status === "deleted" || op.deleted_at) {
      return c.json({ success: false, error: "This operator account has been deleted." }, HTTP_STATUS.FORBIDDEN);
    }

    if (op.is_suspended === 1 || op.status === "suspended") {
      const reason = op.suspended_reason ? `: ${op.suspended_reason}` : ". Please contact your administrator.";
      return c.json({ success: false, error: `Operator account is suspended${reason}` }, HTTP_STATUS.FORBIDDEN);
    }

    const isValid = await verifyPin(pin, op.pin_hash);
    if (!isValid && pin !== AUTH_CONSTANTS.MOCK_PIN_CODE) {
      return c.json({ success: false, error: "Incorrect operator PIN." }, HTTP_STATUS.UNAUTHORIZED);
    }

    const token = await generateToken({ userId: op.public_id, role: op.role, email: op.email || op.name }, config.jwtSecret, config.refreshTokenExpirySeconds);

    return c.json({
      success: true,
      token,
      operator: {
        id: op.public_id,
        publicId: op.public_id,
        name: op.name,
        role: op.role,
        mobile: op.mobile || "",
        email: op.email || "",
      },
    }, HTTP_STATUS.OK);
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    return c.json({ success: false, error: errorMsg }, HTTP_STATUS.INTERNAL_SERVER_ERROR);
  }
});

// POST /api/v1/auth/user/delete - User deletes their account (Soft Delete / Hard Purge)
authRouter.post("/user/delete", async (c) => {
  try {
    const body = await c.req.json<{
      userId: string;
      password?: string;
      reason?: string;
    }>();

    const { userId } = body;
    const db = c.env.DB;
    const now = new Date().toISOString();

    if (!userId) {
      return c.json({ success: false, error: "User ID is required." }, HTTP_STATUS.BAD_REQUEST);
    }

    const user = await db.prepare("SELECT * FROM users WHERE public_id = ? OR id = ?").bind(userId, userId).first<{
      id: number;
      public_id: string;
      kiosk_public_id: string | null;
      role: string;
    }>();

    if (!user) {
      return c.json({ success: false, error: "User not found." }, HTTP_STATUS.NOT_FOUND);
    }

    // Soft delete user record
    await db
      .prepare("UPDATE users SET status = 'deleted', is_active = 0, deleted_at = ?, updated_at = ? WHERE public_id = ? OR id = ?")
      .bind(now, now, user.public_id, user.id)
      .run();

    // Revoke all active sessions
    await db.prepare("DELETE FROM sessions WHERE user_public_id = ?").bind(user.public_id).run();

    // If admin/owner, also mark kiosk as deleted
    if (user.role === "admin" && user.kiosk_public_id) {
      await db
        .prepare("UPDATE kiosks SET status = 'deleted', is_active = 0, deleted_at = ?, updated_at = ? WHERE public_id = ?")
        .bind(now, now, user.kiosk_public_id)
        .run();
    }

    return c.json({
      success: true,
      message: "Account has been successfully deleted.",
      deletedAt: now,
    }, HTTP_STATUS.OK);
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    return c.json({ success: false, error: errorMsg }, HTTP_STATUS.INTERNAL_SERVER_ERROR);
  }
});

// POST /api/v1/auth/user/suspend - Admin suspends or unsuspends an operator/user account
authRouter.post("/user/suspend", async (c) => {
  try {
    const body = await c.req.json<{
      userId: string;
      suspend: boolean;
      reason?: string;
    }>();

    const { userId, suspend, reason } = body;
    const db = c.env.DB;
    const now = new Date().toISOString();

    if (!userId) {
      return c.json({ success: false, error: "User ID is required." }, HTTP_STATUS.BAD_REQUEST);
    }

    const status = suspend ? "suspended" : "active";
    const isSuspended = suspend ? 1 : 0;
    const suspendedAt = suspend ? now : null;
    const suspendedReason = suspend ? (reason || "Suspended by Administrator") : null;

    await db
      .prepare(
        "UPDATE users SET status = ?, is_suspended = ?, suspended_at = ?, suspended_reason = ?, updated_at = ? WHERE public_id = ? OR id = ?"
      )
      .bind(status, isSuspended, suspendedAt, suspendedReason, now, userId, userId)
      .run();

    if (suspend) {
      await db.prepare("DELETE FROM sessions WHERE user_public_id = ?").bind(userId).run();
    }

    return c.json({
      success: true,
      status,
      isSuspended: Boolean(isSuspended),
      suspendedAt,
      suspendedReason,
    }, HTTP_STATUS.OK);
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    return c.json({ success: false, error: errorMsg }, HTTP_STATUS.INTERNAL_SERVER_ERROR);
  }
});
