/**
 * Admin "disable account" mirrored to Firebase Auth (Blaze only).
 *
 * The admin's app writes users/{uid}.disabled = true (+ disabledAt,
 * disabledBy, disabledReason) and removes those fields to enable the
 * account again. On the free Spark plan the app alone enforces it (live
 * sign-out, refused sign-in, rules checks on new bookings / reviews /
 * queue entries). With Cloud Functions, onUserDisabledChanged also
 * disables the Firebase Auth user and revokes its refresh tokens, so no
 * client can get a new ID token; enabling re-enables the Auth user.
 *
 * Pure logic, no Firebase (unit tested).
 */

export type AuthDisableAction = 'disable' | 'enable' | 'none';

/** The `disabled` flag of a users/{uid} document (absent / non-true = false). */
export function isDisabledDoc(doc: Record<string, unknown> | null | undefined): boolean {
  return doc != null && doc.disabled === true;
}

/**
 * What to do with the Auth user after a users/{uid} write from [before] to
 * [after] (null = no document). A deleted profile changes nothing here.
 */
export function authDisableAction(
  before: Record<string, unknown> | null | undefined,
  after: Record<string, unknown> | null | undefined,
): AuthDisableAction {
  if (after == null) return 'none';
  const was = isDisabledDoc(before);
  const now = isDisabledDoc(after);
  if (now && !was) return 'disable';
  if (!now && was) return 'enable';
  return 'none';
}

/** The Auth calls the trigger makes (injected, so tests need no Firebase). */
export interface AuthAccounts {
  setDisabled(uid: string, disabled: boolean): Promise<void>;
  revokeRefreshTokens(uid: string): Promise<void>;
}

/** Firebase Auth error code of a user that does not exist (any more). */
const USER_NOT_FOUND = 'auth/user-not-found';

function errorCode(e: unknown): string | undefined {
  return typeof e === 'object' && e !== null && 'code' in e ? String((e as { code: unknown }).code) : undefined;
}

/**
 * Applies [action] to [uid]. A missing Auth user (deleted login) is not an
 * error. Returns what was done.
 */
export async function mirrorDisabledToAuth(uid: string, action: AuthDisableAction, auth: AuthAccounts): Promise<AuthDisableAction> {
  if (action === 'none') return 'none';
  try {
    await auth.setDisabled(uid, action === 'disable');
    if (action === 'disable') await auth.revokeRefreshTokens(uid);
    return action;
  } catch (e) {
    if (errorCode(e) === USER_NOT_FOUND) return 'none';
    throw e;
  }
}
