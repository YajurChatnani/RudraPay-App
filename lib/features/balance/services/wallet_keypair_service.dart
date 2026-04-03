// Purpose: Generates and securely stores per-network wallet RSA keypairs with in-memory caching.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:pointycastle/key_generators/rsa_key_generator.dart';
import 'package:pointycastle/pointycastle.dart';
import 'package:pointycastle/random/fortuna_random.dart';

import '../../../core/services/secure_storage_service.dart';
import '../../../core/services/token_service.dart';

class WalletKeyPair {
  final String publicKeyPem;
  final String privateKeyPem;
  final String network;
  final String createdAt;

  const WalletKeyPair({
    required this.publicKeyPem,
    required this.privateKeyPem,
    required this.network,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'publicKeyPem': publicKeyPem,
      'privateKeyPem': privateKeyPem,
      'network': network,
      'createdAt': createdAt,
    };
  }

  factory WalletKeyPair.fromJson(Map<String, dynamic> json) {
    return WalletKeyPair(
      publicKeyPem: (json['publicKeyPem'] ?? '').toString(),
      privateKeyPem: (json['privateKeyPem'] ?? '').toString(),
      network: (json['network'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
    );
  }
}

class WalletKeyPairService {
  static const String _storagePrefix = 'wallet_keypair';

  // In-memory cache to avoid reading secure storage on every recharge.
  static final Map<String, WalletKeyPair> _cacheByNetwork = {};

  static Future<void> preloadDefaultNetworkKeyPair({
    String network = 'mudrapay',
  }) async {
    await getOrCreateKeyPair(network: network);
  }

  static Future<String> getPublicKeyPem({String network = 'mudrapay'}) async {
    final pair = await getOrCreateKeyPair(network: network);
    return pair.publicKeyPem;
  }

  static Future<WalletKeyPair> getOrCreateKeyPair({
    String network = 'mudrapay',
  }) async {
    final normalizedNetwork = network.trim().isEmpty ? 'mudrapay' : network.trim().toLowerCase();

    final cached = _cacheByNetwork[normalizedNetwork];
    if (cached != null) {
      return cached;
    }

    final key = await _getUserScopedKey(normalizedNetwork);
    final raw = await SecureStorageService.getString(key);

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final pair = WalletKeyPair.fromJson(decoded);
        if (pair.publicKeyPem.isNotEmpty && pair.privateKeyPem.isNotEmpty) {
          _cacheByNetwork[normalizedNetwork] = pair;
          return pair;
        }
      } catch (_) {
        // If parsing fails, regenerate and overwrite corrupted value.
      }
    }

    // Generate once per network and persist encrypted in secure storage.
    final generated = _generateRsaKeyPair(network: normalizedNetwork);
    await SecureStorageService.setString(key, jsonEncode(generated.toJson()));
    _cacheByNetwork[normalizedNetwork] = generated;
    return generated;
  }

  static WalletKeyPair _generateRsaKeyPair({required String network}) {
    final secureRandom = _secureRandom();
    final params = RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64);
    final generator = RSAKeyGenerator()
      ..init(ParametersWithRandom(params, secureRandom));

    final pair = generator.generateKeyPair();
    final publicKey = pair.publicKey as RSAPublicKey;
    final privateKey = pair.privateKey as RSAPrivateKey;

    final publicPem = CryptoUtils.encodeRSAPublicKeyToPemPkcs1(publicKey);
    final privatePem = CryptoUtils.encodeRSAPrivateKeyToPemPkcs1(privateKey);

    return WalletKeyPair(
      publicKeyPem: publicPem,
      privateKeyPem: privatePem,
      network: network,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
  }

  static FortunaRandom _secureRandom() {
    final random = FortunaRandom();
    final seed = Uint8List.fromList(
      List<int>.generate(32, (_) => Random.secure().nextInt(256)),
    );
    random.seed(KeyParameter(seed));
    return random;
  }

  static Future<String> _getUserScopedKey(String network) async {
    String userId = 'guest';
    try {
      final user = await TokenService.getUser();
      if (user?.id.isNotEmpty == true) {
        userId = user!.id;
      }
    } catch (_) {
      // Keep guest scope if user/session lookup is unavailable.
    }
    return '${userId}_${_storagePrefix}_$network';
  }
}
