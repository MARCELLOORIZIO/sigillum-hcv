from pathlib import Path

ALLOWED = {
    'lib/sigillum_localization.dart',
    'lib/sigillum_quick_guide_page.dart',
    'lib/commercial_gate.dart',
    'lib/user_home_page.dart',
}


def read(path: str) -> str:
    return Path(path).read_text(encoding='utf-8')


def write(path: str, content: str) -> None:
    if path not in ALLOWED:
        raise RuntimeError(f'Write outside UI/localization allowlist blocked: {path}')
    Path(path).write_text(content, encoding='utf-8')


# ---------------------------------------------------------------------------
# Shared Creator-home copy. Presentation only: no camera/HCV/Registry code.
# ---------------------------------------------------------------------------
loc_path = 'lib/sigillum_localization.dart'
loc = read(loc_path)
replacements = {
    "'certifyMediaTitle': 'Certifica foto o video',": "'certifyMediaTitle': 'Crea e Certifica foto o video',",
    "'certifyMediaTitle': 'Certify photo or video',": "'certifyMediaTitle': 'Create and certify a photo or video',",
    "'certifyMediaTitle': 'Certificar foto o video',": "'certifyMediaTitle': 'Crear y certificar una foto o un vídeo',",
    "'certifyMediaTitle': 'Сертифицировать фото или видео',": "'certifyMediaTitle': 'Создать и сертифицировать фото или видео',",
}
for old, new in replacements.items():
    if old in loc:
        loc = loc.replace(old, new, 1)
    elif new not in loc:
        raise RuntimeError(f'Creator media title anchor missing: {old}')

# Add quick-guide labels to every language block immediately after infoSubtitle.
quick_labels = {
    'it': (
        "      'infoSubtitle': 'Controlli, limiti, termini e supporto.',\n",
        "      'infoSubtitle': 'Controlli, limiti, termini e supporto.',\n"
        "      'quickGuideTitle': 'Come si usa SIGILLUM',\n"
        "      'quickGuideSubtitle': 'Guida rapida: camera, coordinate, flash, zoom, verifica e sottotitoli',\n"
        "      'quickGuideTooltip': 'Come si usa',\n",
    ),
    'en': (
        "      'infoSubtitle': 'Checks, limits, terms and support.',\n",
        "      'infoSubtitle': 'Checks, limits, terms and support.',\n"
        "      'quickGuideTitle': 'How to use SIGILLUM',\n"
        "      'quickGuideSubtitle': 'Quick guide: camera, coordinates, flash, zoom, verification and captions',\n"
        "      'quickGuideTooltip': 'How to use',\n",
    ),
    'es': (
        "      'infoSubtitle': 'Controles, limites, terminos y soporte.',\n",
        "      'infoSubtitle': 'Controles, limites, terminos y soporte.',\n"
        "      'quickGuideTitle': 'Cómo usar SIGILLUM',\n"
        "      'quickGuideSubtitle': 'Guía rápida: cámara, coordenadas, flash, zoom, verificación y subtítulos',\n"
        "      'quickGuideTooltip': 'Cómo se usa',\n",
    ),
    'ru': (
        "      'infoSubtitle': 'Проверки, ограничения, условия и поддержка.',\n",
        "      'infoSubtitle': 'Проверки, ограничения, условия и поддержка.',\n"
        "      'quickGuideTitle': 'Как пользоваться SIGILLUM',\n"
        "      'quickGuideSubtitle': 'Краткое руководство: камера, координаты, вспышка, зум, проверка и субтитры',\n"
        "      'quickGuideTooltip': 'Как пользоваться',\n",
    ),
}
for code, (anchor, expanded) in quick_labels.items():
    token = f"'quickGuideTitle':"
    # Count only inside the whole file by checking the exact translated title.
    translated_title = expanded.split("'quickGuideTitle': ", 1)[1].split(',\n', 1)[0]
    if translated_title not in loc:
        if anchor not in loc:
            raise RuntimeError(f'Quick-guide localization anchor missing for {code}')
        loc = loc.replace(anchor, expanded, 1)

write(loc_path, loc)


# ---------------------------------------------------------------------------
# Complete four-language quick guide.
# ---------------------------------------------------------------------------
guide_path = 'lib/sigillum_quick_guide_page.dart'
guide = r'''import 'package:flutter/material.dart';

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
    intro: 'Le operazioni essenziali in pochi passaggi.',
    footer:
        'La cartella File è l’archivio principale. Foto è una copia di comodità. L’HCVPACK conserva insieme contenuto e certificato per la verifica offline.',
    steps: [
      _GuideStep(
        icon: Icons.verified_user_outlined,
        title: '1. Verifica o crea e certifica',
        text:
            'Per controllare un contenuto usa “Verifica contenuto”. Per creare nuovi contenuti certificati accedi come Creator e scegli foto, video o testo.',
      ),
      _GuideStep(
        icon: Icons.videocam_outlined,
        title: '2. Camera: coordinate, flash e zoom',
        text:
            'Nella schermata camera, prima di scattare o avviare il video, puoi scegliere se aggiungere oppure no le coordinate GPS. Puoi inoltre usare il flash e regolare lo zoom. Durante il controllo della scena muovi leggermente il telefono come indicato; quando compare PROSEGUI torna all’inquadratura desiderata e, per il video, premi REC.',
      ),
      _GuideStep(
        icon: Icons.folder_outlined,
        title: '3. Dove trovi i file',
        text:
            'SIGILLUM salva i file in File > Sul mio iPhone > Fotocamera Sigillum. Qui trovi il contenuto certificato, il certificato .HCV e l’HCVPACK; per i video possono essere creati anche i file relativi ai sottotitoli.',
      ),
      _GuideStep(
        icon: Icons.closed_caption_outlined,
        title: '4. Sottotitoli sincronizzati dopo il video',
        text:
            'Quando la registrazione è conclusa puoi creare una copia derivata con sottotitoli sincronizzati. L’originale certificato non viene modificato. La copia sottotitolata può essere salvata anche in Foto.',
      ),
      _GuideStep(
        icon: Icons.text_snippet_outlined,
        title: '5. Verifica successiva',
        text:
            'Puoi verificare un file, un HCVPACK o un HCV-ID dal Registry. Per un messaggio o un post già pubblicato usa Verifica contenuto > Verifica testo pubblicato.',
      ),
    ],
  ),
  'en': _GuideCopy(
    pageTitle: 'How to use SIGILLUM',
    heading: 'Quick guide',
    intro: 'The essential workflow in a few steps.',
    footer:
        'The Files folder is the primary archive. Photos is a convenience copy. The HCVPACK keeps the content and certificate together for offline verification.',
    steps: [
      _GuideStep(
        icon: Icons.verified_user_outlined,
        title: '1. Verify or create and certify',
        text:
            'Use “Verify content” to check existing content. Sign in as a Creator to create and certify a new photo, video or text.',
      ),
      _GuideStep(
        icon: Icons.videocam_outlined,
        title: '2. Camera: coordinates, flash and zoom',
        text:
            'On the camera screen, before taking a photo or starting a video, you can choose whether to include GPS coordinates. You can also use the flash and adjust zoom. During the scene check, move the phone slightly as instructed; when CONTINUE appears, return to your preferred framing and, for video, tap REC.',
      ),
      _GuideStep(
        icon: Icons.folder_outlined,
        title: '3. Where files are stored',
        text:
            'SIGILLUM stores files in Files > On My iPhone > Fotocamera Sigillum. The certified content, .HCV certificate and HCVPACK are stored there; video subtitle files may also be created.',
      ),
      _GuideStep(
        icon: Icons.closed_caption_outlined,
        title: '4. Synchronized captions after video',
        text:
            'After recording is complete, you can create a separate derived copy with synchronized captions. The certified original is not modified. The captioned copy can also be saved to Photos.',
      ),
      _GuideStep(
        icon: Icons.text_snippet_outlined,
        title: '5. Verify later',
        text:
            'You can verify a file, HCVPACK or HCV-ID through the Registry. For a published message or post, use Verify content > Verify published text.',
      ),
    ],
  ),
  'es': _GuideCopy(
    pageTitle: 'Cómo usar SIGILLUM',
    heading: 'Guía rápida',
    intro: 'Las operaciones esenciales en pocos pasos.',
    footer:
        'La carpeta Archivos es el archivo principal. Fotos es una copia de comodidad. El HCVPACK conserva juntos el contenido y el certificado para la verificación sin conexión.',
    steps: [
      _GuideStep(
        icon: Icons.verified_user_outlined,
        title: '1. Verificar o crear y certificar',
        text:
            'Usa “Verificar contenido” para comprobar contenido existente. Accede como Creator para crear y certificar una nueva foto, vídeo o texto.',
      ),
      _GuideStep(
        icon: Icons.videocam_outlined,
        title: '2. Cámara: coordenadas, flash y zoom',
        text:
            'En la pantalla de cámara, antes de hacer una foto o iniciar un vídeo, puedes elegir si incluir o no las coordenadas GPS. También puedes usar el flash y ajustar el zoom. Durante el control de la escena mueve ligeramente el teléfono como se indica; cuando aparezca CONTINUAR vuelve al encuadre deseado y, para vídeo, pulsa REC.',
      ),
      _GuideStep(
        icon: Icons.folder_outlined,
        title: '3. Dónde se guardan los archivos',
        text:
            'SIGILLUM guarda los archivos en Archivos > En mi iPhone > Fotocamera Sigillum. Allí encontrarás el contenido certificado, el certificado .HCV y el HCVPACK; para los vídeos también pueden generarse archivos de subtítulos.',
      ),
      _GuideStep(
        icon: Icons.closed_caption_outlined,
        title: '4. Subtítulos sincronizados después del vídeo',
        text:
            'Cuando termina la grabación puedes crear una copia derivada separada con subtítulos sincronizados. El original certificado no se modifica. La copia subtitulada también puede guardarse en Fotos.',
      ),
      _GuideStep(
        icon: Icons.text_snippet_outlined,
        title: '5. Verificar después',
        text:
            'Puedes verificar un archivo, un HCVPACK o un HCV-ID mediante el Registry. Para un mensaje o publicación ya publicados usa Verificar contenido > Verificar texto publicado.',
      ),
    ],
  ),
  'ru': _GuideCopy(
    pageTitle: 'Как пользоваться SIGILLUM',
    heading: 'Краткое руководство',
    intro: 'Основные операции в нескольких шагах.',
    footer:
        'Папка Files является основным архивом. Photos — дополнительная удобная копия. HCVPACK хранит контент и сертификат вместе для офлайн-проверки.',
    steps: [
      _GuideStep(
        icon: Icons.verified_user_outlined,
        title: '1. Проверить или создать и сертифицировать',
        text:
            'Используйте «Проверить контент» для проверки существующего материала. Войдите как Creator, чтобы создать и сертифицировать новое фото, видео или текст.',
      ),
      _GuideStep(
        icon: Icons.videocam_outlined,
        title: '2. Камера: координаты, вспышка и зум',
        text:
            'На экране камеры перед съемкой фото или запуском видео можно выбрать, добавлять ли GPS-координаты. Также можно использовать вспышку и менять зум. Во время проверки сцены слегка перемещайте телефон по инструкции; когда появится ПРОДОЛЖИТЬ, вернитесь к нужному кадру и для видео нажмите REC.',
      ),
      _GuideStep(
        icon: Icons.folder_outlined,
        title: '3. Где находятся файлы',
        text:
            'SIGILLUM сохраняет файлы в Files > On My iPhone > Fotocamera Sigillum. Там находятся сертифицированный контент, сертификат .HCV и HCVPACK; для видео также могут создаваться файлы субтитров.',
      ),
      _GuideStep(
        icon: Icons.closed_caption_outlined,
        title: '4. Синхронизированные субтитры после видео',
        text:
            'После завершения записи можно создать отдельную производную копию с синхронизированными субтитрами. Сертифицированный оригинал не изменяется. Копию с субтитрами также можно сохранить в Photos.',
      ),
      _GuideStep(
        icon: Icons.text_snippet_outlined,
        title: '5. Последующая проверка',
        text:
            'Можно проверить файл, HCVPACK или HCV-ID через Registry. Для уже опубликованного сообщения или поста используйте Проверить контент > Проверить опубликованный текст.',
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
'''
write(guide_path, guide)


# ---------------------------------------------------------------------------
# Final generated commercial landing: pass the selected language into the
# guide and use the shared four-language labels. This file is commercial UI.
# ---------------------------------------------------------------------------
gate_path = 'lib/commercial_gate.dart'
gate = read(gate_path)
if 'SigillumQuickGuidePage' in gate:
    gate = gate.replace(
        "builder: (_) => const SigillumQuickGuidePage(languageCode: 'it'),",
        "builder: (_) => SigillumQuickGuidePage(languageCode: _languageCode),",
    )
    gate = gate.replace(
        "title: 'Come si usa SIGILLUM',",
        "title: SigillumCopy.t(_languageCode, 'quickGuideTitle'),",
    )
    gate = gate.replace(
        "subtitle: 'Guida rapida: camera, file, verifica e sottotitoli',",
        "subtitle: SigillumCopy.t(_languageCode, 'quickGuideSubtitle'),",
    )
    gate = gate.replace(
        "tooltip: 'Come si usa',",
        "tooltip: SigillumCopy.t(_languageCode, 'quickGuideTooltip'),",
    )
    if "SigillumQuickGuidePage(languageCode: _languageCode)" not in gate:
        raise RuntimeError('Commercial quick guide still does not receive selected language')
write(gate_path, gate)


# Creator home quick-guide card: remove the old IT/EN-only ternary.
home_path = 'lib/user_home_page.dart'
home = read(home_path)
home = home.replace(
    "title: languageCode.toLowerCase().startsWith('it') ? 'Come si usa SIGILLUM' : 'How to use SIGILLUM',",
    "title: _t('quickGuideTitle'),",
)
home = home.replace(
    "subtitle: languageCode.toLowerCase().startsWith('it') ? 'Guida rapida a camera, file, verifica e sottotitoli' : 'Quick guide to camera, files, verification and captions',",
    "subtitle: _t('quickGuideSubtitle'),",
)
write(home_path, home)


# Safety: this refinement is not allowed to write any HCV/camera/pack file.
for forbidden in [
    'lib/camera_page.dart',
    'lib/hcv_engine.dart',
    'lib/hcv_crypto.dart',
    'lib/hcv_package.dart',
    'lib/hcv_verifier.dart',
    'lib/hcv_registry_service.dart',
]:
    if forbidden in ALLOWED:
        raise RuntimeError(f'Protected file unexpectedly in UI allowlist: {forbidden}')

print('Four-language Creator wording and quick guide applied; HCV/camera/Registry engine untouched')
