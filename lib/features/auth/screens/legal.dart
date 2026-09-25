import 'package:flutter/material.dart';

// Condensed legal text shown in the app. Full versions live in
// terms-of-service.md and privacy-policy.md. Blocks are separated by blank
// lines: the first is the intro, the last is the footer, and each block in
// between starts with its heading line.
const termsOfServiceText = '''
Smart Plate ("the Application") is operated by Jenalyn Pagauitan and Jemimah Jimenez (the "Service Provider"). By using the app you agree to these Terms.

License
The Application is distributed as open source software under its applicable license.

Intellectual Property
The Service Provider retains all rights in the app's code, design, and branding.

Account and Age
You must be legally permitted to use the app in your jurisdiction and meet the minimum age of digital consent. Below that age, a parent or guardian must accept these Terms on your behalf.

User-Generated Content
If you post content, it must not be illegal, infringing, abusive, spam, or misleading. The Service Provider may remove content or suspend accounts that violate these rules, and you may report content or appeal a moderation decision at smartplate@gmail.com.

Third-Party Services
The app uses Google Play Services.

Limitation of Liability
The Service Provider is not liable for indirect or consequential damages, except where liability cannot be excluded by law (e.g. negligence causing injury, fraud).

Termination
The Service Provider may suspend or terminate access for material breach, with notice and a cure period where applicable, or immediately for unlawful conduct.

Governing Law
These Terms are governed by the laws of the jurisdiction where the Service Provider is established.

Changes
The Service Provider may update these Terms and will post the new version here.

Effective 2026-07-29. Full terms: terms-of-service.md. Contact: smartplate@gmail.com
''';

const privacyPolicyText = '''
This policy applies to the Smart Plate app, operated by Jenalyn Pagauitan and Jemimah Jimenez (the "Service Provider").

Information Collected
Device IP address, pages visited and time spent in the app, and your mobile operating system.

How It's Used
To operate and improve the app, send required notices, and, where permitted, marketing communications.

Third-Party Sharing
Only aggregated, anonymized data is shared with external services to improve the app. The app uses Google Play Services.

International Transfers
Data may be transferred outside your country of residence, using safeguards such as Standard Contractual Clauses where required.

Your Rights
You may request access to, correction of, or deletion of your data, and California residents have CCPA/CPRA rights, by contacting smartplate@gmail.com.

Data Retention
User-provided data is kept for the duration of your use plus 12 months; automatically collected data for up to 24 months; aggregated/anonymized data indefinitely, unless law requires otherwise.

Children
The app is not intended for children under the applicable minimum age, and data mistakenly collected from a child will be deleted.

Security
The Service Provider maintains physical, electronic, and procedural safeguards, and will notify you of any data breach as required by law.

Changes
The Service Provider may update this policy and will notify you of material changes.

Effective 2026-07-29. Full policy: privacy-policy.md. Contact: smartplate@gmail.com
''';


// One heading and its paragraph from the legal text.
class _LegalSection {
  final String heading;
  final String body;
  const _LegalSection(this.heading, this.body);
}

// Full-screen reader for the Terms of Service or Privacy Policy.
// Pops true when the user taps Accept.
class LegalScreen extends StatelessWidget {
  final String title;
  final String text;
  final IconData icon;
  final bool showAccept;

  const LegalScreen({
    super.key,
    required this.title,
    required this.text,
    required this.icon,
    this.showAccept = true,
  });

  static const Color brandGreen = Color(0xFF67A75F);
  static const Color darkBlue = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color borderColor = Color(0xFFE2E8F0);
  static const Color bgLight = Color(0xFFF8FAFC);

  List<String> get _blocks => text
      .trim()
      .split(RegExp(r'\n\s*\n'))
      .map((b) => b.trim())
      .where((b) => b.isNotEmpty)
      .toList();

  String get _intro => _blocks.first;
  String get _footer => _blocks.length > 1 ? _blocks.last : '';

  List<_LegalSection> get _sections {
    final blocks = _blocks;
    if (blocks.length < 3) return const [];
    return [
      for (final block in blocks.sublist(1, blocks.length - 1))
        _LegalSection(
          block.split('\n').first.trim(),
          block.split('\n').skip(1).join(' ').trim(),
        ),
    ];
  }

  // "Effective 2026-07-29." becomes "July 29, 2026".
  String? get _effectiveDate {
    final m = RegExp(r'Effective (\d{4})-(\d{2})-(\d{2})').firstMatch(_footer);
    if (m == null) return null;
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June', 'July',
      'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[int.parse(m.group(2)!) - 1]} ${int.parse(m.group(3)!)}, ${m.group(1)}';
  }

  String? get _contact =>
      RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+').firstMatch(_footer)?.group(0);

  @override
  Widget build(BuildContext context) {
    final sections = _sections;
    final effective = _effectiveDate;
    final contact = _contact;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: darkBlue),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: darkBlue,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          // Header card with the document name and date.
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: bgLight,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: brandGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: brandGreen),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: darkBlue,
                    letterSpacing: -0.5,
                  ),
                ),
                if (effective != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Effective $effective',
                    style: const TextStyle(fontSize: 13, color: textSecondary),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  _intro,
                  style: const TextStyle(
                    fontSize: 14,
                    color: darkBlue,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < sections.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 26,
                    width: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: brandGreen.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: brandGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sections[i].heading,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: darkBlue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sections[i].body,
                          style: const TextStyle(
                            fontSize: 14,
                            color: textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (contact != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.mail_outline_rounded,
                    color: brandGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Questions?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: darkBlue,
                          ),
                        ),
                        Text(
                          contact,
                          style: const TextStyle(
                            fontSize: 13,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: showAccept
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                height: 55,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Accept',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
