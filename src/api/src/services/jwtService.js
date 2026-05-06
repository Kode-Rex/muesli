import jwt from 'jsonwebtoken';
import { randomUUID } from 'crypto';
import { config } from '../config/index.js';

const ISSUER = 'muesli-api';
const AUDIENCE = 'muesli-ios';

export function signAccessToken(userId) {
  return jwt.sign(
    { sub: userId, jti: randomUUID() },
    config.auth.jwtSecret,
    { algorithm: 'HS256', expiresIn: `${config.auth.accessTokenTtlMin}m`, issuer: ISSUER, audience: AUDIENCE }
  );
}

export function verifyAccessToken(token) {
  return jwt.verify(token, config.auth.jwtSecret, { algorithms: ['HS256'], issuer: ISSUER, audience: AUDIENCE, clockTolerance: 60 });
}
