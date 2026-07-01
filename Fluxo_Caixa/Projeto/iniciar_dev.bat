@echo off
cd /d "D:\FERRAMENTAS_MCS_IA\Fluxo_Caixa\Projeto"
echo Iniciando servidor de desenvolvimento...
echo Abra http://localhost:5173/Fluxo-caixa/ no navegador
echo Para parar, feche esta janela ou pressione Ctrl+C
echo.
npx vite --config vite.static.config.ts --host
pause
