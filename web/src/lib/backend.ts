const DEFAULT_LOCAL_BACKEND_URL = "http://localhost:8788";
const DEFAULT_DOWNLOAD_URL = "https://downloads.clickyhq.com/Clicky.dmg";

function isLoopbackHost(hostname: string) {
  return hostname === "localhost" || hostname === "127.0.0.1";
}

function normalizeConfiguredBackendUrl(value: string | undefined) {
  const trimmedValue = value?.trim();
  return trimmedValue ? trimmedValue : null;
}

export function getBackendUrl() {
  const configuredBackendUrl = normalizeConfiguredBackendUrl(
    import.meta.env.VITE_BACKEND_URL,
  );

  if (typeof window === "undefined") {
    return configuredBackendUrl ?? DEFAULT_LOCAL_BACKEND_URL;
  }

  const { hostname, origin } = window.location;
  if (isLoopbackHost(hostname)) {
    return configuredBackendUrl ?? DEFAULT_LOCAL_BACKEND_URL;
  }

  try {
    return configuredBackendUrl
      ? new URL(configuredBackendUrl, origin).origin
      : origin;
  } catch {
    return origin;
  }
}

export function getDownloadUrl() {
  return (
    normalizeConfiguredBackendUrl(import.meta.env.VITE_CLICKY_DOWNLOAD_URL) ??
    DEFAULT_DOWNLOAD_URL
  );
}
