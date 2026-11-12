import 'package:flutter/widgets.dart';

import '../../../core/l10n/app_lang.dart';
import '../application/auth_errors.dart';

/// Human-readable sign-in error in the current language.
String authErrorText(BuildContext context, Object error) =>
    switch (authErrorKind(error)) {
      AuthErrorKind.invalidCredentials => context.tr(
        uz: 'Email yoki parol noto‘g‘ri.',
        ru: 'Неверный email или пароль.',
        en: 'Wrong email or password.',
      ),
      AuthErrorKind.emailNotConfirmed => context.tr(
        uz: 'Email hali tasdiqlanmagan. Pochtangizdagi havolani bosing.',
        ru: 'Email ещё не подтверждён. Перейдите по ссылке из письма.',
        en: 'Email is not confirmed yet. Open the link we sent you.',
      ),
      AuthErrorKind.userExists => context.tr(
        uz: 'Bu email bilan hisob allaqachon bor. «Kirish»ni tanlang.',
        ru: 'Аккаунт с этим email уже есть. Выберите «Вход».',
        en: 'An account with this email already exists. Choose “Sign in”.',
      ),
      AuthErrorKind.weakPassword => context.tr(
        uz: 'Parol juda oddiy. Kamida 6 ta belgi, harf va raqam ishlating.',
        ru: 'Слишком простой пароль. Минимум 6 символов, буквы и цифры.',
        en: 'Password is too weak. Use 6+ characters with letters and digits.',
      ),
      AuthErrorKind.invalidEmail => context.tr(
        uz: 'Email manzili noto‘g‘ri.',
        ru: 'Некорректный email.',
        en: 'Invalid email address.',
      ),
      AuthErrorKind.rateLimited => context.tr(
        uz: 'Juda ko‘p urinish. Birozdan so‘ng qayta urinib ko‘ring.',
        ru: 'Слишком много попыток. Попробуйте чуть позже.',
        en: 'Too many attempts. Please try again a bit later.',
      ),
      AuthErrorKind.anonymousDisabled => context.tr(
        uz: 'Bu kirish usuli hozircha o‘chirilgan. Email orqali kiring.',
        ru: 'Этот способ входа сейчас отключён. Войдите по email.',
        en: 'This sign-in option is disabled for now. Use email.',
      ),
      AuthErrorKind.signupDisabled => context.tr(
        uz: 'Ro‘yxatdan o‘tish vaqtincha yopiq.',
        ru: 'Регистрация временно закрыта.',
        en: 'Sign-up is temporarily closed.',
      ),
      AuthErrorKind.network => context.tr(
        uz: 'Internet aloqasi yo‘q. Tarmoqni tekshirib, qayta urinib ko‘ring.',
        ru: 'Нет связи с интернетом. Проверьте сеть и попробуйте снова.',
        en: 'No internet connection. Check your network and try again.',
      ),
      AuthErrorKind.unknown => context.tr(
        uz: 'Kirishda xatolik yuz berdi. Qayta urinib ko‘ring.',
        ru: 'Не удалось войти. Попробуйте ещё раз.',
        en: 'Could not sign in. Please try again.',
      ),
    };
