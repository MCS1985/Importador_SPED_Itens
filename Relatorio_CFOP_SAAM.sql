/* ====================================================================================
   PROJETO: AUDITORIA FISCAL E CONTRIBUIÇÕES - FULL STACK V92 (FLEX ARCHITECTURE)
   DATA: 2026-05-26
   VERSÃO: 9.2 (Final Consolidada)
   OBJETIVO: Relatório de Auditoria Cruzada (Fiscal vs Contribuições)
   CORREÇÕES APLICADAS:
   1. Bloco 05 (D700): Corrigido JOIN para reg_d730 (Analítico real da NFCom).
   2. Booleanos: Ajustada comparação de situacao_conferencia para suportar 'true'/'t'.
   3. Contribuições: Removido MAX(cfop) de tabelas pc_c505, pc_d105, pc_d505 (não possuem CFOP).
   4. CST Cleanup: Implementada blindagem de Regex para remover lixos ('0,00', '00') e 
      uso de marcador '-' para evitar conversão automática do Excel.
   5. Estrutura: Camada BASE centralizada para limpeza de dados.
   ==================================================================================== */

WITH CFOP_NAT_BC_CRED (cfop, nat_bc_cred) AS (
    VALUES
        ('1101', '02'),
        ('1102', '01'),
        ('1111', '02'),
        ('1113', '01'),
        ('1116', '02'),
        ('1117', '01'),
        ('1118', '01'),
        ('1120', '02'),
        ('1121', '01'),
        ('1122', '02'),
        ('1124', '03'),
        ('1125', '03'),
        ('1126', '02'),
        ('1128', '02'),
        ('1132', '02'),
        ('1135', '02'),
        ('1159', '01'),
        ('1201', '12'),
        ('1202', '12'),
        ('1203', '12'),
        ('1204', '12'),
        ('1206', '12'),
        ('1207', '12'),
        ('1215', '12'),
        ('1216', '12'),
        ('1251', '04'),
        ('1252', '04'),
        ('1253', '04'),
        ('1254', '04'),
        ('1255', '04'),
        ('1256', '04'),
        ('1257', '04'),
        ('1351', '07'),
        ('1352', '07'),
        ('1353', '07'),
        ('1354', '07'),
        ('1355', '07'),
        ('1356', '07'),
        ('1360', '07'),
        ('1401', '02'),
        ('1403', '01'),
        ('1406', '10'),
        ('1407', '02'),
        ('1410', '12'),
        ('1411', '12'),
        ('1456', '02'),
        ('1551', '10'),
        ('1556', '02'),
        ('1651', '02'),
        ('1652', '01'),
        ('1653', '02'),
        ('1660', '12'),
        ('1661', '12'),
        ('1662', '12'),
        ('1932', '07'),
        ('1933', '03'),
        ('2101', '02'),
        ('2102', '01'),
        ('2111', '02'),
        ('2113', '01'),
        ('2116', '02'),
        ('2117', '01'),
        ('2118', '01'),
        ('2120', '02'),
        ('2121', '01'),
        ('2122', '02'),
        ('2124', '03'),
        ('2125', '03'),
        ('2126', '02'),
        ('2128', '02'),
        ('2132', '02'),
        ('2135', '02'),
        ('2159', '01'),
        ('2201', '12'),
        ('2202', '12'),
        ('2206', '12'),
        ('2207', '12'),
        ('2215', '12'),
        ('2216', '12'),
        ('2251', '04'),
        ('2252', '04'),
        ('2253', '04'),
        ('2254', '04'),
        ('2255', '04'),
        ('2256', '04'),
        ('2257', '04'),
        ('2351', '07'),
        ('2352', '07'),
        ('2353', '07'),
        ('2354', '07'),
        ('2355', '07'),
        ('2356', '07'),
        ('2401', '02'),
        ('2403', '01'),
        ('2406', '10'),
        ('2407', '02'),
        ('2410', '12'),
        ('2411', '12'),
        ('2456', '02'),
        ('2551', '10'),
        ('2556', '02'),
        ('2651', '02'),
        ('2652', '01'),
        ('2653', '02'),
        ('2660', '12'),
        ('2661', '12'),
        ('2662', '12'),
        ('2932', '07'),
        ('2933', '03'),
        ('3101', '02'),
        ('3102', '01'),
        ('3126', '02'),
        ('3128', '02'),
        ('3251', '01'),
        ('3556', '02'),
        ('3651', '02'),
        ('3652', '01'),
        ('3653', '02'),
        ('D100', 'Escolher Nat'),
        ('F100', 'Escolher Nat'),
        ('F120', 'Escolher Nat'),
        ('F130', 'Escolher Nat'),
        ('F150', 'Escolher Nat'),
        ('F550', 'Escolher Nat')
),

DATA_POOL AS (

    /* ==========================================
       01. FISCAL - C170 (MERCADORIAS)
       ========================================== */
    SELECT 
        'FISCAL'::text                                                          AS sped_origem,
        COALESCE(r0.dt_fin, '19000101')::text                                   AS dt_ref,
        CASE 
            WHEN COALESCE(rc100.ind_oper, '1') = '0' THEN 'Entrada' 
            ELSE 'Saída' 
        END::text                                                               AS sentido,
        'C170'::text                                                            AS registro,
        COALESCE(rc170.cfop, 'N/A')::text                                       AS cfop,
        COALESCE(rc170.cst_icms, '00')::text                                    AS cst,
        0::numeric                                                              AS aliq_pis,
        0::numeric                                                              AS aliq_cofins,
        'N/A'::text                                                             AS nat_bc_cred,
        COALESCE(rc170.vl_item, 0)::numeric                                     AS vl_item,
        COALESCE(rc170.vl_desc, 0)::numeric                                     AS vl_desc,
        GREATEST((COALESCE(rc170.vl_item, 0) - COALESCE(rc170.vl_desc, 0)), 0)::numeric      AS vl_liquido,
        COALESCE(rc170.vl_bc_icms, 0)::numeric                                  AS vl_bc_icms,
        COALESCE(rc170.vl_icms, 0)::numeric                                     AS vl_icms,
        COALESCE(rc170.vl_icms_st, 0)::numeric                                  AS vl_icms_st,
        COALESCE(rc170.vl_ipi, 0)::numeric                                      AS vl_ipi,
        0::numeric                                                              AS vl_iss,
        GREATEST(0::numeric, 0)::numeric                                        AS bc_pis_cof_escriturada,
        GREATEST(0::numeric, 0)::numeric                                        AS v_pis,
        GREATEST(0::numeric, 0)::numeric                                        AS v_cof,
        CASE 
            WHEN rc170.situacao_conferencia::text IN ('t', 'true', '1', 'S', 'Y') THEN 'Item Conferido' 
            ELSE 'Não conferido' 
        END::text                                                               AS st_conf
    FROM public.reg_c170 rc170
    LEFT JOIN public.reg_c100 rc100 ON rc170.fk_c100 = rc100.id
    LEFT JOIN public.reg_0000 r0    ON rc100.fk_0000 = r0.id

    UNION ALL

    /* ==========================================
       02. FISCAL - C500 (ENERGIA / ÁGUA)
       ========================================== */
    SELECT 
        'FISCAL'::text                                                          AS sped_origem,
        COALESCE(r0.dt_fin, '19000101')::text                                   AS dt_ref,
        'Entrada'::text                                                         AS sentido,
        'C500'::text                                                            AS registro,
        COALESCE(rc590.cfop, '1253')::text                                      AS cfop,
        COALESCE(rc590.cst_icms, '00')::text                                    AS cst,
        0::numeric                                                              AS aliq_pis,
        0::numeric                                                              AS aliq_cofins,
        'N/A'::text                                                             AS nat_bc_cred,
        COALESCE(rc500.vl_doc, 0)::numeric                                      AS vl_item,
        0::numeric                                                              AS vl_desc,
        GREATEST(COALESCE(rc500.vl_doc, 0), 0)::numeric                         AS vl_liquido,
        0::numeric                                                              AS vl_bc_icms,
        COALESCE(rc500.vl_icms, 0)::numeric                                     AS vl_icms,
        0::numeric                                                              AS vl_icms_st,
        0::numeric                                                              AS vl_ipi,
        0::numeric                                                              AS vl_iss,
        GREATEST(0::numeric, 0)::numeric                                        AS bc_pis_cof_escriturada,
        GREATEST(0::numeric, 0)::numeric                                        AS v_pis,
        GREATEST(0::numeric, 0)::numeric                                        AS v_cof,
        'Não conferido'::text                                                   AS st_conf
    FROM public.reg_c500 rc500
    LEFT JOIN public.reg_0000 r0 ON rc500.fk_0000 = r0.id
    LEFT JOIN (
        SELECT fk_c500, MAX(cfop) as cfop, MAX(cst_icms) as cst_icms
        FROM public.reg_c590
        GROUP BY fk_c500
    ) rc590 ON rc590.fk_c500 = rc500.id

    UNION ALL

    /* ==========================================
       03. FISCAL - D100 (TRANSPORTES)
       ========================================== */
    SELECT 
        'FISCAL'::text                                                          AS sped_origem,
        COALESCE(r0.dt_fin, '19000101')::text                                   AS dt_ref,
        CASE 
            WHEN COALESCE(rd100.ind_oper, '1') = '0' THEN 'Entrada' 
            ELSE 'Saída' 
        END::text                                                               AS sentido,
        'D100'::text                                                            AS registro,
        COALESCE(rd190.cfop, 'N/A')::text                                       AS cfop,
        '00'::text                                                              AS cst,
        0::numeric                                                              AS aliq_pis,
        0::numeric                                                              AS aliq_cofins,
        'N/A'::text                                                             AS nat_bc_cred,
        COALESCE(rd100.vl_doc, 0)::numeric                                      AS vl_item,
        0::numeric                                                              AS vl_desc,
        GREATEST(COALESCE(rd100.vl_doc, 0), 0)::numeric                         AS vl_liquido,
        0::numeric                                                              AS vl_bc_icms,
        COALESCE(rd100.vl_icms, 0)::numeric                                     AS vl_icms,
        0::numeric                                                              AS vl_icms_st,
        0::numeric                                                              AS vl_ipi,
        0::numeric                                                              AS vl_iss,
        GREATEST(0::numeric, 0)::numeric                                        AS bc_pis_cof_escriturada,
        GREATEST(0::numeric, 0)::numeric                                        AS v_pis,
        GREATEST(0::numeric, 0)::numeric                                        AS v_cof,
        'Não conferido'::text                                                   AS st_conf
    FROM public.reg_d100 rd100
    LEFT JOIN public.reg_d190 rd190 ON rd190.fk_d100 = rd100.id
    LEFT JOIN public.reg_0000 r0    ON rd100.fk_0000 = r0.id

    UNION ALL

    /* ==========================================
       04. FISCAL - D500 (TELECOM)
       ========================================== */
    SELECT 
        'FISCAL'::text                                                          AS sped_origem,
        COALESCE(r0.dt_fin, '19000101')::text                                   AS dt_ref,
        CASE 
            WHEN COALESCE(rd500.ind_oper, '1') = '0' THEN 'Entrada' 
            ELSE 'Saída' 
        END::text                                                               AS sentido,
        'D500'::text                                                            AS registro,
        COALESCE(rd590.cfop, '1352')::text                                      AS cfop,
        COALESCE(rd590.cst_icms, '00')::text                                    AS cst,
        0::numeric                                                              AS aliq_pis,
        0::numeric                                                              AS aliq_cofins,
        'N/A'::text                                                             AS nat_bc_cred,
        COALESCE(rd500.vl_doc, 0)::numeric                                      AS vl_item,
        0::numeric                                                              AS vl_desc,
        GREATEST(COALESCE(rd500.vl_doc, 0), 0)::numeric                         AS vl_liquido,
        0::numeric                                                              AS vl_bc_icms,
        COALESCE(rd500.vl_icms, 0)::numeric                                     AS vl_icms,
        0::numeric                                                              AS vl_icms_st,
        0::numeric                                                              AS vl_ipi,
        0::numeric                                                              AS vl_iss,
        GREATEST(0::numeric, 0)::numeric                                        AS bc_pis_cof_escriturada,
        GREATEST(0::numeric, 0)::numeric                                        AS v_pis,
        GREATEST(0::numeric, 0)::numeric                                        AS v_cof,
        'Não conferido'::text                                                   AS st_conf
    FROM public.reg_d500 rd500
    LEFT JOIN public.reg_0000 r0 ON rd500.fk_0000 = r0.id
    LEFT JOIN (
        SELECT fk_d500, MAX(cfop) as cfop, MAX(cst_icms) as cst_icms
        FROM public.reg_d590
        GROUP BY fk_d500
    ) rd590 ON rd590.fk_d500 = rd500.id

    UNION ALL

    /* ==========================================
       05. FISCAL - D700 (SERVIÇOS TELECOM - NFCom)
       ========================================== */
    SELECT 
        'FISCAL'::text                                                          AS sped_origem,
        COALESCE(r0.dt_fin, '19000101')::text                                   AS dt_ref,
        'Entrada'::text                                                         AS sentido,
        'D700'::text                                                            AS registro,
        COALESCE(rd730.cfop, '1352')::text                                      AS cfop,
        COALESCE(rd730.cst_icms, '00')::text                                    AS cst,
        0::numeric                                                              AS aliq_pis,
        0::numeric                                                              AS aliq_cofins,
        'N/A'::text                                                             AS nat_bc_cred,
        COALESCE(rd700.vl_doc, 0)::numeric                                      AS vl_item,
        0::numeric                                                              AS vl_desc,
        GREATEST(COALESCE(rd700.vl_doc, 0), 0)::numeric                         AS vl_liquido,
        0::numeric                                                              AS vl_bc_icms,
        COALESCE(rd700.vl_icms, 0)::numeric                                     AS vl_icms,
        0::numeric                                                              AS vl_icms_st,
        0::numeric                                                              AS vl_ipi,
        0::numeric                                                              AS vl_iss,
        0::numeric                                                              AS bc_pis_cof_escriturada,
        0::numeric                                                              AS v_pis,
        0::numeric                                                              AS v_cof,
        'Não conferido'::text                                                   AS st_conf
    FROM public.reg_d700 rd700
    LEFT JOIN public.reg_0000 r0 ON rd700.fk_0000 = r0.id
    LEFT JOIN (
        SELECT fk_d700, MAX(cfop) as cfop, MAX(cst_icms) as cst_icms
        FROM public.reg_d730
        GROUP BY fk_d700
    ) rd730 ON rd730.fk_d700 = rd700.id

    UNION ALL

    /* ==========================================
       06. CONTRIB - A170 (SERVIÇOS)
       ========================================== */
    SELECT 
        'CONTRIBUIÇÕES'::text                                                   AS sped_origem,
        COALESCE(p0.dt_fim, '19000101')::text                                   AS dt_ref,
        CASE 
            WHEN COALESCE(pa100.ind_oper, '1') = '0' THEN 'Entrada' 
            ELSE 'Saída' 
        END::text                                                               AS sentido,
        'A170'::text                                                            AS registro,
        '1933'::text                                                            AS cfop,
        COALESCE(pa170.cst_pis, '00')::text                                     AS cst,
        COALESCE(pa170.aliq_pis, 0)::numeric                                    AS aliq_pis,
        COALESCE(pa170.aliq_cofins, 0)::numeric                                 AS aliq_cofins,
        CASE
            WHEN pa170.nat_bc_cred IS NULL
              OR TRIM(pa170.nat_bc_cred::text) = ''
              OR TRIM(pa170.nat_bc_cred::text) IN ('0', '0,0', '0,00', '0.00')
                THEN 'Escriturou vazio'
            ELSE TRIM(pa170.nat_bc_cred::text)
        END::text                                                               AS nat_bc_cred,
        COALESCE(pa170.vl_item, 0)::numeric                                     AS vl_item,
        COALESCE(pa170.vl_desc, 0)::numeric                                     AS vl_desc,
        GREATEST((COALESCE(pa170.vl_item, 0) - COALESCE(pa170.vl_desc, 0)), 0)::numeric      AS vl_liquido,
        0::numeric                                                              AS vl_bc_icms,
        0::numeric                                                              AS vl_icms,
        0::numeric                                                              AS vl_icms_st,
        0::numeric                                                              AS vl_ipi,
        COALESCE(pa100.vl_iss, 0)::numeric                                      AS vl_iss,
        GREATEST(COALESCE(pa170.vl_bc_pis, 0), 0)::numeric                                   AS bc_pis_cof_escriturada,
        GREATEST(COALESCE(pa170.vl_pis, 0), 0)::numeric                                      AS v_pis,
        GREATEST(COALESCE(pa170.vl_cofins, 0), 0)::numeric                                   AS v_cof,
        CASE 
            WHEN pa170.situacao_conferencia::text IN ('t', 'true', '1', 'S', 'Y') THEN 'Item Conferido' 
            ELSE 'Não conferido' 
        END::text                                                               AS st_conf
    FROM public.pc_a170 pa170
    LEFT JOIN public.pc_a100 pa100 ON pa170.fk_a100 = pa100.id
    LEFT JOIN public.pc_0000 p0    ON pa100.fk_0000 = p0.id

    UNION ALL

    /* ==========================================
       07. CONTRIB - C170 (MERCADORIAS)
       ========================================== */
    SELECT 
        'CONTRIBUIÇÕES'::text                                                   AS sped_origem,
        COALESCE(p0.dt_fim, '19000101')::text                                   AS dt_ref,
        CASE 
            WHEN COALESCE(pc100.ind_oper, '1') = '0' THEN 'Entrada' 
            ELSE 'Saída' 
        END::text                                                               AS sentido,
        'C170'::text                                                            AS registro,
        COALESCE(pc170.cfop, 'N/A')::text                                       AS cfop,
        COALESCE(pc170.cst_pis, '00')::text                                     AS cst,
        COALESCE(pc170.aliq_pis, 0)::numeric                                    AS aliq_pis,
        COALESCE(pc170.aliq_cofins, 0)::numeric                                 AS aliq_cofins,
        COALESCE((
            SELECT cfop_nat.nat_bc_cred
            FROM CFOP_NAT_BC_CRED cfop_nat
            WHERE cfop_nat.cfop = UPPER(TRIM(REGEXP_REPLACE(COALESCE(pc170.cfop, 'N/A')::text, '[^0-9A-Za-z]', '', 'g')))
        ), 'N/A')::text                                                         AS nat_bc_cred,
        COALESCE(pc170.vl_item, 0)::numeric                                     AS vl_item,
        COALESCE(pc170.vl_desc, 0)::numeric                                     AS vl_desc,
        GREATEST((COALESCE(pc170.vl_item, 0) - COALESCE(pc170.vl_desc, 0)), 0)::numeric      AS vl_liquido,
        COALESCE(pc170.vl_bc_icms, 0)::numeric                                  AS vl_bc_icms,
        COALESCE(pc170.vl_icms, 0)::numeric                                     AS vl_icms,
        COALESCE(pc170.vl_icms_st, 0)::numeric                                  AS vl_icms_st,
        COALESCE(pc170.vl_ipi, 0)::numeric                                      AS vl_ipi,
        0::numeric                                                              AS vl_iss,
        GREATEST(COALESCE(pc170.vl_bc_pis, 0), 0)::numeric                                   AS bc_pis_cof_escriturada,
        GREATEST(COALESCE(pc170.vl_pis, 0), 0)::numeric                                      AS v_pis,
        GREATEST(COALESCE(pc170.vl_cofins, 0), 0)::numeric                                   AS v_cof,
        CASE 
            WHEN pc170.situacao_conferencia::text IN ('t', 'true', '1', 'S', 'Y') THEN 'Item Conferido' 
            ELSE 'Não conferido' 
        END::text                                                               AS st_conf
    FROM public.pc_c170 pc170
    LEFT JOIN public.pc_c100 pc100 ON pc170.fk_c100 = pc100.id
    LEFT JOIN public.pc_0000 p0    ON pc100.fk_0000 = p0.id

    UNION ALL

    /* ==========================================
       08. CONTRIB - C175 (VENDAS CONSUMIDOR)
       ========================================== */
    SELECT 
        'CONTRIBUIÇÕES'::text                                                   AS sped_origem,
        COALESCE(p0.dt_fim, '19000101')::text                                   AS dt_ref,
        'Saída'::text                                                           AS sentido,
        'C175'::text                                                            AS registro,
        COALESCE(pc175.cfop, 'N/A')::text                                       AS cfop,
        COALESCE(pc175.cst_pis, '00')::text                                     AS cst,
        COALESCE(pc175.aliq_pis, 0)::numeric                                    AS aliq_pis,
        COALESCE(pc175.aliq_cofins, 0)::numeric                                 AS aliq_cofins,
        COALESCE((
            SELECT cfop_nat.nat_bc_cred
            FROM CFOP_NAT_BC_CRED cfop_nat
            WHERE cfop_nat.cfop = UPPER(TRIM(REGEXP_REPLACE(COALESCE(pc175.cfop, 'N/A')::text, '[^0-9A-Za-z]', '', 'g')))
        ), 'N/A')::text                                                         AS nat_bc_cred,
        COALESCE(pc175.vl_opr, 0)::numeric                                      AS vl_item,
        COALESCE(pc175.vl_desc, 0)::numeric                                     AS vl_desc,
        GREATEST((COALESCE(pc175.vl_opr, 0) - COALESCE(pc175.vl_desc, 0)), 0)::numeric      AS vl_liquido,
        CASE 
            WHEN COALESCE(pc100.vl_doc, 0) > 0 
            THEN (COALESCE(pc100.vl_bc_icms, 0) * (COALESCE(pc175.vl_opr, 0) / pc100.vl_doc))::numeric 
            ELSE 0 
        END                                                                     AS vl_bc_icms,
        CASE 
            WHEN COALESCE(pc100.vl_doc, 0) > 0 
            THEN (COALESCE(pc100.vl_icms, 0) * (COALESCE(pc175.vl_opr, 0) / pc100.vl_doc))::numeric 
            ELSE 0 
        END                                                                     AS vl_icms,
        CASE 
            WHEN COALESCE(pc100.vl_doc, 0) > 0 
            THEN (COALESCE(pc100.vl_icms_st, 0) * (COALESCE(pc175.vl_opr, 0) / pc100.vl_doc))::numeric 
            ELSE 0 
        END                                                                     AS vl_icms_st,
        0::numeric                                                              AS vl_ipi,
        0::numeric                                                              AS vl_iss,
        GREATEST(COALESCE(pc175.vl_bc_pis, 0), 0)::numeric                                   AS bc_pis_cof_escriturada,
        GREATEST(COALESCE(pc175.vl_pis, 0), 0)::numeric                                      AS v_pis,
        GREATEST(COALESCE(pc175.vl_cofins, 0), 0)::numeric                                   AS v_cof,
        CASE 
            WHEN pc175.situacao_conferencia::text IN ('t', 'true', '1', 'S', 'Y') THEN 'Item Conferido' 
            ELSE 'Não conferido' 
        END::text                                                               AS st_conf
    FROM public.pc_c175 pc175
    LEFT JOIN public.pc_c100 pc100 ON pc100.id = pc175.fk_c100
    LEFT JOIN public.pc_0000 p0 ON pc175.fk_0000 = p0.id

    UNION ALL

    /* ==========================================
       09. CONTRIB - C180 (SAÍDAS CONSOLIDADAS)
       ========================================== */
    SELECT 
        'CONTRIBUIÇÕES'::text                                                   AS sped_origem,
        COALESCE(p0.dt_fim, '19000101')::text                                   AS dt_ref,
        'Saída'::text                                                           AS sentido,
        'C180'::text                                                            AS registro,
        COALESCE(pc181.cfop, 'N/A')::text                                       AS cfop,
        COALESCE(pc181.cst_pis, '00')::text                                     AS cst,
        COALESCE(pc181.aliq_pis, 0)::numeric                                    AS aliq_pis,
        COALESCE(pc185_agr.aliq_cofins, 0)::numeric                             AS aliq_cofins,
        COALESCE((
            SELECT cfop_nat.nat_bc_cred
            FROM CFOP_NAT_BC_CRED cfop_nat
            WHERE cfop_nat.cfop = UPPER(TRIM(REGEXP_REPLACE(COALESCE(pc181.cfop, 'N/A')::text, '[^0-9A-Za-z]', '', 'g')))
        ), 'N/A')::text                                                         AS nat_bc_cred,
        COALESCE(pc181.vl_item, 0)::numeric                                     AS vl_item,
        COALESCE(pc181.vl_desc, 0)::numeric                                     AS vl_desc,
        GREATEST((COALESCE(pc181.vl_item, 0) - COALESCE(pc181.vl_desc, 0)), 0)::numeric      AS vl_liquido,
        0::numeric                                                              AS vl_bc_icms,
        0::numeric                                                              AS vl_icms,
        0::numeric                                                              AS vl_icms_st,
        0::numeric                                                              AS vl_ipi,
        0::numeric                                                              AS vl_iss,
        GREATEST(COALESCE(pc181.vl_bc_pis, 0), 0)::numeric                                   AS bc_pis_cof_escriturada,
        GREATEST(COALESCE(pc181.vl_pis, 0), 0)::numeric                                      AS v_pis,
        GREATEST(COALESCE(pc185_agr.vl_cofins, 0), 0)::numeric                               AS v_cof,
        'Não conferido'::text                                                   AS st_conf
    FROM public.pc_c181 pc181
    LEFT JOIN public.pc_c180 pc180 ON pc181.fk_c180 = pc180.id
    LEFT JOIN public.pc_0000 p0    ON pc180.fk_0000 = p0.id
    LEFT JOIN (
        SELECT
            fk_c180,
            cfop,
            cst_cofins,
            AVG(COALESCE(aliq_cofins, 0))::numeric AS aliq_cofins,
            SUM(COALESCE(vl_cofins, 0))::numeric AS vl_cofins
        FROM public.pc_c185
        GROUP BY
            fk_c180,
            cfop,
            cst_cofins
    ) pc185_agr
        ON pc185_agr.fk_c180 = pc180.id
       AND pc185_agr.cfop = pc181.cfop
       AND pc185_agr.cst_cofins = pc181.cst_pis

    UNION ALL

    /* ==========================================
       10. CONTRIB - C190 (ENTRADAS CONSOLIDADAS)
       ========================================== */
    SELECT 
        'CONTRIBUIÇÕES'::text                                                   AS sped_origem,
        COALESCE(p0.dt_fim, '19000101')::text                                   AS dt_ref,
        'Entrada'::text                                                         AS sentido,
        'C190'::text                                                            AS registro,
        COALESCE(pc191.cfop, 'N/A')::text                                       AS cfop,
        COALESCE(pc191.cst_pis, '00')::text                                     AS cst,
        COALESCE(pc191.aliq_pis, 0)::numeric                                    AS aliq_pis,
        COALESCE(pc195_agr.aliq_cofins, 0)::numeric                             AS aliq_cofins,
        COALESCE((
            SELECT cfop_nat.nat_bc_cred
            FROM CFOP_NAT_BC_CRED cfop_nat
            WHERE cfop_nat.cfop = UPPER(TRIM(REGEXP_REPLACE(COALESCE(pc191.cfop, 'N/A')::text, '[^0-9A-Za-z]', '', 'g')))
        ), 'N/A')::text                                                         AS nat_bc_cred,
        COALESCE(pc191.vl_item, 0)::numeric                                     AS vl_item,
        COALESCE(pc191.vl_desc, 0)::numeric                                     AS vl_desc,
        GREATEST((COALESCE(pc191.vl_item, 0) - COALESCE(pc191.vl_desc, 0)), 0)::numeric      AS vl_liquido,
        0::numeric                                                              AS vl_bc_icms,
        0::numeric                                                              AS vl_icms,
        0::numeric                                                              AS vl_icms_st,
        0::numeric                                                              AS vl_ipi,
        0::numeric                                                              AS vl_iss,
        GREATEST(COALESCE(pc191.vl_bc_pis, 0), 0)::numeric                                   AS bc_pis_cof_escriturada,
        GREATEST(COALESCE(pc191.vl_pis, 0), 0)::numeric                                      AS v_pis,
        GREATEST(COALESCE(pc195_agr.vl_cofins, 0), 0)::numeric                               AS v_cof,
        'Não conferido'::text                                                   AS st_conf
    FROM public.pc_c191 pc191
    LEFT JOIN public.pc_c190 pc190 ON pc191.fk_c190 = pc190.id
    LEFT JOIN public.pc_0000 p0    ON pc190.fk_0000 = p0.id
    LEFT JOIN (
        SELECT
            fk_c190,
            cfop,
            cst_cofins,
            AVG(COALESCE(aliq_cofins, 0))::numeric AS aliq_cofins,
            SUM(COALESCE(vl_cofins, 0))::numeric AS vl_cofins
        FROM public.pc_c195
        GROUP BY
            fk_c190,
            cfop,
            cst_cofins
    ) pc195_agr
        ON pc195_agr.fk_c190 = pc190.id
       AND pc195_agr.cfop = pc191.cfop
       AND pc195_agr.cst_cofins = pc191.cst_pis

    UNION ALL

    /* ==========================================
       11. CONTRIB - C500 (ENERGIA / ÁGUA)
       ========================================== */
    SELECT 
        'CONTRIBUIÇÕES'::text                                                   AS sped_origem,
        COALESCE(p0.dt_fim, '19000101')::text                                   AS dt_ref,
        'Entrada'::text                                                         AS sentido,
        'C500'::text                                                            AS registro,
        '1253'::text                                                            AS cfop,
        COALESCE(pc501.cst_pis, '00')::text                                     AS cst,
        COALESCE(pc501.aliq_pis, 0)::numeric                                    AS aliq_pis,
        COALESCE(pc505_agr.aliq_cofins, 0)::numeric                             AS aliq_cofins,
        COALESCE((
            SELECT cfop_nat.nat_bc_cred
            FROM CFOP_NAT_BC_CRED cfop_nat
            WHERE cfop_nat.cfop = '1253'
        ), 'N/A')::text                                                         AS nat_bc_cred,
        COALESCE(pc500.vl_doc, 0)::numeric                                      AS vl_item,
        0::numeric                                                              AS vl_desc,
        GREATEST(COALESCE(pc500.vl_doc, 0), 0)::numeric                         AS vl_liquido,
        0::numeric                                                              AS vl_bc_icms,
        COALESCE(pc500.vl_icms, 0)::numeric                                     AS vl_icms,
        0::numeric                                                              AS vl_icms_st,
        0::numeric                                                              AS vl_ipi,
        0::numeric                                                              AS vl_iss,
        GREATEST(COALESCE(pc501.vl_bc_pis, 0), 0)::numeric                                   AS bc_pis_cof_escriturada,
        GREATEST(COALESCE(pc501.vl_pis, 0), 0)::numeric                                      AS v_pis,
        GREATEST(COALESCE(pc505_agr.vl_cofins, 0), 0)::numeric                               AS v_cof,
        CASE 
            WHEN pc500.situacao_conferencia::text IN ('t', 'true', '1', 'S', 'Y') THEN 'Item Conferido' 
            ELSE 'Não conferido' 
        END::text                                                               AS st_conf
    FROM public.pc_c500 pc500
    LEFT JOIN public.pc_c501 pc501 ON pc501.fk_c500 = pc500.id
    LEFT JOIN public.pc_0000 p0    ON pc500.fk_0000 = p0.id
    LEFT JOIN (
        SELECT
            fk_c500,
            cst_cofins,
            AVG(COALESCE(aliq_cofins, 0))::numeric AS aliq_cofins,
            SUM(COALESCE(vl_cofins, 0))::numeric AS vl_cofins
        FROM public.pc_c505
        GROUP BY
            fk_c500,
            cst_cofins
    ) pc505_agr
        ON pc505_agr.fk_c500 = pc500.id
       AND pc505_agr.cst_cofins = pc501.cst_pis

    UNION ALL

    /* ==========================================
       12. CONTRIB - C870 (ECF)
       ========================================== */
    SELECT 
        'CONTRIBUIÇÕES'::text                                                   AS sped_origem,
        COALESCE(p0.dt_fim, '19000101')::text                                   AS dt_ref,
        'Saída'::text                                                           AS sentido,
        'C870'::text                                                            AS registro,
        COALESCE(pc870.cfop, 'N/A')::text                                       AS cfop,
        COALESCE(pc870.cst_pis, '00')::text                                     AS cst,
        COALESCE(pc870.aliq_pis, 0)::numeric                                    AS aliq_pis,
        COALESCE(pc870.aliq_cofins, 0)::numeric                                 AS aliq_cofins,
        COALESCE((
            SELECT cfop_nat.nat_bc_cred
            FROM CFOP_NAT_BC_CRED cfop_nat
            WHERE cfop_nat.cfop = UPPER(TRIM(REGEXP_REPLACE(COALESCE(pc870.cfop, 'N/A')::text, '[^0-9A-Za-z]', '', 'g')))
        ), 'N/A')::text                                                         AS nat_bc_cred,
        COALESCE(pc870.vl_item, 0)::numeric                                     AS vl_item,
        COALESCE(pc870.vl_desc, 0)::numeric                                     AS vl_desc,
        GREATEST((COALESCE(pc870.vl_item, 0) - COALESCE(pc870.vl_desc, 0)), 0)::numeric      AS vl_liquido,
        0::numeric                                                              AS vl_bc_icms,
        0::numeric                                                              AS vl_icms,
        0::numeric                                                              AS vl_icms_st,
        0::numeric                                                              AS vl_ipi,
        0::numeric                                                              AS vl_iss,
        GREATEST(COALESCE(pc870.vl_bc_pis, 0), 0)::numeric                                   AS bc_pis_cof_escriturada,
        GREATEST(COALESCE(pc870.vl_pis, 0), 0)::numeric                                      AS v_pis,
        GREATEST(COALESCE(pc870.vl_cofins, 0), 0)::numeric                                   AS v_cof,
        CASE 
            WHEN pc870.situacao_conferencia::text IN ('t', 'true', '1', 'S', 'Y') THEN 'Item Conferido' 
            ELSE 'Não conferido' 
        END::text                                                               AS st_conf
    FROM public.pc_c870 pc870
    LEFT JOIN public.pc_0000 p0 ON pc870.fk_0000 = p0.id

    UNION ALL

    /* ==========================================
       13. CONTRIB - D100 (ENTRADAS DE TRANSPORTES)
       ========================================== */
    SELECT 
        'CONTRIBUIÇÕES'::text                                                   AS sped_origem,
        COALESCE(p0.dt_fim, '19000101')::text                                   AS dt_ref,
        CASE 
            WHEN COALESCE(pd100.ind_oper, '0') = '0' THEN 'Entrada' 
            ELSE 'Saída' 
        END::text                                                               AS sentido,
        'D100'::text                                                            AS registro,
        '1353'::text                                                            AS cfop,
        COALESCE(pd101.cst_pis, '00')::text                                     AS cst,
        COALESCE(pd101.aliq_pis, 0)::numeric                                    AS aliq_pis,
        COALESCE(pd105_agr.aliq_cofins, 0)::numeric                             AS aliq_cofins,
        COALESCE((
            SELECT cfop_nat.nat_bc_cred
            FROM CFOP_NAT_BC_CRED cfop_nat
            WHERE cfop_nat.cfop = '1353'
        ), 'N/A')::text                                                         AS nat_bc_cred,
        COALESCE(pd100.vl_doc, 0)::numeric                                      AS vl_item,
        0::numeric                                                              AS vl_desc,
        GREATEST(COALESCE(pd100.vl_doc, 0), 0)::numeric                         AS vl_liquido,
        0::numeric                                                              AS vl_bc_icms,
        COALESCE(pd100.vl_icms, 0)::numeric                                     AS vl_icms,
        0::numeric                                                              AS vl_icms_st,
        0::numeric                                                              AS vl_ipi,
        0::numeric                                                              AS vl_iss,
        GREATEST(COALESCE(pd101.vl_bc_pis, 0), 0)::numeric                                   AS bc_pis_cof_escriturada,
        GREATEST(COALESCE(pd101.vl_pis, 0), 0)::numeric                                      AS v_pis,
        GREATEST(COALESCE(pd105_agr.vl_cofins, 0), 0)::numeric                               AS v_cof,
        CASE 
            WHEN pd100.situacao_conferencia::text IN ('t', 'true', '1', 'S', 'Y') THEN 'Item Conferido' 
            ELSE 'Não conferido' 
        END::text                                                               AS st_conf
    FROM public.pc_d100 pd100
    LEFT JOIN public.pc_d101 pd101 ON pd101.fk_d100 = pd100.id
    LEFT JOIN public.pc_0000 p0    ON pd100.fk_0000 = p0.id
    LEFT JOIN (
        SELECT
            fk_d100,
            cst_cofins,
            AVG(COALESCE(aliq_cofins, 0))::numeric AS aliq_cofins,
            SUM(COALESCE(vl_cofins, 0))::numeric AS vl_cofins
        FROM public.pc_d105
        GROUP BY
            fk_d100,
            cst_cofins
    ) pd105_agr
        ON pd105_agr.fk_d100 = pd100.id
       AND pd105_agr.cst_cofins = pd101.cst_pis

    UNION ALL

    /* ==========================================
       14. CONTRIB - D200 (SAÍDAS DE TRANSPORTES)
       ========================================== */
    SELECT 
        'CONTRIBUIÇÕES'::text                                                   AS sped_origem,
        COALESCE(p0.dt_fim, '19000101')::text                                   AS dt_ref,
        'Saída'::text                                                           AS sentido,
        'D200'::text                                                            AS registro,
        COALESCE(pd200.cfop, 'N/A')::text                                       AS cfop,
        COALESCE(pd201.cst_pis, '00')::text                                     AS cst,
        COALESCE(pd201.aliq_pis, 0)::numeric                                    AS aliq_pis,
        COALESCE(pd205_agr.aliq_cofins, 0)::numeric                             AS aliq_cofins,
        COALESCE((
            SELECT cfop_nat.nat_bc_cred
            FROM CFOP_NAT_BC_CRED cfop_nat
            WHERE cfop_nat.cfop = UPPER(TRIM(REGEXP_REPLACE(COALESCE(pd200.cfop, 'N/A')::text, '[^0-9A-Za-z]', '', 'g')))
        ), 'N/A')::text                                                         AS nat_bc_cred,
        COALESCE(pd200.vl_doc, 0)::numeric                                      AS vl_item,
        COALESCE(pd200.vl_desc, 0)::numeric                                     AS vl_desc,
        GREATEST((COALESCE(pd200.vl_doc, 0) - COALESCE(pd200.vl_desc, 0)), 0)::numeric       AS vl_liquido,
        0::numeric                                                              AS vl_bc_icms,
        COALESCE(pd200.vl_icms, 0)::numeric                                     AS vl_icms,
        0::numeric                                                              AS vl_icms_st,
        0::numeric                                                              AS vl_ipi,
        0::numeric                                                              AS vl_iss,
        GREATEST(COALESCE(pd201.vl_bc_pis, 0), 0)::numeric                                   AS bc_pis_cof_escriturada,
        GREATEST(COALESCE(pd201.vl_pis, 0), 0)::numeric                                      AS v_pis,
        GREATEST(COALESCE(pd205_agr.vl_cofins, 0), 0)::numeric                               AS v_cof,
        CASE 
            WHEN pd200.situacao_conferencia::text IN ('t', 'true', '1', 'S', 'Y') THEN 'Item Conferido' 
            ELSE 'Não conferido' 
        END::text                                                               AS st_conf
    FROM public.pc_d200 pd200
    LEFT JOIN public.pc_d201 pd201 ON pd201.fk_d200 = pd200.id
    LEFT JOIN public.pc_0000 p0    ON pd200.fk_0000 = p0.id
    LEFT JOIN (
        SELECT
            fk_d200,
            cst_cofins,
            AVG(COALESCE(aliq_cofins, 0))::numeric AS aliq_cofins,
            SUM(COALESCE(vl_cofins, 0))::numeric AS vl_cofins
        FROM public.pc_d205
        GROUP BY
            fk_d200,
            cst_cofins
    ) pd205_agr
        ON pd205_agr.fk_d200 = pd200.id
       AND pd205_agr.cst_cofins = pd201.cst_pis

    UNION ALL

    /* ==========================================
       15. CONTRIB - D500 (TELECOM - AJUSTADO)
       ========================================== */
    SELECT 
        'CONTRIBUIÇÕES'::text                                                   AS sped_origem,
        COALESCE(p0.dt_fim, '19000101')::text                                   AS dt_ref,
        CASE 
            WHEN COALESCE(pd500.ind_oper, '1') = '0' THEN 'Entrada' 
            ELSE 'Saída' 
        END::text                                                               AS sentido,
        'D500'::text                                                            AS registro,
        '1352'::text                                                            AS cfop,
        COALESCE(pd501.cst_pis, '00')::text                                     AS cst,
        COALESCE(pd501.aliq_pis, 0)::numeric                                    AS aliq_pis,
        COALESCE(pd505_agr.aliq_cofins, 0)::numeric                             AS aliq_cofins,
        COALESCE((
            SELECT cfop_nat.nat_bc_cred
            FROM CFOP_NAT_BC_CRED cfop_nat
            WHERE cfop_nat.cfop = '1352'
        ), 'N/A')::text                                                         AS nat_bc_cred,
        COALESCE(pd500.vl_serv, 0)::numeric                                     AS vl_item,
        COALESCE(pd500.vl_desc, 0)::numeric                                     AS vl_desc,
        GREATEST((COALESCE(pd500.vl_serv, 0) - COALESCE(pd500.vl_desc, 0)), 0)::numeric      AS vl_liquido,
        0::numeric                                                              AS vl_bc_icms,
        COALESCE(pd500.vl_icms, 0)::numeric                                     AS vl_icms,
        0::numeric                                                              AS vl_icms_st,
        0::numeric                                                              AS vl_ipi,
        0::numeric                                                              AS vl_iss,
        GREATEST(COALESCE(pd501.vl_bc_pis, 0), 0)::numeric                                   AS bc_pis_cof_escriturada,
        GREATEST(COALESCE(pd501.vl_pis, 0), 0)::numeric                                      AS v_pis,
        GREATEST(COALESCE(pd505_agr.vl_cofins, 0), 0)::numeric                               AS v_cof,
        CASE 
            WHEN pd500.situacao_conferencia::text IN ('t', 'true', '1', 'S', 'Y') THEN 'Item Conferido' 
            ELSE 'Não conferido' 
        END::text                                                               AS st_conf
    FROM public.pc_d500 pd500
    LEFT JOIN public.pc_d501 pd501 ON pd501.fk_d500 = pd500.id
    LEFT JOIN public.pc_0000 p0    ON pd500.fk_0000 = p0.id
    LEFT JOIN (
        SELECT
            fk_d500,
            cst_cofins,
            AVG(COALESCE(aliq_cofins, 0))::numeric AS aliq_cofins,
            SUM(COALESCE(vl_cofins, 0))::numeric AS vl_cofins
        FROM public.pc_d505
        GROUP BY
            fk_d500,
            cst_cofins
    ) pd505_agr
        ON pd505_agr.fk_d500 = pd500.id
       AND pd505_agr.cst_cofins = pd501.cst_pis

    UNION ALL

    /* ==========================================
       16. CONTRIB - F100 (DEMAIS DOCUMENTOS)
       ========================================== */
    SELECT 
        'CONTRIBUIÇÕES'::text                                                   AS sped_origem,
        COALESCE(p0.dt_fim, '19000101')::text                                   AS dt_ref,
        CASE 
            WHEN COALESCE(pf100.ind_oper, '1') = '0' THEN 'Entrada' 
            ELSE 'Saída' 
        END::text                                                               AS sentido,
        'F100'::text                                                            AS registro,
        'F100'::text                                                            AS cfop,
        COALESCE(pf100.cst_pis, '00')::text                                     AS cst,
        COALESCE(pf100.aliq_pis, 0)::numeric                                    AS aliq_pis,
        COALESCE(pf100.aliq_cofins, 0)::numeric                                 AS aliq_cofins,
        COALESCE(pf100.nat_bc_cred, 'N/A')::text                                AS nat_bc_cred,
        COALESCE(pf100.vl_oper, 0)::numeric                                     AS vl_item,
        0::numeric                                                              AS vl_desc,
        GREATEST(COALESCE(pf100.vl_oper, 0), 0)::numeric                        AS vl_liquido,
        0::numeric                                                              AS vl_bc_icms,
        0::numeric                                                              AS vl_icms,
        0::numeric                                                              AS vl_icms_st,
        0::numeric                                                              AS vl_ipi,
        0::numeric                                                              AS vl_iss,
        GREATEST(COALESCE(pf100.vl_bc_pis, 0), 0)::numeric                                   AS bc_pis_cof_escriturada,
        GREATEST(COALESCE(pf100.vl_pis, 0), 0)::numeric                                      AS v_pis,
        GREATEST(COALESCE(pf100.vl_cofins, 0), 0)::numeric                                   AS v_cof,
        CASE 
            WHEN pf100.situacao_conferencia::text IN ('t', 'true', '1', 'S', 'Y') THEN 'Item Conferido' 
            ELSE 'Não conferido' 
        END::text                                                               AS st_conf
    FROM public.pc_f100 pf100
    LEFT JOIN public.pc_0000 p0 ON pf100.fk_0000 = p0.id

    UNION ALL

    /* ==========================================
       17. CONTRIB - F120 (ATIVO IMOBILIZADO DEPREC.)
       ========================================== */
    SELECT 
        'CONTRIBUIÇÕES'::text                                                   AS sped_origem,
        COALESCE(p0.dt_fim, '19000101')::text                                   AS dt_ref,
        'Entrada'::text                                                         AS sentido,
        'F120'::text                                                            AS registro,
        'F120'::text                                                            AS cfop,
        COALESCE(pf120.cst_pis, '00')::text                                     AS cst,
        COALESCE(pf120.aliq_pis, 0)::numeric                                    AS aliq_pis,
        COALESCE(pf120.aliq_cofins, 0)::numeric                                 AS aliq_cofins,
        COALESCE(pf120.nat_bc_cred, 'N/A')::text                                AS nat_bc_cred,
        COALESCE(pf120.vl_oper_dep, 0)::numeric                                 AS vl_item,
        0::numeric                                                              AS vl_desc,
        GREATEST(COALESCE(pf120.vl_oper_dep, 0), 0)::numeric                    AS vl_liquido,
        0::numeric                                                              AS vl_bc_icms,
        0::numeric                                                              AS vl_icms,
        0::numeric                                                              AS vl_icms_st,
        0::numeric                                                              AS vl_ipi,
        0::numeric                                                              AS vl_iss,
        GREATEST(COALESCE(pf120.vl_bc_pis, 0), 0)::numeric                                   AS bc_pis_cof_escriturada,
        GREATEST(COALESCE(pf120.vl_pis, 0), 0)::numeric                                      AS v_pis,
        GREATEST(COALESCE(pf120.vl_cofins, 0), 0)::numeric                                   AS v_cof,
        CASE 
            WHEN pf120.situacao_conferencia::text IN ('t', 'true', '1', 'S', 'Y') THEN 'Item Conferido' 
            ELSE 'Não conferido' 
        END::text                                                               AS st_conf
    FROM public.pc_f120 pf120
    LEFT JOIN public.pc_0000 p0 ON pf120.fk_0000 = p0.id

    UNION ALL

    /* ==========================================
       18. CONTRIB - F130 (ATIVO IMOBILIZADO AQUIS.)
       ========================================== */
    SELECT 
        'CONTRIBUIÇÕES'::text                                                   AS sped_origem,
        COALESCE(p0.dt_fim, '19000101')::text                                   AS dt_ref,
        'Entrada'::text                                                         AS sentido,
        'F130'::text                                                            AS registro,
        'F130'::text                                                            AS cfop,
        COALESCE(pf130.cst_pis, '00')::text                                     AS cst,
        COALESCE(pf130.aliq_pis, 0)::numeric                                    AS aliq_pis,
        COALESCE(pf130.aliq_cofins, 0)::numeric                                 AS aliq_cofins,
        COALESCE(pf130.nat_bc_cred, 'N/A')::text                                AS nat_bc_cred,
        COALESCE(pf130.vl_oper_aquis, 0)::numeric                               AS vl_item,
        0::numeric                                                              AS vl_desc,
        GREATEST(COALESCE(pf130.vl_oper_aquis, 0), 0)::numeric                  AS vl_liquido,
        0::numeric                                                              AS vl_bc_icms,
        0::numeric                                                              AS vl_icms,
        0::numeric                                                              AS vl_icms_st,
        0::numeric                                                              AS vl_ipi,
        0::numeric                                                              AS vl_iss,
        GREATEST(COALESCE(pf130.vl_bc_pis, 0), 0)::numeric                                   AS bc_pis_cof_escriturada,
        GREATEST(COALESCE(pf130.vl_pis, 0), 0)::numeric                                      AS v_pis,
        GREATEST(COALESCE(pf130.vl_cofins, 0), 0)::numeric                                   AS v_cof,
        'Não conferido'::text                                                   AS st_conf
    FROM public.pc_f130 pf130
    LEFT JOIN public.pc_0000 p0 ON pf130.fk_0000 = p0.id

    UNION ALL

    /* ==========================================
       19. CONTRIB - F150 (ESTOQUE ABERTURA)
       ========================================== */
    SELECT 
        'CONTRIBUIÇÕES'::text                                                   AS sped_origem,
        COALESCE(p0.dt_fim, '19000101')::text                                   AS dt_ref,
        'Entrada'::text                                                         AS sentido,
        'F150'::text                                                            AS registro,
        'F150'::text                                                            AS cfop,
        COALESCE(pf150.cst_pis, '00')::text                                     AS cst,
        COALESCE(pf150.aliq_pis, 0)::numeric                                    AS aliq_pis,
        COALESCE(pf150.aliq_cofins, 0)::numeric                                 AS aliq_cofins,
        COALESCE(pf150.nat_bc_cred, 'N/A')::text                                AS nat_bc_cred,
        COALESCE(pf150.vl_bc_est, 0)::numeric                                   AS vl_item,
        0::numeric                                                              AS vl_desc,
        GREATEST(COALESCE(pf150.vl_bc_est, 0), 0)::numeric                      AS vl_liquido,
        0::numeric                                                              AS vl_bc_icms,
        0::numeric                                                              AS vl_icms,
        0::numeric                                                              AS vl_icms_st,
        0::numeric                                                              AS vl_ipi,
        0::numeric                                                              AS vl_iss,
        GREATEST(COALESCE(pf150.vl_bc_est, 0), 0)::numeric                                   AS bc_pis_cof_escriturada,
        GREATEST(COALESCE(pf150.vl_cred_pis, 0), 0)::numeric                                 AS v_pis,
        GREATEST(COALESCE(pf150.vl_cred_cofins, 0), 0)::numeric                              AS v_cof,
        CASE 
            WHEN pf150.situacao_conferencia::text IN ('t', 'true', '1', 'S', 'Y') THEN 'Item Conferido' 
            ELSE 'Não conferido' 
        END::text                                                               AS st_conf
    FROM public.pc_f150 pf150
    LEFT JOIN public.pc_0000 p0 ON pf150.fk_0000 = p0.id

    UNION ALL

    /* ==========================================
       20. CONTRIB - F500 (RECEITAS PRÓPRIAS)
       ========================================== */
    SELECT 
        'CONTRIBUIÇÕES'::text                                                   AS sped_origem,
        COALESCE(p0.dt_fim, '19000101')::text                                   AS dt_ref,
        'Saída'::text                                                           AS sentido,
        'F500'::text                                                            AS registro,
        COALESCE(pf500.cfop, 'N/A')::text                                       AS cfop,
        COALESCE(pf500.cst_pis, '00')::text                                     AS cst,
        COALESCE(pf500.aliq_pis, 0)::numeric                                    AS aliq_pis,
        COALESCE(pf500.aliq_cofins, 0)::numeric                                 AS aliq_cofins,
        COALESCE((
            SELECT cfop_nat.nat_bc_cred
            FROM CFOP_NAT_BC_CRED cfop_nat
            WHERE cfop_nat.cfop = UPPER(TRIM(REGEXP_REPLACE(COALESCE(pf500.cfop, 'N/A')::text, '[^0-9A-Za-z]', '', 'g')))
        ), 'N/A')::text                                                         AS nat_bc_cred,
        COALESCE(pf500.vl_rec_caixa, 0)::numeric                                AS vl_item,
        0::numeric                                                              AS vl_desc,
        GREATEST(COALESCE(pf500.vl_rec_caixa, 0), 0)::numeric                   AS vl_liquido,
        0::numeric                                                              AS vl_bc_icms,
        0::numeric                                                              AS vl_icms,
        0::numeric                                                              AS vl_icms_st,
        0::numeric                                                              AS vl_ipi,
        0::numeric                                                              AS vl_iss,
        GREATEST(COALESCE(pf500.vl_bc_pis, 0), 0)::numeric                                   AS bc_pis_cof_escriturada,
        GREATEST(COALESCE(pf500.vl_pis, 0), 0)::numeric                                      AS v_pis,
        GREATEST(COALESCE(pf500.vl_cofins, 0), 0)::numeric                                   AS v_cof,
        'Não conferido'::text                                                   AS st_conf
    FROM public.pc_f500 pf500
    LEFT JOIN public.pc_0000 p0 ON pf500.fk_0000 = p0.id

    UNION ALL

    /* ==========================================
       21. CONTRIB - F550 (RECEITAS POR OPERAÇÃO)
       ========================================== */
    SELECT 
        'CONTRIBUIÇÕES'::text                                                   AS sped_origem,
        COALESCE(p0.dt_fim, '19000101')::text                                   AS dt_ref,
        'Saída'::text                                                           AS sentido,
        'F550'::text                                                            AS registro,
        COALESCE(pf550.cfop, 'N/A')::text                                       AS cfop,
        COALESCE(pf550.cst_pis, '00')::text                                     AS cst,
        COALESCE(pf550.aliq_pis, 0)::numeric                                    AS aliq_pis,
        COALESCE(pf550.aliq_cofins, 0)::numeric                                 AS aliq_cofins,
        COALESCE((
            SELECT cfop_nat.nat_bc_cred
            FROM CFOP_NAT_BC_CRED cfop_nat
            WHERE cfop_nat.cfop = UPPER(TRIM(REGEXP_REPLACE(COALESCE(pf550.cfop, 'N/A')::text, '[^0-9A-Za-z]', '', 'g')))
        ), 'N/A')::text                                                         AS nat_bc_cred,
        COALESCE(pf550.vl_rec_comp, 0)::numeric                                 AS vl_item,
        0::numeric                                                              AS vl_desc,
        GREATEST(COALESCE(pf550.vl_rec_comp, 0), 0)::numeric                    AS vl_liquido,
        0::numeric                                                              AS vl_bc_icms,
        0::numeric                                                              AS vl_icms,
        0::numeric                                                              AS vl_icms_st,
        0::numeric                                                              AS vl_ipi,
        0::numeric                                                              AS vl_iss,
        GREATEST(COALESCE(pf550.vl_bc_pis, 0), 0)::numeric                                   AS bc_pis_cof_escriturada,
        GREATEST(COALESCE(pf550.vl_pis, 0), 0)::numeric                                      AS v_pis,
        GREATEST(COALESCE(pf550.vl_cofins, 0), 0)::numeric                                   AS v_cof,
        'Não conferido'::text                                                   AS st_conf
    FROM public.pc_f550 pf550
    LEFT JOIN public.pc_0000 p0 ON pf550.fk_0000 = p0.id

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
                WHEN registro IN ('A170', 'D500') THEN (vl_liquido - vl_iss)
                ELSE vl_liquido
            END,
            0
        )::numeric AS bc_pis_cof_calculada_base
    FROM (
        SELECT
            DATA_POOL.*,
            LEFT(COALESCE(NULLIF(REGEXP_REPLACE(dt_ref::text, '[^0-9]', '', 'g'), ''), '01011900'), 8) AS dt_ref_digitos
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
        ROUND(aliq_pis_final, 4)::text,
        ROUND(aliq_cofins_final, 4)::text,
        nat_bc_cred_final,
        st_conf
    ) AS "chave_unica",
    ('01/' || periodo_competencia) AS "Período",
    ano_competencia AS "Ano",
    mes_competencia AS "Mês",
    CASE
        WHEN mes_competencia IN ('01', '02', '03') THEN '1'
        WHEN mes_competencia IN ('04', '05', '06') THEN '2'
        WHEN mes_competencia IN ('07', '08', '09') THEN '3'
        WHEN mes_competencia IN ('10', '11', '12') THEN '4'
        ELSE 'N/A'
    END::text AS "Trimestre",
    sped_origem AS "sped_origem",
    sentido AS "sentido",
    registro AS "Registro",
    cfop AS "CFOP",
    cst_final AS "CST",
    aliq_pis_final AS "Alíq. Pis do SPED",
    aliq_cofins_final AS "Alíq. Cofins do SPED",
    nat_bc_cred_final AS "Nat. BC. Créd.",
    st_conf AS "status_conferencia",
    COUNT(*) AS "qtd_registros",
    GREATEST(COALESCE(SUM(vl_item), 0), 0)::numeric(18,2) AS "total_item",
    GREATEST(COALESCE(SUM(vl_desc), 0), 0)::numeric(18,2) AS "total_desconto",
    GREATEST(COALESCE(SUM(vl_liquido), 0), 0)::numeric(18,2) AS "total_liquido",
    GREATEST(COALESCE(SUM(vl_bc_icms), 0), 0)::numeric(18,2) AS "total_bc_icms",
    GREATEST(COALESCE(SUM(vl_icms), 0), 0)::numeric(18,2) AS "total_icms",
    GREATEST(COALESCE(SUM(vl_icms_st), 0), 0)::numeric(18,2) AS "total_icms_st",
    GREATEST(COALESCE(SUM(vl_ipi), 0), 0)::numeric(18,2) AS "total_ipi",
    GREATEST(COALESCE(SUM(vl_iss), 0), 0)::numeric(18,2) AS "total_iss",
    GREATEST(COALESCE(SUM(bc_pis_cof_calculada_base), 0), 0)::numeric(18,2) AS "bc_pis_cof_calculada",
    GREATEST(COALESCE(SUM(bc_pis_cof_escriturada), 0), 0)::numeric(18,2) AS "bc_pis_cof_escriturada",
    GREATEST(COALESCE(SUM(v_pis), 0), 0)::numeric(18,2) AS "total_pis",
    GREATEST(COALESCE(SUM(v_cof), 0), 0)::numeric(18,2) AS "total_cof",
    GREATEST(COALESCE(SUM(v_pis + v_cof), 0), 0)::numeric(18,2) AS "total_pis_cofins"
FROM (
    SELECT
        b0.*,
        -- Tratamento centralizado da Natureza da BC
        CASE
            WHEN b0.sped_origem = 'FISCAL' THEN 'N/A'
            WHEN b0.sped_origem = 'CONTRIBUIÇÕES'
             AND b0.registro IN ('C170', 'C175', 'C180', 'C190', 'C500', 'C870', 'D100', 'D200', 'D500', 'F500', 'F550')
             AND (
                 b0.nat_bc_cred IS NULL
              OR TRIM(b0.nat_bc_cred::text) = ''
              OR UPPER(TRIM(b0.nat_bc_cred::text)) = 'N/A'
              OR TRIM(b0.nat_bc_cred::text) IN ('0', '0,0', '0,00', '0.00')
             )
                THEN COALESCE(cfop_nat.nat_bc_cred, 'N/A')
            WHEN b0.nat_bc_cred IS NULL
              OR TRIM(b0.nat_bc_cred::text) = ''
              OR UPPER(TRIM(b0.nat_bc_cred::text)) = 'N/A'
              OR TRIM(b0.nat_bc_cred::text) IN ('0', '0,0', '0,00', '0.00')
                THEN 'N/A'
            WHEN b0.sentido = 'Saída'
             AND NOT (
                 b0.sped_origem = 'CONTRIBUIÇÕES'
             AND b0.registro IN ('C170', 'C175', 'C180', 'C190', 'C500', 'C870', 'D100', 'D200', 'D500', 'F500', 'F550')
             ) THEN 'N/A'
            ELSE b0.nat_bc_cred::text
        END AS nat_bc_cred_final,
        
        -- Tratamento centralizado do CST (Blindagem Nível Máximo)
        CASE
            WHEN b0.cst IS NULL THEN '-'
            WHEN REGEXP_REPLACE(b0.cst::text, '[^0-9]', '', 'g') IN ('', '0', '00', '000', '0000')
                THEN '-'
            ELSE TRIM(b0.cst::text)
        END AS cst_final,

        GREATEST(COALESCE(b0.aliq_pis, 0), 0)::numeric AS aliq_pis_final,
        GREATEST(COALESCE(b0.aliq_cofins, 0), 0)::numeric AS aliq_cofins_final

    FROM BASE b0
    LEFT JOIN CFOP_NAT_BC_CRED cfop_nat
        ON b0.sped_origem = 'CONTRIBUIÇÕES'
       AND b0.registro IN ('C170', 'C175', 'C180', 'C190', 'C500', 'C870', 'D100', 'D200', 'D500', 'F500', 'F550')
       AND cfop_nat.cfop = UPPER(TRIM(REGEXP_REPLACE(b0.cfop::text, '[^0-9A-Za-z]', '', 'g')))
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
    "Ano" ASC, "Mês" ASC, "Registro" ASC;

