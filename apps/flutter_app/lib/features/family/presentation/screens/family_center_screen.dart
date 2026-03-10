// Family center: members management and PDF form import.
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:wearefamily_app/core/api/api_client.dart';
import 'package:wearefamily_app/core/api/user_profile.dart';
import 'package:wearefamily_app/core/theme/app_colors.dart';
import 'package:wearefamily_app/core/theme/app_spacing.dart';
import 'package:wearefamily_app/shared/widgets/glass_card.dart';

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
      final selected = _resolveSelectedFamily(families);
      setState(() {
        _families = families;
        _selectedFamilyId = selected;
      });

      if (selected != null) {
        await _loadFamilyDetails();
      }
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingFamilies = false;
        });
      }
    }
  }

  String? _resolveSelectedFamily(List<Family> families) {
    if (families.isEmpty) {
      return null;
    }

    if (_selectedFamilyId == null) {
      return families.first.id;
    }

    final exists = families.any((item) => item.id == _selectedFamilyId);
    return exists ? _selectedFamilyId : families.first.id;
  }

  Future<void> _loadFamilyDetails() async {
    final familyId = _selectedFamilyId;
    if (familyId == null) {
      return;
    }

    setState(() {
      _loadingDetails = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        widget.apiClient.fetchFamilyMembers(widget.profile, familyId),
        widget.apiClient.fetchFamilyDocuments(widget.profile, familyId),
      ]);

      setState(() {
        _members = results[0] as List<FamilyMember>;
        _documents = results[1] as List<FamilyDocument>;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingDetails = false;
        });
      }
    }
  }

  Future<void> _addMember() async {
    final familyId = _selectedFamilyId;
    if (familyId == null) {
      return;
    }

    final form = await showDialog<_MemberFormResult>(
      context: context,
      builder: (_) => const _AddMemberDialog(),
    );

    if (form == null) {
      return;
    }

    try {
      await widget.apiClient.createFamilyMember(
        profile: widget.profile,
        familyId: familyId,
        name: form.name,
        relation: form.relation,
        gender: form.gender,
        birthDate: form.birthDate,
        phone: form.phone,
      );
      await _loadFamilyDetails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Family member added.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  Future<void> _uploadPdf() async {
    final familyId = _selectedFamilyId;
    if (familyId == null) {
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to read selected file bytes.')),
        );
      }
      return;
    }

    try {
      await widget.apiClient.uploadFamilyPdf(
        profile: widget.profile,
        familyId: familyId,
        file: UploadFilePayload(
          fileName: file.name,
          bytes: bytes,
        ),
      );
      await _loadFamilyDetails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF imported successfully.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingFamilies) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    if (_error != null && _families.isEmpty) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_families.isEmpty) {
      return const Center(
        child: Text(
          'No family records found.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final selectedFamily = _families.firstWhere(
          (item) => item.id == _selectedFamilyId,
          orElse: () => _families.first,
        );

        final panels = [
          _buildMembersPanel(context, selectedFamily),
          _buildDocumentsPanel(context),
        ];

        return RefreshIndicator(
          onRefresh: _loadFamilyDetails,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _buildHeader(context, selectedFamily),
              const SizedBox(height: AppSpacing.lg),
              if (constraints.maxWidth >= 1100)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: panels[0]),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(child: panels[1]),
                  ],
                )
              else ...[
                panels[0],
                const SizedBox(height: AppSpacing.lg),
                panels[1],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, Family selectedFamily) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Family Center',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
              ),
              IconButton(
                onPressed: _loadingDetails ? null : _loadFamilyDetails,
                icon: const Icon(Icons.refresh, color: Colors.white70),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Manage members and import policy forms (PDF).',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            value: selectedFamily.id,
            decoration: InputDecoration(
              labelText: 'Selected Family',
              labelStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            dropdownColor: const Color(0xFF11263A),
            style: const TextStyle(color: Colors.white),
            items: _families
                .map(
                  (item) => DropdownMenuItem(
                    value: item.id,
                    child: Text(item.name),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _selectedFamilyId = value;
              });
              _loadFamilyDetails();
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, style: const TextStyle(color: AppColors.rose)),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 260.ms);
  }

  Widget _buildMembersPanel(BuildContext context, Family family) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Members (${_members.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
              ),
              FilledButton.icon(
                onPressed: _loadingDetails ? null : _addMember,
                icon: const Icon(Icons.person_add),
                label: const Text('Add'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.mint,
                  foregroundColor: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (_loadingDetails)
            const Center(child: CircularProgressIndicator(color: AppColors.accent))
          else if (_members.isEmpty)
            const Text('No members yet.', style: TextStyle(color: Colors.white70))
          else
            ..._members.map((member) => _MemberTile(member: member)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Owner ID: ${family.ownerUserId}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 80.ms, duration: 260.ms).slideY(begin: 0.05);
  }

  Widget _buildDocumentsPanel(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Policy PDFs (${_documents.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
              ),
              FilledButton.icon(
                onPressed: _loadingDetails ? null : _uploadPdf,
                icon: const Icon(Icons.upload_file),
                label: const Text('Import PDF'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (_loadingDetails)
            const Center(child: CircularProgressIndicator(color: AppColors.accent))
          else if (_documents.isEmpty)
            const Text('No PDF forms imported.', style: TextStyle(color: Colors.white70))
          else
            ..._documents.map((doc) => _DocumentTile(document: doc)),
        ],
      ),
    ).animate().fadeIn(delay: 140.ms, duration: 260.ms).slideY(begin: 0.05);
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member});

  final FamilyMember member;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.mint.withOpacity(0.24),
            child: Text(
              member.name.isEmpty ? '?' : member.name.substring(0, 1).toUpperCase(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                Text(
                  '${member.relation}${member.phone == null ? '' : ' · ${member.phone}'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.document});

  final FamilyDocument document;

  @override
  Widget build(BuildContext context) {
    final kb = max(1, document.fileSize ~/ 1024);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.picture_as_pdf, color: AppColors.accent),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(document.fileName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                Text(
                  '${document.docType} · ${kb}KB',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberFormResult {
  const _MemberFormResult({
    required this.name,
    required this.relation,
    required this.gender,
    required this.birthDate,
    required this.phone,
  });

  final String name;
  final String relation;
  final String? gender;
  final String? birthDate;
  final String? phone;
}

class _AddMemberDialog extends StatefulWidget {
  const _AddMemberDialog();

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _relationController = TextEditingController();
  final _genderController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _relationController.dispose();
    _genderController.dispose();
    _birthDateController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF13283D),
      title: const Text('Add Family Member', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DialogField(controller: _nameController, label: 'Name', requiredField: true),
              _DialogField(controller: _relationController, label: 'Relation', requiredField: true),
              _DialogField(controller: _genderController, label: 'Gender (optional)'),
              _DialogField(controller: _birthDateController, label: 'Birth Date YYYY-MM-DD (optional)'),
              _DialogField(controller: _phoneController, label: 'Phone (optional)'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) {
              return;
            }
            Navigator.of(context).pop(
              _MemberFormResult(
                name: _nameController.text.trim(),
                relation: _relationController.text.trim(),
                gender: _optional(_genderController.text),
                birthDate: _optional(_birthDateController.text),
                phone: _optional(_phoneController.text),
              ),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }

  String? _optional(String value) {
    final v = value.trim();
    return v.isEmpty ? null : v;
  }
}

class _DialogField extends StatelessWidget {
  const _DialogField({
    required this.controller,
    required this.label,
    this.requiredField = false,
  });

  final TextEditingController controller;
  final String label;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        validator: requiredField
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Required';
                }
                return null;
              }
            : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.white.withOpacity(0.08),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
