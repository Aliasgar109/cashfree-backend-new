import 'package:flutter/material.dart';
import '../services/localization_service.dart';
import '../l10n/app_localizations.dart';

/// Widget for language selection with localization support
class LanguageSelector extends StatelessWidget {
  final LocalizationService localizationService;
  final bool showTitle;
  final bool isCompact;
  final VoidCallback? onLanguageChanged;
  
  const LanguageSelector({
    super.key,
    required this.localizationService,
    this.showTitle = true,
    this.isCompact = false,
    this.onLanguageChanged,
  });
  
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    if (isCompact) {
      return _buildCompactSelector(context, l10n);
    } else {
      return _buildFullSelector(context, l10n);
    }
  }
  
  Widget _buildCompactSelector(BuildContext context, AppLocalizations l10n) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.language),
      tooltip: l10n.language,
      onSelected: (String languageCode) async {
        await localizationService.changeLanguage(languageCode);
        onLanguageChanged?.call();
      },
      itemBuilder: (BuildContext context) {
        return LocalizationService.supportedLocales.map((Locale locale) {
          final languageCode = locale.languageCode;
          final languageName = LocalizationService.languageNames[languageCode] ?? languageCode;
          final isSelected = localizationService.isLanguageSelected(languageCode);
          
          return PopupMenuItem<String>(
            value: languageCode,
            child: Row(
              children: [
                if (isSelected) 
                  const Icon(Icons.check, color: Colors.green, size: 20)
                else 
                  const SizedBox(width: 20),
                const SizedBox(width: 8),
                Text(languageName),
              ],
            ),
          );
        }).toList();
      },
    );
  }
  
  Widget _buildFullSelector(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Text(
            l10n.language,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
        ],
        ...LocalizationService.supportedLocales.map((Locale locale) {
          final languageCode = locale.languageCode;
          final languageName = LocalizationService.languageNames[languageCode] ?? languageCode;
          final isSelected = localizationService.isLanguageSelected(languageCode);
          
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isSelected 
                    ? Theme.of(context).primaryColor 
                    : Colors.grey.shade300,
                child: Text(
                  languageCode.toUpperCase(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black54,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              title: Text(
                languageName,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: isSelected 
                  ? Icon(
                      Icons.check_circle,
                      color: Theme.of(context).primaryColor,
                    )
                  : null,
              onTap: () async {
                if (!isSelected) {
                  await localizationService.changeLanguage(languageCode);
                  onLanguageChanged?.call();
                }
              },
            ),
          );
        }).toList(),
      ],
    );
  }
}

/// Simple language toggle button for switching between English and Gujarati
class LanguageToggleButton extends StatelessWidget {
  final LocalizationService localizationService;
  final VoidCallback? onLanguageChanged;
  
  const LanguageToggleButton({
    super.key,
    required this.localizationService,
    this.onLanguageChanged,
  });
  
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
          ),
        ),
        child: Text(
          localizationService.currentLanguageCode.toUpperCase(),
          style: TextStyle(
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
      tooltip: 'Switch Language',
      onPressed: () async {
        await localizationService.toggleLanguage();
        onLanguageChanged?.call();
      },
    );
  }
}

/// Language selection dialog
class LanguageSelectionDialog extends StatelessWidget {
  final LocalizationService localizationService;
  
  const LanguageSelectionDialog({
    super.key,
    required this.localizationService,
  });
  
  static Future<void> show(
    BuildContext context,
    LocalizationService localizationService,
  ) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return LanguageSelectionDialog(
          localizationService: localizationService,
        );
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return AlertDialog(
      title: Text(l10n.language),
      content: SizedBox(
        width: double.maxFinite,
        child: LanguageSelector(
          localizationService: localizationService,
          showTitle: false,
          onLanguageChanged: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}