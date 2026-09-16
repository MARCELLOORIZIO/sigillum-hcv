from pathlib import Path

path = Path('.github/scripts/build113_copy_complete_patch.py')
text = path.read_text(encoding='utf-8')

# The English phrase appears in more than one copy map; update all expected hits.
text = text.replace(
    "s = replace_once(s, \"'compatible': 'No determinable'\", \"'compatible': 'Cannot be determined'\", 'English compatible grammar')",
    "s = replace_required(s, \"'compatible': 'No determinable'\", \"'compatible': 'Cannot be determined'\", 'English compatible grammar', count=2)",
)

# The original CommercialGate helper anchored additions to openResourceFailed,
# whose wording differs slightly by language. Anchor to purchaseFailed instead.
old_loop = "for old,new in cg_add.items(): s=replace_once(s,old,new,'commercial map add')"
new_loop = '''# Insert the four new CommercialGate keys using stable per-language anchors.
for anchor, addition in [
    ("      'purchaseFailed': 'Acquisto non completato.',\\n", "      'accountExists': 'Questa email è già associata a un account. Accedi oppure usa Password dimenticata.',\\n      'accountNotFoundCreate': 'Non esiste un account con questa email. Puoi crearne uno nuovo.',\\n      'kycProcessingNotice': 'La verifica è stata inviata a Stripe. Attendi l’esito prima di avviare altre procedure.',\\n      'refreshVerification': 'AGGIORNA STATO VERIFICA',\\n"),
    ("      'purchaseFailed': 'Purchase not completed.',\\n", "      'accountExists': 'This email is already linked to an account. Sign in or use Forgot password.',\\n      'accountNotFoundCreate': 'No account exists with this email. You can create a new one.',\\n      'kycProcessingNotice': 'The verification was submitted to Stripe. Wait for the result before starting another procedure.',\\n      'refreshVerification': 'REFRESH VERIFICATION STATUS',\\n"),
    ("      'purchaseFailed': 'Compra no completada.',\\n", "      'accountExists': 'Este correo ya está asociado a una cuenta. Inicia sesión o usa ¿Olvidaste la contraseña?.',\\n      'accountNotFoundCreate': 'No existe una cuenta con este correo. Puedes crear una nueva.',\\n      'kycProcessingNotice': 'La verificación se envió a Stripe. Espera el resultado antes de iniciar otro procedimiento.',\\n      'refreshVerification': 'ACTUALIZAR ESTADO DE VERIFICACIÓN',\\n"),
    ("      'purchaseFailed': 'Покупка не завершена.',\\n", "      'accountExists': 'Этот email уже связан с аккаунтом. Войдите или используйте восстановление пароля.',\\n      'accountNotFoundCreate': 'Аккаунта с этим email нет. Можно создать новый.',\\n      'kycProcessingNotice': 'Проверка отправлена в Stripe. Дождитесь результата перед запуском новой процедуры.',\\n      'refreshVerification': 'ОБНОВИТЬ СТАТУС ПРОВЕРКИ',\\n"),
]:
    if anchor not in s:
        raise RuntimeError(f'commercial purchase anchor missing: {anchor!r}')
    s = s.replace(anchor, addition + anchor, 1)'''
if old_loop not in text:
    raise RuntimeError('commercial loop rewrite anchor missing')
text = text.replace(old_loop, new_loop, 1)

path.write_text(text, encoding='utf-8')
print('BUILD113 copy materializer prepared')
