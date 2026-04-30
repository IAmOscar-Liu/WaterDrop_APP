import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_ad_ecommerce/firebase_options_dev.dart' as dev_options;
import 'package:flutter_ad_ecommerce/firebase_options_stg.dart' as stg_options;

enum AppFlavor {
  dev,
  stg;

  static const _name = String.fromEnvironment('FLAVOR', defaultValue: 'dev');
  static AppFlavor? _current;

  static void configure(AppFlavor flavor) {
    _current = flavor;
  }

  static AppFlavor get current {
    final configuredFlavor = _current;
    if (configuredFlavor != null) return configuredFlavor;

    switch (_name) {
      case 'stg':
        return AppFlavor.stg;
      case 'dev':
      default:
        return AppFlavor.dev;
    }
  }

  FirebaseOptions get firebaseOptions {
    switch (this) {
      case AppFlavor.dev:
        return dev_options.DevFirebaseOptions.currentPlatform;
      case AppFlavor.stg:
        return stg_options.StgFirebaseOptions.currentPlatform;
    }
  }
}
