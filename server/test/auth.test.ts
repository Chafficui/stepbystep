import { describe, expect, it } from 'vitest';
import { signOrgaToken, verifyOrgaToken } from '../src/auth.js';

const SECRET = 'u'.repeat(40);

describe('orga session token', () => {
  it('sign/verify round-trip', () => {
    const token = signOrgaToken(SECRET, 1_000_000);
    const payload = verifyOrgaToken(token, SECRET, 1_000_000);
    expect(payload).toEqual({ role: 'orga', exp: 1_000_000 + 24 * 3600 });
  });

  it('expired token is invalid', () => {
    const token = signOrgaToken(SECRET, 1_000_000);
    expect(verifyOrgaToken(token, SECRET, 1_000_000 + 24 * 3600 + 1)).toBeNull();
  });

  it('wrong secret or tampered payload is invalid', () => {
    const token = signOrgaToken(SECRET, 1_000_000);
    expect(verifyOrgaToken(token, 'v'.repeat(40), 1_000_001)).toBeNull();
    const [body, sig] = token.split('.');
    const forged = Buffer.from(JSON.stringify({ role: 'orga', exp: 9_999_999_999 })).toString('base64url');
    expect(verifyOrgaToken(`${forged}.${sig}`, SECRET, 1_000_001)).toBeNull();
    expect(verifyOrgaToken(`${body}.AAAA${sig.slice(4)}`, SECRET, 1_000_001)).toBeNull();
  });
});
