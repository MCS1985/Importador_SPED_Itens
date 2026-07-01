import { useState, useRef, useMemo } from "react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { ScrollArea } from "@/components/ui/scroll-area";
import { AlertCircle, CheckCircle2, FileSpreadsheet, Upload, Download } from "lucide-react";
import { financeActions, useFinance, type Transaction } from "@/lib/finance-store";
import { BRL, formatDatePt } from "@/lib/format";
import { cn } from "@/lib/utils";
import { toast } from "sonner";
import * as XLSX from "xlsx";

type Props = { open: boolean; onOpenChange: (v: boolean) => void };

type Row = Record<string, string>;
type Parsed = {
  data: string;
  descricao: string;
  valor: number;
  natureza: string;
  cr?: string;
  entidade?: string;
  empresa?: string;
  obs?: string;
  _error?: string;
};

const COL_MAP: Record<string, string> = {
  data: "data",
  date: "data",
  descricao: "descricao",
  descrição: "descricao",
  descriminacao: "descricao",
  discriminacao: "descricao",
  histórico: "descricao",
  historico: "descricao",
  valor: "valor",
  valor_r: "valor",
  valor_receita: "valor",
  natureza: "natureza",
  codigo: "natureza",
  código: "natureza",
  cr: "cr",
  centro_resultado: "cr",
  "centro de resultado": "cr",
  entidade: "entidade",
  empresa: "empresa",
  obs: "obs",
  observacao: "obs",
  observação: "obs",
};

function normalizeHeader(h: string): string {
  return h.toLowerCase().replace(/[_\s-]+/g, "_").replace(/[^a-z0-9_]/g, "").trim();
}

function findColumn(headers: string[], candidates: string[]): string | undefined {
  for (const c of candidates) {
    const found = headers.find((h) => normalizeHeader(h) === normalizeHeader(c));
    if (found) return found;
  }
  return undefined;
}

function tryParseDate(v: unknown): string {
  if (v == null || v === "") return "";
  if (v instanceof Date && !isNaN(v.getTime())) {
    const y = v.getFullYear();
    const m = String(v.getMonth() + 1).padStart(2, "0");
    const d = String(v.getDate()).padStart(2, "0");
    return `${y}-${m}-${d}`;
  }
  const s = String(v).trim();
  if (/^\d{4}-\d{2}-\d{2}$/.test(s)) return s;
  if (/^\d{2}\/\d{2}\/\d{4}$/.test(s)) {
    const [d, m, y] = s.split("/");
    return `${y}-${m}-${d}`;
  }
  if (/^\d{2}\/\d{2}\/\d{2}$/.test(s)) {
    const [d, m, y] = s.split("/");
    return `20${y}-${m}-${d}`;
  }
  if (/^\d{8}$/.test(s)) {
    return `${s.slice(0, 4)}-${s.slice(4, 6)}-${s.slice(6, 8)}`;
  }
  const d = new Date(s);
  if (!isNaN(d.getTime())) return d.toISOString().slice(0, 10);
  return s;
}

function tryParseValor(v: unknown): number {
  if (v == null || v === "") return 0;
  const s = String(v).trim().replace(/[R$\s]/g, "").replace(/\./g, "").replace(",", ".");
  const n = parseFloat(s);
  return isNaN(n) ? 0 : n;
}

function parseRows(headers: string[], rows: Record<string, unknown>[], naturezaList: { codigo: string; descricao: string }[]): Parsed[] {
  const dataCol = findColumn(headers, ["data", "date"]);
  const descCol = findColumn(headers, ["descricao", "descrição", "descriminacao", "discriminacao", "histórico", "historico"]);
  const valorCol = findColumn(headers, ["valor", "valor_r", "valor_receita"]);
  const natCol = findColumn(headers, ["natureza", "codigo", "código"]);
  const crCol = findColumn(headers, ["cr", "centro_resultado", "centro de resultado"]);
  const entCol = findColumn(headers, ["entidade"]);
  const empCol = findColumn(headers, ["empresa"]);
  const obsCol = findColumn(headers, ["obs", "observacao", "observação"]);

  return rows.map((row) => {
    function cell(col: string | undefined): string {
      return col ? String(row[col] ?? "") : "";
    }
    const data = tryParseDate(cell(dataCol));
    const descricao = cell(descCol).trim();
    const valor = tryParseValor(cell(valorCol));
    const natureza = cell(natCol).trim();
    const cr = cell(crCol).trim() || undefined;
    const entidade = cell(entCol).trim() || undefined;
    const empresa = cell(empCol).trim() || undefined;
    const obs = cell(obsCol).trim() || undefined;

    const errors: string[] = [];
    if (!data) errors.push("Data inválida");
    if (!descricao) errors.push("Descrição vazia");
    if (!natureza) errors.push("Natureza vazia");

    let matchedCr = cr;
    if (natureza && !matchedCr) {
      const n = naturezaList.find((x) => x.codigo === natureza);
      if (n) matchedCr = n.descricao;
    }

    return {
      data: data || "2000-01-01",
      descricao: descricao || "(sem descrição)",
      valor,
      natureza: natureza || "?",
      cr: matchedCr,
      entidade,
      empresa,
      obs,
      _error: errors.length > 0 ? errors.join("; ") : undefined,
    };
  });
}

export function ImportDialog({ open, onOpenChange }: Props) {
  const { naturezas } = useFinance();
  const fileRef = useRef<HTMLInputElement>(null);
  const [filename, setFilename] = useState("");
  const [parsed, setParsed] = useState<Parsed[]>([]);
  const [loading, setLoading] = useState(false);

  const validCount = useMemo(() => parsed.filter((p) => !p._error).length, [parsed]);
  const hasErrors = useMemo(() => parsed.some((p) => p._error), [parsed]);

  function handleFile(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    setFilename(file.name);
    setLoading(true);

    const reader = new FileReader();
    reader.onload = (ev) => {
      try {
        const data = new Uint8Array(ev.target!.result as ArrayBuffer);
        const workbook = XLSX.read(data, { type: "array", cellDates: true, raw: true });
        const sheet = workbook.Sheets[workbook.SheetNames[0]];
        const json = XLSX.utils.sheet_to_json<Record<string, string>>(sheet, { defval: "" });
        if (json.length === 0) {
          toast.error("Planilha vazia");
          setParsed([]);
          return;
        }
        const headers = Object.keys(json[0]);
        const result = parseRows(headers, json, naturezas);
        setParsed(result);
      } catch (err) {
        toast.error("Erro ao ler arquivo: " + (err instanceof Error ? err.message : "desconhecido"));
        setParsed([]);
      } finally {
        setLoading(false);
      }
    };
    reader.onerror = () => {
      toast.error("Erro ao ler arquivo");
      setLoading(false);
    };
    reader.readAsArrayBuffer(file);
  }

  function handleImport() {
    const valid = parsed.filter((p) => !p._error);
    if (valid.length === 0) {
      toast.error("Nenhum lançamento válido para importar");
      return;
    }
    const txs: Omit<Transaction, "id">[] = valid.map((p) => ({
      data: p.data,
      descricao: p.descricao,
      valor: p.valor,
      natureza: p.natureza,
      cr: p.cr ?? "",
      entidade: p.entidade ?? "",
      empresa: p.empresa ?? "",
      obs: p.obs ?? "",
    }));
    financeActions.importTransactions(txs);
    toast.success(`${txs.length} lançamento${txs.length !== 1 ? "s" : ""} importado${txs.length !== 1 ? "s" : ""} com sucesso`);
    onOpenChange(false);
    setParsed([]);
    setFilename("");
    if (fileRef.current) fileRef.current.value = "";
  }

  function handleClose(v: boolean) {
    onOpenChange(v);
    if (!v) {
      setTimeout(() => {
        setParsed([]);
        setFilename("");
        if (fileRef.current) fileRef.current.value = "";
      }, 200);
    }
  }

  function downloadTemplate() {
    const wb = XLSX.utils.book_new();
    const headers = ["Data", "Descricao", "Valor", "Natureza", "CR", "Entidade", "Empresa", "Obs"];
    const sample = [
      ["15/01/2026", "Salário mensal", 5000.0, "REC1", "", "", "", ""],
      ["20/01/2026", "Supermercado", -850.0, "DESP1", "", "", "", ""],
      ["25/01/2026", "Combustível", -200.0, "OPF2", "", "", "", "Posto Shell"],
    ];
    const data = [headers, ...sample];
    const ws = XLSX.utils.aoa_to_sheet(data);
    ws["!cols"] = [
      { wch: 14 }, { wch: 35 }, { wch: 12 }, { wch: 10 }, { wch: 40 }, { wch: 20 }, { wch: 20 }, { wch: 25 },
    ];
    XLSX.utils.book_append_sheet(wb, ws, "Planilha1");
    XLSX.writeFile(wb, "modelo_importacao.xlsx");
  }

  return (
    <Dialog open={open} onOpenChange={handleClose}>
      <DialogContent className="max-w-3xl max-h-[90vh] flex flex-col">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <FileSpreadsheet className="size-5" />
            Importar lançamentos
          </DialogTitle>
          <DialogDescription>
            Selecione um arquivo <strong>.xlsx</strong> ou <strong>.csv</strong> com as colunas: Data, Descrição, Valor, Natureza (e opcionais: CR, Entidade, Empresa, Obs).
          </DialogDescription>
        </DialogHeader>

        <div className="flex items-center gap-3">
          <input
            ref={fileRef}
            type="file"
            accept=".xlsx,.csv"
            onChange={handleFile}
            className="hidden"
            id="import-file"
          />
          <label htmlFor="import-file" className="cursor-pointer">
            <div className="flex items-center gap-2 rounded-lg border border-border bg-muted/30 px-4 py-2 text-sm text-muted-foreground hover:bg-muted/50">
              <Upload className="size-4" />
              {filename || "Escolher arquivo..."}
            </div>
          </label>
          <Button variant="outline" size="sm" onClick={downloadTemplate}>
            <Download className="size-4" /> Baixar modelo
          </Button>
          {filename && (
            <span className="text-xs text-muted-foreground">
              {parsed.length} linha{parsed.length !== 1 ? "s" : ""} encontrada{parsed.length !== 1 ? "s" : ""}
            </span>
          )}
        </div>

        {loading && <div className="text-sm text-muted-foreground">Lendo arquivo...</div>}

        {parsed.length > 0 && (
          <>
            <ScrollArea className="flex-1 rounded-lg border border-border">
              <table className="w-full text-xs">
                <thead>
                  <tr className="border-b border-border bg-muted/30 text-muted-foreground">
                    <th className="px-2 py-1.5 text-left">Data</th>
                    <th className="px-2 py-1.5 text-left">Descrição</th>
                    <th className="px-2 py-1.5 text-left">Natureza</th>
                    <th className="px-2 py-1.5 text-left">CR</th>
                    <th className="px-2 py-1.5 text-right">Valor</th>
                    <th className="px-2 py-1.5 w-6" />
                  </tr>
                </thead>
                <tbody>
                  {parsed.slice(0, 500).map((p, i) => (
                    <tr key={i} className={cn("border-b border-border/50", p._error && "bg-destructive/5")}>
                      <td className="px-2 py-1 font-mono">{p.data}</td>
                      <td className="max-w-[200px] truncate px-2 py-1">{p.descricao}</td>
                      <td className="px-2 py-1 font-mono">{p.natureza}</td>
                      <td className="max-w-[160px] truncate px-2 py-1 text-muted-foreground">{p.cr || "—"}</td>
                      <td className={cn("px-2 py-1 text-right font-mono", p.valor >= 0 ? "text-primary" : "text-destructive")}>
                        {p.valor >= 0 ? "+" : "−"}{BRL.format(Math.abs(p.valor))}
                      </td>
                      <td className="px-2 py-1">
                        {p._error ? (
                          <span title={p._error}><AlertCircle className="size-3.5 text-destructive" /></span>
                        ) : (
                          <CheckCircle2 className="size-3.5 text-primary" />
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
              {parsed.length > 500 && (
                <div className="px-2 py-2 text-center text-xs text-muted-foreground">
                  Mostrando 500 de {parsed.length} linhas
                </div>
              )}
            </ScrollArea>

            <div className="flex items-center justify-between gap-3 border-t border-border pt-3">
              <div className="text-xs text-muted-foreground">
                {hasErrors && (
                  <span className="flex items-center gap-1 text-destructive">
                    <AlertCircle className="size-3.5" />
                    {parsed.length - validCount} linha{parsed.length - validCount !== 1 ? "s" : ""} com erro{parsed.length - validCount !== 1 ? "s" : ""}
                  </span>
                )}
                <span className="flex items-center gap-1 text-primary">
                  <CheckCircle2 className="size-3.5" />
                  {validCount} linha{validCount !== 1 ? "s" : ""} válida{validCount !== 1 ? "s" : ""}
                </span>
              </div>
              <div className="flex gap-2">
                <Button variant="outline" onClick={() => handleClose(false)}>
                  Cancelar
                </Button>
                <Button onClick={handleImport} disabled={validCount === 0}>
                  Importar {validCount > 0 && `(${validCount})`}
                </Button>
              </div>
            </div>
          </>
        )}
      </DialogContent>
    </Dialog>
  );
}
