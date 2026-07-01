import { useMemo, useState } from "react";
import { Plus, Trash2, Tag } from "lucide-react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
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
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { financeActions, GRUPO_LABELS, useFinance, type Natureza } from "@/lib/finance-store";
import { toast } from "sonner";
import { cn } from "@/lib/utils";

export function NaturezasView() {
  const { naturezas, entidades, transactions } = useFinance();
  const [openNew, setOpenNew] = useState(false);
  const [toDelete, setToDelete] = useState<Natureza | null>(null);
  const [newEnt, setNewEnt] = useState("");

  const grouped = useMemo(() => {
    const map = new Map<string, Natureza[]>();
    for (const n of naturezas) {
      if (!map.has(n.grupo)) map.set(n.grupo, []);
      map.get(n.grupo)!.push(n);
    }
    return [...map.entries()].sort();
  }, [naturezas]);

  const usage = useMemo(() => {
    const map = new Map<string, number>();
    for (const t of transactions) map.set(t.natureza, (map.get(t.natureza) ?? 0) + 1);
    return map;
  }, [transactions]);

  return (
    <div className="space-y-6">
      <div className="glass-card p-5">
        <div className="flex items-center justify-between">
          <div>
            <h3 className="font-display text-base font-semibold">Entidades</h3>
            <p className="text-xs text-muted-foreground">Empresas ou pessoas pagantes / recebedoras</p>
          </div>
          <div className="flex items-center gap-2">
            <Input
              value={newEnt}
              onChange={(e) => setNewEnt(e.target.value)}
              placeholder="Nova entidade"
              className="w-40"
            />
            <Button
              onClick={() => {
                if (!newEnt.trim()) return;
                financeActions.addEntidade(newEnt);
                setNewEnt("");
                toast.success("Entidade adicionada");
              }}
            >
              <Plus className="size-4" /> Adicionar
            </Button>
          </div>
        </div>
        <div className="mt-4 flex flex-wrap gap-2">
          {entidades.map((e) => (
            <span
              key={e}
              className="group inline-flex items-center gap-2 rounded-full border border-border bg-muted/40 px-3 py-1 text-sm"
            >
              {e}
              {entidades.length > 1 && (
                <button
                  className="text-muted-foreground opacity-0 transition-opacity hover:text-destructive group-hover:opacity-100"
                  onClick={() => {
                    financeActions.deleteEntidade(e);
                    toast.success("Entidade removida");
                  }}
                >
                  <Trash2 className="size-3" />
                </button>
              )}
            </span>
          ))}
        </div>
      </div>

      <div className="glass-card p-5">
        <div className="mb-4 flex items-center justify-between">
          <div>
            <h3 className="font-display text-base font-semibold">Centros de Resultado / Naturezas</h3>
            <p className="text-xs text-muted-foreground">{naturezas.length} cadastrados</p>
          </div>
          <NewNaturezaDialog open={openNew} onOpenChange={setOpenNew} />
        </div>

        <div className="space-y-6">
          {grouped.map(([grupo, items]) => (
            <div key={grupo}>
              <div className="mb-2 flex items-center gap-2">
                <Tag className="size-3.5 text-muted-foreground" />
                <h4 className="text-xs font-semibold uppercase tracking-widest text-muted-foreground">
                  {GRUPO_LABELS[grupo] ?? grupo}
                </h4>
                <span className="text-xs text-muted-foreground">· {items.length}</span>
              </div>
              <ul className="grid grid-cols-1 gap-2 md:grid-cols-2">
                {items.map((n) => {
                  const used = usage.get(n.codigo) ?? 0;
                  return (
                    <li
                      key={n.codigo}
                      className="group flex items-center gap-3 rounded-xl border border-border bg-muted/20 p-3 transition-colors hover:bg-muted/40"
                    >
                      <span
                        className={cn(
                          "rounded-md border px-2 py-1 font-mono text-xs",
                          n.tipo === "receita"
                            ? "border-primary/30 bg-primary/10 text-primary"
                            : "border-destructive/30 bg-destructive/10 text-destructive"
                        )}
                      >
                        {n.codigo}
                      </span>
                      <div className="min-w-0 flex-1">
                        <div className="truncate text-sm">{n.descricao}</div>
                        <div className="text-xs text-muted-foreground">
                          {used} {used === 1 ? "lançamento" : "lançamentos"}
                        </div>
                      </div>
                      <button
                        className="text-muted-foreground opacity-0 transition-opacity hover:text-destructive group-hover:opacity-100"
                        onClick={() => setToDelete(n)}
                        aria-label="Excluir"
                      >
                        <Trash2 className="size-4" />
                      </button>
                    </li>
                  );
                })}
              </ul>
            </div>
          ))}
        </div>
      </div>

      <AlertDialog open={!!toDelete} onOpenChange={(o) => !o && setToDelete(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Excluir natureza {toDelete?.codigo}?</AlertDialogTitle>
            <AlertDialogDescription>
              {(usage.get(toDelete?.codigo ?? "") ?? 0) > 0
                ? `Existem ${usage.get(toDelete?.codigo ?? "")} lançamentos usando essa natureza. Eles permanecerão, mas a categoria deixará de existir.`
                : "Esta natureza não está em uso. Pode excluir tranquilamente."}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancelar</AlertDialogCancel>
            <AlertDialogAction
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
              onClick={() => {
                if (toDelete) {
                  financeActions.deleteNatureza(toDelete.codigo);
                  toast.success("Natureza removida");
                }
                setToDelete(null);
              }}
            >
              Excluir
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}

function NewNaturezaDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (o: boolean) => void }) {
  const { naturezas } = useFinance();
  const [codigo, setCodigo] = useState("");
  const [grupo, setGrupo] = useState("DESP");
  const [tipo, setTipo] = useState<"receita" | "despesa">("despesa");
  const [descricao, setDescricao] = useState("");

  function submit(e: React.FormEvent) {
    e.preventDefault();
    const cod = codigo.trim().toUpperCase();
    if (!cod || !descricao.trim()) {
      toast.error("Preencha código e descrição");
      return;
    }
    if (naturezas.some((n) => n.codigo === cod)) {
      toast.error("Código já existe");
      return;
    }
    financeActions.addNatureza({ codigo: cod, grupo, tipo, descricao: descricao.trim() });
    toast.success("Natureza cadastrada");
    setCodigo("");
    setDescricao("");
    onOpenChange(false);
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogTrigger asChild>
        <Button className="gradient-mint font-semibold">
          <Plus className="size-4" /> Nova natureza
        </Button>
      </DialogTrigger>
      <DialogContent className="glass-elevated sm:max-w-md">
        <form onSubmit={submit}>
          <DialogHeader>
            <DialogTitle className="font-display">Nova natureza</DialogTitle>
            <DialogDescription>
              Crie um centro de resultado para classificar lançamentos.
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="grid grid-cols-2 gap-3">
              <div>
                <Label>Tipo</Label>
                <Select value={tipo} onValueChange={(v) => setTipo(v as any)}>
                  <SelectTrigger className="mt-1.5"><SelectValue /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value="receita">Receita</SelectItem>
                    <SelectItem value="despesa">Despesa</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div>
                <Label>Grupo</Label>
                <Select value={grupo} onValueChange={setGrupo}>
                  <SelectTrigger className="mt-1.5"><SelectValue /></SelectTrigger>
                  <SelectContent>
                    {Object.entries(GRUPO_LABELS).map(([k, v]) => (
                      <SelectItem key={k} value={k}>{v}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>
            <div>
              <Label htmlFor="cod">Código</Label>
              <Input
                id="cod"
                value={codigo}
                onChange={(e) => setCodigo(e.target.value)}
                placeholder="Ex.: DESP6"
                className="mt-1.5 font-mono uppercase"
              />
            </div>
            <div>
              <Label htmlFor="desc">Descrição</Label>
              <Input
                id="desc"
                value={descricao}
                onChange={(e) => setDescricao(e.target.value)}
                placeholder="Ex.: CPF - Desp. Streaming"
                className="mt-1.5"
              />
            </div>
          </div>
          <DialogFooter>
            <Button type="button" variant="ghost" onClick={() => onOpenChange(false)}>
              Cancelar
            </Button>
            <Button type="submit" className="gradient-mint font-semibold">
              Cadastrar
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
