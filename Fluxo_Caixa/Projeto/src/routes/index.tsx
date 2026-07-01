import { useState, type FormEvent } from "react";
import { createFileRoute } from "@tanstack/react-router";
import {
  LayoutDashboard,
  ListTree,
  Tags,
  Plus,
  Wallet,
  Settings as SettingsIcon,
  RefreshCw,
  Trash2,
  KeyRound,
  LogOut,
  FileSpreadsheet,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { cn } from "@/lib/utils";
import { DashboardView } from "@/components/finance/DashboardView";
import { TransactionsView } from "@/components/finance/TransactionsView";
import { NaturezasView } from "@/components/finance/NaturezasView";
import { TransactionDialog } from "@/components/finance/TransactionDialog";
import { ImportDialog } from "@/components/finance/ImportDialog";
import { financeActions, useFinance, useHydrateFinance } from "@/lib/finance-store";
import { useAuth } from "@/lib/auth-store";
import { toast } from "sonner";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "Fluxo · Finanças Pessoais MCS" },
      {
        name: "description",
        content:
          "Dashboard moderno de fluxo de caixa pessoal com receitas, despesas, naturezas e centros de resultado.",
      },
    ],
  }),
  component: AppHome,
});

type Tab = "dashboard" | "lancamentos" | "naturezas";

const NAV: { id: Tab; label: string; icon: React.ComponentType<{ className?: string }> }[] = [
  { id: "dashboard", label: "Dashboard", icon: LayoutDashboard },
  { id: "lancamentos", label: "Lançamentos", icon: ListTree },
  { id: "naturezas", label: "Naturezas & CRs", icon: Tags },
];

function AppHome() {
  useHydrateFinance();
  const { transactions } = useFinance();
  const [tab, setTab] = useState<Tab>("dashboard");
  const [openNew, setOpenNew] = useState(false);
  const [openImport, setOpenImport] = useState(false);
  const [year] = useState(2026);

  return (
    <div className="min-h-screen">
      {/* Sidebar */}
      <aside className="fixed inset-y-0 left-0 z-30 hidden w-64 flex-col border-r border-border bg-surface/80 backdrop-blur-xl lg:flex">
        <div className="flex items-center gap-3 px-6 py-6">
          <div className="flex size-10 items-center justify-center rounded-xl gradient-mint shadow-[var(--shadow-glow-mint)]">
            <Wallet className="size-5" />
          </div>
          <div>
            <div className="font-display text-base font-bold leading-tight">Fluxo</div>
            <div className="text-[10px] uppercase tracking-widest text-muted-foreground">Finanças MCS</div>
          </div>
        </div>

        <nav className="flex-1 px-3">
          {NAV.map((item) => {
            const active = tab === item.id;
            return (
              <button
                key={item.id}
                onClick={() => setTab(item.id)}
                className={cn(
                  "group mb-1 flex w-full items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition-all",
                  active
                    ? "bg-primary/10 text-primary ring-1 ring-primary/20"
                    : "text-muted-foreground hover:bg-muted/40 hover:text-foreground"
                )}
              >
                <item.icon className={cn("size-4", active && "text-primary")} />
                {item.label}
                {active && <span className="ml-auto size-1.5 rounded-full bg-primary" />}
              </button>
            );
          })}
        </nav>

        <div className="border-t border-border p-4">
          <div className="rounded-xl border border-border bg-muted/30 p-3">
            <div className="text-[10px] uppercase tracking-widest text-muted-foreground">
              Total registrado
            </div>
            <div className="mt-1 font-display text-xl font-semibold num">
              {transactions.length}
            </div>
            <div className="text-xs text-muted-foreground">lançamentos salvos localmente</div>
          </div>
        </div>
      </aside>

      {/* Mobile top nav */}
      <header className="sticky top-0 z-20 flex items-center justify-between border-b border-border bg-background/80 px-4 py-3 backdrop-blur-xl lg:hidden">
        <div className="flex items-center gap-2">
          <div className="flex size-8 items-center justify-center rounded-lg gradient-mint">
            <Wallet className="size-4" />
          </div>
          <span className="font-display font-bold">Fluxo</span>
        </div>
        <div className="flex gap-1 rounded-full border border-border bg-muted/40 p-1 text-xs">
          {NAV.map((item) => (
            <button
              key={item.id}
              onClick={() => setTab(item.id)}
              className={cn(
                "rounded-full px-3 py-1 font-medium",
                tab === item.id ? "bg-primary text-primary-foreground" : "text-muted-foreground"
              )}
            >
              {item.label.split(" ")[0]}
            </button>
          ))}
        </div>
      </header>

      {/* Main */}
      <main className="flex h-dvh flex-col lg:pl-64">
        <div className="shrink-0 border-b border-border bg-background backdrop-blur-xl">
          <div className="mx-auto max-w-7xl px-4 py-4 lg:px-8">
            <div className="flex flex-wrap items-end justify-between gap-4">
              <div>
                <div className="text-xs uppercase tracking-widest text-muted-foreground">
                  Ano-base · {year}
                </div>
                <h1 className="mt-1 font-display text-3xl font-bold leading-tight md:text-4xl">
                  {tab === "dashboard" && (
                    <>
                      Bem-vindo de volta, <span className="text-gradient-mint">MCS</span>
                    </>
                  )}
                  {tab === "lancamentos" && "Todos os lançamentos"}
                  {tab === "naturezas" && "Naturezas & Centros de Resultado"}
                </h1>
                <p className="mt-1 text-sm text-muted-foreground">
                  {tab === "dashboard" && "Visão consolidada do seu fluxo de caixa em tempo real."}
                  {tab === "lancamentos" && "Filtre, edite e organize todas as suas movimentações."}
                  {tab === "naturezas" && "Gerencie categorias e entidades do seu cadastro."}
                </p>
              </div>

              <div className="flex items-center gap-2">
                <Button
                  onClick={() => setOpenNew(true)}
                  className="gradient-mint font-semibold shadow-[var(--shadow-glow-mint)] transition-transform hover:scale-[1.02]"
                >
                  <Plus className="size-4" /> Novo lançamento
                </Button>

                <DropdownMenu>
                  <DropdownMenuTrigger asChild>
                    <Button variant="outline" size="icon" aria-label="Configurações">
                      <SettingsIcon className="size-5" strokeWidth={1.5} />
                    </Button>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align="end" className="w-56">
                    <DropdownMenuLabel>Dados locais</DropdownMenuLabel>
                    <DropdownMenuSeparator />
                    <ResetItem />
                    <ClearItem />
                    <DropdownMenuSeparator />
                    <DropdownMenuItem onSelect={() => setOpenImport(true)}>
                      <FileSpreadsheet className="size-4" /> Importar planilha
                    </DropdownMenuItem>
                    <ChangePasswordItem />
                    <LogoutItem />
                  </DropdownMenuContent>
                </DropdownMenu>
              </div>
            </div>
          </div>
        </div>

        <div className="min-h-0 flex-1 overflow-y-auto">
          <div className="mx-auto max-w-7xl px-4 pb-8 pt-6 lg:px-8">
            {tab === "dashboard" && <DashboardView year={year} />}
            {tab === "lancamentos" && <TransactionsView year={year} />}
            {tab === "naturezas" && <NaturezasView />}
          </div>
        </div>

        {/* Floating action button - mobile */}
        <button
          onClick={() => setOpenNew(true)}
          className="fixed bottom-6 right-6 z-40 flex size-14 items-center justify-center rounded-full gradient-mint shadow-[var(--shadow-glow-mint)] transition-transform hover:scale-110 lg:hidden"
          aria-label="Novo lançamento"
        >
          <Plus className="size-6" />
        </button>
      </main>

      <TransactionDialog open={openNew} onOpenChange={setOpenNew} />
      <ImportDialog open={openImport} onOpenChange={setOpenImport} />
    </div>
  );
}

function ResetItem() {
  return (
    <AlertDialog>
      <AlertDialogTrigger asChild>
        <DropdownMenuItem onSelect={(e) => e.preventDefault()}>
          <RefreshCw className="size-4" /> Restaurar planilha original
        </DropdownMenuItem>
      </AlertDialogTrigger>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>Restaurar dados originais?</AlertDialogTitle>
          <AlertDialogDescription>
            Isso vai substituir tudo pelos dados originais da planilha 2026 (648 lançamentos).
            Suas alterações locais serão perdidas.
          </AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel>Cancelar</AlertDialogCancel>
          <AlertDialogAction
            onClick={() => {
              financeActions.resetAll();
              toast.success("Dados restaurados");
            }}
          >
            Restaurar
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
}

function ChangePasswordItem() {
  const { changePassword } = useAuth();
  const [current, setCurrent] = useState("");
  const [next, setNext] = useState("");
  const [open, setOpen] = useState(false);

  function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const ok = changePassword(current, next);
    if (!ok) {
      toast.error("Senha atual incorreta");
      return;
    }
    toast.success("Senha alterada");
    setCurrent("");
    setNext("");
    setOpen(false);
  }

  return (
    <AlertDialog open={open} onOpenChange={setOpen}>
      <AlertDialogTrigger asChild>
        <DropdownMenuItem onSelect={(e) => e.preventDefault()}>
          <KeyRound className="size-4" /> Alterar senha
        </DropdownMenuItem>
      </AlertDialogTrigger>
      <AlertDialogContent>
        <form onSubmit={handleSubmit}>
          <AlertDialogHeader>
            <AlertDialogTitle>Alterar senha</AlertDialogTitle>
          </AlertDialogHeader>
          <div className="space-y-3 py-4">
            <input
              type="password"
              value={current}
              onChange={(e) => setCurrent(e.target.value)}
              placeholder="Senha atual"
              className="w-full rounded-lg border border-white/10 bg-white/5 px-4 py-2.5 text-sm text-foreground"
              required
            />
            <input
              type="password"
              value={next}
              onChange={(e) => setNext(e.target.value)}
              placeholder="Nova senha"
              className="w-full rounded-lg border border-white/10 bg-white/5 px-4 py-2.5 text-sm text-foreground"
              required
              minLength={1}
            />
          </div>
          <AlertDialogFooter>
            <AlertDialogCancel type="button">Cancelar</AlertDialogCancel>
            <AlertDialogAction type="submit">Salvar</AlertDialogAction>
          </AlertDialogFooter>
        </form>
      </AlertDialogContent>
    </AlertDialog>
  );
}

function LogoutItem() {
  const { logout } = useAuth();
  return (
    <DropdownMenuItem
      onSelect={() => logout()}
      className="text-destructive"
    >
      <LogOut className="size-4" /> Sair
    </DropdownMenuItem>
  );
}

function ClearItem() {
  return (
    <AlertDialog>
      <AlertDialogTrigger asChild>
        <DropdownMenuItem onSelect={(e) => e.preventDefault()} className="text-destructive">
          <Trash2 className="size-4" /> Limpar todos os lançamentos
        </DropdownMenuItem>
      </AlertDialogTrigger>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>Excluir todos os lançamentos?</AlertDialogTitle>
          <AlertDialogDescription>
            Naturezas e entidades serão mantidas, mas todas as movimentações serão apagadas.
            Esta ação não pode ser desfeita.
          </AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel>Cancelar</AlertDialogCancel>
          <AlertDialogAction
            className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
            onClick={() => {
              financeActions.clearAll();
              toast.success("Lançamentos excluídos");
            }}
          >
            Excluir tudo
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
}
