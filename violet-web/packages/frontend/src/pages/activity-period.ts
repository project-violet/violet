export function filterActivityPeriod<T extends { date: string }>(days: T[], period: number): T[] {
  if (!period || days.length === 0) return days;
  const latest = new Date(`${days[days.length - 1].date}T00:00:00Z`);
  latest.setUTCDate(latest.getUTCDate() - period + 1);
  const cutoff = latest.toISOString().slice(0, 10);
  return days.filter((day) => day.date >= cutoff);
}
