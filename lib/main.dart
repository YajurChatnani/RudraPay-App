import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'features/home/screens/home_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/payment/screens/payment_entry_screen.dart';
import 'features/receive/screens/receive_entry_screen.dart';
import 'features/transactions/screens/transactions_list_screen.dart';
import 'features/bluetooth/screens/pay_bluetooth_connecting_screen.dart';
import 'features/bluetooth/screens/receive_bluetooth_connecting_screen.dart';
import 'features/bluetooth/screens/receive_bluetooth_connected_screen.dart';
import 'features/payment/screens/enter_amount_screen.dart';
import 'features/payment/screens/transfer_pending_screen.dart';
import 'features/payment/screens/transaction_result_screen.dart';
import 'features/payment/screens/transaction_fail_screen.dart';
import 'features/transactions/screens/transaction_detail_screen.dart';
import 'features/balance/screens/add_balance_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/signup_screen.dart';
import 'features/auth/screens/onboarding_screen.dart';
import 'core/config/app_config.dart';
import 'core/services/token_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Load environment variables
    await dotenv.load(fileName: ".env");
    
    // Validate configuration
    final config = AppConfig();
    if (!config.isConfigured) {
      throw Exception(config.configError);
    }
    
    runApp(const WalletApp());
  } catch (e) {
    runApp(ErrorApp(error: e.toString()));
  }
}

class WalletApp extends StatelessWidget {
  const WalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Offline Wallet',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0B0B),
      ),
      home: FutureBuilder<bool>(
        future: TokenService.isLoggedIn(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFF0B0B0B),
              body: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                ),
              ),
            );
          }
          
          // If logged in, go to home, otherwise go to login
          if (snapshot.data == true) {
            return const HomeScreen();
          } else {
            return const LoginScreen();
          }
        },
      ),
      onGenerateRoute: _routeBuilder,
    );
  }
}

/// Global animated routing (PERMANENT)
Route _routeBuilder(RouteSettings settings) {
  Widget page;

  switch (settings.name) {
    case '/login':
      page = const LoginScreen();
      break;
    case '/signup':
      page = const SignupScreen();
      break;
    case '/onboarding':
      // Extract arguments for onboarding
      final args = settings.arguments as Map<String, dynamic>?;
      page = OnboardingScreen(
        email: args?['email'] as String?,
        password: args?['password'] as String?,
      );
      break;
    case '/home':
      page = const HomeScreen();
      break;
    case '/profile':
      page = const ProfileScreen();
      break;
    case '/pay':
      page = const PaymentEntryScreen();
      break;
    case '/receive':
      page = const ReceiveEntryScreen();
      break;
    case '/transactions':
      page = const TransactionsListScreen();
      break;
    case '/pay/connect':
      page = const PayBluetoothConnectingScreen();
      break;
    case '/receive/connect':
      page = const ReceiveBluetoothConnectingScreen();
      break;
    case '/receive/connected':
      page = const ReceiveBluetoothConnectedScreen();
      break;
    case '/pay/amount':
      page = const EnterAmountScreen();
      break;
    case '/pay/pending':
      page = const TransferPendingScreen();
      break;
    case '/transaction/result':
      page = const TransactionResultScreen();
      break;
    case '/transaction/fail':
      page = const TransactionFailScreen();
      break;
    case '/transaction/detail':
      page = const TransactionDetailScreen();
      break;
    case '/add-balance':
      page = const AddBalanceScreen();
      break;

    default:
      page = const LoginScreen();
  }

  return PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 350),
    settings: settings,
    pageBuilder: (_, animation, __) => FadeTransition(
      opacity: animation,
      child: page,
    ),
  );
}

/// Error app widget displayed when configuration fails
class ErrorApp extends StatelessWidget {
  final String error;
  
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0B0B0B),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.settings_suggest_rounded,
                  size: 80,
                  color: Colors.red.shade400,
                ),
                const SizedBox(height: 24),
                Text(
                  'Configuration Error',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade400,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
