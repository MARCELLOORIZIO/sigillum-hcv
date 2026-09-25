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
    heading: 'Guida rapida',
    intro: 'Creazione, protezione, condivisione e verifica in pochi passaggi.',
    footer:
        'Foto e video certificati restano cifrati nell’area privata SIGILLUM. La copia in chiaro esiste solo temporaneamente quando l’app deve visualizzare o condividere il contenuto.',
    steps: [
      _GuideStep(
        icon: Icons.verified_user_outlined,
        title: '1. Verifica o crea e certifica',
        text:
            'Per controllare un contenuto usa “Verifica contenuto” o “SIGILLUM Verified Originals”. Per creare nuovi contenuti certificati accedi come Creator e scegli foto, video o testo.',
      ),
      _GuideStep(
        icon: Icons.videocam_outlined,
        title: '2. Crea foto o video con la Camera SIGILLUM',
        text:
            'SIGILLUM acquisisce il contenuto, esegue i controlli tecnici, crea HCV-ID, hash, certificato e HCVPACK. Il risultato del controllo rischio schermo resta un’evidenza tecnica e non impedisce la certificazione o la pubblicazione.',
      ),
      _GuideStep(
        icon: Icons.lock_outlined,
        title: '3. Originali protetti',
        text:
            'Dopo la certificazione, foto o video e HCVPACK vengono cifrati nell’area privata dell’app e non vengono salvati automaticamente in Foto. Apri “Originali protetti” per visualizzarli o condividerli.',
      ),
      _GuideStep(
        icon: Icons.ios_share_outlined,
        title: '4. Condivisione sui social',
        text:
            'Quando scegli di condividere, SIGILLUM verifica l’originale e registra prima la copia di riferimento ufficiale. Solo dopo il buon esito viene aperto il menu Condividi di iPhone. Se il riferimento non viene registrato, il file non viene rilasciato al social.',
      ),
      _GuideStep(
        icon: Icons.fact_check_outlined,
        title: '5. Verifica successiva',
        text:
            'Puoi verificare un HCV-ID oppure selezionare un file dalla libreria. SIGILLUM controlla certificato e Registry e, quando disponibile, consente di consultare la copia di riferimento ufficiale secondo le condizioni di accesso previste.',
      ),
    ],
  ),
  'en': _GuideCopy(
    pageTitle: 'How to use SIGILLUM',
    heading: 'Quick guide',
    intro: 'Create, protect, share and verify in a few steps.',
    footer:
        'Certified photos and videos remain encrypted in SIGILLUM’s private area. A clear copy exists only temporarily when the app needs to display or share the content.',
    steps: [
      _GuideStep(
        icon: Icons.verified_user_outlined,
        title: '1. Verify or create and certify',
        text:
            'Use “Verify content” or “SIGILLUM Verified Originals” to check existing content. Sign in as a Creator to create and certify a new photo, video or text.',
      ),
      _GuideStep(
        icon: Icons.videocam_outlined,
        title: '2. Create a photo or video with the SIGILLUM Camera',
        text:
            'SIGILLUM captures the content, runs its technical checks, and creates the HCV-ID, hash, certificate and HCVPACK. The screen-risk result remains technical evidence and does not block certification or publication.',
      ),
      _GuideStep(
        icon: Icons.lock_outlined,
        title: '3. Protected originals',
        text:
            'After certification, the photo or video and HCVPACK are encrypted in the app’s private area and are not automatically saved to Photos. Open “Protected originals” to view or share them.',
      ),
      _GuideStep(
        icon: Icons.ios_share_outlined,
        title: '4. Share to social platforms',
        text:
            'When you choose to share, SIGILLUM verifies the original and first registers the official reference copy. The iPhone share sheet opens only after that succeeds. If the reference cannot be registered, the file is not released to the social platform.',
      ),
      _GuideStep(
        icon: Icons.fact_check_outlined,
        title: '5. Verify later',
        text:
            'You can verify an HCV-ID or select a file from your library. SIGILLUM checks the certificate and Registry and, when available, lets you view the official reference copy under the applicable access conditions.',
      ),
    ],
  ),
  'es': _GuideCopy(
    pageTitle: 'Cómo usar SIGILLUM',
    heading: 'Guía rápida',
    intro: 'Crea, protege, comparte y verifica en pocos pasos.',
    footer:
        'Las fotos y los vídeos certificados permanecen cifrados en el área privada de SIGILLUM. Solo existe una copia en claro de forma temporal cuando la app necesita mostrar o compartir el contenido.',
    steps: [
      _GuideStep(
        icon: Icons.verified_user_outlined,
        title: '1. Verificar o crear y certificar',
        text:
            'Usa “Verificar contenido” o “SIGILLUM Verified Originals” para comprobar contenido existente. Accede como Creator para crear y certificar una nueva foto, vídeo o texto.',
      ),
      _GuideStep(
        icon: Icons.videocam_outlined,
        title: '2. Crear una foto o un vídeo con la Cámara SIGILLUM',
        text:
            'SIGILLUM captura el contenido, ejecuta los controles técnicos y crea HCV-ID, hash, certificado y HCVPACK. El resultado del riesgo de pantalla sigue siendo evidencia técnica y no bloquea la certificación ni la publicación.',
      ),
      _GuideStep(
        icon: Icons.lock_outlined,
        title: '3. Originales protegidos',
        text:
            'Después de la certificación, la foto o el vídeo y el HCVPACK se cifran en el área privada de la app y no se guardan automáticamente en Fotos. Abre “Originales protegidos” para verlos o compartirlos.',
      ),
      _GuideStep(
        icon: Icons.ios_share_outlined,
        title: '4. Compartir en redes sociales',
        text:
            'Cuando eliges compartir, SIGILLUM verifica el original y registra primero la copia de referencia oficial. El menú Compartir del iPhone solo se abre después de que el registro termine correctamente. Si la referencia no se registra, el archivo no se entrega a la red social.',
      ),
      _GuideStep(
        icon: Icons.fact_check_outlined,
        title: '5. Verificar después',
        text:
            'Puedes verificar un HCV-ID o seleccionar un archivo de tu biblioteca. SIGILLUM comprueba el certificado y el Registry y, cuando está disponible, permite consultar la copia de referencia oficial según las condiciones de acceso aplicables.',
      ),
    ],
  ),
  'ru': _GuideCopy(
    pageTitle: 'Как пользоваться SIGILLUM',
    heading: 'Краткое руководство',
    intro: 'Создание, защита, отправка и проверка в нескольких шагах.',
    footer:
        'Сертифицированные фото и видео остаются зашифрованными в закрытой области SIGILLUM. Открытая копия создаётся только временно, когда приложение должно показать или отправить контент.',
    steps: [
      _GuideStep(
        icon: Icons.verified_user_outlined,
        title: '1. Проверить или создать и сертифицировать',
        text:
            'Используйте «Проверить контент» или «SIGILLUM Verified Originals» для проверки существующего материала. Войдите как Creator, чтобы создать и сертифицировать новое фото, видео или текст.',
      ),
      _GuideStep(
        icon: Icons.videocam_outlined,
        title: '2. Создать фото или видео камерой SIGILLUM',
        text:
            'SIGILLUM захватывает контент, выполняет технические проверки и создаёт HCV-ID, хеш, сертификат и HCVPACK. Результат оценки риска экрана остаётся техническим свидетельством и не блокирует сертификацию или публикацию.',
      ),
      _GuideStep(
        icon: Icons.lock_outlined,
        title: '3. Защищённые оригиналы',
        text:
            'После сертификации фото или видео и HCVPACK шифруются в закрытой области приложения и не сохраняются автоматически в Photos. Откройте «Защищённые оригиналы», чтобы просмотреть или отправить их.',
      ),
      _GuideStep(
        icon: Icons.ios_share_outlined,
        title: '4. Отправка в социальные сети',
        text:
            'Когда вы выбираете отправку, SIGILLUM проверяет оригинал и сначала регистрирует официальную эталонную копию. Меню «Поделиться» iPhone открывается только после успешной регистрации. Если эталон не зарегистрирован, файл не передаётся социальной платформе.',
      ),
      _GuideStep(
        icon: Icons.fact_check_outlined,
        title: '5. Последующая проверка',
        text:
            'Можно проверить HCV-ID или выбрать файл из библиотеки. SIGILLUM проверяет сертификат и Registry и, если эталон доступен, позволяет открыть официальную эталонную копию в соответствии с условиями доступа.',
      ),
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
