import { useState, type FormEvent } from "react";
import { useAuth } from "@/lib/auth-store";

export function LoginScreen() {
  const { login } = useAuth();
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState(false);

  function handleSubmit(e: FormEvent) {
    e.preventDefault();
    const ok = login(username, password);
    if (!ok) {
      setError(true);
      setPassword("");
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-background p-4">
      <div className="w-full max-w-sm">
        <div className="mb-8 text-center">
          <h1 className="text-4xl font-bold text-gradient-mint">Fluxo</h1>
          <p className="mt-2 text-sm text-muted-foreground">
            Controle financeiro pessoal
          </p>
        </div>
        <form
          onSubmit={handleSubmit}
          className="space-y-5 rounded-2xl border border-white/10 bg-black/40 p-8 backdrop-blur-xl"
        >
          <div>
            <label htmlFor="username" className="text-sm font-medium text-foreground">
              Usuário
            </label>
            <input
              id="username"
              type="text"
              value={username}
              onChange={(e) => {
                setUsername(e.target.value);
                setError(false);
              }}
              className="mt-1.5 block w-full rounded-lg border border-white/10 bg-white/5 px-4 py-2.5 text-sm text-foreground placeholder-muted-foreground outline-none transition-colors focus:border-mint-400/50 focus:ring-1 focus:ring-mint-400/20"
              placeholder="Digite o usuário"
              autoFocus
            />
          </div>
          <div>
            <label htmlFor="password" className="text-sm font-medium text-foreground">
              Senha
            </label>
            <input
              id="password"
              type="password"
              value={password}
              onChange={(e) => {
                setPassword(e.target.value);
                setError(false);
              }}
              className="mt-1.5 block w-full rounded-lg border border-white/10 bg-white/5 px-4 py-2.5 text-sm text-foreground placeholder-muted-foreground outline-none transition-colors focus:border-mint-400/50 focus:ring-1 focus:ring-mint-400/20"
              placeholder="Digite a senha"
            />
            {error && (
              <p className="mt-1.5 text-xs text-red-400">Usuário ou senha incorretos</p>
            )}
          </div>
          <button
            type="submit"
            className="w-full rounded-lg gradient-mint px-4 py-2.5 text-sm font-semibold text-black transition-transform hover:scale-[1.02]"
          >
            Entrar
          </button>
        </form>
        <p className="mt-6 text-center text-xs text-muted-foreground">
          Fluxo · Finanças Pessoais v1.0
        </p>
      </div>
    </div>
  );
}
