import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/config/colors.dart';
import '../../core/config/kora_icons.dart';
import '../../core/config/text_styles.dart';
import '../../core/config/widgets.dart';
import '../../core/network/resource_api_service.dart';
import '../../core/network/session_manager.dart';
import '../../core/network/user_api_service.dart';
import '../../models/user.dart';

/// Écran de profil utilisateur
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User _currentUser = User(
    id: '',
    name: 'Utilisateur',
    email: '',
    university: '',
    universityId: '',
    profileImageUrl: '',
  );
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    unawaited(_loadProfile());
  }

  Future<void> _loadProfile() async {
    final user = await UserApiService.refreshCurrentUser();
    final profileImageUrl = await SessionManager.getProfileImageUrl();
    final offlineIds = user != null && user.id.isNotEmpty
        ? await ResourceApiService.getOfflineDocumentIds(user.id)
        : <String>{};

    if (!mounted) {
      return;
    }

    setState(() {
      if (user != null) {
        _currentUser = user.copyWith(
          downloadedDocumentsCount: offlineIds.length,
        );
      }
      _profileImageUrl = profileImageUrl;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 40),

              // Avatar
              _buildAvatar(),

              const SizedBox(height: 20),

              // Email
              Text(
                _currentUser.name,
                style: AppTextStyles.h2,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // Section Documents téléchargés
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Documents téléchargés',
                      style: AppTextStyles.h4.copyWith(
                        color: AppColors.primaryGold,
                      ),
                    ),

                    const SizedBox(height: 16),

                    _buildInfoCard(
                      iconWidget: KoraIcons.book(
                        color: AppColors.primaryGold,
                        size: 32,
                      ),
                      count: _currentUser.downloadedDocumentsCount,
                      label: 'Documents prêts pour une\nlecture hors ligne',
                    ),

                    const SizedBox(height: 32),

                    // Section Université
                    Text(
                      'Université',
                      style: AppTextStyles.h4.copyWith(
                        color: AppColors.primaryGold,
                      ),
                    ),

                    const SizedBox(height: 16),

                    _buildInfoCard(
                      iconWidget: KoraIcons.university(
                        color: AppColors.primaryGold,
                        size: 32,
                      ),
                      label: _currentUser.university,
                      showCount: false,
                    ),

                    const SizedBox(height: 64),

                    // Bouton de déconnexion
                    CustomButton(
                      text: 'Se déconnecter',
                      icon: Icons.logout,
                      onPressed: _handleLogout,
                      backgroundColor: AppColors.darkBackground,
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  /// Construit l'avatar de l'utilisateur
  Widget _buildAvatar() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primaryGold,
          width: 3,
        ),
      ),
      child: ClipOval(
        child: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
            ? Image.network(
                _profileImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildAvatarFallback(),
              )
            : _buildAvatarFallback(),
      ),
    );
  }

  Widget _buildAvatarFallback() {
    return ColoredBox(
      color: Colors.grey.shade200,
      child: Icon(
        Icons.person,
        size: 60,
        color: Colors.grey.shade400,
      ),
    );
  }

  Future<void> _performLogout() async {
    await SessionManager.clear();

    if (!mounted) {
      return;
    }

    await Navigator.of(context).pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
    );
  }

  /// Construit une carte d'information
  Widget _buildInfoCard({
    required String label,
    IconData? icon,
    Widget? iconWidget,
    int? count,
    bool showCount = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.mediumGray,
        ),
      ),
      child: Row(
        children: [
          // Icône
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: AppColors.primaryGold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: iconWidget ??
                Icon(
                  icon ?? Icons.info_outline,
                  color: AppColors.primaryGold,
                  size: 32,
                ),
          ),

          const SizedBox(width: 16),

          // Texte
          Expanded(
            child: Row(
              children: [
                if (showCount && count != null) ...[
                  Text(
                    count.toString(),
                    style: AppTextStyles.h2.copyWith(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textDark,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Gère la déconnexion
  void _handleLogout() {
    // ignore: inference_failure_on_function_invocation
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              unawaited(_performLogout());
            },
            child: const Text(
              'Déconnexion',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  /// Construit la barre de navigation inférieure
  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: KoraIcons.home(color: AppColors.iconGray),
                onPressed: () => Navigator.of(context).pushNamed('/home'),
              ),
              IconButton(
                icon: KoraIcons.search(color: AppColors.iconGray),
                onPressed: () => Navigator.of(context).pushNamed('/explorer'),
              ),
              IconButton(
                icon: KoraIcons.download(color: AppColors.iconGray),
                onPressed: () => Navigator.of(context).pushNamed('/offline'),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: KoraIcons.profile(color: AppColors.textLight),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Profile',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
