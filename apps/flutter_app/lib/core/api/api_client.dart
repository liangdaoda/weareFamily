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
      throw ApiException(
          _resolveErrorMessage(response.body, 'Delete PDF failed'));
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
    required this.metrics,
  });

  final String tenantId;
  final String role;
  final String tenantMode;
  final DashboardMetrics metrics;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      tenantId: (json['tenantId'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      tenantMode: (json['tenantMode'] ?? '').toString(),
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
  });

  final int totalPolicies;
  final int activePolicies;
  final int expiringSoon;
  final double premiumTotal;

  factory DashboardMetrics.fromJson(Map<String, dynamic> json) {
    return DashboardMetrics(
      totalPolicies: (json['totalPolicies'] as num? ?? 0).toInt(),
      activePolicies: (json['activePolicies'] as num? ?? 0).toInt(),
      expiringSoon: (json['expiringSoon'] as num? ?? 0).toInt(),
      premiumTotal: (json['premiumTotal'] as num? ?? 0).toDouble(),
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
