/**
 * Centralized API Constants & HTTP Enumerations
 * Monorepo: Dossier Cloudflare Edge Serverless API
 */

export const HTTP_STATUS = {
  OK: 200,
  CREATED: 201,
  ACCEPTED: 202,
  NO_CONTENT: 204,
  BAD_REQUEST: 400,
  UNAUTHORIZED: 401,
  FORBIDDEN: 403,
  NOT_FOUND: 404,
  CONFLICT: 409,
  UNPROCESSABLE_ENTITY: 422,
  TOO_MANY_REQUESTS: 429,
  INTERNAL_SERVER_ERROR: 500,
  SERVICE_UNAVAILABLE: 503,
} as const;

export const AUTH_CONSTANTS = {
  APP_NAME: "Dossier Cloudflare Edge",
  APP_VERSION: "1.3.0",
  DEFAULT_SALT_ROUNDS: 10,
  ACCESS_TOKEN_EXPIRY_SECONDS: 15 * 60, // 15 minutes
  REFRESH_TOKEN_EXPIRY_SECONDS: 30 * 24 * 60 * 60, // 30 days
  SESSION_EXPIRY_DAYS: 30,
  OTP_EXPIRY_SECONDS: 10 * 60, // 10 minutes (600 seconds)
  OTP_DEFAULT_LENGTH: 6,
  PIN_DEFAULT_LENGTH: 4,
  MIN_MOBILE_DIGITS: 10,
  MOCK_OTP_CODE: "123456",
  MOCK_PIN_CODE: "1234",
  DEFAULT_COUNTRY_DIAL_CODE: "+91",
} as const;

export const TWILIO_CONSTANTS = {
  VERIFY_API_BASE_URL: "https://verify.twilio.com/v2/Services",
  MESSAGES_API_BASE_URL: "https://api.twilio.com/2010-04-01/Accounts",
  DEFAULT_CHANNEL: "sms",
  AUTH_ENGINE_VERIFY_V2: "Twilio Verify v2",
  AUTH_ENGINE_FALLBACK: "Twilio SMS / Dev Mock",
} as const;

export const SYNC_CONSTANTS = {
  DEFAULT_PAGE_SIZE: 50,
  MAX_SYNC_BATCH_SIZE: 100,
  MAX_PAYLOAD_SIZE_BYTES: 10 * 1024 * 1024, // 10MB
} as const;
