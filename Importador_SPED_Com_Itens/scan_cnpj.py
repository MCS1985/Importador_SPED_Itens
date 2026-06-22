import glob, re, os
all_txt = glob.glob('D:/FERRAMENTAS_MCS_IA/**/*.txt', recursive=True)
print(f'Total: {len(all_txt)}')
cnpjs = {}
for fname in sorted(all_txt):
    basename = os.path.basename(fname)
    m = re.search(r'(\d{14})', basename)
    if m:
        cnpj = m.group(1)
    else:
        cnpj = 'unknown'
    has_c501 = False
    with open(fname, 'rb') as f:
        if b'|C501|' in f.read():
            has_c501 = True
    if cnpj not in cnpjs:
        cnpjs[cnpj] = {'count': 0, 'has_c501': False}
    cnpjs[cnpj]['count'] += 1
    if has_c501:
        cnpjs[cnpj]['has_c501'] = True
for cnpj, info in sorted(cnpjs.items()):
    print(f'CNPJ {cnpj}: {info["count"]} files, C501={info["has_c501"]}')
