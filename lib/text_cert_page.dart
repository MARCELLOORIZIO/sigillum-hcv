import 'package:flutter/widgets.dart';

import 'production_text_cert_page.dart';

class TextCertPage extends ProductionTextCertPage {
  const TextCertPage({
    super.key,
    this.languageCode = 'it',
  });

  final String languageCode;
}
