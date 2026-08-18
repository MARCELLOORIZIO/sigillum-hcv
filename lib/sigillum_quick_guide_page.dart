import 'package:flutter/material.dart';

import 'sigillum_theme.dart';

class SigillumQuickGuidePage extends StatelessWidget {
  const SigillumQuickGuidePage({
    super.key,
    this.languageCode = 'it',
  });

  final String languageCode;

  bool get _it => languageCode.toLowerCase().startsWith('it');

  @override
  Widget build(BuildContext context) {
    final steps = _it
        ? const [
            _GuideStep(
              icon: Icons.verified_user_outlined,
              title: '1. Verifica o certifica',
              text:
                  'Per controllare un contenuto usa “Verifica contenuto”. Per creare contenuti certificati accedi come Creator e usa foto, video o testo.',
            ),
            _GuideStep(
              icon: Icons.videocam_outlined,
              title: '2. Segui la camera',
              text:
                  'Durante il controllo della scena muovi leggermente il telefono come indicato. Quando compare PROSEGUI torna all’inquadratura desiderata; per il video premi poi REC.',
            ),
            _GuideStep(
              icon: Icons.folder_outlined,
              title: '3. Dove trovi i file',
              text:
                  'SIGILLUM salva automaticamente i file in File > Sul mio iPhone > Fotocamera Sigillum. Qui trovi l’originale certificato, il certificato .HCV, l’HCVPACK e gli eventuali file sottotitoli.',
            ),
            _GuideStep(
              icon: Icons.closed_caption_outlined,
              title: '4. Video con sottotitoli',
              text:
                  '“Crea video con sottotitoli” produce una copia derivata con scritte sincronizzate. L’originale certificato non viene modificato. Puoi salvare la copia sottotitolata anche in Foto.',
            ),
            _GuideStep(
              icon: Icons.text_snippet_outlined,
              title: '5. Testi pubblicati',
              text:
                  'Per verificare un messaggio o un post già pubblicato apri Verifica contenuto > Verifica testo pubblicato e incolla il testo con il relativo HCV-ID.',
            ),
          ]
        : const [
            _GuideStep(
              icon: Icons.verified_user_outlined,
              title: '1. Verify or certify',
              text:
                  'Use “Verify content” to check a file. Sign in as a Creator to certify new photos, videos or text.',
            ),
            _GuideStep(
              icon: Icons.videocam_outlined,
              title: '2. Follow the camera prompts',
              text:
                  'Move the phone slightly when requested. When CONTINUE appears, return to your preferred framing; for video, then tap REC.',
            ),
            _GuideStep(
              icon: Icons.folder_outlined,
              title: '3. Where files are stored',
              text:
                  'SIGILLUM automatically saves files in Files > On My iPhone > Fotocamera Sigillum. The certified original, .HCV certificate, HCVPACK and subtitle files are stored there.',
            ),
            _GuideStep(
              icon: Icons.closed_caption_outlined,
              title: '4. Captioned video',
              text:
                  '“Create captioned video” makes a separate derived copy with synchronized captions. The certified original is never modified. You can also save the captioned copy to Photos.',
            ),
            _GuideStep(
              icon: Icons.text_snippet_outlined,
              title: '5. Published text',
              text:
                  'To verify a message or post, open Verify content > Verify published text and paste the text with its HCV-ID.',
            ),
          ];

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(_it ? 'Come si usa SIGILLUM' : 'How to use SIGILLUM'),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFEAFBFF),
              Color(0xFFFAF9FA),
              Color(0xFFF2ECFF),
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 34),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: SigillumTheme.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x15280D5F),
                      blurRadius: 28,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7645D9), Color(0xFF1FC7D4)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.verified_user_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _it ? 'Guida rapida' : 'Quick guide',
                      style: const TextStyle(
                        color: SigillumTheme.ink,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _it
                          ? 'Le operazioni essenziali in pochi passaggi.'
                          : 'The essential workflow in a few steps.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: SigillumTheme.muted,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              for (final step in steps) ...[
                _GuideCard(step: step),
                const SizedBox(height: 12),
              ],
              Container(
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8FAFC),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFB9EEF2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: SigillumTheme.accentDark,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _it
                            ? 'La cartella File è l’archivio principale. Foto è una copia di comodità: per i video sottotitolati usa la copia indicata come “sottotitolato”.'
                            : 'The Files folder is the primary archive. Photos is a convenience copy: for captioned videos use the copy explicitly marked as captioned.',
                        style: const TextStyle(
                          color: SigillumTheme.ink,
                          fontSize: 14,
                          height: 1.35,
                        ),
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

class _GuideStep {
  const _GuideStep({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.step});

  final _GuideStep step;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: SigillumTheme.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10280D5F),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Color(0xFFE8FAFC),
              shape: BoxShape.circle,
            ),
            child: Icon(step.icon, color: SigillumTheme.accentDark, size: 28),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: const TextStyle(
                    color: SigillumTheme.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  step.text,
                  style: const TextStyle(
                    color: SigillumTheme.muted,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
