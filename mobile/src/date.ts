export function isoDate(date: Date) {
  return date.toISOString().slice(0, 10);
}

export function daysAgo(days: number) {
  const date = new Date();
  date.setDate(date.getDate() - days);
  return isoDate(date);
}
