class RouteNames {
  // ─── Entry & auth ─────────────────────────────────────────────────────
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String roleSelection = '/role-selection';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';

  /// Role-based redirect: chef approved → dashboard; rejected → rejection; customer → customer home.
  static const String rootDecider = '/root';

  // ─── Chef registration (step-based; never navigates to dashboard) ──────
  static const String chefRegistration = '/chef-registration';
  static const String chefRegAccount = '/chef-registration/account';
  static const String chefRegDocuments = '/chef-registration/documents';
  static const String chefRegSuccess = '/chef-registration/success';
  static const String chefRejection = '/chef-rejection';

  // ─── Chef dashboard (bottom nav: Home, Orders, Menu, Reels, Chat, Profile; Earnings inside Profile)
  static const String chefHome = '/chef/home';
  static const String chefOrders = '/chef/orders';
  static const String chefMenu = '/chef/menu';
  static const String chefReels = '/chef/reels';
  static const String chefChat = '/chef/chat';
  static const String chefProfile = '/chef/profile';
  static const String chefInspectionCall = '/chef/inspection-call';
  static const String chefFrozen = '/chef/frozen';
  static const String chefBlocked = '/chef/blocked';
  static const String cookPending = '/chef/pending';

  /// Unified suspended account (customer + chef); prefer over [chefBlocked].
  static const String accountSuspended = '/account-suspended';

  static const String adminHome = '/admin';

  // ─── Customer app (Naham customer: single screen with internal nav) ───
  static const String customerRoot = '/customer';
  static const String customerHome = '/customer/home';
  static const String customerExplore = '/customer/explore';
  static const String customerReels = '/customer/reels';
  static const String customerCart = '/customer/cart';
  static const String customerProfile = '/customer/profile';
  static const String customerSearch = '/customer/search';
  static const String customerFavorites = '/customer/favorites';
  static const String customerNotifications = '/customer/notifications';
  static const String customerAddresses = '/customer/addresses';
  static const String customerChefProfile = '/customer/chef';
  static const String customerOrderDetails = '/customer/order-details';
  static const String customerPayment = '/customer/payment';

  // ─── Legacy / aliases (for gradual migration) ──────────────────────────
  static const String startup = splash;
  static const String home = chefHome;
  static const String orders = chefOrders;
  static const String reels = chefReels;
  static const String chat = chefChat;
  static const String menu = chefMenu;
  static const String profile = chefProfile;

  // Nested
  static const String orderDetails = 'order-details';
  static const String chatDetails = 'chat-details';
  static const String addReel = 'add-reel';
  static const String reelDetails = 'reel-details';
  static const String addDish = 'add-dish';
  static const String editDish = 'edit-dish';
  static const String editProfile = 'edit-profile';
  static const String analytics = 'analytics';
  static const String documents = 'documents';
  static const String settings = 'settings';
  static const String chefNotifications = '/chef/notifications';
}
