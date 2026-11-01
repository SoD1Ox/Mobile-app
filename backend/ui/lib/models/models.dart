/// Plain data models mirroring the staffing-agency backend DTOs
/// (API contract).  ORM models live on the server; the client only ever
/// sees these Pydantic-shaped JSON payloads.
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
        'manager' => 'Рекрутер',
        _ => 'Сотрудник',
      };
}

/// Vacancy — open position of a partner company (main list entity).
class VacancyItem {
  final int id;
  final String title;
  final String? description;
  final double? salaryFrom;
  final double? salaryTo;
  final String? city;
  final bool remote;
  final int companyId;
  final List<SkillItem> skills;
  final DateTime createdAt;
  final DateTime updatedAt;

  VacancyItem.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        title = j['title'],
        description = j['description'],
        salaryFrom = _toDouble(j['salary_from']),
        salaryTo = _toDouble(j['salary_to']),
        city = j['city'],
        remote = j['remote'] ?? false,
        companyId = j['company_id'],
        skills = ((j['skills'] as List?) ?? [])
            .map((e) => SkillItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        createdAt = DateTime.parse(j['created_at']),
        updatedAt = DateTime.parse(j['updated_at']);

  String get salaryLabel {
    String fmt(double v) {
      final s = v.toStringAsFixed(0);
      final buf = StringBuffer();
      for (var i = 0; i < s.length; i++) {
        if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
        buf.write(s[i]);
      }
      return buf.toString();
    }

    if (salaryFrom == null && salaryTo == null) return 'Зарплата не указана';
    if (salaryFrom != null && salaryTo != null) {
      return '${fmt(salaryFrom!)} – ${fmt(salaryTo!)} ₽';
    }
    if (salaryFrom != null) return 'от ${fmt(salaryFrom!)} ₽';
    return 'до ${fmt(salaryTo!)} ₽';
  }
}

/// Candidate — job seeker in the agency database.
class CandidateItem {
  final int id;
  final String fullName;
  final String? email;
  final String? phone;
  final String? city;
  final String? specialization;
  final int experienceYears;
  final String? resumeUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  CandidateItem.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        fullName = j['full_name'],
        email = j['email'],
        phone = j['phone'],
        city = j['city'],
        specialization = j['specialization'],
        experienceYears = j['experience_years'] ?? 0,
        resumeUrl = j['resume_url'],
        createdAt = DateTime.parse(j['created_at']),
        updatedAt = DateTime.parse(j['updated_at']);

  String get expLabel {
    final n = experienceYears;
    if (n == 0) return 'Без опыта';
    final mod10 = n % 10;
    final mod100 = n % 100;
    final word = mod10 == 1 && mod100 != 11
        ? 'год'
        : (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14))
            ? 'года'
            : 'лет';
    return '$n $word';
  }
}

/// Company — partner employer.
class CompanyItem {
  final int id;
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  final String? industry;

  CompanyItem.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        name = j['name'],
        email = j['email'],
        phone = j['phone'],
        address = j['address'],
        industry = j['industry'];
}

/// Application — a candidate applying to a vacancy (high-volume entity)
/// moving through the hiring pipeline.
class ApplicationItem {
  final int id;
  final String status; // new|review|interview|offer|hired|rejected
  final int candidateId;
  final int vacancyId;
  final int? managerId;
  final DateTime createdAt;
  final DateTime updatedAt;

  ApplicationItem.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        status = j['status'],
        candidateId = j['candidate_id'],
        vacancyId = j['vacancy_id'],
        managerId = j['manager_id'],
        createdAt = DateTime.parse(j['created_at']),
        updatedAt = DateTime.parse(j['updated_at']);

  static const statusLabels = {
    'new': 'Новый отклик',
    'review': 'Рассмотрение',
    'interview': 'Интервью',
    'offer': 'Оффер',
    'hired': 'Трудоустроен',
    'rejected': 'Отказ',
  };

  /// Ordered pipeline used by the kanban board and the detail screen.
  static const pipelineOrder = [
    'new',
    'review',
    'interview',
    'offer',
    'hired',
  ];

  String get statusLabel => statusLabels[status] ?? status;
}

/// Skill — tag attached to vacancies (many-to-many).
class SkillItem {
  final int id;
  final String name;

  SkillItem.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        name = j['name'];
}

/// Recruiter note about a candidate.
class CommentItem {
  final int id;
  final String text;
  final int candidateId;
  final int authorId;
  final String? authorName;
  final DateTime createdAt;

  CommentItem.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        text = j['text'],
        candidateId = j['candidate_id'],
        authorId = j['author_id'],
        authorName = j['author_name'],
        createdAt = DateTime.parse(j['created_at']);
}

/// Paginated envelope returned by list endpoints (large-data mechanism).
class DataPage<T> {
  final List<T> items;
  final int total;
  final int page;
  final int pageSize;
  final int pages;

  DataPage.fromJson(
      Map<String, dynamic> j, T Function(Map<String, dynamic> e) parse)
      : items = ((j['items'] as List?) ?? [])
            .map((e) => parse(Map<String, dynamic>.from(e as Map)))
            .toList(),
        total = j['total'] ?? 0,
        page = j['page'] ?? 1,
        pageSize = j['page_size'] ?? 20,
        pages = j['pages'] ?? 1;

  bool get hasMore => page < pages;
}

double? _toDouble(dynamic v) =>
    v == null ? null : double.tryParse('$v');
