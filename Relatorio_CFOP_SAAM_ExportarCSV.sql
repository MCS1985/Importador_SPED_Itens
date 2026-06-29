-- =====================================================================================
-- Relatorio_CFOP_SAAM_ExportarCSV.sql
-- Wrapper que exporta o relatório direto para CSV.
-- Uso: duckdb -c ".read D:/FERRAMENTAS_MCS_IA/Relatorio_CFOP_SAAM_ExportarCSV.sql"
-- =====================================================================================

/* ====================================================================================
   PROJETO: AUDITORIA FISCAL E CONTRIBUIÇÕES - DUCKDB STANDALONE V1.0
   DATA: 2026-06-05
   VERSÃO: 1.0 (DuckDB - leitura direta dos .txt SPED PISCOFINS)
   OBJETIVO: Mesma saída do Relatorio_CFOP_SAAM.sql (28 colunas), porém lendo
             direto da pasta de SPEDs sem precisar carregar no PostgreSQL.

   PRÉ-REQUISITOS:
   1. DuckDB CLI instalado (https://duckdb.org/docs/installation/).
      Windows: baixe duckdb_cli-windows-amd64.zip, extraia, adicione ao PATH.
   2. Pasta com arquivos SPED PISCOFINS .txt.

   USO:
       duckdb -c ".read D:/FERRAMENTAS_MCS_IA/Relatorio_CFOP_SAAM_DuckDB.sql"
   ou interativo:
       duckdb
       D .read D:/FERRAMENTAS_MCS_IA/Relatorio_CFOP_SAAM_DuckDB.sql

   Para gerar CSV/Excel, descomente o bloco COPY no fim do arquivo.

   ESCOPO: Apenas blocos de CONTRIBUIÇÕES (registros 06–21 do SQL original).
   Os 5 blocos FISCAIS (EFD ICMS/IPI) foram REMOVIDOS — a pasta indicada
   só contém PISCOFINS.
   ==================================================================================== */

------------------------------------------------------------------------------
-- 0. CONFIGURAÇÃO
------------------------------------------------------------------------------
SET preserve_insertion_order = true;

-- Altere aqui se mudar a pasta dos SPEDs:
SET VARIABLE caminho_sped = 'D:/FERRAMENTAS_MCS_IA/Arquivos_SPED/Contribuições/*.txt';

------------------------------------------------------------------------------
-- 1. LEITURA RAW DOS .TXT (delim=|, latin-1, padding de nulos)
--    Cada linha do SPED vira uma linha aqui, com 50 colunas c00..c49.
--    c00 é o vazio antes do primeiro pipe; c01 é o REG (0000, C100, etc.).
------------------------------------------------------------------------------
CREATE OR REPLACE TEMP TABLE _sped_raw AS
SELECT
    filename,
    ROW_NUMBER() OVER () AS gln,
    NULLIF(c01, '') AS reg,
    c02, c03, c04, c05, c06, c07, c08, c09, c10,
    c11, c12, c13, c14, c15, c16, c17, c18, c19, c20,
    c21, c22, c23, c24, c25, c26, c27, c28, c29, c30,
    c31, c32, c33, c34, c35, c36, c37, c38, c39, c40,
    c41, c42, c43, c44, c45, c46, c47, c48, c49
FROM read_csv(
    getvariable('caminho_sped'),
    delim       = '|',
    quote       = '',
    escape      = '',
    header      = false,
    encoding    = 'utf-8',
    null_padding= true,
    ignore_errors = true,
    filename    = true,
    strict_mode = false,
    auto_detect = false,
    -- OBS: SPED é Latin-1. Lemos como UTF-8 + strict_mode=false porque os
    -- campos usados (REG/CFOP/CST/números/datas) são ASCII puro. Apenas
    -- razão social/endereço (não usados) ficariam com acentos garbled.
    -- auto_detect=false é obrigatório porque DuckDB sniffer rejeita
    -- assinatura digital binária no fim dos SPED.
    columns     = {
        'c00':'VARCHAR','c01':'VARCHAR','c02':'VARCHAR','c03':'VARCHAR','c04':'VARCHAR',
        'c05':'VARCHAR','c06':'VARCHAR','c07':'VARCHAR','c08':'VARCHAR','c09':'VARCHAR',
        'c10':'VARCHAR','c11':'VARCHAR','c12':'VARCHAR','c13':'VARCHAR','c14':'VARCHAR',
        'c15':'VARCHAR','c16':'VARCHAR','c17':'VARCHAR','c18':'VARCHAR','c19':'VARCHAR',
        'c20':'VARCHAR','c21':'VARCHAR','c22':'VARCHAR','c23':'VARCHAR','c24':'VARCHAR',
        'c25':'VARCHAR','c26':'VARCHAR','c27':'VARCHAR','c28':'VARCHAR','c29':'VARCHAR',
        'c30':'VARCHAR','c31':'VARCHAR','c32':'VARCHAR','c33':'VARCHAR','c34':'VARCHAR',
        'c35':'VARCHAR','c36':'VARCHAR','c37':'VARCHAR','c38':'VARCHAR','c39':'VARCHAR',
        'c40':'VARCHAR','c41':'VARCHAR','c42':'VARCHAR','c43':'VARCHAR','c44':'VARCHAR',
        'c45':'VARCHAR','c46':'VARCHAR','c47':'VARCHAR','c48':'VARCHAR','c49':'VARCHAR'
    }
);

------------------------------------------------------------------------------
-- 2. NUMERAÇÃO POR ARQUIVO + GROUP IDs PARA LINKAGEM PAI-FILHO
--    g_xxxx incrementa a cada novo registro pai, "carimbando" os filhos
--    seguintes com o mesmo número.
------------------------------------------------------------------------------
CREATE OR REPLACE TEMP TABLE _sped AS
SELECT
    *,
    ROW_NUMBER() OVER (PARTITION BY filename ORDER BY gln) AS rn,
    SUM(CASE WHEN reg = 'A100' THEN 1 ELSE 0 END)
        OVER (PARTITION BY filename ORDER BY gln ROWS UNBOUNDED PRECEDING) AS g_a100,
    SUM(CASE WHEN reg = 'C100' THEN 1 ELSE 0 END)
        OVER (PARTITION BY filename ORDER BY gln ROWS UNBOUNDED PRECEDING) AS g_c100,
    SUM(CASE WHEN reg = 'C180' THEN 1 ELSE 0 END)
        OVER (PARTITION BY filename ORDER BY gln ROWS UNBOUNDED PRECEDING) AS g_c180,
    SUM(CASE WHEN reg = 'C190' THEN 1 ELSE 0 END)
        OVER (PARTITION BY filename ORDER BY gln ROWS UNBOUNDED PRECEDING) AS g_c190,
    SUM(CASE WHEN reg = 'C500' THEN 1 ELSE 0 END)
        OVER (PARTITION BY filename ORDER BY gln ROWS UNBOUNDED PRECEDING) AS g_c500,
    SUM(CASE WHEN reg = 'D100' THEN 1 ELSE 0 END)
        OVER (PARTITION BY filename ORDER BY gln ROWS UNBOUNDED PRECEDING) AS g_d100,
    SUM(CASE WHEN reg = 'D200' THEN 1 ELSE 0 END)
        OVER (PARTITION BY filename ORDER BY gln ROWS UNBOUNDED PRECEDING) AS g_d200,
    SUM(CASE WHEN reg = 'D500' THEN 1 ELSE 0 END)
        OVER (PARTITION BY filename ORDER BY gln ROWS UNBOUNDED PRECEDING) AS g_d500
FROM _sped_raw
WHERE reg IS NOT NULL
  AND length(reg) = 4;

------------------------------------------------------------------------------
-- 3. MACRO para converter texto SPED em DECIMAL (vírgula como separador)
------------------------------------------------------------------------------
CREATE OR REPLACE TEMP MACRO num(v) AS
    COALESCE(
        TRY_CAST(REPLACE(NULLIF(TRIM(v), ''), ',', '.') AS DECIMAL(18,6)),
        0
    );

------------------------------------------------------------------------------
-- 4. EXTRATORES POR REGISTRO (cada CTE tipa os campos via macro num())
--    Esses TEMP TABLEs equivalem às tabelas pc_xxxx do SAAM.
------------------------------------------------------------------------------

-- Header 0000 (uma linha por arquivo, fornece dt_fim no formato DDMMAAAA)
CREATE OR REPLACE TEMP TABLE _t_0000 AS
SELECT filename, TRIM(c07) AS dt_fim
FROM _sped WHERE reg = '0000';

-- A100 (parente do A170 - serviços)
CREATE OR REPLACE TEMP TABLE _t_a100 AS
SELECT filename, g_a100,
       TRIM(c02) AS ind_oper,
       num(c12)  AS vl_doc,
       num(c14)  AS vl_desc,
       num(c21)  AS vl_iss
FROM _sped WHERE reg = 'A100';

-- A170 (itens de serviços)
CREATE OR REPLACE TEMP TABLE _t_a170 AS
SELECT filename, g_a100,
       num(c05) AS vl_item,
       num(c06) AS vl_desc,
       TRIM(c07) AS nat_bc_cred,
       TRIM(c09) AS cst_pis,
       num(c10) AS vl_bc_pis,
       num(c11) AS aliq_pis,
       num(c12) AS vl_pis,
       TRIM(c13) AS cst_cofins,
       num(c14) AS vl_bc_cofins,
       num(c15) AS aliq_cofins,
       num(c16) AS vl_cofins
FROM _sped WHERE reg = 'A170';

-- C100 (parente do C170/C175 - mercadorias)
CREATE OR REPLACE TEMP TABLE _t_c100 AS
SELECT filename, g_c100,
       TRIM(c02) AS ind_oper,
       num(c12)  AS vl_doc,
       num(c14)  AS vl_desc,
       num(c21)  AS vl_bc_icms,
       num(c22)  AS vl_icms,
       num(c23)  AS vl_bc_icms_st,
       num(c24)  AS vl_icms_st
FROM _sped WHERE reg = 'C100';

-- C170 (itens de mercadorias)
CREATE OR REPLACE TEMP TABLE _t_c170 AS
SELECT filename, g_c100,
       num(c07)  AS vl_item,
       num(c08)  AS vl_desc,
       TRIM(c10) AS cst_icms,
       TRIM(c11) AS cfop,
       num(c13)  AS vl_bc_icms,
       num(c15)  AS vl_icms,
       num(c18)  AS vl_icms_st,
       num(c24)  AS vl_ipi,
       TRIM(c25) AS cst_pis,
       num(c26)  AS vl_bc_pis,
       num(c27)  AS aliq_pis,
       num(c30)  AS vl_pis,
       TRIM(c31) AS cst_cofins,
       num(c32)  AS vl_bc_cofins,
       num(c33)  AS aliq_cofins,
       num(c36)  AS vl_cofins
FROM _sped WHERE reg = 'C170';

-- C175 (vendas consumidor)
CREATE OR REPLACE TEMP TABLE _t_c175 AS
SELECT filename, g_c100,
       TRIM(c02) AS cfop,
       num(c03)  AS vl_opr,
       num(c04)  AS vl_desc,
       TRIM(c05) AS cst_pis,
       num(c06)  AS vl_bc_pis,
       num(c07)  AS aliq_pis,
       num(c08)  AS vl_pis,
       TRIM(c09) AS cst_cofins,
       num(c10)  AS vl_bc_cofins,
       num(c11)  AS aliq_cofins,
       num(c12)  AS vl_cofins
FROM _sped WHERE reg = 'C175';

-- C180 (parente do C181/C185 - vendas consolidadas)
CREATE OR REPLACE TEMP TABLE _t_c180 AS
SELECT filename, g_c180
FROM _sped WHERE reg = 'C180';

-- C181 (PIS C180)
CREATE OR REPLACE TEMP TABLE _t_c181 AS
SELECT filename, g_c180,
       TRIM(c02) AS cst_pis,
       TRIM(c03) AS cfop,
       num(c04)  AS vl_item,
       num(c05)  AS vl_desc,
       num(c06)  AS vl_bc_pis,
       num(c07)  AS aliq_pis,
       num(c10)  AS vl_pis
FROM _sped WHERE reg = 'C181';

-- C185 (COFINS C180)
CREATE OR REPLACE TEMP TABLE _t_c185 AS
SELECT filename, g_c180,
       TRIM(c02) AS cst_cofins,
       TRIM(c03) AS cfop,
       num(c04)  AS vl_item,
       num(c05)  AS vl_desc,
       num(c06)  AS vl_bc_cofins,
       num(c07)  AS aliq_cofins,
       num(c10)  AS vl_cofins
FROM _sped WHERE reg = 'C185';

-- C190 (parente do C191/C195 - entradas consolidadas)
CREATE OR REPLACE TEMP TABLE _t_c190 AS
SELECT filename, g_c190
FROM _sped WHERE reg = 'C190';

-- C191 (PIS C190)
CREATE OR REPLACE TEMP TABLE _t_c191 AS
SELECT filename, g_c190,
       TRIM(c03) AS cst_pis,
       TRIM(c04) AS cfop,
       num(c05)  AS vl_item,
       num(c06)  AS vl_desc,
       num(c07)  AS vl_bc_pis,
       num(c08)  AS aliq_pis,
       num(c11)  AS vl_pis
FROM _sped WHERE reg = 'C191';

-- C195 (COFINS C190)
CREATE OR REPLACE TEMP TABLE _t_c195 AS
SELECT filename, g_c190,
       TRIM(c03) AS cst_cofins,
       TRIM(c04) AS cfop,
       num(c05)  AS vl_item,
       num(c06)  AS vl_desc,
       num(c07)  AS vl_bc_cofins,
       num(c08)  AS aliq_cofins,
       num(c11)  AS vl_cofins
FROM _sped WHERE reg = 'C195';

-- C500 (energia/água/comb. - parente C501/C505)
CREATE OR REPLACE TEMP TABLE _t_c500 AS
SELECT filename, g_c500,
       num(c11)  AS vl_doc,
       num(c18)  AS vl_icms
FROM _sped WHERE reg = 'C500';

-- C501 (PIS C500)
CREATE OR REPLACE TEMP TABLE _t_c501 AS
SELECT filename, g_c500,
       TRIM(c02) AS cst_pis,
       num(c05)  AS vl_bc_pis,
       num(c06)  AS aliq_pis,
       num(c07)  AS vl_pis
FROM _sped WHERE reg = 'C501';

-- C505 (COFINS C500)
CREATE OR REPLACE TEMP TABLE _t_c505 AS
SELECT filename, g_c500,
       TRIM(c02) AS cst_cofins,
       num(c05)  AS vl_bc_cofins,
       num(c06)  AS aliq_cofins,
       num(c07)  AS vl_cofins
FROM _sped WHERE reg = 'C505';

-- C870 (ECF - autocontido)
CREATE OR REPLACE TEMP TABLE _t_c870 AS
SELECT filename,
       TRIM(c02) AS cfop,
       num(c03)  AS vl_item,
       num(c04)  AS vl_desc,
       TRIM(c05) AS cst_pis,
       num(c06)  AS vl_bc_pis,
       num(c07)  AS aliq_pis,
       num(c08)  AS vl_pis,
       TRIM(c09) AS cst_cofins,
       num(c10)  AS vl_bc_cofins,
       num(c11)  AS aliq_cofins,
       num(c12)  AS vl_cofins
FROM _sped WHERE reg = 'C870';

-- D100 (transporte entrada - parente D101/D105)
CREATE OR REPLACE TEMP TABLE _t_d100 AS
SELECT filename, g_d100,
       TRIM(c02) AS ind_oper,
       num(c15)  AS vl_doc,
       num(c20)  AS vl_icms
FROM _sped WHERE reg = 'D100';

-- D101 (PIS D100)
CREATE OR REPLACE TEMP TABLE _t_d101 AS
SELECT filename, g_d100,
       TRIM(c04) AS cst_pis,
       num(c06)  AS vl_bc_pis,
       num(c07)  AS aliq_pis,
       num(c08)  AS vl_pis
FROM _sped WHERE reg = 'D101';

-- D105 (COFINS D100)
CREATE OR REPLACE TEMP TABLE _t_d105 AS
SELECT filename, g_d100,
       TRIM(c04) AS cst_cofins,
       num(c06)  AS vl_bc_cofins,
       num(c07)  AS aliq_cofins,
       num(c08)  AS vl_cofins
FROM _sped WHERE reg = 'D105';

-- D200 (transporte saída - parente D201/D205)
CREATE OR REPLACE TEMP TABLE _t_d200 AS
SELECT filename, g_d200,
       TRIM(c08) AS cfop,
       num(c10)  AS vl_doc,
       num(c11)  AS vl_desc
FROM _sped WHERE reg = 'D200';

-- D201 (PIS D200)
CREATE OR REPLACE TEMP TABLE _t_d201 AS
SELECT filename, g_d200,
       TRIM(c02) AS cst_pis,
       num(c03)  AS vl_item,
       num(c04)  AS vl_bc_pis,
       num(c05)  AS aliq_pis,
       num(c06)  AS vl_pis
FROM _sped WHERE reg = 'D201';

-- D205 (COFINS D200)
CREATE OR REPLACE TEMP TABLE _t_d205 AS
SELECT filename, g_d200,
       TRIM(c02) AS cst_cofins,
       num(c03)  AS vl_item,
       num(c04)  AS vl_bc_cofins,
       num(c05)  AS aliq_cofins,
       num(c06)  AS vl_cofins
FROM _sped WHERE reg = 'D205';

-- D500 (telecom - parente D501/D505)
CREATE OR REPLACE TEMP TABLE _t_d500 AS
SELECT filename, g_d500,
       TRIM(c02) AS ind_oper,
       num(c13)  AS vl_desc,
       num(c14)  AS vl_serv,
       num(c19)  AS vl_icms
FROM _sped WHERE reg = 'D500';

-- D501 (PIS D500)
CREATE OR REPLACE TEMP TABLE _t_d501 AS
SELECT filename, g_d500,
       TRIM(c02) AS cst_pis,
       num(c05)  AS vl_bc_pis,
       num(c06)  AS aliq_pis,
       num(c07)  AS vl_pis
FROM _sped WHERE reg = 'D501';

-- D505 (COFINS D500)
CREATE OR REPLACE TEMP TABLE _t_d505 AS
SELECT filename, g_d500,
       TRIM(c02) AS cst_cofins,
       num(c05)  AS vl_bc_cofins,
       num(c06)  AS aliq_cofins,
       num(c07)  AS vl_cofins
FROM _sped WHERE reg = 'D505';

-- F100 (demais documentos - autocontido)
CREATE OR REPLACE TEMP TABLE _t_f100 AS
SELECT filename,
       TRIM(c02) AS ind_oper,
       num(c06)  AS vl_oper,
       TRIM(c07) AS cst_pis,
       num(c08)  AS vl_bc_pis,
       num(c09)  AS aliq_pis,
       num(c10)  AS vl_pis,
       TRIM(c11) AS cst_cofins,
       num(c12)  AS vl_bc_cofins,
       num(c13)  AS aliq_cofins,
       num(c14)  AS vl_cofins,
       TRIM(c15) AS nat_bc_cred
FROM _sped WHERE reg = 'F100';

-- F120 (ativo imobilizado depreciação - autocontido)
CREATE OR REPLACE TEMP TABLE _t_f120 AS
SELECT filename,
       TRIM(c02) AS nat_bc_cred,
       num(c06)  AS vl_oper_dep,
       TRIM(c08) AS cst_pis,
       num(c09)  AS vl_bc_pis,
       num(c10)  AS aliq_pis,
       num(c11)  AS vl_pis,
       TRIM(c12) AS cst_cofins,
       num(c13)  AS vl_bc_cofins,
       num(c14)  AS aliq_cofins,
       num(c15)  AS vl_cofins
FROM _sped WHERE reg = 'F120';

-- F130 (ativo imobilizado aquisição - autocontido)
CREATE OR REPLACE TEMP TABLE _t_f130 AS
SELECT filename,
       TRIM(c02) AS nat_bc_cred,
       num(c07)  AS vl_oper_aquis,
       TRIM(c11) AS cst_pis,
       num(c12)  AS vl_bc_pis,
       num(c13)  AS aliq_pis,
       num(c14)  AS vl_pis,
       TRIM(c15) AS cst_cofins,
       num(c16)  AS vl_bc_cofins,
       num(c17)  AS aliq_cofins,
       num(c18)  AS vl_cofins
FROM _sped WHERE reg = 'F130';

-- F150 (estoque abertura - autocontido)
CREATE OR REPLACE TEMP TABLE _t_f150 AS
SELECT filename,
       TRIM(c02) AS nat_bc_cred,
       num(c05)  AS vl_bc_est,
       TRIM(c07) AS cst_pis,
       num(c08)  AS aliq_pis,
       num(c09)  AS vl_cred_pis,
       TRIM(c10) AS cst_cofins,
       num(c11)  AS aliq_cofins,
       num(c12)  AS vl_cred_cofins
FROM _sped WHERE reg = 'F150';

-- F500 (receitas próprias - autocontido)
CREATE OR REPLACE TEMP TABLE _t_f500 AS
SELECT filename,
       num(c02)  AS vl_rec_caixa,
       TRIM(c03) AS cst_pis,
       num(c05)  AS vl_bc_pis,
       num(c06)  AS aliq_pis,
       num(c07)  AS vl_pis,
       TRIM(c08) AS cst_cofins,
       num(c10)  AS vl_bc_cofins,
       num(c11)  AS aliq_cofins,
       num(c12)  AS vl_cofins,
       TRIM(c14) AS cfop
FROM _sped WHERE reg = 'F500';

-- F550 (receitas por operação - autocontido)
CREATE OR REPLACE TEMP TABLE _t_f550 AS
SELECT filename,
       num(c02)  AS vl_rec_comp,
       TRIM(c03) AS cst_pis,
       num(c05)  AS vl_bc_pis,
       num(c06)  AS aliq_pis,
       num(c07)  AS vl_pis,
       TRIM(c08) AS cst_cofins,
       num(c10)  AS vl_bc_cofins,
       num(c11)  AS aliq_cofins,
       num(c12)  AS vl_cofins,
       TRIM(c14) AS cfop
FROM _sped WHERE reg = 'F550';


------------------------------------------------------------------------------
-- 5. CTE PRINCIPAL — réplica do Relatorio_CFOP_SAAM.sql, blocos 06–21
------------------------------------------------------------------------------

COPY (
WITH CFOP_NAT_BC_CRED(cfop, nat_bc_cred) AS (
    VALUES
        ('1101','02'),('1102','01'),('1111','02'),('1113','01'),('1116','02'),
        ('1117','01'),('1118','01'),('1120','02'),('1121','01'),('1122','02'),
        ('1124','03'),('1125','03'),('1126','02'),('1128','02'),('1132','02'),
        ('1135','02'),('1159','01'),('1201','12'),('1202','12'),('1203','12'),
        ('1204','12'),('1206','12'),('1207','12'),('1215','12'),('1216','12'),
        ('1251','04'),('1252','04'),('1253','04'),('1254','04'),('1255','04'),
        ('1256','04'),('1257','04'),('1351','07'),('1352','07'),('1353','07'),
        ('1354','07'),('1355','07'),('1356','07'),('1360','07'),('1401','02'),
        ('1403','01'),('1406','10'),('1407','02'),('1410','12'),('1411','12'),
        ('1456','02'),('1551','10'),('1556','02'),('1651','02'),('1652','01'),
        ('1653','02'),('1660','12'),('1661','12'),('1662','12'),('1932','07'),
        ('1933','03'),('2101','02'),('2102','01'),('2111','02'),('2113','01'),
        ('2116','02'),('2117','01'),('2118','01'),('2120','02'),('2121','01'),
        ('2122','02'),('2124','03'),('2125','03'),('2126','02'),('2128','02'),
        ('2132','02'),('2135','02'),('2159','01'),('2201','12'),('2202','12'),
        ('2206','12'),('2207','12'),('2215','12'),('2216','12'),('2251','04'),
        ('2252','04'),('2253','04'),('2254','04'),('2255','04'),('2256','04'),
        ('2257','04'),('2351','07'),('2352','07'),('2353','07'),('2354','07'),
        ('2355','07'),('2356','07'),('2401','02'),('2403','01'),('2406','10'),
        ('2407','02'),('2410','12'),('2411','12'),('2456','02'),('2551','10'),
        ('2556','02'),('2651','02'),('2652','01'),('2653','02'),('2660','12'),
        ('2661','12'),('2662','12'),('2932','07'),('2933','03'),('3101','02'),
        ('3102','01'),('3126','02'),('3128','02'),('3251','01'),('3556','02'),
        ('3651','02'),('3652','01'),('3653','02'),
        ('D100','Escolher Nat'),('F100','Escolher Nat'),('F120','Escolher Nat'),
        ('F130','Escolher Nat'),('F150','Escolher Nat'),('F550','Escolher Nat')
),

DATA_POOL AS (

    /* ==========================================
       06. CONTRIB - A170 (SERVIÇOS)
       ========================================== */
    SELECT
        'CONTRIBUIÇÕES'                                                         AS sped_origem,
        COALESCE(p0.dt_fim, '19000101')                                         AS dt_ref,
        CASE WHEN COALESCE(pa100.ind_oper,'1')='0' THEN 'Entrada' ELSE 'Saída' END AS sentido,
        'A170'                                                                  AS registro,
        '1933'                                                                  AS cfop,
        COALESCE(pa170.cst_pis,'00')                                            AS cst,
        COALESCE(pa170.aliq_pis,0)::DECIMAL(18,6)                               AS aliq_pis,
        COALESCE(pa170.aliq_cofins,0)::DECIMAL(18,6)                            AS aliq_cofins,
        CASE
            WHEN pa170.nat_bc_cred IS NULL
              OR TRIM(pa170.nat_bc_cred)=''
              OR TRIM(pa170.nat_bc_cred) IN ('0','0,0','0,00','0.00')
                THEN 'Escriturou vazio'
            ELSE TRIM(pa170.nat_bc_cred)
        END                                                                     AS nat_bc_cred,
        COALESCE(pa170.vl_item,0)::DECIMAL(18,6)                                AS vl_item,
        COALESCE(pa170.vl_desc,0)::DECIMAL(18,6)                                AS vl_desc,
        GREATEST(COALESCE(pa170.vl_item,0)-COALESCE(pa170.vl_desc,0),0)::DECIMAL(18,6) AS vl_liquido,
        0::DECIMAL(18,6)                                                        AS vl_bc_icms,
        0::DECIMAL(18,6)                                                        AS vl_icms,
        0::DECIMAL(18,6)                                                        AS vl_icms_st,
        0::DECIMAL(18,6)                                                        AS vl_ipi,
        COALESCE(pa100.vl_iss,0)::DECIMAL(18,6)                                 AS vl_iss,
        GREATEST(COALESCE(pa170.vl_bc_pis,0),0)::DECIMAL(18,6)                  AS bc_pis_cof_escriturada,
        GREATEST(COALESCE(pa170.vl_pis,0),0)::DECIMAL(18,6)                     AS v_pis,
        GREATEST(COALESCE(pa170.vl_cofins,0),0)::DECIMAL(18,6)                  AS v_cof,
        'Não conferido'                                                         AS st_conf
    FROM _t_a170 pa170
    LEFT JOIN _t_a100 pa100 USING (filename, g_a100)
    LEFT JOIN _t_0000 p0    USING (filename)

    UNION ALL

    /* ==========================================
       07. CONTRIB - C170 (MERCADORIAS)
       ========================================== */
    SELECT
        'CONTRIBUIÇÕES'                                                         AS sped_origem,
        COALESCE(p0.dt_fim,'19000101')                                          AS dt_ref,
        CASE WHEN COALESCE(pc100.ind_oper,'1')='0' THEN 'Entrada' ELSE 'Saída' END AS sentido,
        'C170'                                                                  AS registro,
        COALESCE(NULLIF(pc170.cfop,''),'N/A')                                   AS cfop,
        COALESCE(NULLIF(pc170.cst_pis,''),'00')                                 AS cst,
        COALESCE(pc170.aliq_pis,0)::DECIMAL(18,6)                               AS aliq_pis,
        COALESCE(pc170.aliq_cofins,0)::DECIMAL(18,6)                            AS aliq_cofins,
        COALESCE((
            SELECT cn.nat_bc_cred FROM CFOP_NAT_BC_CRED cn
            WHERE cn.cfop = UPPER(TRIM(REGEXP_REPLACE(COALESCE(pc170.cfop,'N/A'),'[^0-9A-Za-z]','','g')))
        ),'N/A')                                                                AS nat_bc_cred,
        COALESCE(pc170.vl_item,0)::DECIMAL(18,6)                                AS vl_item,
        COALESCE(pc170.vl_desc,0)::DECIMAL(18,6)                                AS vl_desc,
        GREATEST(COALESCE(pc170.vl_item,0)-COALESCE(pc170.vl_desc,0),0)::DECIMAL(18,6) AS vl_liquido,
        COALESCE(pc170.vl_bc_icms,0)::DECIMAL(18,6)                             AS vl_bc_icms,
        COALESCE(pc170.vl_icms,0)::DECIMAL(18,6)                                AS vl_icms,
        COALESCE(pc170.vl_icms_st,0)::DECIMAL(18,6)                             AS vl_icms_st,
        COALESCE(pc170.vl_ipi,0)::DECIMAL(18,6)                                 AS vl_ipi,
        0::DECIMAL(18,6)                                                        AS vl_iss,
        GREATEST(COALESCE(pc170.vl_bc_pis,0),0)::DECIMAL(18,6)                  AS bc_pis_cof_escriturada,
        GREATEST(COALESCE(pc170.vl_pis,0),0)::DECIMAL(18,6)                     AS v_pis,
        GREATEST(COALESCE(pc170.vl_cofins,0),0)::DECIMAL(18,6)                  AS v_cof,
        'Não conferido'                                                         AS st_conf
    FROM _t_c170 pc170
    LEFT JOIN _t_c100 pc100 USING (filename, g_c100)
    LEFT JOIN _t_0000 p0    USING (filename)

    UNION ALL

    /* ==========================================
       08. CONTRIB - C175 (VENDAS CONSUMIDOR)
       ========================================== */
    SELECT
        'CONTRIBUIÇÕES'                                                         AS sped_origem,
        COALESCE(p0.dt_fim,'19000101')                                          AS dt_ref,
        'Saída'                                                                 AS sentido,
        'C175'                                                                  AS registro,
        COALESCE(NULLIF(pc175.cfop,''),'N/A')                                   AS cfop,
        COALESCE(NULLIF(pc175.cst_pis,''),'00')                                 AS cst,
        COALESCE(pc175.aliq_pis,0)::DECIMAL(18,6)                               AS aliq_pis,
        COALESCE(pc175.aliq_cofins,0)::DECIMAL(18,6)                            AS aliq_cofins,
        COALESCE((
            SELECT cn.nat_bc_cred FROM CFOP_NAT_BC_CRED cn
            WHERE cn.cfop = UPPER(TRIM(REGEXP_REPLACE(COALESCE(pc175.cfop,'N/A'),'[^0-9A-Za-z]','','g')))
        ),'N/A')                                                                AS nat_bc_cred,
        COALESCE(pc175.vl_opr,0)::DECIMAL(18,6)                                 AS vl_item,
        COALESCE(pc175.vl_desc,0)::DECIMAL(18,6)                                AS vl_desc,
        GREATEST(COALESCE(pc175.vl_opr,0)-COALESCE(pc175.vl_desc,0),0)::DECIMAL(18,6) AS vl_liquido,
        CASE WHEN COALESCE(pc100.vl_doc,0)>0
             THEN (COALESCE(pc100.vl_bc_icms,0)*(COALESCE(pc175.vl_opr,0)/pc100.vl_doc))::DECIMAL(18,6)
             ELSE 0 END                                                         AS vl_bc_icms,
        CASE WHEN COALESCE(pc100.vl_doc,0)>0
             THEN (COALESCE(pc100.vl_icms,0)*(COALESCE(pc175.vl_opr,0)/pc100.vl_doc))::DECIMAL(18,6)
             ELSE 0 END                                                         AS vl_icms,
        CASE WHEN COALESCE(pc100.vl_doc,0)>0
             THEN (COALESCE(pc100.vl_icms_st,0)*(COALESCE(pc175.vl_opr,0)/pc100.vl_doc))::DECIMAL(18,6)
             ELSE 0 END                                                         AS vl_icms_st,
        0::DECIMAL(18,6)                                                        AS vl_ipi,
        0::DECIMAL(18,6)                                                        AS vl_iss,
        GREATEST(COALESCE(pc175.vl_bc_pis,0),0)::DECIMAL(18,6)                  AS bc_pis_cof_escriturada,
        GREATEST(COALESCE(pc175.vl_pis,0),0)::DECIMAL(18,6)                     AS v_pis,
        GREATEST(COALESCE(pc175.vl_cofins,0),0)::DECIMAL(18,6)                  AS v_cof,
        'Não conferido'                                                         AS st_conf
    FROM _t_c175 pc175
    LEFT JOIN _t_c100 pc100 USING (filename, g_c100)
    LEFT JOIN _t_0000 p0    USING (filename)

    UNION ALL

    /* ==========================================
       09. CONTRIB - C180 (SAÍDAS CONSOLIDADAS)
       ========================================== */
    SELECT
        'CONTRIBUIÇÕES'                                                         AS sped_origem,
        COALESCE(p0.dt_fim,'19000101')                                          AS dt_ref,
        'Saída'                                                                 AS sentido,
        'C180'                                                                  AS registro,
        COALESCE(NULLIF(pc181.cfop,''),'N/A')                                   AS cfop,
        COALESCE(NULLIF(pc181.cst_pis,''),'00')                                 AS cst,
        COALESCE(pc181.aliq_pis,0)::DECIMAL(18,6)                               AS aliq_pis,
        COALESCE(pc185_agr.aliq_cofins,0)::DECIMAL(18,6)                        AS aliq_cofins,
        COALESCE((
            SELECT cn.nat_bc_cred FROM CFOP_NAT_BC_CRED cn
            WHERE cn.cfop = UPPER(TRIM(REGEXP_REPLACE(COALESCE(pc181.cfop,'N/A'),'[^0-9A-Za-z]','','g')))
        ),'N/A')                                                                AS nat_bc_cred,
        COALESCE(pc181.vl_item,0)::DECIMAL(18,6)                                AS vl_item,
        COALESCE(pc181.vl_desc,0)::DECIMAL(18,6)                                AS vl_desc,
        GREATEST(COALESCE(pc181.vl_item,0)-COALESCE(pc181.vl_desc,0),0)::DECIMAL(18,6) AS vl_liquido,
        0::DECIMAL(18,6)                                                        AS vl_bc_icms,
        0::DECIMAL(18,6)                                                        AS vl_icms,
        0::DECIMAL(18,6)                                                        AS vl_icms_st,
        0::DECIMAL(18,6)                                                        AS vl_ipi,
        0::DECIMAL(18,6)                                                        AS vl_iss,
        GREATEST(COALESCE(pc181.vl_bc_pis,0),0)::DECIMAL(18,6)                  AS bc_pis_cof_escriturada,
        GREATEST(COALESCE(pc181.vl_pis,0),0)::DECIMAL(18,6)                     AS v_pis,
        GREATEST(COALESCE(pc185_agr.vl_cofins,0),0)::DECIMAL(18,6)              AS v_cof,
        'Não conferido'                                                         AS st_conf
    FROM _t_c181 pc181
    LEFT JOIN _t_0000 p0 USING (filename)
    LEFT JOIN (
        SELECT filename, g_c180, cfop, cst_cofins,
               AVG(COALESCE(aliq_cofins,0))::DECIMAL(18,6) AS aliq_cofins,
               SUM(COALESCE(vl_cofins,0))::DECIMAL(18,6)   AS vl_cofins
        FROM _t_c185
        GROUP BY filename, g_c180, cfop, cst_cofins
    ) pc185_agr
        ON pc185_agr.filename = pc181.filename
       AND pc185_agr.g_c180   = pc181.g_c180
       AND pc185_agr.cfop     = pc181.cfop
       AND pc185_agr.cst_cofins = pc181.cst_pis

    UNION ALL

    /* ==========================================
       10. CONTRIB - C190 (ENTRADAS CONSOLIDADAS)
       ========================================== */
    SELECT
        'CONTRIBUIÇÕES'                                                         AS sped_origem,
        COALESCE(p0.dt_fim,'19000101')                                          AS dt_ref,
        'Entrada'                                                               AS sentido,
        'C190'                                                                  AS registro,
        COALESCE(NULLIF(pc191.cfop,''),'N/A')                                   AS cfop,
        COALESCE(NULLIF(pc191.cst_pis,''),'00')                                 AS cst,
        COALESCE(pc191.aliq_pis,0)::DECIMAL(18,6)                               AS aliq_pis,
        COALESCE(pc195_agr.aliq_cofins,0)::DECIMAL(18,6)                        AS aliq_cofins,
        COALESCE((
            SELECT cn.nat_bc_cred FROM CFOP_NAT_BC_CRED cn
            WHERE cn.cfop = UPPER(TRIM(REGEXP_REPLACE(COALESCE(pc191.cfop,'N/A'),'[^0-9A-Za-z]','','g')))
        ),'N/A')                                                                AS nat_bc_cred,
        COALESCE(pc191.vl_item,0)::DECIMAL(18,6)                                AS vl_item,
        COALESCE(pc191.vl_desc,0)::DECIMAL(18,6)                                AS vl_desc,
        GREATEST(COALESCE(pc191.vl_item,0)-COALESCE(pc191.vl_desc,0),0)::DECIMAL(18,6) AS vl_liquido,
        0::DECIMAL(18,6)                                                        AS vl_bc_icms,
        0::DECIMAL(18,6)                                                        AS vl_icms,
        0::DECIMAL(18,6)                                                        AS vl_icms_st,
        0::DECIMAL(18,6)                                                        AS vl_ipi,
        0::DECIMAL(18,6)                                                        AS vl_iss,
        GREATEST(COALESCE(pc191.vl_bc_pis,0),0)::DECIMAL(18,6)                  AS bc_pis_cof_escriturada,
        GREATEST(COALESCE(pc191.vl_pis,0),0)::DECIMAL(18,6)                     AS v_pis,
        GREATEST(COALESCE(pc195_agr.vl_cofins,0),0)::DECIMAL(18,6)              AS v_cof,
        'Não conferido'                                                         AS st_conf
    FROM _t_c191 pc191
    LEFT JOIN _t_0000 p0 USING (filename)
    LEFT JOIN (
        SELECT filename, g_c190, cfop, cst_cofins,
               AVG(COALESCE(aliq_cofins,0))::DECIMAL(18,6) AS aliq_cofins,
               SUM(COALESCE(vl_cofins,0))::DECIMAL(18,6)   AS vl_cofins
        FROM _t_c195
        GROUP BY filename, g_c190, cfop, cst_cofins
    ) pc195_agr
        ON pc195_agr.filename = pc191.filename
       AND pc195_agr.g_c190   = pc191.g_c190
       AND pc195_agr.cfop     = pc191.cfop
       AND pc195_agr.cst_cofins = pc191.cst_pis

    UNION ALL

    /* ==========================================
       11. CONTRIB - C500 (ENERGIA / ÁGUA)
       ========================================== */
    SELECT
        'CONTRIBUIÇÕES'                                                         AS sped_origem,
        COALESCE(p0.dt_fim,'19000101')                                          AS dt_ref,
        'Entrada'                                                               AS sentido,
        'C500'                                                                  AS registro,
        '1253'                                                                  AS cfop,
        COALESCE(NULLIF(pc501.cst_pis,''),'00')                                 AS cst,
        COALESCE(pc501.aliq_pis,0)::DECIMAL(18,6)                               AS aliq_pis,
        COALESCE(pc505_agr.aliq_cofins,0)::DECIMAL(18,6)                        AS aliq_cofins,
        COALESCE((
            SELECT cn.nat_bc_cred FROM CFOP_NAT_BC_CRED cn
            WHERE cn.cfop = '1253'
        ),'N/A')                                                                AS nat_bc_cred,
        COALESCE(pc500.vl_doc,0)::DECIMAL(18,6)                                 AS vl_item,
        0::DECIMAL(18,6)                                                        AS vl_desc,
        GREATEST(COALESCE(pc500.vl_doc,0),0)::DECIMAL(18,6)                     AS vl_liquido,
        0::DECIMAL(18,6)                                                        AS vl_bc_icms,
        COALESCE(pc500.vl_icms,0)::DECIMAL(18,6)                                AS vl_icms,
        0::DECIMAL(18,6)                                                        AS vl_icms_st,
        0::DECIMAL(18,6)                                                        AS vl_ipi,
        0::DECIMAL(18,6)                                                        AS vl_iss,
        GREATEST(COALESCE(pc501.vl_bc_pis,0),0)::DECIMAL(18,6)                  AS bc_pis_cof_escriturada,
        GREATEST(COALESCE(pc501.vl_pis,0),0)::DECIMAL(18,6)                     AS v_pis,
        GREATEST(COALESCE(pc505_agr.vl_cofins,0),0)::DECIMAL(18,6)              AS v_cof,
        'Não conferido'                                                         AS st_conf
    FROM _t_c500 pc500
    LEFT JOIN _t_c501 pc501 USING (filename, g_c500)
    LEFT JOIN _t_0000 p0    USING (filename)
    LEFT JOIN (
        SELECT filename, g_c500, cst_cofins,
               AVG(COALESCE(aliq_cofins,0))::DECIMAL(18,6) AS aliq_cofins,
               SUM(COALESCE(vl_cofins,0))::DECIMAL(18,6)   AS vl_cofins
        FROM _t_c505
        GROUP BY filename, g_c500, cst_cofins
    ) pc505_agr
        ON pc505_agr.filename = pc500.filename
       AND pc505_agr.g_c500   = pc500.g_c500
       AND pc505_agr.cst_cofins = pc501.cst_pis

    UNION ALL

    /* ==========================================
       12. CONTRIB - C870 (ECF)
       ========================================== */
    SELECT
        'CONTRIBUIÇÕES'                                                         AS sped_origem,
        COALESCE(p0.dt_fim,'19000101')                                          AS dt_ref,
        'Saída'                                                                 AS sentido,
        'C870'                                                                  AS registro,
        COALESCE(NULLIF(pc870.cfop,''),'N/A')                                   AS cfop,
        COALESCE(NULLIF(pc870.cst_pis,''),'00')                                 AS cst,
        COALESCE(pc870.aliq_pis,0)::DECIMAL(18,6)                               AS aliq_pis,
        COALESCE(pc870.aliq_cofins,0)::DECIMAL(18,6)                            AS aliq_cofins,
        COALESCE((
            SELECT cn.nat_bc_cred FROM CFOP_NAT_BC_CRED cn
            WHERE cn.cfop = UPPER(TRIM(REGEXP_REPLACE(COALESCE(pc870.cfop,'N/A'),'[^0-9A-Za-z]','','g')))
        ),'N/A')                                                                AS nat_bc_cred,
        COALESCE(pc870.vl_item,0)::DECIMAL(18,6)                                AS vl_item,
        COALESCE(pc870.vl_desc,0)::DECIMAL(18,6)                                AS vl_desc,
        GREATEST(COALESCE(pc870.vl_item,0)-COALESCE(pc870.vl_desc,0),0)::DECIMAL(18,6) AS vl_liquido,
        0::DECIMAL(18,6)                                                        AS vl_bc_icms,
        0::DECIMAL(18,6)                                                        AS vl_icms,
        0::DECIMAL(18,6)                                                        AS vl_icms_st,
        0::DECIMAL(18,6)                                                        AS vl_ipi,
        0::DECIMAL(18,6)                                                        AS vl_iss,
        GREATEST(COALESCE(pc870.vl_bc_pis,0),0)::DECIMAL(18,6)                  AS bc_pis_cof_escriturada,
        GREATEST(COALESCE(pc870.vl_pis,0),0)::DECIMAL(18,6)                     AS v_pis,
        GREATEST(COALESCE(pc870.vl_cofins,0),0)::DECIMAL(18,6)                  AS v_cof,
        'Não conferido'                                                         AS st_conf
    FROM _t_c870 pc870
    LEFT JOIN _t_0000 p0 USING (filename)

    UNION ALL

    /* ==========================================
       13. CONTRIB - D100 (ENTRADAS DE TRANSPORTES)
       ========================================== */
    SELECT
        'CONTRIBUIÇÕES'                                                         AS sped_origem,
        COALESCE(p0.dt_fim,'19000101')                                          AS dt_ref,
        CASE WHEN COALESCE(pd100.ind_oper,'0')='0' THEN 'Entrada' ELSE 'Saída' END AS sentido,
        'D100'                                                                  AS registro,
        '1353'                                                                  AS cfop,
        COALESCE(NULLIF(pd101.cst_pis,''),'00')                                 AS cst,
        COALESCE(pd101.aliq_pis,0)::DECIMAL(18,6)                               AS aliq_pis,
        COALESCE(pd105_agr.aliq_cofins,0)::DECIMAL(18,6)                        AS aliq_cofins,
        COALESCE((
            SELECT cn.nat_bc_cred FROM CFOP_NAT_BC_CRED cn
            WHERE cn.cfop = '1353'
        ),'N/A')                                                                AS nat_bc_cred,
        COALESCE(pd100.vl_doc,0)::DECIMAL(18,6)                                 AS vl_item,
        0::DECIMAL(18,6)                                                        AS vl_desc,
        GREATEST(COALESCE(pd100.vl_doc,0),0)::DECIMAL(18,6)                     AS vl_liquido,
        0::DECIMAL(18,6)                                                        AS vl_bc_icms,
        COALESCE(pd100.vl_icms,0)::DECIMAL(18,6)                                AS vl_icms,
        0::DECIMAL(18,6)                                                        AS vl_icms_st,
        0::DECIMAL(18,6)                                                        AS vl_ipi,
        0::DECIMAL(18,6)                                                        AS vl_iss,
        GREATEST(COALESCE(pd101.vl_bc_pis,0),0)::DECIMAL(18,6)                  AS bc_pis_cof_escriturada,
        GREATEST(COALESCE(pd101.vl_pis,0),0)::DECIMAL(18,6)                     AS v_pis,
        GREATEST(COALESCE(pd105_agr.vl_cofins,0),0)::DECIMAL(18,6)              AS v_cof,
        'Não conferido'                                                         AS st_conf
    FROM _t_d100 pd100
    LEFT JOIN _t_d101 pd101 USING (filename, g_d100)
    LEFT JOIN _t_0000 p0    USING (filename)
    LEFT JOIN (
        SELECT filename, g_d100, cst_cofins,
               AVG(COALESCE(aliq_cofins,0))::DECIMAL(18,6) AS aliq_cofins,
               SUM(COALESCE(vl_cofins,0))::DECIMAL(18,6)   AS vl_cofins
        FROM _t_d105
        GROUP BY filename, g_d100, cst_cofins
    ) pd105_agr
        ON pd105_agr.filename = pd100.filename
       AND pd105_agr.g_d100   = pd100.g_d100
       AND pd105_agr.cst_cofins = pd101.cst_pis

    UNION ALL

    /* ==========================================
       14. CONTRIB - D200 (SAÍDAS DE TRANSPORTES)
       ========================================== */
    SELECT
        'CONTRIBUIÇÕES'                                                         AS sped_origem,
        COALESCE(p0.dt_fim,'19000101')                                          AS dt_ref,
        'Saída'                                                                 AS sentido,
        'D200'                                                                  AS registro,
        COALESCE(NULLIF(pd200.cfop,''),'N/A')                                   AS cfop,
        COALESCE(NULLIF(pd201.cst_pis,''),'00')                                 AS cst,
        COALESCE(pd201.aliq_pis,0)::DECIMAL(18,6)                               AS aliq_pis,
        COALESCE(pd205_agr.aliq_cofins,0)::DECIMAL(18,6)                        AS aliq_cofins,
        COALESCE((
            SELECT cn.nat_bc_cred FROM CFOP_NAT_BC_CRED cn
            WHERE cn.cfop = UPPER(TRIM(REGEXP_REPLACE(COALESCE(pd200.cfop,'N/A'),'[^0-9A-Za-z]','','g')))
        ),'N/A')                                                                AS nat_bc_cred,
        COALESCE(pd200.vl_doc,0)::DECIMAL(18,6)                                 AS vl_item,
        COALESCE(pd200.vl_desc,0)::DECIMAL(18,6)                                AS vl_desc,
        GREATEST(COALESCE(pd200.vl_doc,0)-COALESCE(pd200.vl_desc,0),0)::DECIMAL(18,6) AS vl_liquido,
        0::DECIMAL(18,6)                                                        AS vl_bc_icms,
        0::DECIMAL(18,6)                                                        AS vl_icms,
        0::DECIMAL(18,6)                                                        AS vl_icms_st,
        0::DECIMAL(18,6)                                                        AS vl_ipi,
        0::DECIMAL(18,6)                                                        AS vl_iss,
        GREATEST(COALESCE(pd201.vl_bc_pis,0),0)::DECIMAL(18,6)                  AS bc_pis_cof_escriturada,
        GREATEST(COALESCE(pd201.vl_pis,0),0)::DECIMAL(18,6)                     AS v_pis,
        GREATEST(COALESCE(pd205_agr.vl_cofins,0),0)::DECIMAL(18,6)              AS v_cof,
        'Não conferido'                                                         AS st_conf
    FROM _t_d200 pd200
    LEFT JOIN _t_d201 pd201 USING (filename, g_d200)
    LEFT JOIN _t_0000 p0    USING (filename)
    LEFT JOIN (
        SELECT filename, g_d200, cst_cofins,
               AVG(COALESCE(aliq_cofins,0))::DECIMAL(18,6) AS aliq_cofins,
               SUM(COALESCE(vl_cofins,0))::DECIMAL(18,6)   AS vl_cofins
        FROM _t_d205
        GROUP BY filename, g_d200, cst_cofins
    ) pd205_agr
        ON pd205_agr.filename = pd200.filename
       AND pd205_agr.g_d200   = pd200.g_d200
       AND pd205_agr.cst_cofins = pd201.cst_pis

    UNION ALL

    /* ==========================================
       15. CONTRIB - D500 (TELECOM)
       ========================================== */
    SELECT
        'CONTRIBUIÇÕES'                                                         AS sped_origem,
        COALESCE(p0.dt_fim,'19000101')                                          AS dt_ref,
        CASE WHEN COALESCE(pd500.ind_oper,'1')='0' THEN 'Entrada' ELSE 'Saída' END AS sentido,
        'D500'                                                                  AS registro,
        '1352'                                                                  AS cfop,
        COALESCE(NULLIF(pd501.cst_pis,''),'00')                                 AS cst,
        COALESCE(pd501.aliq_pis,0)::DECIMAL(18,6)                               AS aliq_pis,
        COALESCE(pd505_agr.aliq_cofins,0)::DECIMAL(18,6)                        AS aliq_cofins,
        COALESCE((
            SELECT cn.nat_bc_cred FROM CFOP_NAT_BC_CRED cn
            WHERE cn.cfop = '1352'
        ),'N/A')                                                                AS nat_bc_cred,
        COALESCE(pd500.vl_serv,0)::DECIMAL(18,6)                                AS vl_item,
        COALESCE(pd500.vl_desc,0)::DECIMAL(18,6)                                AS vl_desc,
        GREATEST(COALESCE(pd500.vl_serv,0)-COALESCE(pd500.vl_desc,0),0)::DECIMAL(18,6) AS vl_liquido,
        0::DECIMAL(18,6)                                                        AS vl_bc_icms,
        COALESCE(pd500.vl_icms,0)::DECIMAL(18,6)                                AS vl_icms,
        0::DECIMAL(18,6)                                                        AS vl_icms_st,
        0::DECIMAL(18,6)                                                        AS vl_ipi,
        0::DECIMAL(18,6)                                                        AS vl_iss,
        GREATEST(COALESCE(pd501.vl_bc_pis,0),0)::DECIMAL(18,6)                  AS bc_pis_cof_escriturada,
        GREATEST(COALESCE(pd501.vl_pis,0),0)::DECIMAL(18,6)                     AS v_pis,
        GREATEST(COALESCE(pd505_agr.vl_cofins,0),0)::DECIMAL(18,6)              AS v_cof,
        'Não conferido'                                                         AS st_conf
    FROM _t_d500 pd500
    LEFT JOIN _t_d501 pd501 USING (filename, g_d500)
    LEFT JOIN _t_0000 p0    USING (filename)
    LEFT JOIN (
        SELECT filename, g_d500, cst_cofins,
               AVG(COALESCE(aliq_cofins,0))::DECIMAL(18,6) AS aliq_cofins,
               SUM(COALESCE(vl_cofins,0))::DECIMAL(18,6)   AS vl_cofins
        FROM _t_d505
        GROUP BY filename, g_d500, cst_cofins
    ) pd505_agr
        ON pd505_agr.filename = pd500.filename
       AND pd505_agr.g_d500   = pd500.g_d500
       AND pd505_agr.cst_cofins = pd501.cst_pis

    UNION ALL

    /* ==========================================
       16. CONTRIB - F100 (DEMAIS DOCUMENTOS)
       ========================================== */
    SELECT
        'CONTRIBUIÇÕES'                                                         AS sped_origem,
        COALESCE(p0.dt_fim,'19000101')                                          AS dt_ref,
        CASE WHEN COALESCE(pf100.ind_oper,'1')='0' THEN 'Entrada' ELSE 'Saída' END AS sentido,
        'F100'                                                                  AS registro,
        'F100'                                                                  AS cfop,
        COALESCE(NULLIF(pf100.cst_pis,''),'00')                                 AS cst,
        COALESCE(pf100.aliq_pis,0)::DECIMAL(18,6)                               AS aliq_pis,
        COALESCE(pf100.aliq_cofins,0)::DECIMAL(18,6)                            AS aliq_cofins,
        COALESCE(NULLIF(pf100.nat_bc_cred,''),'N/A')                            AS nat_bc_cred,
        COALESCE(pf100.vl_oper,0)::DECIMAL(18,6)                                AS vl_item,
        0::DECIMAL(18,6)                                                        AS vl_desc,
        GREATEST(COALESCE(pf100.vl_oper,0),0)::DECIMAL(18,6)                    AS vl_liquido,
        0::DECIMAL(18,6)                                                        AS vl_bc_icms,
        0::DECIMAL(18,6)                                                        AS vl_icms,
        0::DECIMAL(18,6)                                                        AS vl_icms_st,
        0::DECIMAL(18,6)                                                        AS vl_ipi,
        0::DECIMAL(18,6)                                                        AS vl_iss,
        GREATEST(COALESCE(pf100.vl_bc_pis,0),0)::DECIMAL(18,6)                  AS bc_pis_cof_escriturada,
        GREATEST(COALESCE(pf100.vl_pis,0),0)::DECIMAL(18,6)                     AS v_pis,
        GREATEST(COALESCE(pf100.vl_cofins,0),0)::DECIMAL(18,6)                  AS v_cof,
        'Não conferido'                                                         AS st_conf
    FROM _t_f100 pf100
    LEFT JOIN _t_0000 p0 USING (filename)

    UNION ALL

    /* ==========================================
       17. CONTRIB - F120 (ATIVO IMOBILIZADO DEPREC.)
       ========================================== */
    SELECT
        'CONTRIBUIÇÕES'                                                         AS sped_origem,
        COALESCE(p0.dt_fim,'19000101')                                          AS dt_ref,
        'Entrada'                                                               AS sentido,
        'F120'                                                                  AS registro,
        'F120'                                                                  AS cfop,
        COALESCE(NULLIF(pf120.cst_pis,''),'00')                                 AS cst,
        COALESCE(pf120.aliq_pis,0)::DECIMAL(18,6)                               AS aliq_pis,
        COALESCE(pf120.aliq_cofins,0)::DECIMAL(18,6)                            AS aliq_cofins,
        COALESCE(NULLIF(pf120.nat_bc_cred,''),'N/A')                            AS nat_bc_cred,
        COALESCE(pf120.vl_oper_dep,0)::DECIMAL(18,6)                            AS vl_item,
        0::DECIMAL(18,6)                                                        AS vl_desc,
        GREATEST(COALESCE(pf120.vl_oper_dep,0),0)::DECIMAL(18,6)                AS vl_liquido,
        0::DECIMAL(18,6)                                                        AS vl_bc_icms,
        0::DECIMAL(18,6)                                                        AS vl_icms,
        0::DECIMAL(18,6)                                                        AS vl_icms_st,
        0::DECIMAL(18,6)                                                        AS vl_ipi,
        0::DECIMAL(18,6)                                                        AS vl_iss,
        GREATEST(COALESCE(pf120.vl_bc_pis,0),0)::DECIMAL(18,6)                  AS bc_pis_cof_escriturada,
        GREATEST(COALESCE(pf120.vl_pis,0),0)::DECIMAL(18,6)                     AS v_pis,
        GREATEST(COALESCE(pf120.vl_cofins,0),0)::DECIMAL(18,6)                  AS v_cof,
        'Não conferido'                                                         AS st_conf
    FROM _t_f120 pf120
    LEFT JOIN _t_0000 p0 USING (filename)

    UNION ALL

    /* ==========================================
       18. CONTRIB - F130 (ATIVO IMOBILIZADO AQUIS.)
       ========================================== */
    SELECT
        'CONTRIBUIÇÕES'                                                         AS sped_origem,
        COALESCE(p0.dt_fim,'19000101')                                          AS dt_ref,
        'Entrada'                                                               AS sentido,
        'F130'                                                                  AS registro,
        'F130'                                                                  AS cfop,
        COALESCE(NULLIF(pf130.cst_pis,''),'00')                                 AS cst,
        COALESCE(pf130.aliq_pis,0)::DECIMAL(18,6)                               AS aliq_pis,
        COALESCE(pf130.aliq_cofins,0)::DECIMAL(18,6)                            AS aliq_cofins,
        COALESCE(NULLIF(pf130.nat_bc_cred,''),'N/A')                            AS nat_bc_cred,
        COALESCE(pf130.vl_oper_aquis,0)::DECIMAL(18,6)                          AS vl_item,
        0::DECIMAL(18,6)                                                        AS vl_desc,
        GREATEST(COALESCE(pf130.vl_oper_aquis,0),0)::DECIMAL(18,6)              AS vl_liquido,
        0::DECIMAL(18,6)                                                        AS vl_bc_icms,
        0::DECIMAL(18,6)                                                        AS vl_icms,
        0::DECIMAL(18,6)                                                        AS vl_icms_st,
        0::DECIMAL(18,6)                                                        AS vl_ipi,
        0::DECIMAL(18,6)                                                        AS vl_iss,
        GREATEST(COALESCE(pf130.vl_bc_pis,0),0)::DECIMAL(18,6)                  AS bc_pis_cof_escriturada,
        GREATEST(COALESCE(pf130.vl_pis,0),0)::DECIMAL(18,6)                     AS v_pis,
        GREATEST(COALESCE(pf130.vl_cofins,0),0)::DECIMAL(18,6)                  AS v_cof,
        'Não conferido'                                                         AS st_conf
    FROM _t_f130 pf130
    LEFT JOIN _t_0000 p0 USING (filename)

    UNION ALL

    /* ==========================================
       19. CONTRIB - F150 (ESTOQUE ABERTURA)
       ========================================== */
    SELECT
        'CONTRIBUIÇÕES'                                                         AS sped_origem,
        COALESCE(p0.dt_fim,'19000101')                                          AS dt_ref,
        'Entrada'                                                               AS sentido,
        'F150'                                                                  AS registro,
        'F150'                                                                  AS cfop,
        COALESCE(NULLIF(pf150.cst_pis,''),'00')                                 AS cst,
        COALESCE(pf150.aliq_pis,0)::DECIMAL(18,6)                               AS aliq_pis,
        COALESCE(pf150.aliq_cofins,0)::DECIMAL(18,6)                            AS aliq_cofins,
        COALESCE(NULLIF(pf150.nat_bc_cred,''),'N/A')                            AS nat_bc_cred,
        COALESCE(pf150.vl_bc_est,0)::DECIMAL(18,6)                              AS vl_item,
        0::DECIMAL(18,6)                                                        AS vl_desc,
        GREATEST(COALESCE(pf150.vl_bc_est,0),0)::DECIMAL(18,6)                  AS vl_liquido,
        0::DECIMAL(18,6)                                                        AS vl_bc_icms,
        0::DECIMAL(18,6)                                                        AS vl_icms,
        0::DECIMAL(18,6)                                                        AS vl_icms_st,
        0::DECIMAL(18,6)                                                        AS vl_ipi,
        0::DECIMAL(18,6)                                                        AS vl_iss,
        GREATEST(COALESCE(pf150.vl_bc_est,0),0)::DECIMAL(18,6)                  AS bc_pis_cof_escriturada,
        GREATEST(COALESCE(pf150.vl_cred_pis,0),0)::DECIMAL(18,6)                AS v_pis,
        GREATEST(COALESCE(pf150.vl_cred_cofins,0),0)::DECIMAL(18,6)             AS v_cof,
        'Não conferido'                                                         AS st_conf
    FROM _t_f150 pf150
    LEFT JOIN _t_0000 p0 USING (filename)

    UNION ALL

    /* ==========================================
       20. CONTRIB - F500 (RECEITAS PRÓPRIAS)
       ========================================== */
    SELECT
        'CONTRIBUIÇÕES'                                                         AS sped_origem,
        COALESCE(p0.dt_fim,'19000101')                                          AS dt_ref,
        'Saída'                                                                 AS sentido,
        'F500'                                                                  AS registro,
        COALESCE(NULLIF(pf500.cfop,''),'N/A')                                   AS cfop,
        COALESCE(NULLIF(pf500.cst_pis,''),'00')                                 AS cst,
        COALESCE(pf500.aliq_pis,0)::DECIMAL(18,6)                               AS aliq_pis,
        COALESCE(pf500.aliq_cofins,0)::DECIMAL(18,6)                            AS aliq_cofins,
        COALESCE((
            SELECT cn.nat_bc_cred FROM CFOP_NAT_BC_CRED cn
            WHERE cn.cfop = UPPER(TRIM(REGEXP_REPLACE(COALESCE(pf500.cfop,'N/A'),'[^0-9A-Za-z]','','g')))
        ),'N/A')                                                                AS nat_bc_cred,
        COALESCE(pf500.vl_rec_caixa,0)::DECIMAL(18,6)                           AS vl_item,
        0::DECIMAL(18,6)                                                        AS vl_desc,
        GREATEST(COALESCE(pf500.vl_rec_caixa,0),0)::DECIMAL(18,6)               AS vl_liquido,
        0::DECIMAL(18,6)                                                        AS vl_bc_icms,
        0::DECIMAL(18,6)                                                        AS vl_icms,
        0::DECIMAL(18,6)                                                        AS vl_icms_st,
        0::DECIMAL(18,6)                                                        AS vl_ipi,
        0::DECIMAL(18,6)                                                        AS vl_iss,
        GREATEST(COALESCE(pf500.vl_bc_pis,0),0)::DECIMAL(18,6)                  AS bc_pis_cof_escriturada,
        GREATEST(COALESCE(pf500.vl_pis,0),0)::DECIMAL(18,6)                     AS v_pis,
        GREATEST(COALESCE(pf500.vl_cofins,0),0)::DECIMAL(18,6)                  AS v_cof,
        'Não conferido'                                                         AS st_conf
    FROM _t_f500 pf500
    LEFT JOIN _t_0000 p0 USING (filename)

    UNION ALL

    /* ==========================================
       21. CONTRIB - F550 (RECEITAS POR OPERAÇÃO)
       ========================================== */
    SELECT
        'CONTRIBUIÇÕES'                                                         AS sped_origem,
        COALESCE(p0.dt_fim,'19000101')                                          AS dt_ref,
        'Saída'                                                                 AS sentido,
        'F550'                                                                  AS registro,
        COALESCE(NULLIF(pf550.cfop,''),'N/A')                                   AS cfop,
        COALESCE(NULLIF(pf550.cst_pis,''),'00')                                 AS cst,
        COALESCE(pf550.aliq_pis,0)::DECIMAL(18,6)                               AS aliq_pis,
        COALESCE(pf550.aliq_cofins,0)::DECIMAL(18,6)                            AS aliq_cofins,
        COALESCE((
            SELECT cn.nat_bc_cred FROM CFOP_NAT_BC_CRED cn
            WHERE cn.cfop = UPPER(TRIM(REGEXP_REPLACE(COALESCE(pf550.cfop,'N/A'),'[^0-9A-Za-z]','','g')))
        ),'N/A')                                                                AS nat_bc_cred,
        COALESCE(pf550.vl_rec_comp,0)::DECIMAL(18,6)                            AS vl_item,
        0::DECIMAL(18,6)                                                        AS vl_desc,
        GREATEST(COALESCE(pf550.vl_rec_comp,0),0)::DECIMAL(18,6)                AS vl_liquido,
        0::DECIMAL(18,6)                                                        AS vl_bc_icms,
        0::DECIMAL(18,6)                                                        AS vl_icms,
        0::DECIMAL(18,6)                                                        AS vl_icms_st,
        0::DECIMAL(18,6)                                                        AS vl_ipi,
        0::DECIMAL(18,6)                                                        AS vl_iss,
        GREATEST(COALESCE(pf550.vl_bc_pis,0),0)::DECIMAL(18,6)                  AS bc_pis_cof_escriturada,
        GREATEST(COALESCE(pf550.vl_pis,0),0)::DECIMAL(18,6)                     AS v_pis,
        GREATEST(COALESCE(pf550.vl_cofins,0),0)::DECIMAL(18,6)                  AS v_cof,
        'Não conferido'                                                         AS st_conf
    FROM _t_f550 pf550
    LEFT JOIN _t_0000 p0 USING (filename)

),


BASE AS (
    SELECT
        dp.*,
        CASE
            WHEN SUBSTRING(dt_ref_digitos FROM 1 FOR 4) BETWEEN '1900' AND '2099'
                THEN SUBSTRING(dt_ref_digitos FROM 5 FOR 2) || '/' || SUBSTRING(dt_ref_digitos FROM 1 FOR 4)
            ELSE SUBSTRING(dt_ref_digitos FROM 3 FOR 2) || '/' || SUBSTRING(dt_ref_digitos FROM 5 FOR 4)
        END AS periodo_competencia,
        CASE
            WHEN SUBSTRING(dt_ref_digitos FROM 1 FOR 4) BETWEEN '1900' AND '2099'
                THEN SUBSTRING(dt_ref_digitos FROM 1 FOR 4)
            ELSE SUBSTRING(dt_ref_digitos FROM 5 FOR 4)
        END AS ano_competencia,
        CASE
            WHEN SUBSTRING(dt_ref_digitos FROM 1 FOR 4) BETWEEN '1900' AND '2099'
                THEN SUBSTRING(dt_ref_digitos FROM 5 FOR 2)
            ELSE SUBSTRING(dt_ref_digitos FROM 3 FOR 2)
        END AS mes_competencia,
        GREATEST(
            CASE
                WHEN registro = 'C170' THEN (vl_liquido - vl_icms - vl_icms_st - vl_ipi)
                WHEN sped_origem = 'CONTRIBUIÇÕES' AND registro = 'C500' THEN bc_pis_cof_escriturada
                WHEN registro IN ('A170','D500') THEN (vl_liquido - vl_iss)
                ELSE vl_liquido
            END,
            0
        )::DECIMAL(18,6) AS bc_pis_cof_calculada_base
    FROM (
        SELECT
            DATA_POOL.*,
            LEFT(COALESCE(NULLIF(REGEXP_REPLACE(dt_ref,'[^0-9]','','g'),''),'01011900'),8) AS dt_ref_digitos
        FROM DATA_POOL
    ) dp
)

/* ====================================================================================
   SELEÇÃO FINAL COM AGREGAÇÃO (28 COLUNAS EXATAS)
   ==================================================================================== */
SELECT
    CONCAT_WS('|',
        ano_competencia,
        mes_competencia,
        sped_origem,
        sentido,
        registro,
        cfop,
        cst_final,
        ROUND(aliq_pis_final,4)::VARCHAR,
        ROUND(aliq_cofins_final,4)::VARCHAR,
        nat_bc_cred_final,
        st_conf
    ) AS "chave_unica",
    ('01/' || periodo_competencia)                                              AS "Período",
    ano_competencia                                                             AS "Ano",
    mes_competencia                                                             AS "Mês",
    CASE
        WHEN mes_competencia IN ('01','02','03') THEN '1'
        WHEN mes_competencia IN ('04','05','06') THEN '2'
        WHEN mes_competencia IN ('07','08','09') THEN '3'
        WHEN mes_competencia IN ('10','11','12') THEN '4'
        ELSE 'N/A'
    END                                                                         AS "Trimestre",
    sped_origem                                                                 AS "sped_origem",
    sentido                                                                     AS "sentido",
    registro                                                                    AS "Registro",
    cfop                                                                        AS "CFOP",
    cst_final                                                                   AS "CST",
    aliq_pis_final                                                              AS "Alíq. Pis do SPED",
    aliq_cofins_final                                                           AS "Alíq. Cofins do SPED",
    nat_bc_cred_final                                                           AS "Nat. BC. Créd.",
    st_conf                                                                     AS "status_conferencia",
    COUNT(*)                                                                    AS "qtd_registros",
    GREATEST(COALESCE(SUM(vl_item),0),0)::DECIMAL(18,2)                         AS "total_item",
    GREATEST(COALESCE(SUM(vl_desc),0),0)::DECIMAL(18,2)                         AS "total_desconto",
    GREATEST(COALESCE(SUM(vl_liquido),0),0)::DECIMAL(18,2)                      AS "total_liquido",
    GREATEST(COALESCE(SUM(vl_bc_icms),0),0)::DECIMAL(18,2)                      AS "total_bc_icms",
    GREATEST(COALESCE(SUM(vl_icms),0),0)::DECIMAL(18,2)                         AS "total_icms",
    GREATEST(COALESCE(SUM(vl_icms_st),0),0)::DECIMAL(18,2)                      AS "total_icms_st",
    GREATEST(COALESCE(SUM(vl_ipi),0),0)::DECIMAL(18,2)                          AS "total_ipi",
    GREATEST(COALESCE(SUM(vl_iss),0),0)::DECIMAL(18,2)                          AS "total_iss",
    GREATEST(COALESCE(SUM(bc_pis_cof_calculada_base),0),0)::DECIMAL(18,2)       AS "bc_pis_cof_calculada",
    GREATEST(COALESCE(SUM(bc_pis_cof_escriturada),0),0)::DECIMAL(18,2)          AS "bc_pis_cof_escriturada",
    GREATEST(COALESCE(SUM(v_pis),0),0)::DECIMAL(18,2)                           AS "total_pis",
    GREATEST(COALESCE(SUM(v_cof),0),0)::DECIMAL(18,2)                           AS "total_cof",
    GREATEST(COALESCE(SUM(v_pis + v_cof),0),0)::DECIMAL(18,2)                   AS "total_pis_cofins"
FROM (
    SELECT
        b0.*,
        CASE
            WHEN b0.sped_origem = 'FISCAL' THEN 'N/A'
            WHEN b0.sped_origem = 'CONTRIBUIÇÕES'
             AND b0.registro IN ('C170','C175','C180','C190','C500','C870','D100','D200','D500','F500','F550')
             AND (
                 b0.nat_bc_cred IS NULL
              OR TRIM(b0.nat_bc_cred) = ''
              OR UPPER(TRIM(b0.nat_bc_cred)) = 'N/A'
              OR TRIM(b0.nat_bc_cred) IN ('0','0,0','0,00','0.00')
             )
                THEN COALESCE(cfop_nat.nat_bc_cred,'N/A')
            WHEN b0.nat_bc_cred IS NULL
              OR TRIM(b0.nat_bc_cred) = ''
              OR UPPER(TRIM(b0.nat_bc_cred)) = 'N/A'
              OR TRIM(b0.nat_bc_cred) IN ('0','0,0','0,00','0.00')
                THEN 'N/A'
            WHEN b0.sentido = 'Saída'
             AND NOT (
                 b0.sped_origem = 'CONTRIBUIÇÕES'
             AND b0.registro IN ('C170','C175','C180','C190','C500','C870','D100','D200','D500','F500','F550')
             ) THEN 'N/A'
            ELSE b0.nat_bc_cred
        END                                                                     AS nat_bc_cred_final,

        CASE
            WHEN b0.cst IS NULL THEN '-'
            WHEN REGEXP_REPLACE(b0.cst,'[^0-9]','','g') IN ('','0','00','000','0000') THEN '-'
            ELSE TRIM(b0.cst)
        END                                                                     AS cst_final,

        GREATEST(COALESCE(b0.aliq_pis,0),0)::DECIMAL(18,6)                      AS aliq_pis_final,
        GREATEST(COALESCE(b0.aliq_cofins,0),0)::DECIMAL(18,6)                   AS aliq_cofins_final

    FROM BASE b0
    LEFT JOIN CFOP_NAT_BC_CRED cfop_nat
        ON b0.sped_origem = 'CONTRIBUIÇÕES'
       AND b0.registro IN ('C170','C175','C180','C190','C500','C870','D100','D200','D500','F500','F550')
       AND cfop_nat.cfop = UPPER(TRIM(REGEXP_REPLACE(b0.cfop,'[^0-9A-Za-z]','','g')))
) b
GROUP BY
    periodo_competencia,
    ano_competencia,
    mes_competencia,
    sped_origem,
    sentido,
    registro,
    cfop,
    cst_final,
    aliq_pis_final,
    aliq_cofins_final,
    nat_bc_cred_final,
    st_conf
ORDER BY
    "Ano" ASC, "Mês" ASC, "Registro" ASC
) TO 'D:/FERRAMENTAS_MCS_IA/Laudo/Relatorio_CFOP_SAAM.csv' (
    FORMAT     'csv',
    HEADER     true,
    DELIMITER  ';',
    QUOTE      '"',
    DATEFORMAT '%Y-%m-%d'
);