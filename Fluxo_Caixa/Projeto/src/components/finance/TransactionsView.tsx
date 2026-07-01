import { useMemo, useState, useCallback, useRef } from "react";
import { Search, Pencil, Trash2, ArrowUpRight, ArrowDownRight, Filter, TrashIcon } from "lucide-react";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Input } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { TransactionDialog } from "./TransactionDialog";
import { financeActions, useFinance, GRUPO_LABELS, type Transaction } from "@/lib/finance-store";
import { BRL, formatDatePt, MES_CURTO } from "@/lib/format";
import { cn } from "@/lib/utils";
import { toast } from "sonner";

const STORAGE_KEY = "fluxo_col_widths";
const COL_DEFAULTS = [110, 220, 180, 120, 140, 72];
const COL_LABELS = ["Data", "Descrição", "Centro de resultado", "Natureza", "Valor", "Ações"];

function loadWidths(): number[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) return JSON.parse(raw);
  } catch { /* ignore */ }
  return [...COL_DEFAULTS];
}

function saveWidths(widths: number[]) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(widths));
}

function useColumnResize(): [number[], (i: number) => React.MouseEventHandler] {
  const [widths, setWidths] = useState<number[]>(loadWidths);
  const widthsRef = useRef(widths);
  widthsRef.current = widths;
  const dragRef = useRef<{
    i: number;
    startX: number;
    startWi: number;
    startWNext: number;
    totalW: number;
  } | null>(null);

  const handleMouseDown = useCallback((i: number) => (e: React.MouseEvent) => {
    e.preventDefault();
    const wi = widthsRef.current[i];
    const wn = widthsRef.current[i + 1];
    dragRef.current = { i, startX: e.clientX, startWi: wi, startWNext: wn, totalW: wi + wn };
    document.body.style.userSelect = "none";
    document.body.style.cursor = "col-resize";
    const onMove = (ev: MouseEvent) => {
      if (!dragRef.current) return;
      const { i: idx, startX, startWi, totalW } = dragRef.current;
      const dx = ev.clientX - startX;
      const newWi = Math.max(60, Math.min(totalW - 60, startWi + dx));
      const newWn = totalW - newWi;
      setWidths((prev) => {
        const next = [...prev];
        next[idx] = newWi;
        next[idx + 1] = newWn;
        return next;
      });
    };
    const onUp = (ev: MouseEvent) => {
      if (dragRef.current) {
        const { i: idx, startX, startWi, totalW } = dragRef.current;
        const dx = ev.clientX - startX;
        const newWi = Math.max(60, Math.min(totalW - 60, startWi + dx));
        const newWn = totalW - newWi;
        const saved = [...widthsRef.current];
        saved[idx] = newWi;
        saved[idx + 1] = newWn;
        saveWidths(saved);
        dragRef.current = null;
      }
      document.body.style.userSelect = "";
      document.body.style.cursor = "";
      document.removeEventListener("mousemove", onMove);
      document.removeEventListener("mouseup", onUp);
    };
    document.addEventListener("mousemove", onMove);
    document.addEventListener("mouseup", onUp);
  }, []);

  return [widths, handleMouseDown];
}

type Props = { year: number };

export function TransactionsView({ year }: Props) {
  const { transactions, naturezas } = useFinance();
  const [q, setQ] = useState("");
  const [tipo, setTipo] = useState<"todas" | "receita" | "despesa">("todas");
  const [grupo, setGrupo] = useState<string>("todos");
  const [mes, setMes] = useState<string>("todos");
  const [editing, setEditing] = useState<Transaction | null>(null);
  const [toDelete, setToDelete] = useState<Transaction | null>(null);
  const [toDeleteMany, setToDeleteMany] = useState<readonly string[] | null>(null);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [colWidths, startResize] = useColumnResize();

  const natMap = useMemo(() => new Map(naturezas.map((n) => [n.codigo, n])), [naturezas]);
  const grupos = useMemo(() => Array.from(new Set(naturezas.map((n) => n.grupo))), [naturezas]);

  function toggleSelect(id: string) {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id); else next.add(id);
      return next;
    });
  }

  function toggleSelectAll() {
    setSelected((prev) =>
      prev.size === filtered.length ? new Set() : new Set(filtered.map((t) => t.id))
    );
  }

  function handleBulkDelete() {
    const ids = filtered.filter((t) => selected.has(t.id)).map((t) => t.id);
    if (ids.length === 0) return;
    setToDeleteMany(ids);
  }

  function confirmBulkDelete() {
    if (!toDeleteMany) return;
    toDeleteMany.forEach((id) => financeActions.deleteTransaction(id));
    toast.success(`${toDeleteMany.length} lançamento${toDeleteMany.length !== 1 ? "s" : ""} excluído${toDeleteMany.length !== 1 ? "s" : ""}`);
    setSelected(new Set());
    setToDeleteMany(null);
  }

  const filtered = useMemo(() => {
    return transactions
      .filter((t) => t.data.startsWith(String(year)))
      .filter((t) => {
        if (tipo === "receita" && t.valor < 0) return false;
        if (tipo === "despesa" && t.valor >= 0) return false;
        if (grupo !== "todos") {
          const n = natMap.get(t.natureza);
          if (n?.grupo !== grupo) return false;
        }
        if (mes !== "todos" && t.data.slice(5, 7) !== mes) return false;
        if (q.trim()) {
          const needle = q.trim().toLowerCase();
          const hay = `${t.descricao} ${t.cr} ${t.natureza} ${t.obs}`.toLowerCase();
          if (!hay.includes(needle)) return false;
        }
        return true;
      })
      .sort((a, b) => (a.data < b.data ? 1 : a.data > b.data ? -1 : 0));
  }, [transactions, year, tipo, grupo, mes, q, natMap]);

  const totalFiltered = filtered.reduce((s, t) => s + t.valor, 0);

  return (
    <div className="space-y-4">
      <div className="sticky top-0 z-20 rounded-lg bg-background backdrop-blur-xl">
        <div className="glass-card flex flex-col gap-3 p-4 lg:flex-row lg:items-center">
        <div className="relative flex-1">
          <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            placeholder="Buscar por descrição, natureza ou centro…"
            value={q}
            onChange={(e) => setQ(e.target.value)}
            className="pl-9"
          />
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <Filter className="size-4 text-muted-foreground" />
          <Select value={tipo} onValueChange={(v) => setTipo(v as any)}>
            <SelectTrigger className="w-[130px]"><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem value="todas">Todos os tipos</SelectItem>
              <SelectItem value="receita">Receitas</SelectItem>
              <SelectItem value="despesa">Despesas</SelectItem>
            </SelectContent>
          </Select>
          <Select value={grupo} onValueChange={setGrupo}>
            <SelectTrigger className="w-[160px]"><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem value="todos">Todos os grupos</SelectItem>
              {grupos.map((g) => (
                <SelectItem key={g} value={g}>{GRUPO_LABELS[g] ?? g}</SelectItem>
              ))}
            </SelectContent>
          </Select>
          <Select value={mes} onValueChange={setMes}>
            <SelectTrigger className="w-[120px]"><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem value="todos">Todos meses</SelectItem>
              {MES_CURTO.map((m, i) => (
                <SelectItem key={m} value={String(i + 1).padStart(2, "0")}>{m}</SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
      </div>
      </div>

      <div className="glass-card overflow-visible min-w-max">
        <div className="sticky top-[56px] z-10 flex items-center justify-between border-b border-border bg-background px-5 py-3 text-sm backdrop-blur-xl">
          <span className="text-muted-foreground">
            {filtered.length} {filtered.length === 1 ? "lançamento" : "lançamentos"}
          </span>
          <span className="num font-semibold">
            Saldo: <span className={cn(totalFiltered >= 0 ? "text-primary" : "text-destructive")}>{BRL.format(totalFiltered)}</span>
          </span>
        </div>

        <div className="sticky top-[100px] z-10 hidden select-none border-b border-border bg-surface px-5 py-0 backdrop-blur-xl md:flex">
          {COL_LABELS.map((label, i) => {
            return (
              <div key={label} className="relative flex shrink-0 items-center" style={{ width: i !== 1 ? colWidths[i] : undefined, flex: i === 1 ? 1 : undefined, minWidth: i === 1 ? colWidths[1] : undefined }}>
                {i > 0 && (
                  <div
                    onMouseDown={startResize(i - 1)}
                    className="absolute left-0 top-0 z-10 h-full w-2 cursor-col-resize"
                  >
                    <div className="mx-auto h-full w-px bg-border opacity-0" />
                  </div>
                )}
                {i === 0 && (
                  <Checkbox
                    checked={selected.size === filtered.length && filtered.length > 0}
                    onCheckedChange={toggleSelectAll}
                    className="mx-2"
                  />
                )}
                <span className={cn("flex-1 py-2.5 px-2 text-xs uppercase tracking-wider text-muted-foreground", i >= 4 && "text-right")}>
                  {label}
                </span>
                {i < COL_LABELS.length - 1 && (
                  <div
                    onMouseDown={startResize(i)}
                    className="absolute right-0 top-0 z-10 h-full w-2 cursor-col-resize"
                  >
                    <div className="mx-auto h-full w-px bg-border" />
                  </div>
                )}
              </div>
            );
          })}
        </div>

        {selected.size > 0 && (
          <div className="flex items-center gap-3 border-b border-border bg-background px-5 py-2 text-sm">
            <span className="text-muted-foreground">{selected.size} selecionado{selected.size !== 1 && "s"}</span>
            <Button variant="destructive" size="sm" onClick={handleBulkDelete}>
              <TrashIcon className="size-4" /> Excluir selecionados
            </Button>
          </div>
        )}

        <ul className="divide-y divide-border">
          {filtered.map((t) => {
            const isReceita = t.valor >= 0;
            const n = natMap.get(t.natureza);
            return (
              <li
                key={t.id}
                className={cn("hidden items-center gap-0 px-5 py-1.5 transition-colors hover:bg-muted/20 md:flex", selected.has(t.id) && "bg-primary/5")}
              >
                <div className="flex items-center gap-1 text-sm" style={{ width: colWidths[0], minWidth: colWidths[0] }}>
                  <Checkbox
                    checked={selected.has(t.id)}
                    onCheckedChange={() => toggleSelect(t.id)}
                  />
                  <span
                    className={cn(
                      "flex size-8 items-center justify-center rounded-lg border md:hidden",
                      isReceita ? "border-primary/30 bg-primary/10 text-primary" : "border-destructive/30 bg-destructive/10 text-destructive"
                    )}
                  >
                    {isReceita ? <ArrowUpRight className="size-4" /> : <ArrowDownRight className="size-4" />}
                  </span>
                  <span className="num text-muted-foreground">{formatDatePt(t.data)}</span>
                </div>
                <div className="truncate text-sm" style={{ flex: 1, minWidth: colWidths[1] }}>
                  <div className="truncate font-medium">{t.descricao || "—"}</div>
                  {t.obs && <div className="truncate text-xs text-muted-foreground">{t.obs}</div>}
                </div>
                <div className="truncate text-xs text-muted-foreground" style={{ width: colWidths[2], minWidth: colWidths[2] }}>{t.cr || n?.descricao || "—"}</div>
                <div className="text-xs" style={{ width: colWidths[3], minWidth: colWidths[3] }}>
                  <span className="rounded-md border border-border bg-muted/40 px-2 py-0.5 font-mono">
                    {t.natureza}
                  </span>
                </div>
                <div className={cn("num truncate text-right text-sm font-semibold", isReceita ? "text-primary" : "text-destructive")} style={{ width: colWidths[4], minWidth: colWidths[4] }}>
                  {isReceita ? "+" : "−"}{BRL.format(Math.abs(t.valor))}
                </div>
                <div className="flex items-center justify-end gap-1" style={{ width: colWidths[5], minWidth: colWidths[5] }}>
                  <Button size="icon" variant="ghost" onClick={() => setEditing(t)} aria-label="Editar">
                    <Pencil className="size-4" />
                  </Button>
                  <Button size="icon" variant="ghost" onClick={() => setToDelete(t)} aria-label="Excluir">
                    <Trash2 className="size-4 text-destructive" />
                  </Button>
                </div>
              </li>
            );
          })}
        </ul>

        {filtered.length === 0 && (
          <div className="border-t border-border px-5 py-3 text-center text-xs text-muted-foreground">
            Nenhum lançamento encontrado com esses filtros.
          </div>
        )}
      </div>

      <TransactionDialog
        open={!!editing}
        onOpenChange={(o) => !o && setEditing(null)}
        editing={editing}
      />

      <AlertDialog open={!!toDelete} onOpenChange={(o) => !o && setToDelete(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Excluir este lançamento?</AlertDialogTitle>
            <AlertDialogDescription>
              Esta ação não pode ser desfeita. O lançamento será removido do seu fluxo de caixa.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancelar</AlertDialogCancel>
            <AlertDialogAction
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
              onClick={() => {
                if (toDelete) {
                  financeActions.deleteTransaction(toDelete.id);
                  toast.success("Lançamento excluído");
                }
                setToDelete(null);
              }}
            >
              Excluir
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      <AlertDialog open={!!toDeleteMany} onOpenChange={(o) => !o && setToDeleteMany(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Excluir {toDeleteMany?.length} lançamento{toDeleteMany?.length !== 1 && "s"}?</AlertDialogTitle>
            <AlertDialogDescription>
              Esta ação não pode ser desfeita. {toDeleteMany?.length} lançamento{toDeleteMany?.length !== 1 && "s"} será{toDeleteMany?.length === 1 ? " " : "o "} removido{toDeleteMany?.length === 1 ? "" : "s"} do seu fluxo de caixa.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancelar</AlertDialogCancel>
            <AlertDialogAction
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
              onClick={confirmBulkDelete}
            >
              Excluir {toDeleteMany?.length}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
