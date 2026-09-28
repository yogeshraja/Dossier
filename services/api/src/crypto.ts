/**
 * WebCrypto helpers for Cloudflare Workers
 * Monorepo: Dossier Cloudflare Edge Serverless API
 * Uses native SubtleCrypto for fast, secure cryptographic hashing and JWTs.
 */

import { AUTH_CONSTANTS } from "./constants";

export const CRYPTO_CONSTANTS = {
  DEFAULT_PBKDF2_SALT: "dossier-pin-salt-2026",
  DEFAULT_PBKDF2_ITERATIONS: 10000,
  DEFAULT_KEY_LENGTH_BITS: 256,
  DEFAULT_JWT_SECRET: "dossier-jwt-kiosk-secret-2026",
  HASH_ALGORITHM: "SHA-256",
  HMAC_ALGORITHM: "HMAC",
  PBKDF2_ALGORITHM: "PBKDF2",
  JWT_HEADER: { alg: "HS256", typ: "JWT" },
} as const;

export async function hashPin(
  pin: string,
  salt: string = CRYPTO_CONSTANTS.DEFAULT_PBKDF2_SALT
): Promise<string> {
  const enc = new TextEncoder();
  const keyMaterial = await crypto.subtle.importKey(
    "raw",
    enc.encode(pin + salt),
    { name: CRYPTO_CONSTANTS.PBKDF2_ALGORITHM },
    false,
    ["deriveBits", "deriveKey"]
  );

  const derivedKey = await crypto.subtle.deriveBits(
    {
      name: CRYPTO_CONSTANTS.PBKDF2_ALGORITHM,
      salt: enc.encode(salt),
      iterations: CRYPTO_CONSTANTS.DEFAULT_PBKDF2_ITERATIONS,
      hash: CRYPTO_CONSTANTS.HASH_ALGORITHM,
    },
    keyMaterial,
    CRYPTO_CONSTANTS.DEFAULT_KEY_LENGTH_BITS
  );

  return bufferToHex(derivedKey);
}

export async function verifyPin(pin: string, hash: string, salt?: string): Promise<boolean> {
  const computed = await hashPin(pin, salt);
  return computed === hash;
}

export async function generateToken(
  payload: { userId: string; role: string; email?: string },
  customSecret?: string,
  expirySeconds: number = AUTH_CONSTANTS.REFRESH_TOKEN_EXPIRY_SECONDS
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const exp = now + expirySeconds;
  const fullPayload = { ...payload, exp, iat: now };

  const encodedHeader = base64UrlEncode(JSON.stringify(CRYPTO_CONSTANTS.JWT_HEADER));
  const encodedPayload = base64UrlEncode(JSON.stringify(fullPayload));
  const dataToSign = `${encodedHeader}.${encodedPayload}`;

  const secret = customSecret || CRYPTO_CONSTANTS.DEFAULT_JWT_SECRET;
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: CRYPTO_CONSTANTS.HMAC_ALGORITHM, hash: CRYPTO_CONSTANTS.HASH_ALGORITHM },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(CRYPTO_CONSTANTS.HMAC_ALGORITHM, key, enc.encode(dataToSign));
  const encodedSignature = base64UrlEncodeBytes(new Uint8Array(signature));

  return `${dataToSign}.${encodedSignature}`;
}

export async function verifyToken(
  token: string,
  customSecret?: string
): Promise<{ userId: string; role: string; email?: string } | null> {
  try {
    const parts = token.split(".");
    if (parts.length !== 3) return null;

    const [header, payload, signature] = parts;
    const dataToSign = `${header}.${payload}`;

    const secret = customSecret || CRYPTO_CONSTANTS.DEFAULT_JWT_SECRET;
    const enc = new TextEncoder();
    const key = await crypto.subtle.importKey(
      "raw",
      enc.encode(secret),
      { name: CRYPTO_CONSTANTS.HMAC_ALGORITHM, hash: CRYPTO_CONSTANTS.HASH_ALGORITHM },
      false,
      ["verify"]
    );

    const sigBytes = base64UrlDecodeBytes(signature);
    const valid = await crypto.subtle.verify(CRYPTO_CONSTANTS.HMAC_ALGORITHM, key, sigBytes, enc.encode(dataToSign));
    if (!valid) return null;

    const decodedPayload = JSON.parse(new TextDecoder().decode(base64UrlDecodeBytes(payload)));
    if (decodedPayload.exp && decodedPayload.exp < Math.floor(Date.now() / 1000)) {
      return null; // Expired
    }

    return decodedPayload;
  } catch {
    return null;
  }
}

function bufferToHex(buffer: ArrayBuffer): string {
  return Array.from(new Uint8Array(buffer))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function base64UrlEncode(str: string): string {
  return base64UrlEncodeBytes(new TextEncoder().encode(str));
}

function base64UrlEncodeBytes(bytes: Uint8Array): string {
  let binary = "";
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function base64UrlDecodeBytes(str: string): Uint8Array {
  let base64 = str.replace(/-/g, "+").replace(/_/g, "/");
  while (base64.length % 4) {
    base64 += "=";
  }
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}
