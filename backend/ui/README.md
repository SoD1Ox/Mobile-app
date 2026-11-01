# Кадровое агентство — Flutter UI

Flutter-клиент (web/Android) для FastAPI «Кадрового агентства».

## Структура
```
lib/
  main.dart                 // точка входа + MaterialApp (GlassRoot-фон)
  app_state.dart            // сессия, роль, showError()
  api/api_client.dart       // HTTP + JWT access/refresh
  models/models.dart        // Pydantic-схемы -> Dart-классы
  theme/glass.dart          // дизайн-система: мятно-коралловое стекло
  theme/glass_stack.dart    // aurora-фон + реальный blur (BackdropFilter)
  widgets/common.dart       // общие виджеты (поля, чипы статусов, карточки)
  widgets/glass_icons.dart  // собственные векторные иконки (CustomPaint)
  screens/                  // все экраны приложения
```

## Экраны
- Вход / регистрация (`auth_screen`)
- Главная: приветствие, данные пользователя, статистика, навигация (`home_screen`)
- Вакансии: список+поиск+фильтры, детали, форма создания/редактирования
- Кандидаты: список+поиск+фильтры, детали (+заметки), форма
- Воронка найма: Kanban-drag&drop по этапам new→review→interview→offer→hired/rejected
- Компании: список, детали, CRUD контактных лиц
- Пользователи (роль admin)

## Запуск
```bash
flutter pub get
flutter run -d edge            # или chrome / android
```
Адрес API: `--dart-define=API_BASE_URL=http://192.168.0.91:8000/api/v1`

## Сборка APK
```bash
flutter build apk --release --dart-define=API_BASE_URL=http://<IP-ПК>:8000/api/v1
```

## Зависимости
sdk, http, shared_preferences — всё, остальное рисуются вручную (без Material Icons).
