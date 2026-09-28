/// Centralized String Constants & Local Storage Keys
/// Monorepo: Dossier Kiosk Client
class AppStrings {
  AppStrings._();

  // Storage Keys (SharedPreferences / OPFS)
  static const String keyThemeMode = 'dossier_theme_mode';
  static const String keyAuthToken = 'dossier_auth_token';
  static const String keyActiveUser = 'dossier_active_user';
  static const String keyActiveOperator = 'dossier_active_operator';
  static const String keyKioskIdentity = 'dossier_kiosk_identity';
  static const String keyServerUrl = 'dossier_server_url';
  static const String keySidebarCollapsed = 'dossier_sidebar_collapsed';
  static const String keySplitRatios = 'dossier_split_ratios';

  // Fallback Labels
  static const String defaultOperatorName = 'Desk Operator';
  static const String defaultAdminName = 'Admin';
  static const String defaultKioskName = 'Main Kiosk Center';

  // HTTP Header Keys
  static const String headerAuthorization = 'Authorization';
  static const String headerContentType = 'Content-Type';
  static const String headerClient = 'X-Dossier-Client';
  static const String headerVersion = 'X-Dossier-Version';
  static const String contentTypeJson = 'application/json';
  static const String bearerPrefix = 'Bearer ';

  // Route Names
  static const String routeRoot = '/';
  static const String routeAuth = '/auth';
  static const String routeKioskSetup = '/kiosk-setup';
  static const String routeDeskPos = '/desk-pos';
  static const String routeMediaStudio = '/media-studio';
  static const String routeVaultDossiers = '/vault-dossiers';
  static const String routeServicesCatalog = '/services-catalog';
  static const String routeSettings = '/settings';
}
