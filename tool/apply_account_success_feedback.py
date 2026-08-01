from pathlib import Path


def replace_once(source: str, old: str, new: str, label: str) -> str:
    if new in source:
        return source
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected one anchor, found {count}')
    return source.replace(old, new, 1)


path = Path('lib/account_page.dart')
source = path.read_text()

source = replace_once(
    source,
    "import 'package:flutter/material.dart';",
    "import 'dart:async';\n\nimport 'package:flutter/material.dart';",
    'timer import',
)

source = replace_once(
    source,
    """  bool _busy = false;
  bool _obscurePassword = true;
  String? _error;""",
    """  bool _busy = false;
  bool _obscurePassword = true;
  String? _error;
  String? _successAction;
  Timer? _successTimer;""",
    'success state',
)

source = replace_once(
    source,
    """  @override
  void dispose() {
    _nameController.dispose();""",
    """  @override
  void dispose() {
    _successTimer?.cancel();
    _nameController.dispose();""",
    'success timer disposal',
)

source = replace_once(
    source,
    """  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on HCVAuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }""",
    """  Future<void> _run(
    String actionId,
    Future<void> Function() action,
  ) async {
    if (_busy) return;
    _successTimer?.cancel();
    setState(() {
      _busy = true;
      _error = null;
      _successAction = null;
    });
    var succeeded = false;
    try {
      await action();
      succeeded = true;
    } on HCVAuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (succeeded) _markActionSuccess(actionId);
      }
    }
  }""",
    'action-aware runner',
)

replacements = [
    (
        """  Future<void> _register() async {
    if (!_validateCredentials(requireName: true)) return;
    await _run(() async {""",
        """  Future<void> _register() async {
    if (!_validateCredentials(requireName: true)) return;
    await _run('register', () async {""",
        'register action id',
    ),
    (
        """  Future<void> _login() async {
    if (!_validateCredentials()) return;
    await _run(() async {""",
        """  Future<void> _login() async {
    if (!_validateCredentials()) return;
    await _run('login', () async {""",
        'login action id',
    ),
    (
        """  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage(_t('nameRequired'));
      return;
    }
    await _run(() async {""",
        """  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage(_t('nameRequired'));
      return;
    }
    await _run('saveProfile', () async {""",
        'profile action id',
    ),
    (
        """  Future<void> _logout({bool allDevices = false}) async {
    await _run(() async {""",
        """  Future<void> _logout({bool allDevices = false}) async {
    await _run(allDevices ? 'logoutAll' : 'logout', () async {""",
        'logout action id',
    ),
    (
        """    await _run(() async {
      await _auth.changePassword(""",
        """    await _run('changePassword', () async {
      await _auth.changePassword(""",
        'password action id',
    ),
    (
        """  Future<void> _showDevices() async {
    await _run(() async {""",
        """  Future<void> _showDevices() async {
    await _run('devices', () async {""",
        'devices action id',
    ),
    (
        """    await _run(() async {
      await _auth.deleteAccount(password: confirmedPassword);""",
        """    await _run('deleteAccount', () async {
      await _auth.deleteAccount(password: confirmedPassword);""",
        'delete action id',
    ),
]
for old, new, label in replacements:
    source = replace_once(source, old, new, label)

source = replace_once(
    source,
    """  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _short""",
    """  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _markActionSuccess(String actionId) {
    if (!mounted) return;
    _successTimer?.cancel();
    setState(() => _successAction = actionId);
    _successTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _successAction == actionId) {
        setState(() => _successAction = null);
      }
    });
  }

  bool _actionSucceeded(String actionId) => _successAction == actionId;

  IconData _actionIcon(String actionId, IconData normalIcon) =>
      _actionSucceeded(actionId) ? Icons.check_circle_rounded : normalIcon;

  ButtonStyle? _filledSuccessStyle(String actionId) {
    if (!_actionSucceeded(actionId)) return null;
    return FilledButton.styleFrom(
      backgroundColor: SigillumTheme.verified,
      foregroundColor: SigillumTheme.ink,
    );
  }

  ButtonStyle? _outlinedSuccessStyle(String actionId) {
    if (!_actionSucceeded(actionId)) return null;
    return OutlinedButton.styleFrom(
      backgroundColor: SigillumTheme.verified,
      foregroundColor: SigillumTheme.ink,
      side: const BorderSide(color: SigillumTheme.verified),
    );
  }

  ButtonStyle? _textSuccessStyle(String actionId) {
    if (!_actionSucceeded(actionId)) return null;
    return TextButton.styleFrom(
      backgroundColor: SigillumTheme.verified,
      foregroundColor: SigillumTheme.ink,
    );
  }

  Widget _successBanner(String label) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: SigillumTheme.verified,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: SigillumTheme.ink),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: SigillumTheme.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _short""",
    'success helpers',
)

source = replace_once(
    source,
    """              FilledButton.icon(
                onPressed: _busy ? null : _saveProfile,
                icon: const Icon(Icons.save_outlined),
                label: Text(_t('save')),
              ),""",
    """              FilledButton.icon(
                onPressed: _busy ? null : _saveProfile,
                style: _filledSuccessStyle('saveProfile'),
                icon: Icon(_actionIcon('saveProfile', Icons.save_outlined)),
                label: Text(_t('save')),
              ),""",
    'profile success button',
)

source = replace_once(
    source,
    """                        await _loadAccount();
                      },
                icon: const Icon(Icons.badge_outlined),
                label: Text(_t('manageIdentity')),
              ),""",
    """                        await _loadAccount();
                        _markActionSuccess('identity');
                      },
                style: _outlinedSuccessStyle('identity'),
                icon: Icon(_actionIcon('identity', Icons.badge_outlined)),
                label: Text(_t('manageIdentity')),
              ),""",
    'identity success button',
)

source = replace_once(
    source,
    """  List<Widget> _signedOutSecurityChildren() {
    return [
      _DetailRow(label: _t('session'), value: _t('notActive')),""",
    """  List<Widget> _signedOutSecurityChildren() {
    return [
      if (_successAction == 'logout' ||
          _successAction == 'logoutAll' ||
          _successAction == 'deleteAccount') ...[
        _successBanner(
          _successAction == 'deleteAccount' ? _t('deleted') : _t('loggedOut'),
        ),
        const SizedBox(height: 10),
      ],
      _DetailRow(label: _t('session'), value: _t('notActive')),""",
    'signed-out success banner',
)

source = replace_once(
    source,
    """      FilledButton.icon(
        onPressed: _busy ? null : _register,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(_t('createAccount')),
      ),""",
    """      FilledButton.icon(
        onPressed: _busy ? null : _register,
        style: _filledSuccessStyle('register'),
        icon: Icon(
          _actionIcon('register', Icons.person_add_alt_1_rounded),
        ),
        label: Text(_t('createAccount')),
      ),""",
    'register success button',
)

source = replace_once(
    source,
    """      OutlinedButton.icon(
        onPressed: _busy ? null : _login,
        icon: const Icon(Icons.login_rounded),
        label: Text(_t('login')),
      ),""",
    """      OutlinedButton.icon(
        onPressed: _busy ? null : _login,
        style: _outlinedSuccessStyle('login'),
        icon: Icon(_actionIcon('login', Icons.login_rounded)),
        label: Text(_t('login')),
      ),""",
    'login success button',
)

source = replace_once(
    source,
    """  List<Widget> _signedInSecurityChildren() {
    return [
      _DetailRow(label: _t('session'), value: _t('active')),""",
    """  List<Widget> _signedInSecurityChildren() {
    return [
      if (_successAction == 'register' || _successAction == 'login') ...[
        _successBanner(
          _successAction == 'register' ? _t('registered') : _t('loggedIn'),
        ),
        const SizedBox(height: 10),
      ],
      _DetailRow(label: _t('session'), value: _t('active')),""",
    'signed-in success banner',
)

source = replace_once(
    source,
    """      OutlinedButton.icon(
        onPressed: _busy ? null : _showDevices,
        icon: const Icon(Icons.devices_rounded),
        label: Text(_t('devices')),
      ),""",
    """      OutlinedButton.icon(
        onPressed: _busy ? null : _showDevices,
        style: _outlinedSuccessStyle('devices'),
        icon: Icon(_actionIcon('devices', Icons.devices_rounded)),
        label: Text(_t('devices')),
      ),""",
    'devices success button',
)

source = replace_once(
    source,
    """      OutlinedButton.icon(
        onPressed: _busy ? null : _changePassword,
        icon: const Icon(Icons.password_rounded),
        label: Text(_t('changePassword')),
      ),""",
    """      OutlinedButton.icon(
        onPressed: _busy ? null : _changePassword,
        style: _outlinedSuccessStyle('changePassword'),
        icon: Icon(_actionIcon('changePassword', Icons.password_rounded)),
        label: Text(_t('changePassword')),
      ),""",
    'password success button',
)

source = replace_once(
    source,
    """      FilledButton.icon(
        onPressed: _busy ? null : () => _logout(),
        icon: const Icon(Icons.logout_rounded),
        label: Text(_t('logout')),
      ),""",
    """      FilledButton.icon(
        onPressed: _busy ? null : () => _logout(),
        style: _filledSuccessStyle('logout'),
        icon: Icon(_actionIcon('logout', Icons.logout_rounded)),
        label: Text(_t('logout')),
      ),""",
    'logout success button',
)

source = replace_once(
    source,
    """      TextButton.icon(
        onPressed: _busy ? null : () => _logout(allDevices: true),
        icon: const Icon(Icons.phonelink_erase_rounded),
        label: Text(_t('logoutAll')),
      ),""",
    """      TextButton.icon(
        onPressed: _busy ? null : () => _logout(allDevices: true),
        style: _textSuccessStyle('logoutAll'),
        icon: Icon(_actionIcon('logoutAll', Icons.phonelink_erase_rounded)),
        label: Text(_t('logoutAll')),
      ),""",
    'logout-all success button',
)

path.write_text(source)
print('Isolated Account success feedback applied')
