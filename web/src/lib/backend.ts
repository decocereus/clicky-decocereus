const DEFAULT_BACKEND_URL = "http://localhost:8788"

export function getBackendUrl() {
  return import.meta.env.VITE_BACKEND_URL ?? DEFAULT_BACKEND_URL
}
