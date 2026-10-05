import 'package:flutter/material.dart';

import 'sigillum_theme.dart';

class SigillumQuickGuidePage extends StatelessWidget {
  const SigillumQuickGuidePage({
    super.key,
    this.languageCode = 'en',
  });

  final String languageCode;

  String get _lang {
    final code = languageCode.toLowerCase().split(RegExp(r'[-_]')).first;
    return const {'it', 'en', 'es', 'ru'}.contains(code) ? code : 'en';
  }

  _GuideCopy get _copy => _guideCopies[_lang] ?? _guideCopies['en']!;

  @override
  Widget build(BuildContext context) {
    final copy = _copy;
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(copy.pageTitle),
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
                      copy.heading,
                      style: const TextStyle(
                        color: SigillumTheme.ink,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      copy.intro,
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
              for (final step in copy.steps) ...[
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
                        copy.footer,
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

class _GuideCopy {
  const _GuideCopy({
    required this.pageTitle,
    required this.heading,
    required this.intro,
    required this.footer,
    required this.steps,
  });

  final String pageTitle;
  final String heading;
  final String intro;
  final String footer;
  final List<_GuideStep> steps;
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

const _guideCopies = <String, _GuideCopy>{
  'it': _GuideCopy(
    pageTitle: 'Come si usa SIGILLUM',
    heading: 'Tu fai poco. SIGILLUM fa il resto.',
    intro: 'Crea, salva o condividi. La certificazione e la protezione dell’origine avvengono dietro le quinte.',
    footer: 'Compatibilità attuale: solo iPhone, iOS 16 o successivo; tecnicamente da iPhone 8, iPhone 8 Plus e iPhone X in avanti.',
    steps: [
      _GuideStep(icon: Icons.camera_alt_outlined, title: '1. TU — Scatta, registra o scrivi', text: 'Per foto e video usa la Camera SIGILLUM. Per il testo scrivi direttamente nell’app e premi Certifica. Non devi gestire hash, firme o file tecnici.'),
      _GuideStep(icon: Icons.verified_user_outlined, title: '2. SIGILLUM — Crea l’origine verificabile', text: 'SIGILLUM assegna HCV-ID, calcola le impronte, collega Creator e dispositivo, firma il certificato e registra i dati necessari nel Registry. Per foto e video esegue anche i controlli della cattura e del rischio display.'),
      _GuideStep(icon: Icons.lock_outlined, title: '3. SIGILLUM — Protegge l’originale', text: 'Foto, video e HCVPACK vengono protetti nell’area privata dell’app. Il testo mantiene la propria impronta certificata e può essere conservato anche in HCVPACK.'),
      _GuideStep(icon: Icons.ios_share_outlined, title: '4. TU — Salva o condividi', text: 'Quando una foto o un video deve uscire da SIGILLUM, il riferimento originale protetto viene registrato prima del rilascio. Dopo puoi usare normalmente Foto, social, messaggistica o altre app.'),
      _GuideStep(icon: Icons.text_snippet_outlined, title: '5. TESTO — Pubblica le tue parole certificate', text: 'Il testo scritto in SIGILLUM riceve HCV-ID, hash, impronta testuale e certificato firmato. Puoi copiarlo o pubblicarlo con il suo HCV-ID e verificarlo in seguito incollandolo nuovamente nell’app.'),
      _GuideStep(icon: Icons.fact_check_outlined, title: '6. TU — Verifica ciò che ricevi', text: 'Condividi una foto o un video con SIGILLUM, seleziona un file oppure incolla un testo pubblicato. SIGILLUM recupera il certificato e avvia i controlli previsti.'),
      _GuideStep(icon: Icons.compare_arrows_rounded, title: '7. SIGILLUM — Confronta con l’origine', text: 'Per foto e video SIGILLUM confronta la copia con l’originale o con il riferimento protetto; quando previsto puoi anche fare un confronto umano. Per il testo confronta il contenuto pubblicato con l’impronta certificata.'),
    ],
  ),
  'en': _GuideCopy(
    pageTitle: 'How to use SIGILLUM',
    heading: 'You do a little. SIGILLUM does the rest.',
    intro: 'Create, save or share. Certification and origin protection happen behind the scenes.',
    footer: 'Current compatibility: iPhone only, iOS 16 or later; technically iPhone 8, iPhone 8 Plus and iPhone X or later.',
    steps: [
      _GuideStep(icon: Icons.camera_alt_outlined, title: '1. YOU — Capture, record or write', text: 'Use the SIGILLUM Camera for photos and videos. For text, write directly in the app and tap Certify. You do not need to manage hashes, signatures or technical files.'),
      _GuideStep(icon: Icons.verified_user_outlined, title: '2. SIGILLUM — Creates the verifiable origin', text: 'SIGILLUM assigns the HCV-ID, computes fingerprints, links Creator and device, signs the certificate and registers the required data in the Registry. Photos and videos also receive capture and display-risk checks.'),
      _GuideStep(icon: Icons.lock_outlined, title: '3. SIGILLUM — Protects the original', text: 'Photos, videos and HCVPACK stay protected in the app private area. Text keeps its certified fingerprint and may also be preserved in an HCVPACK.'),
      _GuideStep(icon: Icons.ios_share_outlined, title: '4. YOU — Save or share', text: 'Before a photo or video leaves SIGILLUM, the protected original reference is registered. You can then use Photos, social platforms, messaging or other apps normally.'),
      _GuideStep(icon: Icons.text_snippet_outlined, title: '5. TEXT — Publish certified words', text: 'Text written in SIGILLUM receives an HCV-ID, hash, text fingerprint and signed certificate. You can copy or publish it with its HCV-ID and later verify it by pasting it back into the app.'),
      _GuideStep(icon: Icons.fact_check_outlined, title: '6. YOU — Verify what you receive', text: 'Share a photo or video to SIGILLUM, select a file, or paste published text. SIGILLUM retrieves the certificate and runs the appropriate checks.'),
      _GuideStep(icon: Icons.compare_arrows_rounded, title: '7. SIGILLUM — Compares it with the origin', text: 'For photos and videos SIGILLUM compares the copy with the original or protected reference; where available you can also perform a human comparison. For text, it compares the published content with the certified fingerprint.'),
    ],
  ),
  'es': _GuideCopy(
    pageTitle: 'Cómo usar SIGILLUM',
    heading: 'Tú haces poco. SIGILLUM hace el resto.',
    intro: 'Crea, guarda o comparte. La certificación y la protección del origen ocurren en segundo plano.',
    footer: 'Compatibilidad actual: solo iPhone, iOS 16 o posterior; técnicamente iPhone 8, iPhone 8 Plus y iPhone X o posteriores.',
    steps: [
      _GuideStep(icon: Icons.camera_alt_outlined, title: '1. TÚ — Captura, graba o escribe', text: 'Usa la Cámara SIGILLUM para fotos y vídeos. Para texto, escribe directamente en la app y pulsa Certificar. No necesitas gestionar hashes, firmas ni archivos técnicos.'),
      _GuideStep(icon: Icons.verified_user_outlined, title: '2. SIGILLUM — Crea el origen verificable', text: 'SIGILLUM asigna el HCV-ID, calcula las huellas, vincula Creator y dispositivo, firma el certificado y registra los datos necesarios en el Registry. Las fotos y los vídeos reciben además controles de captura y riesgo de pantalla.'),
      _GuideStep(icon: Icons.lock_outlined, title: '3. SIGILLUM — Protege el original', text: 'Las fotos, los vídeos y HCVPACK permanecen protegidos en el área privada de la app. El texto conserva su huella certificada y también puede guardarse en un HCVPACK.'),
      _GuideStep(icon: Icons.ios_share_outlined, title: '4. TÚ — Guarda o comparte', text: 'Antes de que una foto o un vídeo salga de SIGILLUM se registra la referencia original protegida. Después puedes usar Fotos, redes sociales, mensajería u otras apps normalmente.'),
      _GuideStep(icon: Icons.text_snippet_outlined, title: '5. TEXTO — Publica palabras certificadas', text: 'El texto escrito en SIGILLUM recibe HCV-ID, hash, huella textual y certificado firmado. Puedes copiarlo o publicarlo con su HCV-ID y verificarlo más tarde pegándolo de nuevo en la app.'),
      _GuideStep(icon: Icons.fact_check_outlined, title: '6. TÚ — Verifica lo que recibes', text: 'Comparte una foto o un vídeo con SIGILLUM, selecciona un archivo o pega un texto publicado. SIGILLUM recupera el certificado e inicia los controles previstos.'),
      _GuideStep(icon: Icons.compare_arrows_rounded, title: '7. SIGILLUM — Lo compara con el origen', text: 'Para fotos y vídeos SIGILLUM compara la copia con el original o la referencia protegida; cuando está disponible también puedes realizar una comparación humana. Para texto compara el contenido publicado con la huella certificada.'),
    ],
  ),
  'ru': _GuideCopy(
    pageTitle: 'Как пользоваться SIGILLUM',
    heading: 'Вы делаете немного. Остальное делает SIGILLUM.',
    intro: 'Создайте, сохраните или отправьте. Сертификация и защита происхождения выполняются в фоне.',
    footer: 'Текущая совместимость: только iPhone, iOS 16 или новее; технически iPhone 8, iPhone 8 Plus и iPhone X или новее.',
    steps: [
      _GuideStep(icon: Icons.camera_alt_outlined, title: '1. ВЫ — Снимаете, записываете или пишете', text: 'Для фото и видео используйте Камеру SIGILLUM. Текст пишите прямо в приложении и нажмите Сертифицировать. Управлять хешами, подписями и техническими файлами не нужно.'),
      _GuideStep(icon: Icons.verified_user_outlined, title: '2. SIGILLUM — Создаёт проверяемое происхождение', text: 'SIGILLUM назначает HCV-ID, вычисляет отпечатки, связывает Creator и устройство, подписывает сертификат и регистрирует необходимые данные в Registry. Для фото и видео также выполняются проверки захвата и риска экрана.'),
      _GuideStep(icon: Icons.lock_outlined, title: '3. SIGILLUM — Защищает оригинал', text: 'Фото, видео и HCVPACK защищены в закрытой области приложения. Текст сохраняет сертифицированный отпечаток и также может храниться в HCVPACK.'),
      _GuideStep(icon: Icons.ios_share_outlined, title: '4. ВЫ — Сохраняете или отправляете', text: 'До выхода фото или видео из SIGILLUM регистрируется защищённый оригинальный эталон. После этого можно обычным образом использовать Фото, соцсети, мессенджеры и другие приложения.'),
      _GuideStep(icon: Icons.text_snippet_outlined, title: '5. ТЕКСТ — Публикуйте сертифицированные слова', text: 'Текст, написанный в SIGILLUM, получает HCV-ID, хеш, текстовый отпечаток и подписанный сертификат. Его можно скопировать или опубликовать с HCV-ID, а затем проверить, вставив обратно в приложение.'),
      _GuideStep(icon: Icons.fact_check_outlined, title: '6. ВЫ — Проверяете полученный контент', text: 'Отправьте фото или видео в SIGILLUM, выберите файл или вставьте опубликованный текст. SIGILLUM получает сертификат и запускает нужные проверки.'),
      _GuideStep(icon: Icons.compare_arrows_rounded, title: '7. SIGILLUM — Сравнивает с происхождением', text: 'Для фото и видео SIGILLUM сравнивает копию с оригиналом или защищённым эталоном; при наличии функции можно выполнить и визуальное сравнение. Для текста опубликованный контент сравнивается с сертифицированным отпечатком.'),
    ],
  ),
};

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
