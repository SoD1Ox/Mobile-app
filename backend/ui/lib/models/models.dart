/// Plain data models mirroring the backend DTOs (API contract).
library;

class AppUser {
  final int id;
  final String username;
  final String email;
  final String fullName;
  final String role; // admin | manager | worker
  final bool isActive;

  AppUser.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        username = j['username'],
        email = j['email'],
        fullName = j['full_name'],
        role = j['role'],
        isActive = j['is_active'] ?? true;

  bool get isAdmin => role == 'admin';
  bool get isManager => role == 'manager';
  bool get canManage => isAdmin || isManager;

  String get roleLabel => switch (role) {
        'admin' => 'Администратор',
        'manager' => 'Менеджер',
        _ => 'Сотрудник',
      };
}

class TaskItem {
  final int id;
  final String title;
  final String? description;
  final String status; // new | in_progress | done | archived
  final String priority; // low | medium | high | critical
  final int estimateHours;
  final int projectId;
  final int authorId;
  final List<TagItem> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  TaskItem.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        title = j['title'],
        description = j['description'],
        status = j['status'],
        priority = j['priority'],
        estimateHours = j['estimate_hours'] ?? 0,
        projectId = j['project_id'],
        authorId = j['author_id'],
        tags = ((j['tags'] as List?) ?? [])
            .map((e) => TagItem.fromJson(e))
            .toList(),
        createdAt = DateTime.parse(j['created_at']),
        updatedAt = DateTime.parse(j['updated_at']);

  static const statusLabels = {
    'new': 'Новая',
    'in_progress': 'В работе',
    'review': 'На проверке',
    'done': 'Готово',
    'canceled': 'Отменена',
  };
  static const priorityLabels = {
    'low': 'Низкий',
    'medium': 'Средний',
    'high': 'Высокий',
    'critical': 'Критический',
  };

  String get statusLabel => statusLabels[status] ?? status;
  String get priorityLabel => priorityLabels[priority] ?? priority;
}

class ProjectItem {
  final int id;
  final String name;
  final String? description;
  final double budget;
  final int clientId;

  ProjectItem.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        name = j['name'],
        description = j['description'],
        budget = double.tryParse('${j['budget']}') ?? 0,
        clientId = j['client_id'];
}

class ClientItem {
  final int id;
  final String name;
  final String? email;
  final String? phone;
  final String? address;

  ClientItem.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        name = j['name'],
        email = j['email'],
        phone = j['phone'],
        address = j['address'];
}

class ContactItem {
  final int id;
  final int clientId;
  final String fullName;
  final String? position;
  final String? email;
  final String? phone;

  ContactItem.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        clientId = j['client_id'],
        fullName = j['full_name'],
        position = j['position'],
        email = j['email'],
        phone = j['phone'];
}

class TagItem {
  final int id;
  final String name;

  TagItem.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        name = j['name'];
}

class CommentItem {
  final int id;
  final String text;
  final int taskId;
  final int authorId;
  final DateTime createdAt;

  CommentItem.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        text = j['text'],
        taskId = j['task_id'],
        authorId = j['author_id'],
        createdAt = DateTime.parse(j['created_at']);
}

/// Paginated envelope returned by list endpoints (large-data mechanism).
class DataPage<T> {
  final List<T> items;
  final int total;
  final int page;
  final int pageSize;
  final int pages;

  DataPage.fromJson(Map<String, dynamic> j, T Function(Map<String, dynamic> e) parse)
      : items = ((j['items'] as List?) ?? [])
            .map((e) => parse(Map<String, dynamic>.from(e as Map)))
            .toList(),
        total = j['total'] ?? 0,
        page = j['page'] ?? 1,
        pageSize = j['page_size'] ?? 20,
        pages = j['pages'] ?? 1;

  bool get hasMore => page < pages;
}
