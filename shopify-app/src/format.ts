// Swedish-locale formatting helpers shared across the embedded app.

export function formatMoney(value: number, currency: string | null): string {
  const amount = (value ?? 0).toLocaleString('sv-SE', {
    minimumFractionDigits: 0,
    maximumFractionDigits: 2,
  })
  return currency ? `${amount} ${currency}` : amount
}

export function formatNumber(value: number): string {
  return (value ?? 0).toLocaleString('sv-SE')
}

export function formatDate(value: string | null): string {
  if (!value) return '-'
  const d = new Date(value)
  if (Number.isNaN(d.getTime())) return '-'
  return d.toLocaleDateString('sv-SE')
}
