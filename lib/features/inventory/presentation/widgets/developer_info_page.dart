import 'package:flutter/material.dart';
// Upewnij się, że masz url_launcher w pubspec.yaml
import 'package:url_launcher/url_launcher.dart';

class DeveloperInfoPage extends StatelessWidget {
  const DeveloperInfoPage({super.key});

  // Linki (Podmień na swoje!)
  final String _githubUrl = 'https://github.com/nexlay';
  final String _linkedinUrl =
      'https://www.linkedin.com/in/mykola-pryhodskyi-81265224a?utm_source=share_via&utm_content=profile&utm_medium=member_android';
  final String _email = 'mailto:kontakt@twoj-email.pl';

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(
            title: Text('Developer'),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 20),

              // --- NOWY LAYOUT: STACK (Karta + Awatar) ---
              Stack(
                alignment: Alignment.topCenter,
                children: [
                  // 1. KARTA (Przesunięta w dół)
                  Padding(
                    padding:
                        const EdgeInsets.only(top: 60.0, left: 16, right: 16),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(
                          color: colorScheme.outlineVariant.withOpacity(0.5),
                        ),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            // Puste miejsce na awatar, który "wchodzi" na kartę
                            const SizedBox(height: 50),

                            // Imię i Nazwisko
                            Text(
                              'Mykola Pryhodskyi',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                            ),
                            const SizedBox(height: 4),

                            // Stanowisko
                            Text(
                              'Mobile App Developer',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),

                            const SizedBox(height: 24),
                            Divider(
                                color: colorScheme.outlineVariant
                                    .withOpacity(0.5)),
                            const SizedBox(height: 24),

                            // Opis / Bio (Wewnątrz karty)
                            Text(
                              'Passionate developer focused on creating clean, efficient, and user-friendly mobile applications using Flutter. Always learning and exploring new technologies.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.5,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 2. AWATAR (Na wierzchu)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .scaffoldBackgroundColor, // Kolor tła, żeby zrobić obrys
                      shape: BoxShape.circle,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                        border: Border.all(
                          color: colorScheme.primaryContainer,
                          width: 4,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: colorScheme.primaryContainer,
                        // backgroundImage: const AssetImage('assets/images/dev_photo.jpg'),
                        child: Icon(Icons.person,
                            size: 60, color: colorScheme.onPrimaryContainer),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // 3. SEKCJA KONTAKTU / LINKÓW (Bez zmian)
              _buildSectionTitle(context, 'Connect'),

              const SizedBox(height: 8),

              _buildSocialTile(
                context,
                icon: Icons.code,
                title: 'GitHub',
                subtitle: 'Check out my repositories',
                onTap: () => _launchUrl(_githubUrl),
              ),
              _buildSocialTile(
                context,
                icon: Icons.work_outline,
                title: 'LinkedIn',
                subtitle: 'Connect professionally',
                onTap: () => _launchUrl(_linkedinUrl),
              ),
              _buildSocialTile(
                context,
                icon: Icons.email_outlined,
                title: 'Email',
                subtitle: 'Get in touch',
                onTap: () => _launchUrl(_email),
              ),

              const SizedBox(height: 32),

              // 4. TECH STACK (Bez zmian)
              _buildSectionTitle(context, 'Tech Stack'),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildTechChip(context, 'Flutter'),
                    _buildTechChip(context, 'Dart'),
                    _buildTechChip(context, 'Bloc'),
                    _buildTechChip(context, 'Clean Architecture'),
                    _buildTechChip(context, 'Isar DB'),
                    _buildTechChip(context, 'Material 3'),
                  ],
                ),
              ),

              const SizedBox(height: 50),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildSocialTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .secondaryContainer
                .withOpacity(0.4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.open_in_new, size: 18, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  Widget _buildTechChip(BuildContext context, String label) {
    return Chip(
      label: Text(label),
      backgroundColor: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withOpacity(0.3),
      side: BorderSide.none,
    );
  }
}
