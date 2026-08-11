from pathlib import Path
import re

home_path = Path('lib/user_home_page.dart')
home = home_path.read_text(encoding='utf-8')

if "import 'commercial_profile_page.dart';" not in home:
    old = "import 'account_page.dart';\n"
    if old not in home:
        raise RuntimeError('user home account import anchor missing')
    home = home.replace(old, "import 'commercial_profile_page.dart';\n", 1)

old_widget = """class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
"""
new_widget = """class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key, this.onSessionInvalidated});

  final VoidCallback? onSessionInvalidated;

  @override
"""
if old_widget in home:
    home = home.replace(old_widget, new_widget, 1)

account_pattern = re.compile(
    r"AccountPage\(\s*"
    r"languageCode:\s*languageCode,\s*"
    r"onLanguageChanged:\s*_setLanguage,?\s*"
    r"\)",
    re.DOTALL,
)
new_account = """CommercialProfilePage(
                      languageCode: languageCode,
                      onLanguageChanged: _setLanguage,
                      onSessionInvalidated: widget.onSessionInvalidated ?? () {},
                    )"""
home, _ = account_pattern.subn(new_account, home)

if 'AccountPage(' in home or "import 'account_page.dart';" in home:
    raise RuntimeError('technical AccountPage remains exposed from user home')
if 'CommercialProfilePage(' not in home:
    raise RuntimeError('commercial profile was not routed from user home')

home_path.write_text(home, encoding='utf-8')

gate_path = Path('lib/commercial_gate.dart')
gate = gate_path.read_text(encoding='utf-8')
old_gate = "if (_stage == _GateStage.creator) return const UserHomePage();"
new_gate = """if (_stage == _GateStage.creator) {
      return UserHomePage(
        onSessionInvalidated: () {
          if (!mounted) return;
          setState(() {
            _accountData = const {};
            _stage = _GateStage.landing;
          });
        },
      );
    }"""
if old_gate in gate:
    gate = gate.replace(old_gate, new_gate, 1)
if 'return const UserHomePage();' in gate:
    raise RuntimeError('commercial gate still lacks session invalidation callback')
gate_path.write_text(gate, encoding='utf-8')

print('Simplified commercial profile routed without capture changes')
