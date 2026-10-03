import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skipit/features/auth/data/auth_provider.dart';
import 'package:skipit/features/onboarding/presentation/screens/splash_screen.dart';
import 'package:skipit/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:skipit/features/auth/presentation/screens/login_screen.dart';
import 'package:skipit/features/auth/presentation/screens/signup_screen.dart';
import 'package:skipit/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:skipit/features/home/home_screen.dart';
import 'package:skipit/features/listings/presentation/screens/add_listing_screen.dart';
import 'package:skipit/features/listings/presentation/screens/listing_detail_screen.dart';
import 'package:skipit/features/listings/domain/models/listing.dart';
import 'package:skipit/features/search/presentation/screens/search_screen.dart';
import 'package:skipit/features/profile/presentation/screens/profile_screen.dart';
import 'package:skipit/features/profile/presentation/screens/kyc_verification_screen.dart';
import 'package:skipit/features/bookings/presentation/screens/bookings_screen.dart';
import 'package:skipit/features/wishlist/presentation/screens/wishlist_screen.dart';
import 'package:skipit/features/profile/presentation/screens/payment_methods_screen.dart';
import 'package:skipit/features/profile/presentation/screens/help_center_screen.dart';
import 'package:skipit/features/profile/presentation/screens/safety_center_screen.dart';
import 'package:skipit/features/chat/presentation/screens/inbox_screen.dart';

import 'package:flutter/foundation.dart';

/// A Listenable class that listens to the Riverpod Auth State and notifies
/// GoRouter when it changes, prompting a redirect evaluation.
class GoRouterRefreshListenable extends ChangeNotifier {
  GoRouterRefreshListenable(Ref ref) {
    ref.listen(
      authProvider,
      (previous, next) {
        notifyListeners();
      },
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshListenable = GoRouterRefreshListenable(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      // Use ref.read to prevent this Provider from re-evaluating and destroying GoRouter
      final authState = ref.read(authProvider);
      final isAuthenticated = authState.status == AuthStatus.authenticated;
      final isAuthOrOnboarding = state.matchedLocation == '/' ||
          state.matchedLocation == '/onboarding' ||
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup' ||
          state.matchedLocation == '/forgot-password';

      // If authenticated and on auth/onboarding page, redirect to home
      if (isAuthenticated && isAuthOrOnboarding) {
        return '/home';
      }

      // If not authenticated and NOT on auth/onboarding page, redirect to splash/login
      if (!isAuthenticated && !isAuthOrOnboarding) {
        return '/';
      }

      return null; // no redirect
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/add-listing',
        builder: (context, state) => const AddListingScreen(),
      ),
      GoRoute(
        path: '/listing-detail',
        builder: (context, state) {
          final listing = state.extra as Listing;
          return ListingDetailScreen(listing: listing);
        },
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) {
          final category = state.extra as String?;
          return SearchScreen(initialCategory: category);
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/kyc',
        builder: (context, state) => const KYCVerificationScreen(),
      ),
      GoRoute(
        path: '/bookings',
        builder: (context, state) => const BookingsScreen(),
      ),
      GoRoute(
        path: '/wishlist',
        builder: (context, state) => const WishlistScreen(),
      ),
      GoRoute(
        path: '/payment-methods',
        builder: (context, state) => const PaymentMethodsScreen(),
      ),
      GoRoute(
        path: '/help-center',
        builder: (context, state) => const HelpCenterScreen(),
      ),
      GoRoute(
        path: '/safety-center',
        builder: (context, state) => const SafetyCenterScreen(),
      ),
      GoRoute(
        path: '/inbox',
        builder: (context, state) => const InboxScreen(),
      ),
    ],
  );
});
