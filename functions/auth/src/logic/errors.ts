/**
 * Errors returned to the app. Each has a stable `code` (sent as
 * HttpsError details.code) and the HttpsError status it maps to.
 * Kept free of firebase-functions so the logic is unit-testable.
 */
export const ERROR_STATUS = {
  'invalid-input': 'invalid-argument',
  'invalid-email': 'invalid-argument',
  'email-already-registered': 'already-exists',
  'too-soon': 'resource-exhausted',
  'rate-limited': 'resource-exhausted',
  'invalid-code': 'invalid-argument',
  'code-expired': 'deadline-exceeded',
  'weak-password': 'invalid-argument',
  'email-not-configured': 'failed-precondition',
  'email-send-failed': 'unavailable',
} as const;

export type FlowErrorCode = keyof typeof ERROR_STATUS;

const MESSAGES: Record<FlowErrorCode, string> = {
  'invalid-input': 'The request is missing a field or has a field of the wrong type.',
  'invalid-email': 'Enter a valid email address.',
  'email-already-registered': 'An account with this email already exists. Sign in instead.',
  'too-soon': 'Please wait before asking for another code.',
  'rate-limited': 'Too many codes were requested. Try again later.',
  'invalid-code': 'That code is not correct.',
  'code-expired': 'This code has expired. Ask for a new one.',
  'weak-password': 'Use 8 to 128 characters with at least one letter and one number.',
  'email-not-configured': 'Email sending is not set up yet.',
  'email-send-failed': 'The email could not be sent. Try again in a moment.',
};

export class FlowError extends Error {
  constructor(
    readonly code: FlowErrorCode,
    readonly details: Record<string, unknown> = {},
  ) {
    super(MESSAGES[code]);
    this.name = 'FlowError';
  }

  get status(): (typeof ERROR_STATUS)[FlowErrorCode] {
    return ERROR_STATUS[this.code];
  }
}
