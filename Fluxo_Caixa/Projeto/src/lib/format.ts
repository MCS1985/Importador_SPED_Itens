export const BRL = new Intl.NumberFormat("pt-BR", {
  style: "currency",
  currency: "BRL",
});

export const BRLCompact = new Intl.NumberFormat("pt-BR", {
  style: "currency",
  currency: "BRL",
  notation: "compact",
  maximumFractionDigits: 1,
});

export function formatBRL(n: number) {
  return BRL.format(n);
}

export function formatBRLSigned(n: number) {
  const sign = n > 0 ? "+" : n < 0 ? "−" : "";
  return `${sign}${BRL.format(Math.abs(n))}`;
}

export const MES_CURTO = [
  "Jan", "Fev", "Mar", "Abr", "Mai", "Jun",
  "Jul", "Ago", "Set", "Out", "Nov", "Dez",
];

export const MES_LONGO = [
  "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
  "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro",
];

export function parseDate(d: string): Date {
  // YYYY-MM-DD assumed
  const [y, m, day] = d.split("-").map(Number);
  return new Date(y, (m ?? 1) - 1, day ?? 1);
}

export function ymKey(d: string) {
  return d.slice(0, 7); // YYYY-MM
}

export function formatDatePt(d: string) {
  const dt = parseDate(d);
  return dt.toLocaleDateString("pt-BR");
}
