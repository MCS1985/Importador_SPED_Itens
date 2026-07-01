import { useMemo, useState } from "react";
import { format } from "date-fns";
import { ptBR } from "date-fns/locale";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import {
  Select,
  SelectContent,
  SelectGroup,
  SelectItem,
  SelectLabel,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Button } from "@/components/ui/button";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";
import { Calendar } from "@/components/ui/calendar";
import { CalendarIcon, ArrowDownCircle, ArrowUpCircle } from "lucide-react";
import { cn } from "@/lib/utils";
import { toast } from "sonner";
import {
  financeActions,
  GRUPO_LABELS,
  useFinance,
  type Transaction,
} from "@/lib/finance-store";

type Props = {
  open: boolean;
  onOpenChange: (o: boolean) => void;
  editing?: Transaction | null;
  defaultTipo?: "receita" | "despesa";
};

export function TransactionDialog({ open, onOpenChange, editing, defaultTipo = "despesa" }: Props) {
  const { naturezas, entidades } = useFinance();

  const initial: Omit<Transaction, "id"> = useMemo(() => {
    if (editing) {
      const { id: _id, ...rest } = editing;
      return rest;
    }
    return {
      data: format(new Date(), "yyyy-MM-dd"),
      descricao: "",
      natureza: "",
      cr: "",
      entidade: entidades[0] ?? "MCS",
      empresa: entidades[0] ?? "MCS",
      obs: "",
      valor: 0,
    };
  }, [editing, entidades]);

  const [tipo, setTipo] = useState<"receita" | "despesa">(() => {
    if (editing) return editing.valor >= 0 ? "receita" : "despesa";
    return defaultTipo;
  });
  const [form, setForm] = useState(initial);
  const [valorStr, setValorStr] = useState(() => Math.abs(initial.valor || 0).toString().replace(".", ","));

  // Reset when dialog reopens
  useMemo(() => {
    if (open) {
      setForm(initial);
      setValorStr(Math.abs(initial.valor || 0).toString().replace(".", ","));
      if (editing) setTipo(editing.valor >= 0 ? "receita" : "despesa");
      else setTipo(defaultTipo);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open]);

  const naturezasFiltradas = naturezas.filter((n) => n.tipo === tipo);
  const grupos = Array.from(new Set(naturezasFiltradas.map((n) => n.grupo)));

  function onNaturezaChange(codigo: string) {
    const n = naturezas.find((x) => x.codigo === codigo);
    setForm((f) => ({ ...f, natureza: codigo, cr: n?.descricao ?? f.cr }));
  }

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!form.natureza) {
      toast.error("Selecione a natureza");
      return;
    }
    const valorNum = parseFloat(valorStr.replace(/\./g, "").replace(",", "."));
    if (!isFinite(valorNum) || valorNum <= 0) {
      toast.error("Informe um valor válido");
      return;
    }
    const signed = tipo === "receita" ? Math.abs(valorNum) : -Math.abs(valorNum);
    const payload: Omit<Transaction, "id"> = {
      ...form,
      valor: signed,
      descricao: form.descricao || (tipo === "receita" ? "Receita" : "Despesa"),
    };
    if (editing) {
      financeActions.updateTransaction(editing.id, payload);
      toast.success("Lançamento atualizado");
    } else {
      financeActions.addTransaction(payload);
      toast.success(tipo === "receita" ? "Receita registrada" : "Despesa registrada");
    }
    onOpenChange(false);
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="glass-elevated max-w-lg p-0 sm:rounded-2xl">
        <form onSubmit={handleSubmit}>
          <DialogHeader className="border-b border-border px-6 py-5">
            <DialogTitle className="font-display text-xl">
              {editing ? "Editar lançamento" : "Novo lançamento"}
            </DialogTitle>
            <DialogDescription>
              Registre uma movimentação no seu fluxo de caixa.
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-5 px-6 py-5">
            <div className="grid grid-cols-2 gap-2 rounded-xl bg-muted/40 p-1">
              <button
                type="button"
                onClick={() => setTipo("receita")}
                className={cn(
                  "flex items-center justify-center gap-2 rounded-lg px-3 py-2 text-sm font-semibold transition-all",
                  tipo === "receita"
                    ? "gradient-mint shadow-[var(--shadow-glow-mint)]"
                    : "text-muted-foreground hover:text-foreground"
                )}
              >
                <ArrowUpCircle className="size-4" /> Receita
              </button>
              <button
                type="button"
                onClick={() => setTipo("despesa")}
                className={cn(
                  "flex items-center justify-center gap-2 rounded-lg px-3 py-2 text-sm font-semibold transition-all",
                  tipo === "despesa"
                    ? "bg-destructive/90 text-destructive-foreground shadow-[0_10px_40px_-10px_oklch(0.65_0.22_22/.45)]"
                    : "text-muted-foreground hover:text-foreground"
                )}
              >
                <ArrowDownCircle className="size-4" /> Despesa
              </button>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="col-span-2 sm:col-span-1">
                <Label htmlFor="valor">Valor (R$)</Label>
                <Input
                  id="valor"
                  inputMode="decimal"
                  value={valorStr}
                  onChange={(e) => setValorStr(e.target.value)}
                  placeholder="0,00"
                  className="num mt-1.5 text-lg font-semibold"
                  autoFocus
                />
              </div>
              <div className="col-span-2 sm:col-span-1">
                <Label>Data</Label>
                <Popover>
                  <PopoverTrigger asChild>
                    <Button
                      type="button"
                      variant="outline"
                      className="mt-1.5 w-full justify-start bg-input/50 font-normal"
                    >
                      <CalendarIcon className="mr-2 size-4" />
                      {form.data
                        ? format(new Date(form.data + "T00:00:00"), "dd 'de' MMM yyyy", { locale: ptBR })
                        : "Selecionar"}
                    </Button>
                  </PopoverTrigger>
                  <PopoverContent className="w-auto p-0">
                    <Calendar
                      mode="single"
                      selected={new Date(form.data + "T00:00:00")}
                      onSelect={(d) =>
                        d && setForm((f) => ({ ...f, data: format(d, "yyyy-MM-dd") }))
                      }
                      initialFocus
                    />
                  </PopoverContent>
                </Popover>
              </div>
            </div>

            <div>
              <Label htmlFor="descricao">Descrição</Label>
              <Input
                id="descricao"
                value={form.descricao}
                onChange={(e) => setForm((f) => ({ ...f, descricao: e.target.value }))}
                placeholder="Ex.: Supermercado, Salário…"
                className="mt-1.5"
              />
            </div>

            <div>
              <Label>Natureza / Centro de Resultado</Label>
              <Select value={form.natureza} onValueChange={onNaturezaChange}>
                <SelectTrigger className="mt-1.5 w-full">
                  <SelectValue placeholder="Selecionar natureza" />
                </SelectTrigger>
                <SelectContent>
                  {grupos.map((g) => (
                    <SelectGroup key={g}>
                      <SelectLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                        {GRUPO_LABELS[g] ?? g}
                      </SelectLabel>
                      {naturezasFiltradas
                        .filter((n) => n.grupo === g)
                        .map((n) => (
                          <SelectItem key={n.codigo} value={n.codigo}>
                            <span className="font-mono text-xs text-muted-foreground mr-2">
                              {n.codigo}
                            </span>
                            {n.descricao}
                          </SelectItem>
                        ))}
                    </SelectGroup>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <Label>Entidade</Label>
                <Select
                  value={form.entidade}
                  onValueChange={(v) => setForm((f) => ({ ...f, entidade: v, empresa: v }))}
                >
                  <SelectTrigger className="mt-1.5 w-full">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {entidades.map((e) => (
                      <SelectItem key={e} value={e}>
                        {e}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>

            <div>
              <Label htmlFor="obs">Observações</Label>
              <Textarea
                id="obs"
                rows={2}
                value={form.obs}
                onChange={(e) => setForm((f) => ({ ...f, obs: e.target.value }))}
                placeholder="Notas adicionais (opcional)"
                className="mt-1.5 resize-none"
              />
            </div>
          </div>

          <div className="flex items-center justify-end gap-3 border-t border-border px-6 py-4">
            <Button type="button" variant="ghost" onClick={() => onOpenChange(false)}>
              Cancelar
            </Button>
            <Button
              type="submit"
              className={cn(
                "font-semibold",
                tipo === "receita"
                  ? "gradient-mint hover:opacity-95"
                  : "bg-destructive text-destructive-foreground hover:bg-destructive/90"
              )}
            >
              {editing ? "Salvar alterações" : "Registrar"}
            </Button>
          </div>
        </form>
      </DialogContent>
    </Dialog>
  );
}
