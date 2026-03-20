// Family center with member cards, PDF import, and household insight.
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:wearefamily_app/core/api/api_client.dart';
import 'package:wearefamily_app/core/api/user_profile.dart';
import 'package:wearefamily_app/core/i18n/locale_text.dart';
import 'package:wearefamily_app/core/theme/app_colors.dart';
import 'package:wearefamily_app/core/theme/app_spacing.dart';
import 'package:wearefamily_app/shared/widgets/glass_card.dart';

int? _ageFromBirthDate(String? birthDate) {
  final text = birthDate?.trim() ?? '';
  if (text.isEmpty) {
    return null;
  }
  final date = DateTime.tryParse(text);
  if (date == null) {
    return null;
  }

  final today = DateTime.now();
  var age = today.year - date.year;
  if (today.month < date.month ||
      (today.month == date.month && today.day < date.day)) {
    age -= 1;
  }

  if (age < 0 || age > 130) {
    return null;
  }
  return age;
}

String _formatYmd(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

class FamilyCenterScreen extends StatefulWidget {
  const FamilyCenterScreen({
    super.key,
    required this.profile,
    required this.apiClient,
  });

  final UserProfile profile;
  final ApiClient apiClient;

  @override
  State<FamilyCenterScreen> createState() => _FamilyCenterScreenState();
}

class _FamilyCenterScreenState extends State<FamilyCenterScreen> {
  bool _loadingFamilies = true;
  bool _loadingDetails = false;
  String? _error;

  List<Family> _families = const [];
  String? _selectedFamilyId;
  List<FamilyMember> _members = const [];
  List<FamilyDocument> _documents = const [];
  List<Policy> _familyPolicies = const [];
  FamilyInsight? _familyInsight;

  @override
  void initState() {
    super.initState();
    _loadFamilies();
  }

  Future<void> _loadFamilies() async {
    setState(() {
      _loadingFamilies = true;
      _error = null;
    });
    try {
      final families = await widget.apiClient.fetchFamilies(widget.profile);
      final selected = families.isEmpty
          ? null
          : (_selectedFamilyId != null &&
                  families.any((f) => f.id == _selectedFamilyId)
              ? _selectedFamilyId
              : families.first.id);
      setState(() {
        _families = families;
        _selectedFamilyId = selected;
      });
      if (selected != null) {
        await _loadFamilyDetails();
      }
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingFamilies = false);
      }
    }
  }

  Future<void> _loadFamilyDetails() async {
    final familyId = _selectedFamilyId;
    if (familyId == null) return;

    setState(() {
      _loadingDetails = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        widget.apiClient.fetchFamilyMembers(widget.profile, familyId),
        widget.apiClient.fetchFamilyDocuments(widget.profile, familyId),
        widget.apiClient.fetchFamilyInsight(widget.profile, familyId),
        widget.apiClient.fetchPolicies(widget.profile),
      ]);
      final policies = (results[3] as List<Policy>)
          .where((item) => item.familyId == familyId)
          .toList(growable: false);

      setState(() {
        _members = results[0] as List<FamilyMember>;
        _documents = results[1] as List<FamilyDocument>;
        _familyInsight = results[2] as FamilyInsight;
        _familyPolicies = policies;
      });
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loadingDetails = false);
    }
  }

  void _showTopToast(String message) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final media = MediaQuery.of(context);
    final top = media.padding.top + 12;
    final bottom = (media.size.height - top - 64)
        .clamp(16.0, media.size.height - 16.0)
        .toDouble();

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(16, top, 16, bottom),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _addOrEditMember({FamilyMember? member}) async {
    final familyId = _selectedFamilyId;
    if (familyId == null) return;

    final isEdit = member != null;
    final result = await _showMemberDialog(member: member);
    if (result == null) return;
    final birthDate = _birthDateFromAge(result.age);

    try {
      if (isEdit) {
        await widget.apiClient.updateFamilyMember(
          profile: widget.profile,
          familyId: familyId,
          memberId: member.id,
          name: result.name,
          relation: result.relation,
          gender: result.gender,
          birthDate: birthDate,
        );
      } else {
        await widget.apiClient.createFamilyMember(
          profile: widget.profile,
          familyId: familyId,
          name: result.name,
          relation: result.relation,
          gender: result.gender,
          birthDate: birthDate,
        );
      }
      await _loadFamilyDetails();
      if (mounted) {
        final message = context.tr(
          isEdit ? '成员信息已更新' : '成员已添加',
          isEdit ? 'Member updated' : 'Member added',
        );
        _showTopToast(message);
      }
    } catch (error) {
      if (mounted) {
        _showTopToast(error.toString());
      }
    }
  }

  Future<void> _deleteMember(FamilyMember member) async {
    final familyId = _selectedFamilyId;
    if (familyId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('删除家庭成员', 'Delete family member')),
        content: Text(
          context.tr(
            '确认删除该家庭成员？删除后将无法恢复。',
            'Delete this family member? This action cannot be undone.',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.tr('取消', 'Cancel'))),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.tr('删除', 'Delete'))),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.apiClient.deleteFamilyMember(
        profile: widget.profile,
        familyId: familyId,
        memberId: member.id,
      );
      await _loadFamilyDetails();
    } catch (error) {
      if (mounted) {
        _showTopToast(error.toString());
      }
    }
  }

  Future<void> _deleteDocument(FamilyDocument document) async {
    final familyId = _selectedFamilyId;
    if (familyId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('删除保单表单', 'Delete policy PDF')),
        content: Text(
          context.tr(
            '确认删除该PDF表单？若它是唯一关联来源，会同步删除关联保单。',
            'Delete this PDF form? If it is the only linked source, the linked policy will be deleted too.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('删除', 'Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final result = await widget.apiClient.deleteFamilyDocument(
        profile: widget.profile,
        familyId: familyId,
        documentId: document.id,
      );
      await _loadFamilyDetails();

      if (mounted) {
        final message = result.hasDeletedPolicy
            ? context.tr(
                'PDF已删除，关联保单已同步删除。',
                'PDF deleted. Linked policy was also removed.',
              )
            : context.tr(
                'PDF已删除。',
                'PDF deleted.',
              );
        _showTopToast(message);
      }
    } catch (error) {
      if (mounted) {
        _showTopToast(error.toString());
      }
    }
  }

  Future<_MemberFormData?> _showMemberDialog({FamilyMember? member}) async {
    return showDialog<_MemberFormData>(
      context: context,
      useRootNavigator: true,
      builder: (_) => _MemberEditorDialog(member: member),
    );
  }

  Future<void> _uploadPdf() async {
    final familyId = _selectedFamilyId;
    if (familyId == null) return;

    final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: true);
    if (picked == null ||
        picked.files.isEmpty ||
        picked.files.single.bytes == null) {
      return;
    }

    final file = picked.files.single;
    try {
      await widget.apiClient.uploadFamilyPdf(
        profile: widget.profile,
        familyId: familyId,
        file: UploadFilePayload(fileName: file.name, bytes: file.bytes!),
      );
      await _loadFamilyDetails();
    } catch (error) {
      if (mounted) {
        _showTopToast(error.toString());
      }
    }
  }

  FamilyMemberInsight? _insight(String memberId) {
    final insight = _familyInsight;
    if (insight == null) return null;
    for (final item in insight.members) {
      if (item.memberId == memberId) return item;
    }
    return null;
  }

  String? _birthDateFromAge(int? age) {
    if (age == null || age < 0 || age > 130) {
      return null;
    }
    final now = DateTime.now();
    final year = now.year - age;
    final month = now.month;
    final day = min(now.day, DateTime(year, month + 1, 0).day);
    return _formatYmd(DateTime(year, month, day));
  }

  int? _memberAge(FamilyMember member) {
    final byBirthDate = _ageFromBirthDate(member.birthDate);
    if (byBirthDate != null) {
      return byBirthDate;
    }
    final byInsight = _insight(member.id)?.age;
    if (byInsight == null || byInsight < 0 || byInsight > 130) {
      return null;
    }
    return byInsight;
  }

  List<Policy> _policiesForMember(FamilyMember member) {
    return _familyPolicies.where((policy) {
      final linkedMemberIds =
          policy.aiPayload?.insuredMemberIds ?? const <String>[];
      return linkedMemberIds.contains(member.id);
    }).toList(growable: false);
  }

  int _linkedPolicyCountForMember(FamilyMember member) {
    return _policiesForMember(member).length;
  }

  String _coverageTextForMember(FamilyMember member) {
    final policies = _policiesForMember(member);
    if (policies.isEmpty) {
      return context.tr('未绑定', 'Unlinked');
    }

    double total = 0;
    for (final policy in policies) {
      final items = policy.aiInsight?.coverageItems ??
          policy.aiPayload?.coverageItems ??
          const <PolicyCoverageItem>[];
      for (final item in items) {
        if (item.sumInsured != null && item.sumInsured! > 0) {
          total += item.sumInsured!;
        }
      }
    }

    if (total <= 0) {
      return context.tr('待补充', 'Pending');
    }

    return total >= 1000
        ? 'CNY ${(total / 1000).toStringAsFixed(0)}k'
        : 'CNY ${total.toStringAsFixed(0)}';
  }

  List<String> _tags(FamilyMember member) {
    final ai = _insight(member.id);
    final tags = <String>[];
    if (ai != null) {
      for (final rec in ai.recommendations) {
        if (rec.insuranceType.trim().isNotEmpty &&
            !tags.contains(rec.insuranceType.trim())) {
          tags.add(rec.insuranceType.trim());
        }
      }
    }
    return tags.take(6).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingFamilies) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.accent));
    }
    if (_families.isEmpty) {
      return Center(
          child: Text(context.tr('暂无家庭数据', 'No family data'),
              style: const TextStyle(color: Colors.white70)));
    }

    final selectedFamily = _families.firstWhere(
        (f) => f.id == _selectedFamilyId,
        orElse: () => _families.first);

    return RefreshIndicator(
      onRefresh: _loadFamilyDetails,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          GlassCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(context.tr('家庭中心', 'Family center'),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: Colors.white))),
                IconButton(
                    onPressed: _loadingDetails ? null : _loadFamilyDetails,
                    icon: const Icon(Icons.refresh, color: Colors.white70)),
              ]),
              DropdownButtonFormField<String>(
                initialValue: selectedFamily.id,
                decoration: InputDecoration(
                    labelText: context.tr('选择家庭', 'Select family')),
                items: _families
                    .map((f) => DropdownMenuItem<String>(
                        value: f.id, child: Text(f.name)))
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedFamilyId = value);
                  _loadFamilyDetails();
                },
              ),
              if (_error != null)
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_error!,
                        style: const TextStyle(color: AppColors.rose))),
            ]),
          ),
          const SizedBox(height: AppSpacing.lg),
          GlassCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(
                        '${context.tr('家庭成员', 'Members')} (${_members.length})',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: Colors.white))),
                FilledButton.icon(
                    onPressed:
                        _loadingDetails ? null : () => _addOrEditMember(),
                    icon: const Icon(Icons.person_add, size: 16),
                    label: Text(context.tr('新增成员', 'Add member'))),
              ]),
              const SizedBox(height: AppSpacing.md),
              if (_members.isEmpty)
                Text(context.tr('暂无成员', 'No members'),
                    style: const TextStyle(color: Colors.white70))
              else
                ..._members.map((m) {
                  final memberPolicies = _policiesForMember(m);
                  return _MemberCard(
                    member: m,
                    score: _insight(m.id)?.score,
                    memberAge: _memberAge(m),
                    linkedPolicyCount: _linkedPolicyCountForMember(m),
                    coverageText: _coverageTextForMember(m),
                    tags: _tags(m),
                    hasLinkedPolicies: memberPolicies.isNotEmpty,
                    onEdit: _loadingDetails
                        ? null
                        : () => _addOrEditMember(member: m),
                    onDelete: _loadingDetails ? null : () => _deleteMember(m),
                  );
                }),
            ]),
          ),
          const SizedBox(height: AppSpacing.lg),
          GlassCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(
                        '${context.tr('保单PDF', 'Policy PDFs')} (${_documents.length})',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: Colors.white))),
                FilledButton.icon(
                    onPressed: _loadingDetails ? null : _uploadPdf,
                    icon: const Icon(Icons.upload_file, size: 16),
                    label: Text(context.tr('导入PDF', 'Import PDF'))),
              ]),
              const SizedBox(height: AppSpacing.md),
              if (_documents.isEmpty)
                Text(context.tr('暂无保单PDF', 'No policy PDFs'),
                    style: const TextStyle(color: Colors.white70))
              else
                ..._documents.map((d) {
                  final kb = max(1, d.fileSize ~/ 1024);
                  final hasLinkedPolicy =
                      d.policyId != null && d.policyId!.isNotEmpty;
                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d.fileName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$kb KB · ${context.tr(hasLinkedPolicy ? '已关联保单' : '未关联保单', hasLinkedPolicy ? 'Linked policy' : 'No linked policy')}',
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _ActionIconButton(
                          icon: Icons.delete_outline,
                          onPressed:
                              _loadingDetails ? null : () => _deleteDocument(d),
                          tooltip: context.tr('删除表单', 'Delete PDF'),
                          color: AppColors.rose,
                        ),
                      ],
                    ),
                  );
                }),
            ]),
          ),
        ],
      ),
    );
  }
}

class _MemberFormData {
  const _MemberFormData({
    required this.name,
    required this.relation,
    required this.gender,
    required this.age,
  });

  final String name;
  final String relation;
  final String? gender;
  final int age;
}

class _MemberEditorDialog extends StatefulWidget {
  const _MemberEditorDialog({required this.member});

  final FamilyMember? member;

  @override
  State<_MemberEditorDialog> createState() => _MemberEditorDialogState();
}

class _MemberEditorDialogState extends State<_MemberEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _relationController;
  late final TextEditingController _ageController;
  String? _gender;

  static const List<String> _defaultGenderValues = <String>[
    'male',
    'female',
    'other',
    'unknown',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.member?.name ?? '');
    _relationController = TextEditingController(
      text: widget.member?.relation ?? 'self',
    );
    _ageController = TextEditingController(
      text: (_ageFromBirthDate(widget.member?.birthDate))?.toString() ?? '',
    );
    _gender = widget.member?.gender;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _relationController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  String _genderLabel(BuildContext context, String value) {
    switch (value) {
      case 'male':
        return context.tr('男', 'Male');
      case 'female':
        return context.tr('女', 'Female');
      case 'other':
        return context.tr('其他', 'Other');
      case 'unknown':
        return context.tr('未知', 'Unknown');
      default:
        return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.member;
    final genderValues = <String>[
      ..._defaultGenderValues,
      if (_gender != null &&
          _gender!.trim().isNotEmpty &&
          !_defaultGenderValues.contains(_gender))
        _gender!,
    ];

    return AlertDialog(
      title: Text(
        context.tr(
          member == null ? '添加家庭成员' : '编辑家庭成员',
          member == null ? 'Add family member' : 'Edit family member',
        ),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: context.tr('姓名', 'Name')),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) {
                  return context.tr('姓名不能为空', 'Name is required');
                }
                if (text.length < 2 || text.length > 20) {
                  return context.tr(
                    '姓名长度需要 2-20 个字符',
                    'Name length must be 2-20 chars',
                  );
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _relationController,
              decoration:
                  InputDecoration(labelText: context.tr('关系', 'Relation')),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? context.tr('关系不能为空', 'Relation is required')
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: context.tr('年龄', 'Age')),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) {
                  return context.tr('请输入年龄', 'Age is required');
                }
                final age = int.tryParse(text);
                if (age == null) {
                  return context.tr('年龄必须是数字', 'Age must be numeric');
                }
                if (age < 0 || age > 120) {
                  return context.tr(
                    '年龄需在 0-120 之间',
                    'Age must be between 0 and 120',
                  );
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _gender,
              decoration:
                  InputDecoration(labelText: context.tr('性别', 'Gender')),
              items: genderValues
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item,
                      child: Text(_genderLabel(context, item)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                setState(() {
                  _gender = value;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child: Text(context.tr('取消', 'Cancel')),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) {
              return;
            }
            FocusScope.of(context).unfocus();
            Navigator.of(context, rootNavigator: true).pop(
              _MemberFormData(
                name: _nameController.text.trim(),
                relation: _relationController.text.trim(),
                gender: _gender,
                age: int.parse(_ageController.text.trim()),
              ),
            );
          },
          child: Text(context.tr('保存', 'Save')),
        ),
      ],
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.score,
    required this.memberAge,
    required this.linkedPolicyCount,
    required this.coverageText,
    required this.tags,
    required this.hasLinkedPolicies,
    required this.onEdit,
    required this.onDelete,
  });

  final FamilyMember member;
  final int? score;
  final int? memberAge;
  final int linkedPolicyCount;
  final String coverageText;
  final List<String> tags;
  final bool hasLinkedPolicies;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scoreColor = _scoreColor(score);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.14),
            Colors.white.withValues(alpha: 0.07),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33112944),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFB8D7FF), Color(0xFF86C0FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  member.name.isEmpty ? '?' : member.name.characters.first,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          member.relation,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        if (memberAge != null) _AgeTierBadge(age: memberAge!),
                      ],
                    ),
                  ],
                ),
              ),
              if (score != null && hasLinkedPolicies)
                _ScoreBadge(
                  score: score!,
                  color: scoreColor,
                ),
              const SizedBox(width: AppSpacing.xs),
              _ActionIconButton(
                icon: Icons.settings_outlined,
                onPressed: onEdit,
                tooltip: context.tr('编辑成员', 'Edit member'),
              ),
              const SizedBox(width: 2),
              _ActionIconButton(
                icon: Icons.delete_outline,
                onPressed: onDelete,
                tooltip: context.tr('删除成员', 'Delete member'),
                color: AppColors.rose,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _MemberStatTile(
                  icon: Icons.verified_rounded,
                  label: context.tr('已绑定保单', 'Linked policies'),
                  value: '$linkedPolicyCount',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _MemberStatTile(
                  icon: Icons.shield_outlined,
                  label: context.tr('个人总保额', 'Member sum insured'),
                  value: coverageText,
                  compactUnitValue: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.tr('建议险种', 'Suggested coverage'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (tags.isEmpty)
            Text(
              context.tr('暂无建议', 'No suggestions yet'),
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            )
          else
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: tags
                  .map((tag) => _MemberTagChip(label: tag))
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }

  Color _scoreColor(int? value) {
    if (value == null) {
      return Colors.white70;
    }
    if (value >= 75) {
      return AppColors.mint;
    }
    if (value >= 55) {
      return AppColors.accent;
    }
    return AppColors.rose;
  }
}

class _AgeTierBadge extends StatelessWidget {
  const _AgeTierBadge({required this.age});

  final int age;

  @override
  Widget build(BuildContext context) {
    final spec = _resolve(context, age);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: spec.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: spec.color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(spec.icon, size: 12, color: spec.color),
          const SizedBox(width: 4),
          Text(
            '${spec.label} 路 $age',
            style: TextStyle(
              color: spec.color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  _AgeTierSpec _resolve(BuildContext context, int value) {
    if (value < 18) {
      return _AgeTierSpec(
        icon: Icons.child_care_rounded,
        label: context.tr('儿童', 'Child'),
        color: const Color(0xFF6CCBFF),
      );
    }
    if (value < 60) {
      return _AgeTierSpec(
        icon: Icons.person_rounded,
        label: context.tr('成人', 'Adult'),
        color: const Color(0xFF79E2AE),
      );
    }
    return _AgeTierSpec(
      icon: Icons.elderly_rounded,
      label: context.tr('老人', 'Senior'),
      color: const Color(0xFFFFC986),
    );
  }
}

class _AgeTierSpec {
  const _AgeTierSpec({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({
    required this.score,
    required this.color,
  });

  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message:
          '${context.tr('家庭维度评分', 'Household-dimension score')}: $score/100',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt_rounded, size: 14, color: color),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr('保障评分', 'Protection score'),
                  style: TextStyle(
                    color: color.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '$score/100',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  const _ActionIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.color = Colors.white70,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(9),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}

class _MemberStatTile extends StatelessWidget {
  const _MemberStatTile({
    required this.icon,
    required this.label,
    required this.value,
    this.compactUnitValue = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool compactUnitValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: const Color(0x40162B43),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Colors.white60),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (compactUnitValue)
            _UnitAwareValueText(value: value)
          else
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
        ],
      ),
    );
  }
}

class _UnitAwareValueText extends StatelessWidget {
  const _UnitAwareValueText({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final match = RegExp(
      r'^([A-Za-z]{3})\s+([0-9]+(?:\.[0-9]+)?)([kKmM]?)$',
    ).firstMatch(value.trim());

    if (match == null) {
      return Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          height: 1.06,
        ),
      );
    }

    final unitLeft = match.group(1)!;
    final number = match.group(2)!;
    final unitRight = match.group(3)!;

    const numberStyle = TextStyle(
      color: Colors.white,
      fontSize: 22,
      fontWeight: FontWeight.w800,
      height: 1.06,
    );
    const unitStyle = TextStyle(
      color: Colors.white70,
      fontSize: 13,
      fontWeight: FontWeight.w700,
      height: 1.1,
    );

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        children: [
          TextSpan(text: '$unitLeft ', style: unitStyle),
          TextSpan(text: number, style: numberStyle),
          if (unitRight.isNotEmpty) TextSpan(text: unitRight, style: unitStyle),
        ],
      ),
    );
  }
}

class _MemberTagChip extends StatelessWidget {
  const _MemberTagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
