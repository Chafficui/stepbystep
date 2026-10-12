import { describe, expect, it } from 'vitest';
import { haversineKm } from '../src/geo.js';

function expectCloseTo(actual: number, expected: number, tolerancePct = 0.5): void {
  expect(Math.abs(actual - expected)).toBeLessThanOrEqual((expected * tolerancePct) / 100);
}

describe('haversineKm', () => {
  it('Berlin -> Paris is about 877.5 km', () => {
    expectCloseTo(haversineKm(52.52, 13.405, 48.8566, 2.3522), 877.5);
  });

  it('equator half circumference (0,0 -> 0,180) is about 20015.44 km', () => {
    expectCloseTo(haversineKm(0, 0, 0, 180), 20015.44);
  });

  it('equator to pole (0,0 -> 90,0) is about 10007.54 km', () => {
    expectCloseTo(haversineKm(0, 0, 90, 0), 10007.54);
  });

  it('same point is 0 km', () => {
    expect(haversineKm(52.52, 13.405, 52.52, 13.405)).toBe(0);
  });

  it('Frankfurt -> London is about 638 km (haversine, R=6371)', () => {
    expectCloseTo(haversineKm(50.1109, 8.6821, 51.5074, -0.1278), 637.77);
  });

  it('Munich -> Hamburg is about 612 km', () => {
    expectCloseTo(haversineKm(48.1372, 11.5756, 53.5511, 9.9937), 612);
  });

  it('is symmetric', () => {
    const a = haversineKm(48.8566, 2.3522, 52.52, 13.405);
    const b = haversineKm(52.52, 13.405, 48.8566, 2.3522);
    expect(a).toBeCloseTo(b, 9);
  });
});