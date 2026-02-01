import 'package:flutter/material.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/widgets/developer_info_page.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutCard extends StatelessWidget {
  const AboutCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          // 1. BRANDING HEADER (Logo + Wersja)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
            ),
            child: Column(
              children: [
                // LOGO (Tutaj używam Ikony, ale możesz podmienić na Image.asset)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.nfc, // Zmień na swoje logo
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

                // NAZWA APKI
                Text(
                  'Grid Storage',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                    letterSpacing: 0.5,
                  ),
                ),

                const SizedBox(height: 4),

                // WERSJA
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'v1.0.0 • Clean Architecture',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. LISTA AKCJI (Licencje, Autor)
          Column(
            children: [
              _buildInfoTile(
                context,
                icon: Icons.description_outlined,
                title: 'Open Source Licenses',
                subtitle: 'Libraries used to build this app',
                onTap: () async {
                  final packageInfo = await PackageInfo.fromPlatform();
                  if (context.mounted) {
                    // 2. Wyświetlamy wbudowaną stronę licencji
                    showLicensePage(
                      context: context,
                      applicationName: 'Grid Storage NFC',
                      // Teraz wersja jest dynamiczna!
                      applicationVersion:
                          'v${packageInfo.version} (build ${packageInfo.buildNumber})',
                      applicationIcon: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.nfc,
                            size: 48,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer),
                      ),
                      applicationLegalese:
                          '© ${DateTime.now().year} Grid Storage',
                    );
                  }
                },
              ),
              Divider(
                  height: 1,
                  indent: 56,
                  endIndent: 16,
                  color: colorScheme.outlineVariant.withOpacity(0.5)),
              _buildInfoTile(
                context,
                icon: Icons.code,
                title: 'Developer',
                subtitle: 'Designed & Coded by...',
                onTap: () {
                  // Nawigacja do nowej strony
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DeveloperInfoPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color:
              Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        child:
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      onTap: onTap,
    );
  }
}
