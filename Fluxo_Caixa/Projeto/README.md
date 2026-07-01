# Fluxo · Finanças Pessoais

App pessoal de fluxo de caixa: receitas, despesas, centros de resultado e dashboard — tudo no navegador, sem instalar nada.

**Repositório:** https://github.com/MCS1985/Fluxo-caixa

---

## Usar (qualquer PC)

1. Abra https://mcs1985.github.io/Fluxo-caixa
2. Faça login com **admin** / **admin**
3. Navegue entre Dashboard, Lançamentos e Naturezas & CRs
4. Os dados ficam salvos automaticamente no navegador (localStorage)

---

## Editar pelo próprio GitHub (qualquer PC, sem instalar nada)

1. Abra o repositório: https://github.com/MCS1985/Fluxo-caixa
2. Navegue até o arquivo que quer editar (ex: `src/components/auth/LoginScreen.tsx`)
3. Clique no **lápis** (ícone de editar) no canto superior direito do arquivo
4. Edite o conteúdo
5. No final da página, escreva um resumo da alteração e clique em **Commit changes**
6. Aguarde ~1 minuto e veja em https://mcs1985.github.io/Fluxo-caixa

> **Importante:** Isso altera o código-fonte na branch `main`. A branch `gh-pages` (site ao vivo) só é atualizada quando alguém rodar `npm run build:static` e subir o resultado.

---

## Editar e publicar (no PC pessoal — com Node.js e token GitHub)

### Editar

```powershell
cd D:\FERRAMENTAS_MCS_IA\Fluxo_Caixa\Projeto
code .
```

Edite os arquivos em `src/`. Para testar:

```powershell
npm run dev
```

Abre em http://localhost:8080.

### Publicar (atualizar o site)

```powershell
cd D:\FERRAMENTAS_MCS_IA\Fluxo_Caixa\Projeto
npm run build:static
```

Depois envie a pasta `.output\static\` para a branch `gh-pages` do repositório. O site atualiza em ~1 minuto.

---

## No PC do escritório (VS Code + navegador, sem git)

### Usar o app

Só abrir https://mcs1985.github.io/Fluxo-caixa no navegador.

### Editar o código (código-fonte, branch main)

1. Abra o repositório no navegador: https://github.com/MCS1985/Fluxo-caixa
2. Clique em **Code** > **Download ZIP**
3. Extraia a pasta e abra no VS Code
4. Edite os arquivos em `src/`
5. Para cada arquivo alterado:
   - Vá até ele no GitHub (https://github.com/MCS1985/Fluxo-caixa)
   - Clique no **lápis** ✏️ no canto superior direito
   - Cole o conteúdo novo e clique em **Commit changes**

### Publicar a alteração no site (branch gh-pages)

Se o Node.js estiver instalado no trabalho:

1. No VS Code, abra o terminal e rode:
   ```
   npm install
   npm run build:static
   ```
2. No navegador, abra https://github.com/MCS1985/Fluxo-caixa
3. No canto esquerdo, clique no seletor de branch e troque para `gh-pages`
4. Clique em **Add file** > **Upload files**
5. Arraste os arquivos da pasta `.output\static\` (inclusive a subpasta `assets/`)
6. Role para baixo e clique em **Commit changes**

Se não tiver Node.js no trabalho, copie a pasta `.output\static\` via Google Drive / pendrive e faça o upload de um computador que tenha.
