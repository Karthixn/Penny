export function splitEqual(totalPaise: number, userIds: string[]): { userId: string; amount: number }[] {
  const n = userIds.length;
  const base = Math.floor(totalPaise / n);
  let remainder = totalPaise - base * n;

  return userIds.map((userId) => {
    const extra = remainder > 0 ? 1 : 0;
    remainder--;
    return { userId, amount: base + extra };
  });
}

export function splitPercentage(
  totalPaise: number,
  shares: { userId: string; percentage: number }[],
): { userId: string; amount: number }[] {
  const raw = shares.map((s) => ({
    userId: s.userId,
    exact: (totalPaise * s.percentage) / 100,
  }));

  const floored = raw.map((r) => ({
    userId: r.userId,
    amount: Math.floor(r.exact),
    remainder: r.exact - Math.floor(r.exact),
  }));

  let leftover = totalPaise - floored.reduce((sum, f) => sum + f.amount, 0);

  floored.sort((a, b) => b.remainder - a.remainder);
  for (const f of floored) {
    if (leftover <= 0) break;
    f.amount++;
    leftover--;
  }

  return floored.map(({ userId, amount }) => ({ userId, amount }));
}

export function splitExact(shares: { userId: string; amount: number }[]): { userId: string; amount: number }[] {
  return shares.map(({ userId, amount }) => ({ userId, amount }));
}

export function splitItems(
  items: { amount: number; assigneeIds: string[] }[],
): { userId: string; amount: number }[] {
  const totals: Record<string, number> = {};

  for (const item of items) {
    const perPerson = splitEqual(item.amount, item.assigneeIds);
    for (const p of perPerson) {
      totals[p.userId] = (totals[p.userId] ?? 0) + p.amount;
    }
  }

  return Object.entries(totals).map(([userId, amount]) => ({ userId, amount }));
}
