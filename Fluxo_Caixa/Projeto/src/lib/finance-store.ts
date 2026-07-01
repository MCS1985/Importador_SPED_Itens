import { useEffect, useSyncExternalStore } from "react";
import seedDataJson from "./seed-data.json";

export type Natureza = {
  codigo: string;
  grupo: string;
  descricao: string;
  tipo: "receita" | "despesa";
};

export type Transaction = {
  id: string;
  data: string; // YYYY-MM-DD
  descricao: string;
  natureza: string; // codigo
  cr: string; // descricao do centro de resultado
  entidade: string;
  empresa: string;
  obs: string;
  valor: number; // negativo = despesa, positivo = receita
};

export type FinanceState = {
  naturezas: Natureza[];
  entidades: string[];
  transactions: Transaction[];
};

const STORAGE_KEY = "fluxo-caixa-mcs:v1";

const seed = seedDataJson as {
  naturezas: Natureza[];
  entidades: string[];
  transactions: Omit<Transaction, "id">[];
};

function makeId() {
  return `tx_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`;
}

function initialState(): FinanceState {
  return {
    naturezas: seed.naturezas,
    entidades: seed.entidades.length ? seed.entidades : ["MCS"],
    transactions: seed.transactions.map((t) => ({ ...t, id: makeId() })),
  };
}

let state: FinanceState = (() => {
  if (typeof window === "undefined") return initialState();
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) {
      const s = initialState();
      window.localStorage.setItem(STORAGE_KEY, JSON.stringify(s));
      return s;
    }
    const parsed = JSON.parse(raw) as FinanceState;
    // backfill missing naturezas if seed was updated
    const codes = new Set(parsed.naturezas.map((n) => n.codigo));
    const merged = [
      ...parsed.naturezas,
      ...seed.naturezas.filter((n) => !codes.has(n.codigo)),
    ];
    return { ...parsed, naturezas: merged };
  } catch {
    return initialState();
  }
})();

const listeners = new Set<() => void>();

function persist() {
  if (typeof window !== "undefined") {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  }
}

function emit() {
  persist();
  listeners.forEach((l) => l());
}

function subscribe(cb: () => void) {
  listeners.add(cb);
  return () => listeners.delete(cb);
}

function getSnapshot() {
  return state;
}

export function useFinance() {
  return useSyncExternalStore(subscribe, getSnapshot, getSnapshot);
}

export const financeActions = {
  addTransaction(tx: Omit<Transaction, "id">) {
    state = { ...state, transactions: [{ ...tx, id: makeId() }, ...state.transactions] };
    emit();
  },
  updateTransaction(id: string, patch: Partial<Omit<Transaction, "id">>) {
    state = {
      ...state,
      transactions: state.transactions.map((t) => (t.id === id ? { ...t, ...patch } : t)),
    };
    emit();
  },
  deleteTransaction(id: string) {
    state = { ...state, transactions: state.transactions.filter((t) => t.id !== id) };
    emit();
  },
  addNatureza(n: Natureza) {
    if (state.naturezas.some((x) => x.codigo === n.codigo)) return;
    state = { ...state, naturezas: [...state.naturezas, n] };
    emit();
  },
  updateNatureza(codigo: string, patch: Partial<Natureza>) {
    state = {
      ...state,
      naturezas: state.naturezas.map((n) => (n.codigo === codigo ? { ...n, ...patch } : n)),
    };
    emit();
  },
  deleteNatureza(codigo: string) {
    state = { ...state, naturezas: state.naturezas.filter((n) => n.codigo !== codigo) };
    emit();
  },
  addEntidade(name: string) {
    const trimmed = name.trim();
    if (!trimmed || state.entidades.includes(trimmed)) return;
    state = { ...state, entidades: [...state.entidades, trimmed] };
    emit();
  },
  deleteEntidade(name: string) {
    state = { ...state, entidades: state.entidades.filter((e) => e !== name) };
    emit();
  },
  resetAll() {
    state = initialState();
    emit();
  },
  clearAll() {
    state = { ...state, transactions: [] };
    emit();
  },
  importTransactions(txs: Omit<Transaction, "id">[]) {
    state = {
      ...state,
      transactions: [...txs.map((t) => ({ ...t, id: makeId() })), ...state.transactions],
    };
    emit();
  },
};

/** SSR-safe hook that ensures we re-hydrate from localStorage after mount. */
export function useHydrateFinance() {
  useEffect(() => {
    if (typeof window === "undefined") return;
    try {
      const raw = window.localStorage.getItem(STORAGE_KEY);
      if (raw) {
        const parsed = JSON.parse(raw) as FinanceState;
        const codes = new Set(parsed.naturezas.map((n) => n.codigo));
        const merged = [
          ...parsed.naturezas,
          ...seed.naturezas.filter((n) => !codes.has(n.codigo)),
        ];
        state = { ...parsed, naturezas: merged };
      }
    } catch {
      /* ignore */
    }
    emit();
  }, []);
}

/* ---------- Group / category helpers ---------- */

export const GRUPO_LABELS: Record<string, string> = {
  REC: "Receitas",
  OPF: "Operacional PF",
  DESP: "Despesas Fixas",
  GAST: "Lazer & Estilo",
  FIN: "Financeiras",
  TRI: "Impostos",
  OUG: "Outros Gastos",
  PENS: "Pensão / Família",
};

export const GRUPO_COLORS: Record<string, string> = {
  REC: "var(--chart-1)",
  OPF: "var(--chart-2)",
  DESP: "var(--chart-3)",
  GAST: "var(--chart-4)",
  FIN: "var(--chart-5)",
  TRI: "var(--chart-7)",
  OUG: "var(--chart-8)",
  PENS: "var(--chart-6)",
};
