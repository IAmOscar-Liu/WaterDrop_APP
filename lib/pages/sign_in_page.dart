// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/app_constants.dart';
import 'package:flutter_ad_ecommerce/service/google_auth_service.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/widgets/app_version_text.dart';
import 'package:url_launcher/url_launcher.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  bool _isLoading = false;

  void _handleSignInWithGoogle(BuildContext context) async {
    if (_isLoading) return; // Prevent multiple taps while loading

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await GoogleAuthService().signInWithGoogle();
      if (result != null) return;

      // User cancelled the sign-in
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign-in was cancelled'),
            backgroundColor: AppColors.warningColor,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: AppColors.containerBgColor,
              title: const Text(
                'Sign-in Error',
                style: TextStyle(
                  color: AppColors.primaryTextColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                'Failed to sign in with Google: ${e.toString()}',
                style: const TextStyle(color: AppColors.secondaryTextColor),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      color: AppColors.infoColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              // Top section with image and title
              Expanded(
                flex: 3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Splash screen image
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            // color: Colors.black.withOpacity(0.3),
                            color: Color.fromRGBO(0, 0, 0, 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/icons/splash_screen.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // App title
                    const Text(
                      '水滴 APP',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryTextColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '歡迎回來！請登入後繼續',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.secondaryTextColor,
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Bottom section with login button
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Redesigned Google login button
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.containerBgColor,
                          width: 1.5,
                        ),
                        color: AppColors.containerBgColor,
                        boxShadow: [
                          BoxShadow(
                            // color: Colors.black.withOpacity(0.2),
                            color: Color.fromRGBO(0, 0, 0, 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _isLoading
                              ? null
                              : () => _handleSignInWithGoogle(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Google icon or loading indicator
                                if (_isLoading)
                                  const SizedBox(
                                    width: 30,
                                    height: 30,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.primaryTextColor,
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      color: Colors.white,
                                    ),
                                    child: const Icon(
                                      Icons.g_mobiledata,
                                      size: 30,
                                      color: Color(0xFF4285F4),
                                    ),
                                  ),
                                const SizedBox(width: 12),
                                // Button text
                                Text(
                                  _isLoading ? '登入中...' : '使用 Google 登入',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Terms and conditions text
                    const Text(
                      '您若繼續，即表示您同意我們的服務條款和隱私權政策',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedTextColor,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () {
                        launchUrl(
                          Uri.parse(
                            "${AppConstants.apiBaseUrl}api/file/user-consent",
                          ),
                        );
                      },
                      child: Text(
                        "用戶同意書",
                        style: TextStyle(color: AppColors.infoColor),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const AppVersionText(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
