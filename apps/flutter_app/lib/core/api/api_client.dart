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

  void dispose() {
    _client.close();
  }

  void setAccessToken(String? token) {
    _accessToken = token;
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
      headers: _headersFor(profile),
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
      headers: _headersFor(profile),
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

  Future<List<Family>> fetchFamilies(UserProfile profile) async {
    final response = await _client.get(
      _buildUri('/api/v1/families'),
      headers: _headersFor(profile),
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

  Future<List<FamilyMember>> fetchFamilyMembers(UserProfile profile, String familyId) async {
    final response = await _client.get(
      _buildUri('/api/v1/families/$familyId/members'),
      headers: _headersFor(profile),
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

    return FamilyMember.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<FamilyDocument>> fetchFamilyDocuments(UserProfile profile, String familyId) async {
    final response = await _client.get(
      _buildUri('/api/v1/families/$familyId/documents'),
      headers: _headersFor(profile),
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
    final documentJson = (payload['document'] as Map<String, dynamic>?) ?? payload;
    final policyJson = (payload['policy'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    return UploadFamilyPdfResult(
      document: FamilyDocument.fromJson(documentJson),
      policy: Policy.fromJson(policyJson),
      scanSource: (payload['scan'] as Map<String, dynamic>?)?['source']?.toString(),
    );
  }

  Uri _buildUri(String path) {
    final base = _baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
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
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>? ?? const <String, dynamic>{}),
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
  });

  final String id;
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

  factory Policy.fromJson(Map<String, dynamic> json) {
    return Policy(
      id: (json['id'] ?? '').toString(),
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
