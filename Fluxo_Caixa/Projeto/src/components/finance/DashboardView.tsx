import { useMemo } from "react";
import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { ArrowDownRight, ArrowUpRight, Wallet, TrendingUp, PieChart as PieIcon } from "lucide-react";
import { useFinance, GRUPO_LABELS, GRUPO_COLORS } from "@/lib/finance-store";
import { BRL, BRLCompact, MES_CURTO, ymKey } from "@/lib/format";
import { cn } from "@/lib/utils";

type Props = { year: number };

export function DashboardView({ year }: Props) {
  const { transactions } = useFinance();

  const yearTx = useMemo(
    () => transactions.filter((t) => t.data.startsWith(String(year))),
    [transactions, year]
  );

  const totalReceitas = yearTx.filter((t) => t.valor > 0).reduce((s, t) => s + t.valor, 0);
  const totalDespesas = yearTx.filter((t) => t.valor < 0).reduce((s, t) => s + t.valor, 0);
  const saldo = totalReceitas + totalDespesas;
  const taxa = totalReceitas > 0 ? (saldo / totalReceitas) * 100 : 0;

  const monthly = useMemo(() => {
    const map = new Map<string, { mes: string; receitas: number; despesas: number; saldo: number }>();
    for (let m = 0; m < 12; m++) {
      const k = `${year}-${String(m + 1).padStart(2, "0")}`;
      map.set(k, { mes: MES_CURTO[m], receitas: 0, despesas: 0, saldo: 0 });
    }
    for (const t of yearTx) {
      const row = map.get(ymKey(t.data));
      if (!row) continue;
      if (t.valor >= 0) row.receitas += t.valor;
      else row.despesas += -t.valor;
    }
    let acc = 0;
    return [...map.values()].map((r) => {
      acc += r.receitas - r.despesas;
      return { ...r, saldo: acc };
    });
  }, [yearTx, year]);

  const byGrupo = useMemo(() => {
    const map = new Map<string, number>();
    for (const t of yearTx.filter((x) => x.valor < 0)) {
      const grp = t.natureza.replace(/\d+$/, "");
      map.set(grp, (map.get(grp) ?? 0) + -t.valor);
    }
    return [...map.entries()]
      .map(([grupo, valor]) => ({ grupo, nome: GRUPO_LABELS[grupo] ?? grupo, valor }))
      .sort((a, b) => b.valor - a.valor);
  }, [yearTx]);

  const topNaturezas = useMemo(() => {
    const map = new Map<string, { cr: string; valor: number; count: number }>();
    for (const t of yearTx.filter((x) => x.valor < 0)) {
      const key = t.cr || t.natureza;
      const cur = map.get(key) ?? { cr: key, valor: 0, count: 0 };
      cur.valor += -t.valor;
      cur.count += 1;
      map.set(key, cur);
    }
    return [...map.values()].sort((a, b) => b.valor - a.valor).slice(0, 6);
  }, [yearTx]);

  return (
    <div className="space-y-6">
      {/* KPI cards */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <KpiCard
          label="Saldo do ano"
          value={BRL.format(saldo)}
          hint={`${taxa.toFixed(1)}% das receitas`}
          icon={<Wallet className="size-5" />}
          tone={saldo >= 0 ? "mint" : "danger"}
          highlighted
        />
        <KpiCard
          label="Receitas"
          value={BRL.format(totalReceitas)}
          hint={`${yearTx.filter((t) => t.valor > 0).length} entradas`}
          icon={<ArrowUpRight className="size-5" />}
          tone="mint"
        />
        <KpiCard
          label="Despesas"
          value={BRL.format(Math.abs(totalDespesas))}
          hint={`${yearTx.filter((t) => t.valor < 0).length} saídas`}
          icon={<ArrowDownRight className="size-5" />}
          tone="danger"
        />
        <KpiCard
          label="Lançamentos"
          value={String(yearTx.length)}
          hint={`Em ${year}`}
          icon={<TrendingUp className="size-5" />}
          tone="violet"
        />
      </div>

      {/* Charts row */}
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <div className="glass-card relative overflow-hidden p-5 lg:col-span-2">
          <div className="mb-4 flex items-center justify-between">
            <div>
              <h3 className="font-display text-base font-semibold">Fluxo mensal</h3>
              <p className="text-xs text-muted-foreground">Receitas, despesas e saldo acumulado</p>
            </div>
            <Legend />
          </div>
          <div className="h-72 w-full">
            <ResponsiveContainer>
              <AreaChart data={monthly} margin={{ top: 10, right: 10, bottom: 0, left: -20 }}>
                <defs>
                  <linearGradient id="gMint" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="oklch(0.82 0.17 165)" stopOpacity={0.5} />
                    <stop offset="100%" stopColor="oklch(0.82 0.17 165)" stopOpacity={0} />
                  </linearGradient>
                  <linearGradient id="gRed" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="oklch(0.65 0.22 22)" stopOpacity={0.4} />
                    <stop offset="100%" stopColor="oklch(0.65 0.22 22)" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="oklch(0.27 0.014 270 / .5)" />
                <XAxis dataKey="mes" tick={{ fill: "oklch(0.65 0.015 270)", fontSize: 11 }} axisLine={false} tickLine={false} />
                <YAxis
                  tick={{ fill: "oklch(0.65 0.015 270)", fontSize: 11 }}
                  axisLine={false}
                  tickLine={false}
                  tickFormatter={(v) => BRLCompact.format(v)}
                />
                <Tooltip content={<ChartTooltip />} />
                <Area
                  type="monotone"
                  dataKey="receitas"
                  stroke="oklch(0.82 0.17 165)"
                  strokeWidth={2}
                  fill="url(#gMint)"
                />
                <Area
                  type="monotone"
                  dataKey="despesas"
                  stroke="oklch(0.65 0.22 22)"
                  strokeWidth={2}
                  fill="url(#gRed)"
                />
                <Area
                  type="monotone"
                  dataKey="saldo"
                  stroke="oklch(0.65 0.21 295)"
                  strokeWidth={2}
                  strokeDasharray="4 4"
                  fill="none"
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>

        <div className="glass-card p-5">
          <div className="mb-4 flex items-center justify-between">
            <div>
              <h3 className="font-display text-base font-semibold">Despesas por grupo</h3>
              <p className="text-xs text-muted-foreground">Distribuição no ano</p>
            </div>
            <PieIcon className="size-4 text-muted-foreground" />
          </div>
          {byGrupo.length === 0 ? (
            <EmptyChart />
          ) : (
            <>
              <div className="h-44 w-full">
                <ResponsiveContainer>
                  <PieChart>
                    <Pie
                      data={byGrupo}
                      dataKey="valor"
                      nameKey="nome"
                      innerRadius={48}
                      outerRadius={72}
                      paddingAngle={2}
                      stroke="oklch(0.16 0.014 270)"
                    >
                      {byGrupo.map((entry) => (
                        <Cell key={entry.grupo} fill={GRUPO_COLORS[entry.grupo] ?? "var(--chart-3)"} />
                      ))}
                    </Pie>
                    <Tooltip content={<ChartTooltip />} />
                  </PieChart>
                </ResponsiveContainer>
              </div>
              <div className="space-y-2">
                {byGrupo.slice(0, 5).map((g) => {
                  const total = byGrupo.reduce((s, x) => s + x.valor, 0);
                  const pct = total > 0 ? (g.valor / total) * 100 : 0;
                  return (
                    <div key={g.grupo} className="flex items-center justify-between text-sm">
                      <div className="flex items-center gap-2">
                        <span
                          className="size-2.5 rounded-full"
                          style={{ background: GRUPO_COLORS[g.grupo] ?? "var(--chart-3)" }}
                        />
                        <span className="text-muted-foreground">{g.nome}</span>
                      </div>
                      <span className="num font-medium">{pct.toFixed(1)}%</span>
                    </div>
                  );
                })}
              </div>
            </>
          )}
        </div>
      </div>

      {/* Top centros de resultado + barras */}
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <div className="glass-card p-5 lg:col-span-2">
          <div className="mb-4">
            <h3 className="font-display text-base font-semibold">Comparativo mensal</h3>
            <p className="text-xs text-muted-foreground">Receitas vs. despesas por mês</p>
          </div>
          <div className="h-64 w-full">
            <ResponsiveContainer>
              <BarChart data={monthly} margin={{ top: 10, right: 10, bottom: 0, left: -20 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="oklch(0.27 0.014 270 / .5)" />
                <XAxis dataKey="mes" tick={{ fill: "oklch(0.65 0.015 270)", fontSize: 11 }} axisLine={false} tickLine={false} />
                <YAxis
                  tick={{ fill: "oklch(0.65 0.015 270)", fontSize: 11 }}
                  axisLine={false}
                  tickLine={false}
                  tickFormatter={(v) => BRLCompact.format(v)}
                />
                <Tooltip content={<ChartTooltip />} cursor={{ fill: "oklch(1 0 0 / 0.04)" }} />
                <Bar dataKey="receitas" fill="oklch(0.82 0.17 165)" radius={[6, 6, 0, 0]} />
                <Bar dataKey="despesas" fill="oklch(0.65 0.22 22)" radius={[6, 6, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>

        <div className="glass-card p-5">
          <h3 className="font-display text-base font-semibold">Top centros de resultado</h3>
          <p className="text-xs text-muted-foreground">Maiores saídas do ano</p>
          <ul className="mt-4 space-y-3">
            {topNaturezas.length === 0 && <li className="text-sm text-muted-foreground">Sem dados ainda.</li>}
            {topNaturezas.map((n, i) => {
              const max = topNaturezas[0]?.valor || 1;
              const w = (n.valor / max) * 100;
              return (
                <li key={n.cr}>
                  <div className="flex items-center justify-between text-sm">
                    <span className="line-clamp-1 max-w-[16rem]">
                      <span className="mr-2 text-muted-foreground">#{i + 1}</span>
                      {n.cr}
                    </span>
                    <span className="num font-semibold">{BRLCompact.format(n.valor)}</span>
                  </div>
                  <div className="mt-1.5 h-1.5 w-full overflow-hidden rounded-full bg-muted/60">
                    <div
                      className="h-full gradient-mint"
                      style={{ width: `${w}%`, opacity: 0.6 + 0.4 * (1 - i / topNaturezas.length) }}
                    />
                  </div>
                </li>
              );
            })}
          </ul>
        </div>
      </div>
    </div>
  );
}

function KpiCard({
  label,
  value,
  hint,
  icon,
  tone,
  highlighted,
}: {
  label: string;
  value: string;
  hint: string;
  icon: React.ReactNode;
  tone: "mint" | "danger" | "violet";
  highlighted?: boolean;
}) {
  return (
    <div
      className={cn(
        "glass-card relative overflow-hidden p-5",
        highlighted && "ring-1 ring-primary/30"
      )}
    >
      <div
        className="pointer-events-none absolute inset-0 opacity-60"
        style={{
          background:
            tone === "mint"
              ? "radial-gradient(60% 60% at 80% 0%, oklch(0.82 0.17 165 / .18), transparent 70%)"
              : tone === "violet"
                ? "radial-gradient(60% 60% at 80% 0%, oklch(0.65 0.21 295 / .22), transparent 70%)"
                : "radial-gradient(60% 60% at 80% 0%, oklch(0.65 0.22 22 / .18), transparent 70%)",
        }}
      />
      <div className="relative flex items-start justify-between">
        <span className="text-xs uppercase tracking-widest text-muted-foreground">{label}</span>
        <span
          className={cn(
            "flex size-9 items-center justify-center rounded-xl border",
            tone === "mint" && "border-primary/30 bg-primary/10 text-primary",
            tone === "danger" && "border-destructive/30 bg-destructive/10 text-destructive",
            tone === "violet" && "border-accent/30 bg-accent/10 text-accent"
          )}
        >
          {icon}
        </span>
      </div>
      <div className="relative mt-3 num font-display text-3xl font-semibold">{value}</div>
      <div className="relative mt-1 text-xs text-muted-foreground">{hint}</div>
    </div>
  );
}

function Legend() {
  return (
    <div className="flex items-center gap-3 text-xs text-muted-foreground">
      <span className="flex items-center gap-1.5">
        <span className="size-2 rounded-full bg-primary" /> Receitas
      </span>
      <span className="flex items-center gap-1.5">
        <span className="size-2 rounded-full bg-destructive" /> Despesas
      </span>
      <span className="flex items-center gap-1.5">
        <span className="size-2 rounded-full bg-accent" /> Saldo
      </span>
    </div>
  );
}

function ChartTooltip({ active, payload, label }: any) {
  if (!active || !payload?.length) return null;
  return (
    <div className="glass-elevated rounded-xl px-3 py-2 text-xs">
      {label && <div className="mb-1 font-semibold">{label}</div>}
      {payload.map((p: any) => (
        <div key={p.dataKey} className="flex items-center gap-3">
          <span className="size-2 rounded-full" style={{ background: p.color || p.payload?.fill }} />
          <span className="capitalize text-muted-foreground">{p.name}</span>
          <span className="num ml-auto font-semibold">{BRL.format(p.value)}</span>
        </div>
      ))}
    </div>
  );
}

function EmptyChart() {
  return (
    <div className="flex h-44 flex-col items-center justify-center text-center text-xs text-muted-foreground">
      <PieIcon className="mb-2 size-6 opacity-40" />
      Sem despesas no período.
    </div>
  );
}
