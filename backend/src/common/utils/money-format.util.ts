/**
 * Formats a monetary amount with comma-separated thousands, for embedding in
 * user-facing notification/insight text (push body, in-app insight text).
 */
export function formatMoney(value: number, decimals = 0): string {
  return value.toLocaleString('en-US', {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  });
}
