/**
 * Centralized API Configuration & Environment Resolver
 * Monorepo: Dossier Cloudflare Edge Serverless API
 */

import { AUTH_CONSTANTS, SYNC_CONSTANTS } from "./constants";

export interface EnvBindings {
  DB: D1Database;
  JWT_SECRET?: string;
  TWILIO_ACCOUNT_SID?: string;
  TWILIO_AUTH_TOKEN?: string;
  TWILIO_VERIFY_SERVICE_SID?: string;
  TWILIO_SERVICE_SID?: string;
  TWILIO_PHONE_NUMBER?: string;
  PORT?: string;
  OTP_EXPIRY_SECONDS?: string;
  ACCESS_TOKEN_EXPIRY_SECONDS?: string;
}

export interface ApiConfig {
  jwtSecret: string;
  accessTokenExpirySeconds: number;
  refreshTokenExpirySeconds: number;
  otpExpirySeconds: number;
  otpDefaultLength: number;
  pinDefaultLength: number;
  minMobileDigits: number;
  syncPageSize: number;
  syncBatchSize: number;
}

export function resolveApiConfig(env: Partial<EnvBindings>): ApiConfig {
  return {
    jwtSecret: env.JWT_SECRET || "dossier-default-jwt-secret-do-not-use-in-production",
    accessTokenExpirySeconds: env.ACCESS_TOKEN_EXPIRY_SECONDS
      ? parseInt(env.ACCESS_TOKEN_EXPIRY_SECONDS, 10)
      : AUTH_CONSTANTS.ACCESS_TOKEN_EXPIRY_SECONDS,
    refreshTokenExpirySeconds: AUTH_CONSTANTS.REFRESH_TOKEN_EXPIRY_SECONDS,
    otpExpirySeconds: env.OTP_EXPIRY_SECONDS
      ? parseInt(env.OTP_EXPIRY_SECONDS, 10)
      : AUTH_CONSTANTS.OTP_EXPIRY_SECONDS,
    otpDefaultLength: AUTH_CONSTANTS.OTP_DEFAULT_LENGTH,
    pinDefaultLength: AUTH_CONSTANTS.PIN_DEFAULT_LENGTH,
    minMobileDigits: AUTH_CONSTANTS.MIN_MOBILE_DIGITS,
    syncPageSize: SYNC_CONSTANTS.DEFAULT_PAGE_SIZE,
    syncBatchSize: SYNC_CONSTANTS.MAX_SYNC_BATCH_SIZE,
  };
}
