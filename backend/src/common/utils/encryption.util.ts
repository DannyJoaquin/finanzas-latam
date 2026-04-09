import { createCipheriv, createDecipheriv, randomBytes, scryptSync } from 'crypto';

const ALGORITHM = 'aes-256-cbc';

function getKey(): Buffer {
  const raw = process.env.ENCRYPTION_KEY ?? 'default-32-char-key-change-me!!';
  // Derive a 32-byte key from the env string
  return scryptSync(raw, 'finanzas-latam-salt', 32) as Buffer;
}

export function encrypt(plainText: string): string {
  const iv = randomBytes(16);
  const cipher = createCipheriv(ALGORITHM, getKey(), iv);
  const encrypted = Buffer.concat([cipher.update(plainText, 'utf8'), cipher.final()]);
  return `${iv.toString('hex')}:${encrypted.toString('hex')}`;
}

export function decrypt(cipherText: string): string {
  const [ivHex, encryptedHex] = cipherText.split(':');
  const iv = Buffer.from(ivHex, 'hex');
  const encrypted = Buffer.from(encryptedHex, 'hex');
  const decipher = createDecipheriv(ALGORITHM, getKey(), iv);
  const decrypted = Buffer.concat([decipher.update(encrypted), decipher.final()]);
  return decrypted.toString('utf8');
}
