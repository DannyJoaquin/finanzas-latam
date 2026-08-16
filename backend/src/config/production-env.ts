export const isProduction = process.env.NODE_ENV === 'production';

export function requiredSecret(name: string, developmentFallback: string): string {
  const value = process.env[name] ?? (isProduction ? '' : developmentFallback);

  if (!value) {
    throw new Error(`${name} must be configured`);
  }

  if (isProduction && value.length < 32) {
    throw new Error(`${name} must contain at least 32 characters in production`);
  }

  return value;
}

export function requiredProductionValue(
  name: string,
  developmentFallback = '',
): string {
  const value = process.env[name] ?? (isProduction ? '' : developmentFallback);
  if (!value) throw new Error(`${name} must be configured`);
  return value;
}
