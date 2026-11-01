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
        title = (j['title'] ?? 'Без названия').toString(),
        description = j['description'],
        salaryFrom = _toDouble(j['salary_from']),
        salaryTo = _toDouble(j['salary_to']),
        city = j['city'],
        remote = j['remote'] ?? false,
        companyId = (j['company_id'] as num?)?.toInt() ?? 0,
        skills = ((j['skills'] as List?) ?? [])
            .map((e) => SkillItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        createdAt = _toDate(j['created_at']),
        updatedAt = _toDate(j['updated_at']);

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
      return '${fmt(salaryFrom!)} – ${fmt(salaryTo!)} ₽/мес';
    }
    if (salaryFrom != null) return 'от ${fmt(salaryFrom!)} ₽/мес';
    return 'до ${fmt(salaryTo!)} ₽/мес';
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
        createdAt = _toDate(j['created_at']),
        updatedAt = _toDate(j['updated_at']);

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
        name = (j['name'] ?? 'Компания').toString(),
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
  final int? assignedWorkerId;
  // Denormalized display fields (server resolves relations in one request).
  final String? candidateName;
  final String? vacancyTitle;
  final String? companyName;
  final double? salaryFrom;
  final double? salaryTo;
  final String? assignedWorkerName;
  // Audit trail: "new -> review (by 2 @ 2026-11-01T14:03+00:00)" lines.
  final List<String> statusHistory;
  // Funnel completion fraction 0..1 (self-learning stat).
  final double? completionScore;
  final DateTime createdAt;
  final DateTime updatedAt;

  ApplicationItem.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        status = j['status'],
        candidateId = j['candidate_id'],
        vacancyId = j['vacancy_id'],
        managerId = j['manager_id'],
        assignedWorkerId = j['assigned_worker_id'],
        candidateName = j['candidate_name'] as String?,
        vacancyTitle = j['vacancy_title'] as String?,
        companyName = j['company_name'] as String?,
        salaryFrom = (j['salary_from'] as num?)?.toDouble(),
        salaryTo = (j['salary_to'] as num?)?.toDouble(),
        assignedWorkerName = j['assigned_worker_name'] as String?,
        statusHistory =
            (j['status_history'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
        completionScore = (j['completion_score'] as num?)?.toDouble(),
        createdAt = _toDate(j['created_at']),
        updatedAt = _toDate(j['updated_at']);

  /// Human-readable pipeline timeline for the detail screen.
  static const _stageShort = {
    'new': 'Отклик',
    'review': 'Рассмотрение',
    'interview': 'Интервью',
    'offer': 'Оффер',
    'hired': 'Трудоустроен',
    'rejected': 'Отказ',
  };

  /// Parsed history entries: (fromLabel, toLabel, rawStamp) oldest first.
  List<(String, String, String)> get timeline {
    final out = <(String, String, String)>[];
    for (final line in statusHistory) {
      // format: "a -> b (by N @ ts)"
      final arrow = line.indexOf('->');
      if (arrow == -1) continue;
      final from = line.substring(0, arrow).trim();
      var rest = line.substring(arrow + 2).trim();
      final paren = rest.indexOf('(');
      final to = (paren == -1 ? rest : rest.substring(0, paren)).trim();
      final stamp = paren == -1 ? '' : rest.substring(paren + 1, rest.length - (rest.endsWith(')') ? 1 : 0));
      out.add((
        _stageShort[from] ?? from,
        _stageShort[to] ?? to,
        stamp.replaceAll(RegExp(r'\(by \d+ @ '), '').replaceAll(')', ''),
      ));
    }
    return out;
  }

  /// Salary shown on the card — always "per month".
  String get salaryLabel {
    String fmt(double v) => v >= 1000
        ? '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)} тыс'
        : v.toStringAsFixed(0);
    if (salaryFrom == null && salaryTo == null) return '';
    if (salaryFrom != null && salaryTo != null) {
      return '${fmt(salaryFrom!)}–${fmt(salaryTo!)} ₽/мес';
    }
    if (salaryFrom != null) return 'от ${fmt(salaryFrom!)} ₽/мес';
    return 'до ${fmt(salaryTo!)} ₽/мес';
  }

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
        createdAt = _toDate(j['created_at']);
}

/// Contact person of a partner company.
class ContactItem {
  final int id;
  final String fullName;
  final String? position;
  final String? phone;
  final String? email;
  final int companyId;

  ContactItem.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        fullName = j['full_name'],
        position = j['position'],
        phone = j['phone'],
        email = j['email'],
        companyId = j['company_id'];
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

/// Tolerant date parser: missing/malformed values never crash the UI.
DateTime _toDate(Object? v) {
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}
