import { useSyncExternalStore, useEffect } from "react";

const STORAGE_KEY = "fluxo_auth";

interface AuthState {
  authenticated: boolean;
  username: string;
  password: string;
}

const DEFAULT_USERNAME = "admin";
const DEFAULT_PASSWORD = "admin";

let state: AuthState = { authenticated: false, username: DEFAULT_USERNAME, password: DEFAULT_PASSWORD };
const listeners = new Set<() => void>();

function readState(): AuthState {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) {
      const parsed = JSON.parse(raw);
      return {
        authenticated: false,
        username: parsed.username ?? DEFAULT_USERNAME,
        password: parsed.password ?? DEFAULT_PASSWORD,
      };
    }
  } catch { /* ignore */ }
  return { authenticated: false, username: DEFAULT_USERNAME, password: DEFAULT_PASSWORD };
}

function persist() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
}

function emit() {
  listeners.forEach((fn) => fn());
}

function setState(next: AuthState) {
  state = next;
  persist();
  emit();
}

export function hydrateAuth() {
  state = readState();
}

export function useAuth() {
  const snapshot = useSyncExternalStore(
    (cb) => {
      listeners.add(cb);
      return () => listeners.delete(cb);
    },
    () => state,
    () => state,
  );

  return {
    authenticated: snapshot.authenticated,
    login(username: string, password: string) {
      if (username === state.username && password === state.password) {
        setState({ ...state, authenticated: true });
        return true;
      }
      return false;
    },
    logout() {
      setState({ ...state, authenticated: false });
    },
    changePassword(current: string, next: string) {
      if (current !== state.password) return false;
      setState({ ...state, password: next });
      return true;
    },
  };
}

export function useHydrateAuth() {
  useEffect(() => {
    hydrateAuth();
  }, []);
}
