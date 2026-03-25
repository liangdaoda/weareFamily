// Minimal API client for auth, dashboard, policy, and family endpoints.
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'user_profile.dart';

class ApiClient {
  ApiClient({
    required String baseUrl,
    http.Client? httpClient,
  })  : _baseUrl = baseUrl,
        _client = httpClient ?? http.Client();

  final String _baseUrl;
  final http.Client _client;
  String? _accessToken;
  String _languageCode = 'zh';

  void dispose() {
    _client.close();
  }

  void setAccessToken(String? token) {
    _accessToken = token;
  }

  void setLanguage(String languageCode) {
    _languageCode = languageCode.toLowerCase().startsWith('en') ? 'en' : 'zh';
  }

  Future<AuthSession> login({
    required String email,
    required String password,
    required String tenantId,
  }) async {
    final response = await _client.post(
      _buildUri('/api/v1/auth/login'),
      headers: _baseHeaders(),
      body: jsonEncode({
        'email': email,
        'password': password,
        'tenantId': tenantId,
      }),
    );

    if (response.statusCode != 200) {
      throw ApiException(_resolveErrorMessage(response.body, '登录失败'));
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return AuthSession.fromJson(payload);
  }

  Future<AuthSession> register({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    required String tenantId,
  }) async {
    final response = await _client.post(
      _buildUri('/api/v1/auth/register'),
      headers: _baseHeaders(),
      body: jsonEncode({
        'email': email,
        'password': password,
        'name': name,
        'role': role.name,
        'tenantId': tenantId,
      }),
    );

    if (response.statusCode != 201) {
      throw ApiException(_resolveErrorMessage(response.body, '注册失败'));
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return AuthSession.fromJson(payload);
  }

  Future<AuthSession> ssoLogin({
    required String provider,
    required String subject,
    required String email,
    required String name,
    required UserRole role,
    required String tenantId,
  }) async {
    final response = await _client.post(
      _buildUri('/api/v1/auth/sso/callback'),
      headers: _baseHeaders(),
      body: jsonEncode({
        'provider': provider,
        'subject': subject,
        'email': email,
        'name': name,
        'role': role.name,
        'tenantId': tenantId,
      }),
    );

    if (response.statusCode != 200) {
      throw ApiException(_resolveErrorMessage(response.body, 'SSO登录失败'));
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return AuthSession.fromJson(payload);
  }

  Future<DashboardSummary> fetchDashboardSummary(UserProfile profile) async {
    final response = await _client.get(
      _buildUri('/api/v1/dashboard/summary'),
      headers: _authHeadersFor(profile),
    );

    if (response.statusCode != 200) {
      throw ApiException('看板数据加载失败');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return DashboardSummary.fromJson(payload);
  }

  Future<IncomeBenchmark> fetchCurrentIncomeBenchmark(UserProfile profile) async {
    final response = await _client.get(
      _buildUri('/api/v1/benchmarks/income/current'),
      headers: _authHeadersFor(profile),
    );

    if (response.statusCode != 200) {
      throw ApiException(_resolveErrorMessage(response.body, '鏀跺叆鍩哄噯鍔犺浇澶辫触'));
    }

    return IncomeBenchmark.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<Policy>> fetchPolicies(UserProfile profile) async {
    final response = await _client.get(
      _buildUri('/api/v1/policies'),
      headers: _authHeadersFor(profile),
    );

    if (response.statusCode != 200) {
      throw ApiException('保单列表加载失败');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return (payload['items'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(Policy.fromJson)
        .toList();
  }

  Future<Policy> createPolicy({
    required UserProfile profile,
    required String familyId,
    required String policyNo,
    required String insurerName,
    required String productName,
    required double premium,
    String currency = 'CNY',
    String status = 'active',
    required String startDate,
    String? endDate,
    String? notes,
  }) async {
    final response = await _client.post(
      _buildUri('/api/v1/policies'),
      headers: _headersFor(profile),
      body: jsonEncode({
        'familyId': familyId,
        'policyNo': policyNo,
        'insurerName': insurerName,
        'productName': productName,
        'premium': premium,
        'currency': currency,
        'status': status,
        'startDate': startDate,
        'endDate': endDate,
        'aiNotes': notes,
      }),
    );

    if (response.statusCode != 201) {
      throw ApiException(_resolveErrorMessage(response.body, '保单创建失败'));
    }

    return Policy.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<PolicyValueAnalysis> fetchPolicyValueAnalysis({
    required UserProfile profile,
    required String policyId,
  }) async {
    final response = await _client.get(
      _buildUri('/api/v1/policies/$policyId/value-analysis'),
      headers: _authHeadersFor(profile),
    );

    if (response.statusCode != 200) {
      throw ApiException(_resolveErrorMessage(response.body, 'Value analysis load failed'));
    }

    return PolicyValueAnalysis.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<PolicyValueAnalysis> refreshPolicyValueAnalysis({
    required UserProfile profile,
    required String policyId,
  }) async {
    final response = await _client.post(
      _buildUri('/api/v1/policies/$policyId/value-analysis/refresh'),
      headers: _headersFor(profile),
      body: jsonEncode(const <String, dynamic>{}),
    );

    if (response.statusCode != 200) {
      throw ApiException(_resolveErrorMessage(response.body, 'Value analysis refresh failed'));
    }

    return PolicyValueAnalysis.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<Policy> updatePolicyLifecycle({
    required UserProfile profile,
    required String policyId,
    required String renewalStatus,
    String? assigneeUserId,
    String? lifecycleNote,
  }) async {
    final response = await _client.patch(
      _buildUri('/api/v1/policies/$policyId/lifecycle'),
      headers: _headersFor(profile),
      body: jsonEncode({
        'renewalStatus': renewalStatus,
        'assigneeUserId': assigneeUserId,
        'lifecycleNote': lifecycleNote,
      }),
    );

    if (response.statusCode != 200) {
      throw ApiException(_resolveErrorMessage(response.body, '淇濆崟鐢熷懡鍛ㄦ湡鏇存柊澶辫触'));
    }

    return Policy.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  // Delete a policy by id.
  Future<void> deletePolicy({
    required UserProfile profile,
    required String policyId,
  }) async {
    final response = await _client.delete(
      _buildUri('/api/v1/policies/$policyId'),
      headers: _authHeadersFor(profile),
    );

    if (response.statusCode != 204) {
      throw ApiException(_resolveErrorMessage(response.body, '删除保单失败'));
    }
  }

  Future<List<Family>> fetchFamilies(UserProfile profile) async {
    final response = await _client.get(
      _buildUri('/api/v1/families'),
      headers: _authHeadersFor(profile),
    );

    if (response.statusCode != 200) {
      throw ApiException('家庭列表加载失败');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return (payload['items'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(Family.fromJson)
        .toList();
  }

  Future<BrokerFamiliesOverview> fetchBrokerFamilies(
    UserProfile profile, {
    String sortBy = 'risk',
    String order = 'desc',
    String? risk,
  }) async {
    final query = <String, String>{
      'sortBy': sortBy,
      'order': order,
      if (risk != null && risk.isNotEmpty) 'risk': risk,
    };
    final response = await _client.get(
      _buildUri('/api/v1/broker/families').replace(queryParameters: query),
      headers: _authHeadersFor(profile),
    );

    if (response.statusCode != 200) {
      throw ApiException(_resolveErrorMessage(response.body, 'B绔搴繍钀ュ彴鍔犺浇澶辫触'));
    }

    return BrokerFamiliesOverview.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<OpsTask>> fetchOpsTasks(
    UserProfile profile, {
    String? status,
    String? taskType,
    String? familyId,
  }) async {
    final query = <String, String>{
      if (status != null && status.isNotEmpty) 'status': status,
      if (taskType != null && taskType.isNotEmpty) 'taskType': taskType,
      if (familyId != null && familyId.isNotEmpty) 'familyId': familyId,
    };
    final response = await _client.get(
      _buildUri('/api/v1/tasks').replace(queryParameters: query),
      headers: _authHeadersFor(profile),
    );

    if (response.statusCode != 200) {
      throw ApiException(_resolveErrorMessage(response.body, '浠诲姟鍒楄〃鍔犺浇澶辫触'));
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return (payload['items'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(OpsTask.fromJson)
        .toList();
  }

  Future<OpsTask> updateOpsTaskStatus({
    required UserProfile profile,
    required String taskId,
    required String status,
    String? assignedUserId,
    String? description,
  }) async {
    final response = await _client.patch(
      _buildUri('/api/v1/tasks/$taskId'),
      headers: _headersFor(profile),
      body: jsonEncode({
        'status': status,
        'assignedUserId': assignedUserId,
        'description': description,
      }),
    );

    if (response.statusCode != 200) {
      throw ApiException(_resolveErrorMessage(response.body, 'Task status update failed'));
    }

    return OpsTask.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<FamilyMember>> fetchFamilyMembers(
      UserProfile profile, String familyId) async {
    final response = await _client.get(
      _buildUri('/api/v1/families/$familyId/members'),
      headers: _authHeadersFor(profile),
    );

    if (response.statusCode != 200) {
      throw ApiException('家庭成员加载失败');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return (payload['items'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(FamilyMember.fromJson)
        .toList();
  }

  Future<FamilyMember> createFamilyMember({
    required UserProfile profile,
    required String familyId,
    required String name,
    required String relation,
    String? gender,
    String? birthDate,
    String? phone,
  }) async {
    final response = await _client.post(
      _buildUri('/api/v1/families/$familyId/members'),
      headers: _headersFor(profile),
      body: jsonEncode({
        'name': name,
        'relation': relation,
        'gender': gender,
        'birthDate': birthDate,
        'phone': phone,
      }),
    );

    if (response.statusCode != 201) {
      throw ApiException('创建家庭成员失败');
    }

    return FamilyMember.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<FamilyMember> updateFamilyMember({
    required UserProfile profile,
    required String familyId,
    required String memberId,
    required String name,
    required String relation,
    String? gender,
    String? birthDate,
    String? phone,
  }) async {
    final response = await _client.patch(
      _buildUri('/api/v1/families/$familyId/members/$memberId'),
      headers: _headersFor(profile),
      body: jsonEncode({
        'name': name,
        'relation': relation,
        'gender': gender,
        'birthDate': birthDate,
        'phone': phone,
      }),
    );

    if (response.statusCode != 200) {
      throw ApiException(_resolveErrorMessage(response.body, '更新家庭成员失败'));
    }

    return FamilyMember.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  // Delete one family member.
  Future<void> deleteFamilyMember({
    required UserProfile profile,
    required String familyId,
    required String memberId,
  }) async {
    final response = await _client.delete(
      _buildUri('/api/v1/families/$familyId/members/$memberId'),
      headers: _authHeadersFor(profile),
    );

    if (response.statusCode != 204) {
      throw ApiException(_resolveErrorMessage(response.body, '删除家庭成员失败'));
    }
  }

  Future<List<FamilyDocument>> fetchFamilyDocuments(
      UserProfile profile, String familyId) async {
    final response = await _client.get(
      _buildUri('/api/v1/families/$familyId/documents'),
      headers: _authHeadersFor(profile),
    );

    if (response.statusCode != 200) {
      throw ApiException('保单文档加载失败');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return (payload['items'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(FamilyDocument.fromJson)
        .toList();
  }

  Future<FamilyInsight> fetchFamilyInsight(
      UserProfile profile, String familyId) async {
    final response = await _client.get(
      _buildUri('/api/v1/families/$familyId/insights'),
      headers: _authHeadersFor(profile),
    );

    if (response.statusCode != 200) {
      throw ApiException('家庭AI分析加载失败');
    }

    return FamilyInsight.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<UploadFamilyPdfResult> uploadFamilyPdf({
    required UserProfile profile,
    required String familyId,
    required UploadFilePayload file,
    String? policyId,
    String docType = 'policy-form',
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _buildUri('/api/v1/families/$familyId/documents'),
    );
    request.headers.addAll(_authHeadersFor(profile));
    request.fields['docType'] = docType;
    if (policyId != null && policyId.isNotEmpty) {
      request.fields['policyId'] = policyId;
    }
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        file.bytes,
        filename: file.fileName,
      ),
    );

    final streamed = await _client.send(request);
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode != 201) {
      throw ApiException(_resolveErrorMessage(body, 'PDF导入失败'));
    }

    final payload = jsonDecode(body) as Map<String, dynamic>;
    final documentJson =
        (payload['document'] as Map<String, dynamic>?) ?? payload;
    final policyJson = (payload['policy'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};

    return UploadFamilyPdfResult(
      document: FamilyDocument.fromJson(documentJson),
      policy: Policy.fromJson(policyJson),
      scanSource:
          (payload['scan'] as Map<String, dynamic>?)?['source']?.toString(),
    );
  }

  Future<DeleteFamilyDocumentResult> deleteFamilyDocument({
    required UserProfile profile,
    required String familyId,
    required String documentId,
  }) async {
    final response = await _client.delete(
      _buildUri('/api/v1/families/$familyId/documents/$documentId'),
      headers: _authHeadersFor(profile),
    );

    if (response.statusCode != 200) {
      throw ApiException(_resolveErrorMessage(response.body, '删除PDF失败'));
    }

    return DeleteFamilyDocumentResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Uri _buildUri(String path) {
    final base = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    return Uri.parse('$base$path');
  }

  Map<String, String> _baseHeaders() {
    return {
      'content-type': 'application/json',
    };
  }

  Map<String, String> _headersFor(UserProfile profile) {
    return {
      ..._authHeadersFor(profile),
      'content-type': 'application/json',
    };
  }

  Map<String, String> _authHeadersFor(UserProfile profile) {
    return {
      if (_accessToken != null) 'authorization': 'Bearer $_accessToken',
      'x-user-id': profile.userId,
      'x-user-role': profile.role.headerValue,
      'x-tenant-id': profile.tenantId,
      'x-lang': _languageCode,
    };
  }

  // Extract API error payloads with a safe fallback.
  String _resolveErrorMessage(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded['message'] is String) {
        final message = (decoded['message'] as String).trim();
        if (message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {}
    return fallback;
  }
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AuthSession {
  AuthSession({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
  });

  final String accessToken;
  final String tokenType;
  final String expiresIn;
  final AuthUser user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: (json['accessToken'] ?? '').toString(),
      tokenType: (json['tokenType'] ?? '').toString(),
      expiresIn: (json['expiresIn'] ?? '').toString(),
      user: AuthUser.fromJson(
          json['user'] as Map<String, dynamic>? ?? const <String, dynamic>{}),
    );
  }
}

class DashboardSummary {
  DashboardSummary({
    required this.tenantId,
    required this.role,
    required this.tenantMode,
    required this.benchmark,
    required this.metrics,
  });

  final String tenantId;
  final String role;
  final String tenantMode;
  final IncomeBenchmark benchmark;
  final DashboardMetrics metrics;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      tenantId: (json['tenantId'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      tenantMode: (json['tenantMode'] ?? '').toString(),
      benchmark: IncomeBenchmark.fromJson(
        (json['benchmark'] as Map<String, dynamic>?) ??
            const <String, dynamic>{},
      ),
      metrics: DashboardMetrics.fromJson(
        (json['metrics'] as Map<String, dynamic>? ?? const <String, dynamic>{}),
      ),
    );
  }
}

class DashboardMetrics {
  DashboardMetrics({
    required this.totalPolicies,
    required this.activePolicies,
    required this.expiringSoon,
    required this.premiumTotal,
    required this.monthlyPremium,
    required this.premiumIncomeRatio,
  });

  final int totalPolicies;
  final int activePolicies;
  final int expiringSoon;
  final double premiumTotal;
  final double monthlyPremium;
  final double premiumIncomeRatio;

  factory DashboardMetrics.fromJson(Map<String, dynamic> json) {
    return DashboardMetrics(
      totalPolicies: (json['totalPolicies'] as num? ?? 0).toInt(),
      activePolicies: (json['activePolicies'] as num? ?? 0).toInt(),
      expiringSoon: (json['expiringSoon'] as num? ?? 0).toInt(),
      premiumTotal: (json['premiumTotal'] as num? ?? 0).toDouble(),
      monthlyPremium: (json['monthlyPremium'] as num? ?? 0).toDouble(),
      premiumIncomeRatio: (json['premiumIncomeRatio'] as num? ?? 0).toDouble(),
    );
  }
}

class IncomeBenchmark {
  IncomeBenchmark({
    required this.source,
    required this.region,
    required this.currency,
    required this.period,
    required this.annualIncome,
    required this.monthlyIncome,
    required this.fetchedAt,
    required this.stale,
  });

  final String source;
  final String region;
  final String currency;
  final String period;
  final double annualIncome;
  final double monthlyIncome;
  final String fetchedAt;
  final bool stale;

  factory IncomeBenchmark.fromJson(Map<String, dynamic> json) {
    return IncomeBenchmark(
      source: (json['source'] ?? '').toString(),
      region: (json['region'] ?? '').toString(),
      currency: (json['currency'] ?? '').toString(),
      period: (json['period'] ?? 'annual').toString(),
      annualIncome: (json['annualIncome'] as num? ?? 0).toDouble(),
      monthlyIncome: (json['monthlyIncome'] as num? ?? 0).toDouble(),
      fetchedAt: (json['fetchedAt'] ?? '').toString(),
      stale: json['stale'] == true,
    );
  }
}

class BrokerFamiliesOverview {
  BrokerFamiliesOverview({
    required this.total,
    required this.benchmark,
    required this.items,
  });

  final int total;
  final IncomeBenchmark benchmark;
  final List<BrokerFamilyItem> items;

  factory BrokerFamiliesOverview.fromJson(Map<String, dynamic> json) {
    return BrokerFamiliesOverview(
      total: (json['total'] as num? ?? 0).toInt(),
      benchmark: IncomeBenchmark.fromJson(
        (json['benchmark'] as Map<String, dynamic>?) ??
            const <String, dynamic>{},
      ),
      items: (json['items'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(BrokerFamilyItem.fromJson)
          .toList(),
    );
  }
}

class BrokerFamilyItem {
  BrokerFamilyItem({
    required this.familyId,
    required this.familyName,
    required this.ownerUserId,
    required this.totalPolicies,
    required this.activePolicies,
    required this.expiringSoonCount,
    required this.renewalDueDays,
    required this.premiumAnnualTotal,
    required this.premiumMonthlyAvg,
    required this.premiumIncomeRatio,
    required this.valueScore,
    required this.risk,
    required this.riskScore,
    required this.riskLevel,
  });

  final String familyId;
  final String familyName;
  final String ownerUserId;
  final int totalPolicies;
  final int activePolicies;
  final int expiringSoonCount;
  final int? renewalDueDays;
  final double premiumAnnualTotal;
  final double premiumMonthlyAvg;
  final double premiumIncomeRatio;
  final double? valueScore;
  final double risk;
  final double riskScore;
  final String riskLevel;

  factory BrokerFamilyItem.fromJson(Map<String, dynamic> json) {
    return BrokerFamilyItem(
      familyId: (json['familyId'] ?? '').toString(),
      familyName: (json['familyName'] ?? '').toString(),
      ownerUserId: (json['ownerUserId'] ?? '').toString(),
      totalPolicies: (json['totalPolicies'] as num? ?? 0).toInt(),
      activePolicies: (json['activePolicies'] as num? ?? 0).toInt(),
      expiringSoonCount: (json['expiringSoonCount'] as num? ?? 0).toInt(),
      renewalDueDays: (json['renewalDueDays'] as num?)?.toInt(),
      premiumAnnualTotal: (json['premiumAnnualTotal'] as num? ?? 0).toDouble(),
      premiumMonthlyAvg: (json['premiumMonthlyAvg'] as num? ?? 0).toDouble(),
      premiumIncomeRatio:
          (json['premiumIncomeRatio'] as num? ?? 0).toDouble(),
      valueScore: (json['valueScore'] as num?)?.toDouble(),
      risk: (json['risk'] as num? ?? 0).toDouble(),
      riskScore: (json['riskScore'] as num? ?? 0).toDouble(),
      riskLevel: (json['riskLevel'] ?? '').toString(),
    );
  }
}

class Policy {
  Policy({
    required this.id,
    required this.familyId,
    required this.policyNo,
    required this.insurerName,
    required this.productName,
    required this.premium,
    required this.currency,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.aiRiskScore,
    required this.aiNotes,
    required this.aiPayload,
    required this.aiInsight,
    required this.renewalStatus,
    required this.assigneeUserId,
    required this.lifecycleNote,
    required this.lifecycleUpdatedAt,
    required this.valueScore,
    required this.valueConfidence,
    required this.valueSummary,
    required this.valueDimensions,
    required this.valueReasons,
    required this.valueRecommendations,
    required this.valueScoringVersion,
    required this.valueNeedsReview,
  });

  final String id;
  final String familyId;
  final String policyNo;
  final String insurerName;
  final String productName;
  final double premium;
  final String currency;
  final String status;
  final String startDate;
  final String? endDate;
  final double? aiRiskScore;
  final String? aiNotes;
  final PolicyAiPayload? aiPayload;
  final PolicyAiInsight? aiInsight;
  final String renewalStatus;
  final String? assigneeUserId;
  final String? lifecycleNote;
  final String? lifecycleUpdatedAt;
  final double? valueScore;
  final double? valueConfidence;
  final String? valueSummary;
  final List<PolicyValueDimension> valueDimensions;
  final List<String> valueReasons;
  final List<String> valueRecommendations;
  final String? valueScoringVersion;
  final bool valueNeedsReview;

  factory Policy.fromJson(Map<String, dynamic> json) {
    return Policy(
      id: (json['id'] ?? '').toString(),
      familyId: (json['familyId'] ?? '').toString(),
      policyNo: (json['policyNo'] ?? '').toString(),
      insurerName: (json['insurerName'] ?? '').toString(),
      productName: (json['productName'] ?? '').toString(),
      premium: (json['premium'] as num? ?? 0).toDouble(),
      currency: (json['currency'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      startDate: (json['startDate'] ?? '').toString(),
      endDate: json['endDate']?.toString(),
      aiRiskScore: (json['aiRiskScore'] as num?)?.toDouble(),
      aiNotes: json['aiNotes']?.toString(),
      aiPayload: (json['aiPayload'] as Map<String, dynamic>?) == null
          ? null
          : PolicyAiPayload.fromJson(json['aiPayload'] as Map<String, dynamic>),
      aiInsight: (json['aiInsight'] as Map<String, dynamic>?) == null
          ? null
          : PolicyAiInsight.fromJson(json['aiInsight'] as Map<String, dynamic>),
      renewalStatus: (json['renewalStatus'] ?? 'not_due').toString(),
      assigneeUserId: json['assigneeUserId']?.toString(),
      lifecycleNote: json['lifecycleNote']?.toString(),
      lifecycleUpdatedAt: json['lifecycleUpdatedAt']?.toString(),
      valueScore: (json['valueScore'] as num?)?.toDouble(),
      valueConfidence: (json['valueConfidence'] as num?)?.toDouble(),
      valueSummary: json['valueSummary']?.toString(),
      valueDimensions:
          (json['valueDimensions'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(PolicyValueDimension.fromJson)
              .toList(),
      valueReasons:
          (json['valueReasons'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => item.toString())
              .toList(),
      valueRecommendations:
          (json['valueRecommendations'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => item.toString())
              .toList(),
      valueScoringVersion: json['valueScoringVersion']?.toString(),
      valueNeedsReview: json['valueNeedsReview'] == true,
    );
  }

  Policy copyWith({
    String? id,
    String? familyId,
    String? policyNo,
    String? insurerName,
    String? productName,
    double? premium,
    String? currency,
    String? status,
    String? startDate,
    String? endDate,
    double? aiRiskScore,
    String? aiNotes,
    PolicyAiPayload? aiPayload,
    PolicyAiInsight? aiInsight,
    String? renewalStatus,
    String? assigneeUserId,
    String? lifecycleNote,
    String? lifecycleUpdatedAt,
    double? valueScore,
    double? valueConfidence,
    String? valueSummary,
    List<PolicyValueDimension>? valueDimensions,
    List<String>? valueReasons,
    List<String>? valueRecommendations,
    String? valueScoringVersion,
    bool? valueNeedsReview,
  }) {
    return Policy(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      policyNo: policyNo ?? this.policyNo,
      insurerName: insurerName ?? this.insurerName,
      productName: productName ?? this.productName,
      premium: premium ?? this.premium,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      aiRiskScore: aiRiskScore ?? this.aiRiskScore,
      aiNotes: aiNotes ?? this.aiNotes,
      aiPayload: aiPayload ?? this.aiPayload,
      aiInsight: aiInsight ?? this.aiInsight,
      renewalStatus: renewalStatus ?? this.renewalStatus,
      assigneeUserId: assigneeUserId ?? this.assigneeUserId,
      lifecycleNote: lifecycleNote ?? this.lifecycleNote,
      lifecycleUpdatedAt: lifecycleUpdatedAt ?? this.lifecycleUpdatedAt,
      valueScore: valueScore ?? this.valueScore,
      valueConfidence: valueConfidence ?? this.valueConfidence,
      valueSummary: valueSummary ?? this.valueSummary,
      valueDimensions: valueDimensions ?? this.valueDimensions,
      valueReasons: valueReasons ?? this.valueReasons,
      valueRecommendations: valueRecommendations ?? this.valueRecommendations,
      valueScoringVersion: valueScoringVersion ?? this.valueScoringVersion,
      valueNeedsReview: valueNeedsReview ?? this.valueNeedsReview,
    );
  }
}

class PolicyValueDimension {
  PolicyValueDimension({
    required this.key,
    required this.weight,
    required this.score,
    required this.reason,
  });

  final String key;
  final double weight;
  final double score;
  final String reason;

  factory PolicyValueDimension.fromJson(Map<String, dynamic> json) {
    return PolicyValueDimension(
      key: (json['key'] ?? '').toString(),
      weight: (json['weight'] as num? ?? 0).toDouble(),
      score: (json['score'] as num? ?? 0).toDouble(),
      reason: (json['reason'] ?? '').toString(),
    );
  }
}

class PolicyValueAnalysis {
  PolicyValueAnalysis({
    required this.policyId,
    required this.valueScore,
    required this.valueConfidence,
    required this.valueSummary,
    required this.valueDimensions,
    required this.valueReasons,
    required this.valueRecommendations,
    required this.scoringVersion,
    required this.updatedAt,
    required this.needsReview,
  });

  final String policyId;
  final double valueScore;
  final double valueConfidence;
  final String? valueSummary;
  final List<PolicyValueDimension> valueDimensions;
  final List<String> valueReasons;
  final List<String> valueRecommendations;
  final String scoringVersion;
  final String updatedAt;
  final bool needsReview;

  factory PolicyValueAnalysis.fromJson(Map<String, dynamic> json) {
    return PolicyValueAnalysis(
      policyId: (json['policyId'] ?? '').toString(),
      valueScore: (json['valueScore'] as num? ?? 0).toDouble(),
      valueConfidence: (json['valueConfidence'] as num? ?? 0).toDouble(),
      valueSummary: json['valueSummary']?.toString(),
      valueDimensions:
          (json['valueDimensions'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(PolicyValueDimension.fromJson)
              .toList(),
      valueReasons:
          (json['valueReasons'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => item.toString())
              .toList(),
      valueRecommendations:
          (json['valueRecommendations'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => item.toString())
              .toList(),
      scoringVersion: (json['scoringVersion'] ?? '').toString(),
      updatedAt: (json['updatedAt'] ?? '').toString(),
      needsReview: json['needsReview'] == true,
    );
  }
}

class PolicyAiPayload {
  PolicyAiPayload({
    required this.coverageItems,
    required this.insuredMemberIds,
  });

  final List<PolicyCoverageItem> coverageItems;
  final List<String> insuredMemberIds;

  factory PolicyAiPayload.fromJson(Map<String, dynamic> json) {
    final ids = <String>{};
    final rawInsuredIds = json['insuredMemberIds'];
    if (rawInsuredIds is List) {
      for (final item in rawInsuredIds) {
        final value = item?.toString() ?? '';
        if (value.isNotEmpty) {
          ids.add(value);
        }
      }
    }
    final rawMemberIds = json['memberIds'];
    if (rawMemberIds is List) {
      for (final item in rawMemberIds) {
        final value = item?.toString() ?? '';
        if (value.isNotEmpty) {
          ids.add(value);
        }
      }
    }
    final rawMemberId = json['memberId']?.toString() ?? '';
    if (rawMemberId.isNotEmpty) {
      ids.add(rawMemberId);
    }

    return PolicyAiPayload(
      coverageItems:
          (json['coverageItems'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(PolicyCoverageItem.fromJson)
              .toList(),
      insuredMemberIds: ids.toList(growable: false),
    );
  }
}

class PolicyAiInsight {
  PolicyAiInsight({
    required this.generatedAt,
    required this.locale,
    required this.policyType,
    required this.policyTypeLabel,
    required this.protectionScore,
    required this.riskScore,
    required this.riskLevel,
    required this.summary,
    required this.strengths,
    required this.weaknesses,
    required this.recommendations,
    required this.coverageItems,
    required this.competitive,
  });

  final String generatedAt;
  final String locale;
  final String policyType;
  final String policyTypeLabel;
  final int protectionScore;
  final int riskScore;
  final String riskLevel;
  final String summary;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<String> recommendations;
  final List<PolicyCoverageItem> coverageItems;
  final PolicyCompetitiveInsight competitive;

  factory PolicyAiInsight.fromJson(Map<String, dynamic> json) {
    return PolicyAiInsight(
      generatedAt: (json['generatedAt'] ?? '').toString(),
      locale: (json['locale'] ?? '').toString(),
      policyType: (json['policyType'] ?? '').toString(),
      policyTypeLabel: (json['policyTypeLabel'] ?? '').toString(),
      protectionScore: (json['protectionScore'] as num? ?? 0).toInt(),
      riskScore: (json['riskScore'] as num? ?? 0).toInt(),
      riskLevel: (json['riskLevel'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      strengths: (json['strengths'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList(),
      weaknesses: (json['weaknesses'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList(),
      recommendations:
          (json['recommendations'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => item.toString())
              .toList(),
      coverageItems:
          (json['coverageItems'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(PolicyCoverageItem.fromJson)
              .toList(),
      competitive: PolicyCompetitiveInsight.fromJson(
        (json['competitive'] as Map<String, dynamic>?) ??
            const <String, dynamic>{},
      ),
    );
  }
}

class PolicyCoverageItem {
  PolicyCoverageItem({
    required this.code,
    required this.name,
    required this.sumInsured,
    required this.description,
  });

  final String code;
  final String name;
  final double? sumInsured;
  final String? description;

  factory PolicyCoverageItem.fromJson(Map<String, dynamic> json) {
    return PolicyCoverageItem(
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      sumInsured: (json['sumInsured'] as num?)?.toDouble(),
      description: json['description']?.toString(),
    );
  }
}

class PolicyCompetitiveInsight {
  PolicyCompetitiveInsight({
    required this.title,
    required this.subtitle,
    required this.dimensions,
  });

  final String title;
  final String subtitle;
  final List<PolicyInsightDimension> dimensions;

  factory PolicyCompetitiveInsight.fromJson(Map<String, dynamic> json) {
    return PolicyCompetitiveInsight(
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      dimensions: (json['dimensions'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(PolicyInsightDimension.fromJson)
          .toList(),
    );
  }
}

class PolicyInsightDimension {
  PolicyInsightDimension({
    required this.key,
    required this.label,
    required this.current,
    required this.benchmark,
    required this.comment,
  });

  final String key;
  final String label;
  final double current;
  final double benchmark;
  final String comment;

  factory PolicyInsightDimension.fromJson(Map<String, dynamic> json) {
    return PolicyInsightDimension(
      key: (json['key'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      current: (json['current'] as num? ?? 0).toDouble(),
      benchmark: (json['benchmark'] as num? ?? 0).toDouble(),
      comment: (json['comment'] ?? '').toString(),
    );
  }
}

class UploadFilePayload {
  UploadFilePayload({
    required this.fileName,
    required this.bytes,
  });

  final String fileName;
  final Uint8List bytes;
}

class UploadFamilyPdfResult {
  UploadFamilyPdfResult({
    required this.document,
    required this.policy,
    required this.scanSource,
  });

  final FamilyDocument document;
  final Policy policy;
  final String? scanSource;
}

class DeleteFamilyDocumentResult {
  DeleteFamilyDocumentResult({
    required this.deletedDocumentId,
    required this.deletedPolicyId,
  });

  final String deletedDocumentId;
  final String? deletedPolicyId;

  bool get hasDeletedPolicy =>
      deletedPolicyId != null && deletedPolicyId!.isNotEmpty;

  factory DeleteFamilyDocumentResult.fromJson(Map<String, dynamic> json) {
    return DeleteFamilyDocumentResult(
      deletedDocumentId: (json['deletedDocumentId'] ?? '').toString(),
      deletedPolicyId: json['deletedPolicyId']?.toString(),
    );
  }
}

class OpsTask {
  OpsTask({
    required this.id,
    required this.tenantId,
    required this.familyId,
    required this.policyId,
    required this.documentId,
    required this.taskType,
    required this.status,
    required this.priority,
    required this.title,
    required this.description,
    required this.payload,
    required this.assignedUserId,
    required this.createdByUserId,
    required this.dueAt,
    required this.closedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String tenantId;
  final String familyId;
  final String? policyId;
  final String? documentId;
  final String taskType;
  final String status;
  final String priority;
  final String title;
  final String? description;
  final Map<String, dynamic>? payload;
  final String? assignedUserId;
  final String createdByUserId;
  final String? dueAt;
  final String? closedAt;
  final String createdAt;
  final String updatedAt;

  factory OpsTask.fromJson(Map<String, dynamic> json) {
    return OpsTask(
      id: (json['id'] ?? '').toString(),
      tenantId: (json['tenantId'] ?? '').toString(),
      familyId: (json['familyId'] ?? '').toString(),
      policyId: json['policyId']?.toString(),
      documentId: json['documentId']?.toString(),
      taskType: (json['taskType'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      priority: (json['priority'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: json['description']?.toString(),
      payload: (json['payload'] as Map<String, dynamic>?),
      assignedUserId: json['assignedUserId']?.toString(),
      createdByUserId: (json['createdByUserId'] ?? '').toString(),
      dueAt: json['dueAt']?.toString(),
      closedAt: json['closedAt']?.toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      updatedAt: (json['updatedAt'] ?? '').toString(),
    );
  }
}

class Family {
  Family({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.ownerUserId,
  });

  final String id;
  final String tenantId;
  final String name;
  final String ownerUserId;

  factory Family.fromJson(Map<String, dynamic> json) {
    return Family(
      id: (json['id'] ?? '').toString(),
      tenantId: (json['tenantId'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      ownerUserId: (json['ownerUserId'] ?? '').toString(),
    );
  }
}

class FamilyMember {
  FamilyMember({
    required this.id,
    required this.familyId,
    required this.tenantId,
    required this.name,
    required this.relation,
    required this.gender,
    required this.birthDate,
    required this.phone,
    required this.createdAt,
  });

  final String id;
  final String familyId;
  final String tenantId;
  final String name;
  final String relation;
  final String? gender;
  final String? birthDate;
  final String? phone;
  final String createdAt;

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      id: (json['id'] ?? '').toString(),
      familyId: (json['familyId'] ?? '').toString(),
      tenantId: (json['tenantId'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      relation: (json['relation'] ?? '').toString(),
      gender: json['gender']?.toString(),
      birthDate: json['birthDate']?.toString(),
      phone: json['phone']?.toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
    );
  }
}

class FamilyDocument {
  FamilyDocument({
    required this.id,
    required this.familyId,
    required this.tenantId,
    required this.policyId,
    required this.fileName,
    required this.storagePath,
    required this.mimeType,
    required this.fileSize,
    required this.docType,
    required this.reviewStatus,
    required this.reviewNotes,
    required this.reviewedByUserId,
    required this.reviewedAt,
    required this.uploadedByUserId,
    required this.createdAt,
  });

  final String id;
  final String familyId;
  final String tenantId;
  final String? policyId;
  final String fileName;
  final String storagePath;
  final String mimeType;
  final int fileSize;
  final String docType;
  final String reviewStatus;
  final String? reviewNotes;
  final String? reviewedByUserId;
  final String? reviewedAt;
  final String uploadedByUserId;
  final String createdAt;

  factory FamilyDocument.fromJson(Map<String, dynamic> json) {
    return FamilyDocument(
      id: (json['id'] ?? '').toString(),
      familyId: (json['familyId'] ?? '').toString(),
      tenantId: (json['tenantId'] ?? '').toString(),
      policyId: json['policyId']?.toString(),
      fileName: (json['fileName'] ?? '').toString(),
      storagePath: (json['storagePath'] ?? '').toString(),
      mimeType: (json['mimeType'] ?? '').toString(),
      fileSize: (json['fileSize'] as num? ?? 0).toInt(),
      docType: (json['docType'] ?? '').toString(),
      reviewStatus: (json['reviewStatus'] ?? 'pending').toString(),
      reviewNotes: json['reviewNotes']?.toString(),
      reviewedByUserId: json['reviewedByUserId']?.toString(),
      reviewedAt: json['reviewedAt']?.toString(),
      uploadedByUserId: (json['uploadedByUserId'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
    );
  }
}

class FamilyInsight {
  FamilyInsight({
    required this.familyId,
    required this.locale,
    required this.generatedAt,
    required this.householdScore,
    required this.riskLevel,
    required this.summary,
    required this.annualPremiumTotal,
    required this.monthlyPremiumAvg,
    required this.premiumIncomeRatio,
    required this.benchmarkIncome,
    required this.benchmarkAsOf,
    required this.policyCoverage,
    required this.gaps,
    required this.members,
    required this.priorities,
    required this.sources,
  });

  final String familyId;
  final String locale;
  final String generatedAt;
  final int householdScore;
  final String riskLevel;
  final String summary;
  final double annualPremiumTotal;
  final double monthlyPremiumAvg;
  final double premiumIncomeRatio;
  final FamilyInsightBenchmark benchmarkIncome;
  final String benchmarkAsOf;
  final FamilyPolicyCoverage policyCoverage;
  final List<FamilyPolicyGap> gaps;
  final List<FamilyMemberInsight> members;
  final List<String> priorities;
  final List<FamilyInsightSource> sources;

  factory FamilyInsight.fromJson(Map<String, dynamic> json) {
    return FamilyInsight(
      familyId: (json['familyId'] ?? '').toString(),
      locale: (json['locale'] ?? '').toString(),
      generatedAt: (json['generatedAt'] ?? '').toString(),
      householdScore: (json['householdScore'] as num? ?? 0).toInt(),
      riskLevel: (json['riskLevel'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      annualPremiumTotal: (json['annualPremiumTotal'] as num? ?? 0).toDouble(),
      monthlyPremiumAvg: (json['monthlyPremiumAvg'] as num? ?? 0).toDouble(),
      premiumIncomeRatio: (json['premiumIncomeRatio'] as num? ?? 0).toDouble(),
      benchmarkIncome: FamilyInsightBenchmark.fromJson(
        (json['benchmarkIncome'] as Map<String, dynamic>?) ??
            const <String, dynamic>{},
      ),
      benchmarkAsOf: (json['benchmarkAsOf'] ?? '').toString(),
      policyCoverage: FamilyPolicyCoverage.fromJson(
        (json['policyCoverage'] as Map<String, dynamic>?) ??
            const <String, dynamic>{},
      ),
      gaps: (json['gaps'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(FamilyPolicyGap.fromJson)
          .toList(),
      members: (json['members'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(FamilyMemberInsight.fromJson)
          .toList(),
      priorities: (json['priorities'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList(),
      sources: (json['sources'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(FamilyInsightSource.fromJson)
          .toList(),
    );
  }
}

class FamilyInsightBenchmark {
  FamilyInsightBenchmark({
    required this.annual,
    required this.monthly,
    required this.currency,
  });

  final double annual;
  final double monthly;
  final String currency;

  factory FamilyInsightBenchmark.fromJson(Map<String, dynamic> json) {
    return FamilyInsightBenchmark(
      annual: (json['annual'] as num? ?? 0).toDouble(),
      monthly: (json['monthly'] as num? ?? 0).toDouble(),
      currency: (json['currency'] ?? '').toString(),
    );
  }
}

class FamilyPolicyCoverage {
  FamilyPolicyCoverage({
    required this.medical,
    required this.accident,
    required this.critical,
    required this.life,
  });

  final bool medical;
  final bool accident;
  final bool critical;
  final bool life;

  factory FamilyPolicyCoverage.fromJson(Map<String, dynamic> json) {
    return FamilyPolicyCoverage(
      medical: json['medical'] == true,
      accident: json['accident'] == true,
      critical: json['critical'] == true,
      life: json['life'] == true,
    );
  }
}

class FamilyPolicyGap {
  FamilyPolicyGap({
    required this.title,
    required this.severity,
    required this.description,
  });

  final String title;
  final String severity;
  final String description;

  factory FamilyPolicyGap.fromJson(Map<String, dynamic> json) {
    return FamilyPolicyGap(
      title: (json['title'] ?? '').toString(),
      severity: (json['severity'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
    );
  }
}

class FamilyMemberInsight {
  FamilyMemberInsight({
    required this.memberId,
    required this.name,
    required this.relation,
    required this.age,
    required this.roleType,
    required this.score,
    required this.focusPoints,
    required this.painPoints,
    required this.recommendations,
  });

  final String memberId;
  final String name;
  final String relation;
  final int? age;
  final String roleType;
  final int score;
  final List<String> focusPoints;
  final List<String> painPoints;
  final List<FamilyMemberRecommendation> recommendations;

  factory FamilyMemberInsight.fromJson(Map<String, dynamic> json) {
    return FamilyMemberInsight(
      memberId: (json['memberId'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      relation: (json['relation'] ?? '').toString(),
      age: (json['age'] as num?)?.toInt(),
      roleType: (json['roleType'] ?? '').toString(),
      score: (json['score'] as num? ?? 0).toInt(),
      focusPoints: (json['focusPoints'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList(),
      painPoints: (json['painPoints'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList(),
      recommendations:
          (json['recommendations'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(FamilyMemberRecommendation.fromJson)
              .toList(),
    );
  }
}

class FamilyMemberRecommendation {
  FamilyMemberRecommendation({
    required this.insuranceType,
    required this.priority,
    required this.reason,
  });

  final String insuranceType;
  final String priority;
  final String reason;

  factory FamilyMemberRecommendation.fromJson(Map<String, dynamic> json) {
    return FamilyMemberRecommendation(
      insuranceType: (json['insuranceType'] ?? '').toString(),
      priority: (json['priority'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
    );
  }
}

class FamilyInsightSource {
  FamilyInsightSource({
    required this.title,
    required this.url,
    required this.note,
  });

  final String title;
  final String url;
  final String note;

  factory FamilyInsightSource.fromJson(Map<String, dynamic> json) {
    return FamilyInsightSource(
      title: (json['title'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
      note: (json['note'] ?? '').toString(),
    );
  }
}
