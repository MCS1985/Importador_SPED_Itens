# Documentação do Relatório `Relatorio_CFOP_SAAM.sql`

## O que este script faz?

Este script gera um **relatório de auditoria fiscal cruzada**. Ele compara dados de **21 tipos diferentes de documentos fiscais** (notas fiscais, transportes, energia, telecomunicações, etc.) e calcula contribuições de PIS e COFINS.

O resultado é uma tabela resumo com quantidades, valores totais, impostos e bases de cálculo, agrupados por tipo de documento, CFOP, CST, alíquota, etc.

---

## Como executar

Cole o conteúdo do arquivo `Relatorio_CFOP_SAAM.sql` na rotina **11.4.4** do SAAM e clique em **Executar**. O resultado aparece na aba **Resultados** e pode ser exportado para Excel.

---

## Estrutura do script

O script tem 3 partes principais:

```
DATA_POOL (21 blocos UNION ALL)
    │
    ▼
BASE (cálculos derivados)
    │
    ▼
SELECT FINAL (agrupamento e ordenação)
```

### 1. DATA_POOL

São **21 blocos SELECT** conectados por `UNION ALL`. Cada bloco consulta uma tabela diferente:

| # | Registro | Tabela | Origem |
|---|----------|--------|--------|
| 01 | C170 | reg_c170 | FISCAL - Mercadorias |
| 02 | C500 | reg_c500 | FISCAL - Energia/Água |
| 03 | D100 | reg_d100 | FISCAL - Transportes |
| 04 | D500 | reg_d500 | FISCAL - Telecom |
| 05 | D700 | reg_d700 | FISCAL - NFCom |
| 06 | A170 | pc_a170 | CONTRIB - Serviços |
| 07 | C170 | pc_c170 | CONTRIB - Mercadorias |
| 08 | C175 | pc_c175 | CONTRIB - Vendas Consumidor |
| 09 | C180 | pc_c181 | CONTRIB - Saídas Consolidadas |
| 10 | C190 | pc_c191 | CONTRIB - Entradas Consolidadas |
| 11 | C500 | pc_c500 | CONTRIB - Energia/Água |
| 12 | C870 | pc_c870 | CONTRIB - ECF |
| 13 | D100 | pc_d100 | CONTRIB - Transportes Entrada |
| 14 | D200 | pc_d200 | CONTRIB - Transportes Saída |
| 15 | D500 | pc_d500 | CONTRIB - Telecom |
| 16 | F100 | pc_f100 | CONTRIB - Demais Documentos |
| 17 | F120 | pc_f120 | CONTRIB - Ativo Imobilizado Depreciação |
| 18 | F130 | pc_f130 | CONTRIB - Ativo Imobilizado Aquisição |
| 19 | F150 | pc_f150 | CONTRIB - Estoque Abertura |
| 20 | F500 | pc_f500 | CONTRIB - Receitas Próprias |
| 21 | F550 | pc_f550 | CONTRIB - Receitas por Operação |

Cada bloco SELECT retorna **as mesmas 21 colunas** com os mesmos nomes (aliases). O UNION ALL empilha os resultados um abaixo do outro.

### 2. BASE

Acrescenta colunas calculadas:
- **periodo_competencia, ano_competencia, mes_competencia** — extraídos da `dt_ref`
- **bc_pis_cof_calculada_base** — base de cálculo com proteção GREATEST contra negativos

### 3. SELECT FINAL

- Limpa os campos **CST** (remove lixos como '0,00') e **Nat. BC. Créd.** (substitui vazios por 'N/A')
- Agrupa os dados por chave (período, origem, registro, CFOP, CST, alíquota, etc.)
- Calcula totais (COUNT, SUM) para cada grupo
- Ordena por Ano, Mês, Registro

---

## Como adicionar um novo tipo de documento?

Adicione um novo bloco `SELECT ... UNION ALL` dentro do DATA_POOL, seguindo o mesmo formato dos 21 existentes. São necessários:

1. O `SELECT` com as 21 colunas (sped_origem, dt_ref, sentido, registro, cfop, cst, etc.)
2. O `FROM` com a tabela principal e seus `LEFT JOINs`
3. Um `UNION ALL` antes do bloco (exceto para o primeiro)

## Como remover um tipo de documento?

Apague o bloco `SELECT ... UNION ALL` correspondente dentro do DATA_POOL.

## Como alterar um campo para todos os documentos?

Edite a coluna desejada em **cada um dos 21 blocos** (infelizmente não há como centralizar em SQL puro).

---

## Segurança embutida

- **`vl_liquido`** — nunca fica negativo (GREATEST)
- **`bc_pis_cof_escriturada`, `v_pis`, `v_cof`** — nunca ficam negativos (GREATEST)
- **`bc_pis_cof_calculada_base`** — nunca fica negativa (GREATEST)
- **Divisão por zero** — protegida com CASE WHEN
- **Valores nulos** — convertidos para zero com COALESCE

---

# Versão autônoma em DuckDB — `Relatorio_CFOP_SAAM_DuckDB.sql`

## O que é?

Uma versão **standalone** do relatório que roda **diretamente em DuckDB**, sem precisar de PostgreSQL/SAAM. Lê os arquivos SPED PISCOFINS (.txt) direto de uma pasta e produz o mesmo relatório de 28 colunas.

## Quando usar?

- Quando o SAAM não está disponível
- Para auditoria rápida em ambiente local
- Para integração com pipelines Python/outros via SQL puro
- Para processar muitos arquivos de uma vez (DuckDB é colunar e muito rápido)

## Pré-requisitos

- **DuckDB CLI** v1.0+ (testado com v1.5.3 Variegata)
  - Download: <https://github.com/duckdb/duckdb/releases> (`duckdb_cli-windows-amd64.zip`)
  - Extrair `duckdb.exe` em uma pasta qualquer (ex.: `C:\duckdb\`)
- **Nenhuma instalação adicional** — o arquivo `.sql` é auto-contido

## Como executar

### 1. Modo interativo (vê o resultado na tela)

```powershell
duckdb -c ".read 'D:/FERRAMENTAS_MCS_IA/Relatorio_CFOP_SAAM_DuckDB.sql'"
```

### 2. Modo batch (exporta para CSV)

Use o arquivo wrapper **`Relatorio_CFOP_SAAM_ExportarCSV.sql`** (gerado automaticamente a partir do principal). Basta rodar:

```powershell
duckdb -c ".read 'D:/FERRAMENTAS_MCS_IA/Relatorio_CFOP_SAAM_ExportarCSV.sql'"
```

O CSV será gerado em `D:/FERRAMENTAS_MCS_IA/Laudo/Relatorio_CFOP_SAAM.csv` com separador `;` e encoding UTF-8 (pronto para Excel BR).

### 3. Via Python

```python
import duckdb
con = duckdb.connect()
with open('D:/FERRAMENTAS_MCS_IA/Relatorio_CFOP_SAAM_DuckDB.sql') as f:
    con.execute(f.read())
df = con.execute("SELECT * FROM ...").df()  # opcional: salvar como Parquet, etc.
```

## Como alterar a pasta dos SPEDs

Edite a **linha 32** do arquivo `.sql`:

```sql
SET VARIABLE caminho_sped = 'D:/FERRAMENTAS_MCS_IA/Arquivos_SPED/Contribuições/*.txt';
```

Use **forward slashes** (`/`) e o glob `*.txt` no final.

## Diferenças em relação à versão SAAM/PostgreSQL

| Item | SAAM/PostgreSQL | DuckDB |
|------|-----------------|--------|
| Dependência externa | PostgreSQL/SAAM | Nenhuma (embedded) |
| Origem dos dados | Tabelas `reg_c170`, `pc_c170`, etc. | Arquivos `.txt` lidos com `read_csv` |
| CTE `_sped_raw` | Não existe | Lê todos os `*.txt` da pasta como uma tabela de 50 colunas (`c00..c49`) |
| CTE `_sped` | Não existe | Filtra `c01` (registro) e padroniza encoding |
| Tabelas por registro | `reg_c170`, `pc_c170` | `_t_c170` (geradas a partir de `_sped` filtrando por `c01='C170'`) |
| Vínculo pai–filho | Foreign keys do banco | `SUM(CASE) OVER (PARTITION BY filename ORDER BY gln)` para gerar group_id |
| Blocos fiscais (C100/D100/etc do EFD ICMS) | Sim | **Não** — esta versão processa **somente Contribuições** (PISCOFINS) |
| Macro `num(v)` | Conversão inline | Converte vírgula→ponto e faz `TRY_CAST` retornando 0 em falha |
| Encoding | UTF-8 do banco | Lê SPEDs (Latin-1) como `encoding='utf-8'` com `strict_mode=false` |

## Decisões técnicas importantes

### Encoding SPED

Arquivos SPED são oficialmente **Latin-1** (ISO-8859-1), mas o DuckDB **rejeita** estritamente a leitura como Latin-1 quando há assinatura digital binária no fim do arquivo. Solução aplicada:

```sql
encoding    = 'utf-8',     -- obrigatório
strict_mode = false,       -- aceita bytes não-UTF-8 sem erro
ignore_errors = true,      -- pula linhas malformadas
```

Isso funciona porque os campos usados no relatório (REG, CFOP, CST, números, datas) são **ASCII puro**. Apenas `RAZAO_SOCIAL` e `ENDERECO` (não usados) podem ter acentos garbled.

### Detecção automática de colunas

O parâmetro `auto_detect=true` faz o DuckDB farejar a estrutura do CSV lendo uma amostra. Como a **assinatura digital** no final do SPED é binária e tem `|` embutidos (não delimitados por `\n`), o sniffer confunde o número de colunas. Solução:

```sql
auto_detect = false,
columns = {'c00':'VARCHAR', ..., 'c49':'VARCHAR'}  -- 50 colunas fixas
```

### Filtro de blocos de Contribuições

A pasta `D:/FERRAMENTAS_MCS_IA/Arquivos_SPED/` contém **apenas** a subpasta `Contribuições/` (PISCOFINS). Os 5 blocos fiscais (C100, C500, D100, D500, D700 do EFD ICMS) foram **removidos** desta versão. Os 16 blocos de Contribuições (A170, C170, C175, C180, C190, C500, C870, D100, D200, D500, F100, F120, F130, F150, F500, F550) foram **mantidos** e adaptados.

## Performance

- **46 arquivos SPED** processados em **~7,5 segundos** (DuckDB CLI v1.5.3, Windows 10, i7)
- Tempo escala **linearmente** com o número total de linhas nos SPEDs
- Memória: usa RAM disponível; ~2 GB confortavelmente para centenas de arquivos

## Saída

O relatório produz **28 colunas** idênticas à versão SAAM:

```
chave_unica | Período | Ano | Mês | Trimestre | sped_origem | sentido |
Registro | CFOP | CST | Alíq. Pis do SPED | Alíq. Cofins do SPED |
Nat. BC. Créd. | status_conferencia | qtd_registros | total_item |
total_desconto | total_liquido | total_bc_icms | total_icms |
total_icms_st | total_ipi | total_iss | bc_pis_cof_calculada |
bc_pis_cof_escriturada | total_pis | total_cof | total_pis_cofins
```

A coluna `status_conferencia` é fixada em `'Não conferido'` (não há flag de conferência no SPED cru; é uma feature do SAAM).

## Limitações conhecidas

- **Acentos em `RAZAO_SOCIAL`/`ENDERECO`** podem aparecer garbled (UTF-8 vs Latin-1) — irrelevante para o relatório
- **Sem update/insert** — relatório é read-only
- **CTAS não funciona após `WITH`** em DuckDB — se quiser salvar resultado em tabela, use o `COPY (...) TO ...` no fim do arquivo
- **Opção `ENCODING` não existe em `COPY` (write)** — só aceita em `read_csv`. O CSV de saída é gravado em UTF-8 nativo do DuckDB.
- **Não coloque `;` antes do `) TO`** dentro de `COPY (...)` — o `;` fecha o statement e o `) TO` vira erro de sintaxe.

---

# Landpage web — `analisador_sped.html`

## O que é?

Uma **página web local** (single-file HTML) que roda o relatório **diretamente no navegador**, sem servidor, sem instalar nada. Você arrasta os SPEDs e vê a tabela completa com filtros, totais, e exportação para CSV.

## Como usar

1. **Abra o arquivo** `D:\FERRAMENTAS_MCS_IA\analisador_sped.html` no navegador (Chrome, Edge ou Firefox)
2. **Aguarde** o DuckDB-WASM carregar (1ª vez: ~30s para baixar do CDN; depois: instantâneo do cache)
3. **Arraste** os arquivos `.txt` do SPED para a área de upload (ou clique para selecionar)
4. **Aguarde** o processamento (~8s para 46 arquivos, 665 linhas)
5. **Veja** a tabela completa, filtre por período/CFOP/registro, ordene clicando no cabeçalho
6. **Exporte** para CSV com 1 clique

## Recursos

- **Drag-and-drop** múltiplos arquivos
- **28 colunas** completas com formatação brasileira (R$ X.XXX,XX, datas DD/MM/YYYY, %)
- **Filtros**: ano, mês, registro, CFOP, CST, busca textual
- **Ordenação** clicando em qualquer cabeçalho
- **Cards de estatísticas** no topo: totais de PIS, COFINS, valor bruto, etc.
- **Linha de totais** no rodapé da tabela
- **Export CSV** com separador `;` e BOM UTF-8 (abre direto no Excel)
- **Tema claro/escuro** automático (segue preferência do sistema)
- **Tudo no navegador** — nenhum dado sai do seu PC

## Arquitetura técnica

- **DuckDB-WASM v1.29.0** carregado via CDN (`cdn.jsdelivr.net`)
- **SQL completo** (50KB) embedded como template literal
- **Processamento 100% client-side** — usa web workers
- **Virtual file system** do DuckDB-WASM registra os arquivos dropados

## Como regenerar a partir dos fontes

Se você modificar o SQL em `Relatorio_CFOP_SAAM_DuckDB.sql` e quiser atualizar a landpage:

1. Edite `Relatorio_CFOP_SAAM_DuckDB.sql` (linha 32: caminho SPED; linhas 1140-1247: query final)
2. Use o script PowerShell abaixo para reembutir o SQL no HTML (substitui o trecho entre `SQL_TEMPLATE = \`` e `\``;)
3. Abra o HTML no navegador

## Limitações conhecidas

- **Primeira execução** baixa ~10MB do CDN (uma vez)
- **Navegadores antigos** (IE, Edge Legacy) não suportam — use Chrome/Edge/Firefox atuais
- **CORS file://** — funciona direto com duplo-clique (file://), mas alguns browsers podem bloquear. Se não funcionar, sirva via `python -m http.server` na pasta
- **Sem upload para servidor** — todo processamento é local (privacidade total)
- **Não imprime bem** o rodapé de totais em algumas impressoras — exportar CSV é mais confiável
