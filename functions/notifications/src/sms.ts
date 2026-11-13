/**
 * SMS provider abstraction. The AfroMessage implementation talks to
 * https://api.afromessage.com/api/send with a bearer token. Without a token
 * we only log, so local emulators and fresh projects never send real SMS.
 */

import { logger } from 'firebase-functions/v2';

export interface SmsResult {
  ok: boolean;
  /** Provider message id when available. */
  providerId?: string;
  /** True when nothing was sent because the provider is not configured. */
  skipped?: boolean;
  error?: string;
}

export interface SmsProvider {
  readonly name: string;
  send(to: string, message: string): Promise<SmsResult>;
}

/** Logs the message instead of sending it. */
export class LogOnlySmsProvider implements SmsProvider {
  readonly name = 'log';
  constructor(private readonly reason = 'SMS provider not configured') {}

  async send(to: string, message: string): Promise<SmsResult> {
    logger.info(`[sms:${this.reason}] would send to ${maskPhone(to)}`, { length: message.length, message });
    return { ok: true, skipped: true };
  }
}

export interface AfroMessageConfig {
  token: string;
  identifierId?: string;
  sender?: string;
  endpoint?: string;
  /** Injected in tests. */
  fetchImpl?: typeof fetch;
}

/**
 * AfroMessage "send" API. POST JSON {from, sender, to, message}; the response
 * is {acknowledge: 'success' | 'error', response: {...}}.
 */
export class AfroMessageSmsProvider implements SmsProvider {
  readonly name = 'afromessage';
  private readonly endpoint: string;
  private readonly fetchImpl: typeof fetch;

  constructor(private readonly config: AfroMessageConfig) {
    this.endpoint = config.endpoint ?? 'https://api.afromessage.com/api/send';
    this.fetchImpl = config.fetchImpl ?? fetch;
  }

  async send(to: string, message: string): Promise<SmsResult> {
    const payload: Record<string, string> = { to, message };
    if (this.config.identifierId) payload.from = this.config.identifierId;
    if (this.config.sender) payload.sender = this.config.sender;

    try {
      const res = await this.fetchImpl(this.endpoint, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${this.config.token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
      });
      const text = await res.text();
      let json: { acknowledge?: string; response?: Record<string, unknown> } = {};
      try {
        json = JSON.parse(text);
      } catch {
        // non-JSON error page
      }
      if (!res.ok || json.acknowledge !== 'success') {
        const detail = json.response ? JSON.stringify(json.response) : text.slice(0, 300);
        return { ok: false, error: `HTTP ${res.status}: ${detail}` };
      }
      const id = json.response?.message_id ?? json.response?.messageId;
      return { ok: true, providerId: id === undefined ? undefined : String(id) };
    } catch (err) {
      return { ok: false, error: err instanceof Error ? err.message : String(err) };
    }
  }
}

/** Picks AfroMessage when a token is configured, otherwise logs only. */
export function createSmsProvider(config: { token?: string; identifierId?: string; sender?: string }): SmsProvider {
  const token = config.token?.trim();
  if (!token) return new LogOnlySmsProvider();
  return new AfroMessageSmsProvider({
    token,
    identifierId: config.identifierId?.trim() || undefined,
    sender: config.sender?.trim() || undefined,
  });
}

/** +251911234567 -> +2519*****567 for logs. */
export function maskPhone(phone: string): string {
  if (phone.length < 8) return '***';
  return `${phone.slice(0, 5)}${'*'.repeat(phone.length - 8)}${phone.slice(-3)}`;
}
