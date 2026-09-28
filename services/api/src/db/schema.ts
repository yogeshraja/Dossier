/**
 * Dossier Database Schema (Drizzle ORM for Cloudflare D1 SQLite)
 * Implements the Dual-ID Pattern:
 * - `id`: INTEGER PRIMARY KEY AUTOINCREMENT (Fast internal joins, B-Tree efficiency, easy SQL queries)
 * - `public_id`: TEXT UNIQUE NOT NULL (Opaque, tamper-proof, public API & sync identifier)
 */

import { sqliteTable, integer, text, real, index, uniqueIndex } from "drizzle-orm/sqlite-core";

// ─────────────────────────────────────────────────────────────
// Kiosks (Tenant Workstations)
// ─────────────────────────────────────────────────────────────
export const kiosks = sqliteTable(
  "kiosks",
  {
    id: integer("id").primaryKey({ autoIncrement: true }),
    publicId: text("public_id").notNull().unique(),
    name: text("name").notNull(),
    ownerPublicId: text("owner_public_id").notNull(),
    address: text("address"),
    phone: text("phone"),
    upiVpa: text("upi_vpa"),
    licenseKey: text("license_key").unique(),
    status: text("status").notNull().default("active"), // 'active', 'suspended', 'deleted'
    isActive: integer("is_active").notNull().default(1),
    isSuspended: integer("is_suspended").notNull().default(0),
    suspendedAt: text("suspended_at"),
    suspendedReason: text("suspended_reason"),
    deletedAt: text("deleted_at"),
    createdAt: text("created_at").notNull(),
    updatedAt: text("updated_at").notNull(),
  },
  (table) => [
    index("idx_kiosks_public_id").on(table.publicId),
    index("idx_kiosks_owner").on(table.ownerPublicId),
    index("idx_kiosks_status").on(table.status),
  ]
);

// ─────────────────────────────────────────────────────────────
// Users (Admin Owners & Desk Operators)
// ─────────────────────────────────────────────────────────────
export const users = sqliteTable(
  "users",
  {
    id: integer("id").primaryKey({ autoIncrement: true }),
    publicId: text("public_id").notNull().unique(),
    kioskPublicId: text("kiosk_public_id"),
    name: text("name").notNull(),
    email: text("email"),
    mobile: text("mobile"),
    isMobileVerified: integer("is_mobile_verified").notNull().default(0),
    role: text("role").notNull().default("operator"), // 'admin', 'manager', 'operator'
    pinHash: text("pin_hash").notNull(),
    passwordHash: text("password_hash"),
    authProvider: text("auth_provider").default("local"), // 'email', 'mobile', 'google', 'local'
    googleId: text("google_id"),
    avatarUrl: text("avatar_url"),
    status: text("status").notNull().default("active"), // 'active', 'suspended', 'deleted'
    isActive: integer("is_active").notNull().default(1),
    isSuspended: integer("is_suspended").notNull().default(0),
    suspendedAt: text("suspended_at"),
    suspendedReason: text("suspended_reason"),
    deletedAt: text("deleted_at"),
    createdAt: text("created_at").notNull(),
    updatedAt: text("updated_at").notNull(),
  },
  (table) => [
    index("idx_users_public_id").on(table.publicId),
    index("idx_users_email").on(table.email),
    index("idx_users_mobile").on(table.mobile),
    index("idx_users_kiosk").on(table.kioskPublicId),
    index("idx_users_status").on(table.status),
  ]
);

// ─────────────────────────────────────────────────────────────
// OTP Verifications (Twilio Verify & SMS Tracking)
// ─────────────────────────────────────────────────────────────
export const otpVerifications = sqliteTable(
  "otp_verifications",
  {
    id: integer("id").primaryKey({ autoIncrement: true }),
    publicId: text("public_id").notNull().unique(),
    mobile: text("mobile").notNull(),
    otpHash: text("otp_hash").notNull(),
    expiresAt: text("expires_at").notNull(),
    attempts: integer("attempts").notNull().default(0),
    isVerified: integer("is_verified").notNull().default(0),
    createdAt: text("created_at").notNull(),
  },
  (table) => [
    index("idx_otp_mobile").on(table.mobile),
    index("idx_otp_expires").on(table.expiresAt),
  ]
);

// ─────────────────────────────────────────────────────────────
// Sessions (JWT & Active Device Logins)
// ─────────────────────────────────────────────────────────────
export const sessions = sqliteTable(
  "sessions",
  {
    id: integer("id").primaryKey({ autoIncrement: true }),
    publicId: text("public_id").notNull().unique(),
    userPublicId: text("user_public_id").notNull(),
    token: text("token").notNull().unique(),
    expiresAt: text("expires_at").notNull(),
    createdAt: text("created_at").notNull(),
  },
  (table) => [
    index("idx_sessions_token").on(table.token),
    index("idx_sessions_user").on(table.userPublicId),
  ]
);

// ─────────────────────────────────────────────────────────────
// Sync Items (Offline-First Outbox Queue)
// ─────────────────────────────────────────────────────────────
export const syncItems = sqliteTable(
  "sync_items",
  {
    id: integer("id").primaryKey({ autoIncrement: true }),
    publicId: text("public_id").notNull().unique(),
    userPublicId: text("user_public_id").notNull(),
    kioskPublicId: text("kiosk_public_id"),
    entityType: text("entity_type").notNull(), // 'customer', 'case', 'exhibit', 'transaction'
    entityId: text("entity_id").notNull(),
    action: text("action").notNull(),          // 'create', 'update', 'delete'
    payload: text("payload").notNull(),        // JSON stringified mutation
    clientTimestamp: text("client_timestamp").notNull(),
    serverTimestamp: text("server_timestamp").notNull(),
  },
  (table) => [
    index("idx_sync_user_time").on(table.userPublicId, table.serverTimestamp),
    index("idx_sync_kiosk_time").on(table.kioskPublicId, table.serverTimestamp),
  ]
);

// ─────────────────────────────────────────────────────────────
// Dossiers (Customer Identity Folders)
// ─────────────────────────────────────────────────────────────
export const dossiers = sqliteTable(
  "dossiers",
  {
    id: integer("id").primaryKey({ autoIncrement: true }),
    publicId: text("public_id").notNull().unique(),
    userPublicId: text("user_public_id").notNull(),
    kioskPublicId: text("kiosk_public_id"),
    fullName: text("full_name").notNull(),
    mobile: text("mobile"),
    aadhaarRef: text("aadhaar_ref"),
    panRef: text("pan_ref"),
    metadataJson: text("metadata_json"),
    createdAt: text("created_at").notNull(),
    updatedAt: text("updated_at").notNull(),
  },
  (table) => [
    index("idx_dossiers_user").on(table.userPublicId),
    index("idx_dossiers_mobile").on(table.mobile),
  ]
);

// ─────────────────────────────────────────────────────────────
// Cases (Citizen Intake Workflows)
// ─────────────────────────────────────────────────────────────
export const cases = sqliteTable(
  "cases",
  {
    id: integer("id").primaryKey({ autoIncrement: true }),
    publicId: text("public_id").notNull().unique(),
    dossierPublicId: text("dossier_public_id").notNull(),
    userPublicId: text("user_public_id").notNull(),
    kioskPublicId: text("kiosk_public_id"),
    title: text("title").notNull(),
    category: text("category").notNull(),
    status: text("status").notNull().default("intake"),
    totalAmount: real("total_amount").notNull().default(0.0),
    paidAmount: real("paid_amount").notNull().default(0.0),
    createdAt: text("created_at").notNull(),
    updatedAt: text("updated_at").notNull(),
  },
  (table) => [
    index("idx_cases_dossier").on(table.dossierPublicId),
    index("idx_cases_status").on(table.status),
  ]
);

// Type Inferences
export type Kiosk = typeof kiosks.$inferSelect;
export type InsertKiosk = typeof kiosks.$inferInsert;

export type User = typeof users.$inferSelect;
export type InsertUser = typeof users.$inferInsert;

export type OtpVerification = typeof otpVerifications.$inferSelect;
export type InsertOtpVerification = typeof otpVerifications.$inferInsert;

export type SyncItem = typeof syncItems.$inferSelect;
export type InsertSyncItem = typeof syncItems.$inferInsert;
