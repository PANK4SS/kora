import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/config/colors.dart';
import '../../core/config/document_card.dart';
import '../../core/config/kora_icons.dart';
import '../../core/config/text_styles.dart';
import '../../core/network/catalog_api_service.dart';
import '../../core/network/resource_api_service.dart';
import '../../core/network/user_api_service.dart';
import '../../models/document.dart';
import '../../models/user.dart';

/// Écran de recherche et exploration des documents
class ExplorerScreen extends StatefulWidget {
  const ExplorerScreen({super.key});

  @override
  State<ExplorerScreen> createState() => _ExplorerScreenState();
}

class _ExplorerScreenState extends State<ExplorerScreen> {
  final _searchController = TextEditingController();
  String? _selectedType;
  String? _selectedLevel;
  String? _selectedFiliere;
  String? _selectedMatiere;
  bool _isLoading = true;
  String? _errorMessage;
  User? _currentUser;

  final List<String> _types = [
    'Tous',
    'Cours',
    'Examen',
    'TD',
    'Corrigé',
  ];
  List<String> _levels = <String>['Tous'];
  List<String> _filieres = <String>['Tous'];
  List<String> _matieres = <String>['Tous'];

  List<Document> _allDocuments = <Document>[];

  @override
  void initState() {
    super.initState();
    unawaited(_loadData());
  }

  Future<void> _loadData() async {
    try {
      final user = await UserApiService.refreshCurrentUser();
      if (user == null || user.id.isEmpty) {
        throw Exception('Session invalide. Veuillez vous reconnecter.');
      }

      final resources = await ResourceApiService.getResources();
      final offlineIds =
          await ResourceApiService.getOfflineDocumentIds(user.id);

      UniversityCatalog? catalog;
      if (user.universityId.isNotEmpty) {
        catalog = await CatalogApiService.getUniversityCatalog(
          universityId: user.universityId,
        );
      }

      final filteredResources = resources.where((doc) {
        if (user.university.isEmpty) {
          return true;
        }

        final docUniversity = (doc.university ?? '').trim().toLowerCase();
        final userUniversity = user.university.trim().toLowerCase();

        if (docUniversity.isEmpty) {
          return true;
        }

        return docUniversity == userUniversity;
      }).toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _currentUser = user;
        _allDocuments = filteredResources
            .map(
              (document) => document.copyWith(
                isDownloaded: offlineIds.contains(document.id),
              ),
            )
            .toList();
        _filieres = <String>[
          'Tous',
          ...?catalog?.filieres.map((item) => item.name),
        ];
        _levels = <String>[
          'Tous',
          ...?catalog?.niveaux.map((item) => item.name),
        ];
        _matieres = <String>[
          'Tous',
          ...?catalog?.matieres.map((item) => item.name),
        ];
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = CatalogApiService.parseError(error);
        _isLoading = false;
      });
    }
  }

  List<Document> get _filteredDocuments {
    return _allDocuments.where((doc) {
      if (_searchController.text.isNotEmpty &&
          !doc.title
              .toLowerCase()
              .contains(_searchController.text.toLowerCase())) {
        return false;
      }

      if (_selectedType != null && _selectedType != 'Tous') {
        if (doc.typeLabel.toLowerCase() != _selectedType!.toLowerCase()) {
          return false;
        }
      }

      if (_selectedLevel != null && _selectedLevel != 'Tous') {
        if (!doc.level.toLowerCase().contains(_selectedLevel!.toLowerCase())) {
          return false;
        }
      }

      if (_selectedFiliere != null && _selectedFiliere != 'Tous') {
        final filiere = (doc.filiere ?? '').toLowerCase();
        if (!filiere.contains(_selectedFiliere!.toLowerCase())) {
          return false;
        }
      }

      if (_selectedMatiere != null && _selectedMatiere != 'Tous') {
        final subject = (doc.subject ?? '').toLowerCase();
        if (!subject.contains(_selectedMatiere!.toLowerCase())) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Rechercher un document',
          style: AppTextStyles.h4,
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.lightGray,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: "Entrer le nom d'un document",
                            hintStyle: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textGray,
                            ),
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.search,
                        color: AppColors.iconGray,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildFilterChip(
                        label: _selectedType ?? 'Type',
                        onTap: _showTypeFilter,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFilterChip(
                        label: _selectedLevel ?? 'Niveau',
                        onTap: _showLevelFilter,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildFilterChip(
                        label: _selectedFiliere ?? 'Filiere',
                        onTap: _showFiliereFilter,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFilterChip(
                        label: _selectedMatiere ?? 'Matière',
                        onTap: _showMatiereFilter,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Text(
                          _errorMessage!,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      )
                    : _filteredDocuments.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(20),
                            itemCount: _filteredDocuments.length,
                            itemBuilder: (context, index) {
                              return DocumentCard(
                                document: _filteredDocuments[index],
                                onDownload: () =>
                                    _handleDownload(_filteredDocuments[index]),
                                onTap: () => _handleDocumentTap(
                                  _filteredDocuments[index],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.lightGray,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down,
              color: AppColors.iconGray,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            // ignore: deprecated_member_use
            color: AppColors.iconGray.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun document trouvé',
            style: AppTextStyles.h4.copyWith(
              color: AppColors.textGray,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Essayez d'ajuster vos filtres",
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textGray,
            ),
          ),
        ],
      ),
    );
  }

  void _showTypeFilter() {
    _showFilterBottomSheet(
      title: 'Sélectionner un type',
      items: _types,
      selectedItem: _selectedType,
      onSelect: (value) {
        setState(() {
          _selectedType = value == 'Tous' ? null : value;
        });
      },
    );
  }

  void _showLevelFilter() {
    _showFilterBottomSheet(
      title: 'Sélectionner un niveau',
      items: _levels,
      selectedItem: _selectedLevel,
      onSelect: (value) {
        setState(() {
          _selectedLevel = value == 'Tous' ? null : value;
        });
      },
    );
  }

  void _showFiliereFilter() {
    _showFilterBottomSheet(
      title: 'Sélectionner une filière',
      items: _filieres,
      selectedItem: _selectedFiliere,
      onSelect: (value) {
        setState(() {
          _selectedFiliere = value == 'Tous' ? null : value;
        });
      },
    );
  }

  void _showMatiereFilter() {
    _showFilterBottomSheet(
      title: 'Sélectionner une matière',
      items: _matieres,
      selectedItem: _selectedMatiere,
      onSelect: (value) {
        setState(() {
          _selectedMatiere = value == 'Tous' ? null : value;
        });
      },
    );
  }

  void _showFilterBottomSheet({
    required String title,
    required List<String> items,
    // ignore: inference_failure_on_function_return_type
    required Function(String) onSelect,
    String? selectedItem,
  }) {
    if (items.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune option disponible pour ce filtre.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // ignore: inference_failure_on_function_invocation
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Text(title, style: AppTextStyles.h4),
              ),
              const Divider(),
              ...items.map((item) {
                return ListTile(
                  title: Text(item),
                  onTap: () {
                    onSelect(item);
                    Navigator.pop(context);
                  },
                  trailing: selectedItem == item
                      ? const Icon(Icons.check, color: AppColors.primaryGold)
                      : null,
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _handleDownload(Document document) {
    final user = _currentUser;
    if (user == null || user.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session invalide, veuillez vous reconnecter.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    unawaited(
      ResourceApiService.markAsDownloaded(
        document: document,
        user: user,
      ).then((offlineDocument) {
        if (!mounted) {
          return;
        }
        setState(() {
          _allDocuments = _allDocuments
              .map(
                (item) => item.id == document.id
                    ? item.copyWith(
                        isDownloaded: true,
                        filePath: offlineDocument.filePath,
                        downloadedAt: offlineDocument.downloadedAt,
                      )
                    : item,
              )
              .toList();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${document.title}" ajouté en offline.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }).catchError((Object error) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ResourceApiService.parseError(error)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }),
    );
  }

  void _handleDocumentTap(Document document) {
    // ignore: inference_failure_on_function_invocation
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(document.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${document.typeLabel}'),
            Text('Niveau: ${document.level}'),
            Text('Filière: ${document.filiere}'),
            if (document.subject != null)
              Text('Matière: ${document.subject}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

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
                      child: KoraIcons.search(color: AppColors.textLight),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Explorer',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: KoraIcons.download(color: AppColors.iconGray),
                onPressed: () => Navigator.of(context).pushNamed('/offline'),
              ),
              IconButton(
                icon: KoraIcons.profile(color: AppColors.iconGray),
                onPressed: () => Navigator.of(context).pushNamed('/profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
