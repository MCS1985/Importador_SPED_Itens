import glob, os
# Find C501 files
all_txt = glob.glob('D:/FERRAMENTAS_MCS_IA/**/*.txt', recursive=True)
for fname in sorted(all_txt):
    with open(fname, 'rb') as f:
        if b'|C501|' in f.read():
            folder = os.path.dirname(fname)
            basename = os.path.basename(fname)
            print(f'{folder}')
            print(f'  {basename}')
            # Show first C501 line
            with open(fname, 'r', encoding='latin-1') as f2:
                for line in f2:
                    if '|C501|' in line:
                        parts = line.strip().split('|')
                        print(f'  C501: cst=[{parts[2]}] vl_item=[{parts[3]}] bc=[{parts[4]}] aliq=[{parts[5]}] qtd=[{parts[6]}] aliq_reais=[{parts[7]}] vl_pis=[{parts[8]}]')
                        break
            print()
