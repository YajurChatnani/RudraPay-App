import 'package:flutter/material.dart';
import 'features/home/screens/home_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/payment/screens/payment_entry_screen.dart';
import 'features/receive/screens/receive_entry_screen.dart';
import 'features/transactions/screens/transactions_list_screen.dart';
import 'features/bluetooth/screens/pay_bluetooth_connecting_screen.dart';
import 'features/bluetooth/screens/receive_bluetooth_connecting_screen.dart';
import 'features/bluetooth/screens/pay_bluetooth_connected_screen.dart';
import 'features/bluetooth/screens/receive_bluetooth_connected_screen.dart';
import 'features/payment/screens/enter_amount_screen.dart';
import 'features/payment/screens/transfer_pending_screen.dart';
import 'features/payment/screens/transaction_result_screen.dart';
import 'features/transactions/screens/transaction_detail_screen.dart';
import 'features/balance/screens/add_balance_screen.dart';
import 'features/balance/screens/recharge_result_screen.dart';





void main() {
  runApp(const WalletApp());
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
      home: const HomeScreen(),
      onGenerateRoute: _routeBuilder,
    );
  }
}

/// Global animated routing (PERMANENT)
Route _routeBuilder(RouteSettings settings) {
  Widget page;

  switch (settings.name) {
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
    case '/pay/connected':
      page = const PayBluetoothConnectedScreen();
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
    case '/transaction/detail':
      page = const TransactionDetailScreen();
      break;
    case '/add-balance':
      page = const AddBalanceScreen();
      break;

    default:
      page = const HomeScreen();
  }

  return PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (_, animation, __) => FadeTransition(
      opacity: animation,
      child: page,
    ),
  );
}
