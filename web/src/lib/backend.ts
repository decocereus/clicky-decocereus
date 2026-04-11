const DEFAULT_LOCAL_BACKEND_URL = "http://localhost:8788";

function inferBrowserBackendUrl() {
  if (typeof window === "undefined") {
    return DEFAULT_LOCAL_BACKEND_URL;
  }

  const { hostname, origin } = window.location;
  if (hostname === "localhost" || hostname === "127.0.0.1") {
    return DEFAULT_LOCAL_BACKEND_URL;
  }

  return origin;
}

export function getBackendUrl() {
  return import.meta.env.VITE_BACKEND_URL ?? inferBrowserBackendUrl();
}
