/**
 * Web Application Environment Config Resolver
 * Monorepo: Dossier Web Marketing & Documentation Portal
 */

export const WebConfig = {
  apiBaseUrl: import.meta.env?.VITE_API_BASE_URL || "https://dossier-api.rajayogesh49.workers.dev",
  appName: import.meta.env?.VITE_APP_NAME || "Dossier Documentation",
  appVersion: import.meta.env?.VITE_APP_VERSION || "1.3.0",
};
