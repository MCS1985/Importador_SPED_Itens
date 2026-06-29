import pathlib

# Registros que serão somados e suas posições de campo
# (valor do item, base de cálculo PIS/COFINS) – índices são baseados em 0
REGISTROS = {
    "C100": (14, 16),   # VL_TOTAL (col 15) e VL_BC_PIS (col 17)
    "C170": (8, 25),    # VL_ITEM (col 9) e VL_BC_PIS (col 26)
    "C190": (8, 9),
    "C500": (8, 9),
    "D100": (8, 9),
    "F100": (8, 9),
    "F120": (8, 9),
    "F130": (8, 9),
    "F150": (8, 9),
}

somas = {reg: [0.0, 0.0] for reg in REGISTROS}


def processar_linha(linha_bytes: bytes):
    linha = linha_bytes.decode("latin1", errors="replace")
    partes = linha.split("|")
    if len(partes) < 2:
        return
    reg = partes[1]
    if reg not in REGISTROS:
        return
    idx_val, idx_bc = REGISTROS[reg]
    try:
        vl = float(partes[idx_val].replace(",", "."))
    except (IndexError, ValueError):
        vl = 0.0
    try:
        bc = float(partes[idx_bc].replace(",", "."))
    except (IndexError, ValueError):
        bc = 0.0
    somas[reg][0] += vl
    somas[reg][1] += bc


def percorrer_pasta(pasta: str):
    for arq in pathlib.Path(pasta).rglob("*.txt"):
        for linha in arq.read_bytes().splitlines():
            processar_linha(linha)


def gerar_relatorio():
    entrada = ["A170", "C170", "C190", "C500", "D100", "F100", "F120", "F130", "F150"]
    saida = ["A170", "C170", "C175", "C180", "C500", "D100", "D200", "D500", "F100", "F120", "F130", "F150"]
    linhas = []
    linhas.append("CONTRIB. ENTR.|Vlr Item - ORIG.|BC P/C - ORIG")
    for r in entrada:
        v, b = somas.get(r, (0.0, 0.0))
        linhas.append(f"{r}|{v:.2f}|{b:.2f}")
    total_ent = sum(v for vals in [somas.get(r, (0.0, 0.0)) for r in entrada] for v in vals)
    linhas.append(f"TOTAL|{total_ent:.2f}|{total_ent:.2f}")
    linhas.append("")
    linhas.append("CONTR. SAÍD.|Valor do Item|BC PIS/COFINS")
    for r in saida:
        v, b = somas.get(r, (0.0, 0.0))
        linhas.append(f"{r}|{v:.2f}|{b:.2f}")
    total_sai = sum(v for vals in [somas.get(r, (0.0, 0.0)) for r in saida] for v in vals)
    linhas.append(f"TOTAL|{total_sai:.2f}|{total_sai:.2f}")
    return "\n".join(linhas)

if __name__ == "__main__":
    pasta = r"D:\FERRAMENTAS_MCS_IA\Arquivos_SPED\Contribuições"
    percorrer_pasta(pasta)
    print(gerar_relatorio())
    input("\nPressione ENTER para encerrar…")