/**
 * Twilio SMS & OTP Verification Service
 * Supports standard Twilio REST API with automatic graceful fallback for local development.
 */

export interface TwilioConfig {
  accountSid?: string;
  authToken?: string;
  fromNumber?: string;
}

export class TwilioService {
  private accountSid?: string;
  private authToken?: string;
  private fromNumber?: string;

  constructor(config?: TwilioConfig) {
    this.accountSid = config?.accountSid;
    this.authToken = config?.authToken;
    this.fromNumber = config?.fromNumber;
  }

  /**
   * Formats a phone number to standard E.164 format (+91... for India default if 10 digits)
   */
  static formatToE164(phone: string): string {
    const cleaned = phone.replace(/[^\d+]/g, "");
    if (cleaned.startsWith("+")) {
      return cleaned;
    }
    if (cleaned.length === 10) {
      return `+91${cleaned}`;
    }
    return `+${cleaned}`;
  }

  /**
   * Generates a cryptographically random 6-digit numeric OTP
   */
  static generateOtp(length: number = 6): string {
    const array = new Uint32Array(1);
    crypto.getRandomValues(array);
    const num = array[0] % Math.pow(10, length);
    return num.toString().padStart(length, "0");
  }

  /**
   * Sends an SMS message via Twilio REST API
   */
  async sendSms(to: string, message: string): Promise<{ success: boolean; sid?: string; isMock?: boolean; error?: string }> {
    const formattedTo = TwilioService.formatToE164(to);

    // If Twilio credentials are not configured or are placeholder values, operate in graceful Mock Mode
    if (
      !this.accountSid ||
      !this.authToken ||
      !this.fromNumber ||
      this.accountSid.includes("placeholder") ||
      this.accountSid === "TWILIO_ACCOUNT_SID"
    ) {
      console.log(`[Twilio Dev Mock] SMS to ${formattedTo}: "${message}"`);
      return {
        success: true,
        sid: `mock_sm_${crypto.randomUUID()}`,
        isMock: true,
      };
    }

    try {
      const url = `https://api.twilio.com/2010-04-01/Accounts/${this.accountSid}/Messages.json`;
      const basicAuth = btoa(`${this.accountSid}:${this.authToken}`);

      const bodyParams = new URLSearchParams();
      bodyParams.append("To", formattedTo);
      bodyParams.append("From", this.fromNumber);
      bodyParams.append("Body", message);

      const response = await fetch(url, {
        method: "POST",
        headers: {
          Authorization: `Basic ${basicAuth}`,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: bodyParams.toString(),
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({ message: response.statusText })) as { message?: string; code?: number };
        console.error(`Twilio Error (${response.status}):`, errorData);
        return {
          success: false,
          error: errorData.message || `Twilio SMS delivery failed with status ${response.status}`,
        };
      }

      const data = await response.json() as { sid?: string };
      return {
        success: true,
        sid: data.sid,
        isMock: false,
      };
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      console.error("Twilio sendSms exception:", msg);
      return {
        success: false,
        error: msg,
      };
    }
  }

  /**
   * Sends an OTP verification SMS to a user's mobile number
   */
  async sendOtpSms(to: string, otp: string, appName: string = "Dossier"): Promise<{ success: boolean; sid?: string; isMock?: boolean; error?: string }> {
    const message = `Your ${appName} verification code is: ${otp}. Valid for 10 minutes. Do not share this code with anyone.`;
    return this.sendSms(to, message);
  }
}
