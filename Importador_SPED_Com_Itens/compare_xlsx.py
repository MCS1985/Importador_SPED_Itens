import xlrd, openpyxl
from collections import defaultdict

saam_path = r'D:\FERRAMENTAS_MCS_IA\Importador_SPED_Com_Itens\Tabela de Notas Fiscais - Registro C100 SPED Fiscal.xlsx'
export_path = r'D:\FERRAMENTAS_MCS_IA\Importador_SPED_Com_Itens\Relatorio_CFOP_2026-06-21-22-54-38.xlsx'

# ===== SAAM: extract notas =====
wb_saam = xlrd.open_workbook(saam_path)
ws_saam = wb_saam.sheet_by_index(0)
saam_notas = {}
for r in range(1, ws_saam.nrows):
    num_nota = str(ws_saam.cell_value(r, 1)).strip()
    vl_total = float(ws_saam.cell_value(r, 13) or 0)
    cnpj_part = str(ws_saam.cell_value(r, 5) or '').strip()
    operacao = str(ws_saam.cell_value(r, 2) or '').strip()
    chave = str(ws_saam.cell_value(r, 10) or '').strip()
    saam_notas[num_nota] = {'vl': vl_total, 'cnpj': cnpj_part, 'oper': operacao, 'chave': chave}

print('=== SAAM C100: %d notas ===' % len(saam_notas))
oper_types = defaultdict(int)
for n, d in saam_notas.items():
    oper_types[d['oper']] += 1
for k,v in sorted(oper_types.items()):
    print('  %s: %d' % (k, v))
print('  Valor total: R$ %.2f' % sum(d['vl'] for d in saam_notas.values()))

print()

# ===== EXPORT =====
wb_exp = openpyxl.load_workbook(export_path, data_only=True)
ws_exp = wb_exp.active
exp_rows = []
for r in range(2, ws_exp.max_row + 1):
    row = {
        'num_doc': str(ws_exp.cell(r, 9).value or '').strip(),
        'registro': str(ws_exp.cell(r, 8).value or '').strip(),
        'indicador': str(ws_exp.cell(r, 7).value or '').strip(),
        'vl_item': float(ws_exp.cell(r, 15).value or 0),
        'cfop': str(ws_exp.cell(r, 13).value or '').strip(),
        'chave_acesso': str(ws_exp.cell(r, 5).value or '').strip(),
    }
    exp_rows.append(row)

print('=== Export: %d linhas ===' % len(exp_rows))
per_indicador = defaultdict(int)
per_registro = defaultdict(int)
for r in exp_rows:
    per_indicador[r['indicador']] += 1
    per_registro[r['registro']] += 1
print('Por indicador:')
for k,v in sorted(per_indicador.items()):
    print('  %s: %d' % (k, v))
print('Por registro:')
for k,v in sorted(per_registro.items()):
    print('  %s: %d' % (k, v))

vl_entrada = sum(r['vl_item'] for r in exp_rows if r['indicador'] == 'Entrada')
vl_saida = sum(r['vl_item'] for r in exp_rows if r['indicador'] == 'Saida')
print()
print('Vl. Item Entrada: R$ %.2f' % vl_entrada)
print('Vl. Item Saida: R$ %.2f' % vl_saida)
print('Vl. Item Total: R$ %.2f' % (vl_entrada + vl_saida))

# ===== COMPARE by document number =====
def norm(s):
    s = s.strip()
    while len(s) > 1 and s[0] == '0':
        s = s[1:]
    return s

saam_docs = set(norm(k) for k in saam_notas.keys())
exp_docs = set(norm(r['num_doc']) for r in exp_rows 
               if r['num_doc'] and r['registro'] in ('C170', 'C190'))

only_saam = saam_docs - exp_docs
only_exp = exp_docs - saam_docs
common = saam_docs & exp_docs

print()
print('=== Comparacao por documento ===')
print('Documentos no SAAM: %d' % len(saam_docs))
print('Documentos no Export: %d' % len(exp_docs))
print('Comuns: %d' % len(common))
print('So no SAAM: %d' % len(only_saam))
print('So no Export: %d' % len(only_exp))

# Sum values
vl_saam_total = sum(d['vl'] for d in saam_notas.values())
vl_exp_saam_docs = sum(sum(r['vl_item'] for r in exp_rows if norm(r.get('num_doc','')) == d and r['registro'] in ('C170','C190'))
                       for d in common)
vl_exp_all = sum(r['vl_item'] for r in exp_rows if r['registro'] in ('C170','C190'))

print()
print('Valor total SAAM C100: R$ %.2f' % vl_saam_total)
print('Valor export docs comuns: R$ %.2f' % vl_exp_saam_docs)
print('Valor export total (C170+C190): R$ %.2f' % vl_exp_all)

# Detailed diff for common docs
print()
print('=== Diferencas por documento (valor) ===')
diffs = []
for d in common:
    vl_saam = saam_notas[[k for k in saam_notas if norm(k) == d][0]]['vl']
    vl_exp = sum(r['vl_item'] for r in exp_rows if norm(r['num_doc']) == d and r['registro'] in ('C170', 'C190'))
    diff = abs(vl_saam - vl_exp)
    if diff > 1:
        diffs.append((diff, d, vl_saam, vl_exp))
diffs.sort(reverse=True)
if diffs:
    print('Top 20 maiores diferencas:')
    for diff, d, v1, v2 in diffs[:20]:
        pct = abs(v1 - v2) / max(v1, v2, 1) * 100
        print('  Doc %s: SAAM=R$ %.2f vs Export=R$ %.2f (diff=R$ %.2f, %.1f%%)' % (d, v1, v2, diff, pct))
else:
    print('Nenhuma diferenca > 1.00 encontrada nos docs comuns')

# Missing in export
if only_saam:
    print()
    print('--- Documentos no SAAM mas nao no Export (primeiros 20) ---')
    for d in sorted(only_saam)[:20]:
        orig_key = [k for k in saam_notas if norm(k) == d][0]
        info = saam_notas[orig_key]
        print('  Doc %s: R$ %.2f | %s' % (d, info['vl'], info['oper'][:20]))

if only_exp:
    print()
    print('--- Documentos no Export mas nao no SAAM (primeiros 20) ---')
    for d in sorted(only_exp)[:20]:
        rows = [r for r in exp_rows if norm(r['num_doc']) == d]
        vl = sum(r['vl_item'] for r in rows)
        ind = rows[0]['indicador'] if rows else '?'
        print('  Doc %s: R$ %.2f | %s' % (d, vl, ind))
