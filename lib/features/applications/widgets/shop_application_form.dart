import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/addis_locations.dart';
import '../../../l10n/l10n.dart';
import '../../../services/app_repository.dart';
import '../../shared/widgets/ui_kit.dart';
import '../applications_l10n.dart';
import '../shop_applications_service.dart';

/// The applicant's form: create, edit while pending, or apply again after a
/// rejection ([initial] prefills the fields). Validation and storage go
/// through [ShopApplicationsService]; [onDone] runs after a successful save.
class ShopApplicationForm extends StatefulWidget {
  const ShopApplicationForm({
    super.key,
    this.initial,
    required this.editing,
    required this.onDone,
    this.onCancel,
    this.service,
  });

  /// Prefill (the pending application being edited, or the rejected one).
  final ShopApplication? initial;

  /// True: update the pending application; false: submit a new one.
  final bool editing;
  final ValueChanged<ShopApplication> onDone;
  final VoidCallback? onCancel;
  final ShopApplicationsService? service;

  @override
  State<ShopApplicationForm> createState() => _ShopApplicationFormState();
}

class _ShopApplicationFormState extends State<ShopApplicationForm> {
  late final TextEditingController _owner;
  late final TextEditingController _shop;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _description;
  String? _subCity;
  bool _saving = false;
  String? _error;

  ShopApplicationsService get _service => widget.service ?? ShopApplicationsService.instance;

  @override
  void initState() {
    super.initState();
    final a = widget.initial;
    final user = AppRepository.instance.currentUser?.name;
    _owner = TextEditingController(text: a?.ownerName ?? user ?? '');
    _shop = TextEditingController(text: a?.shopName ?? '');
    _address = TextEditingController(text: a?.address ?? '');
    _phone = TextEditingController(text: a?.phone ?? '');
    _description = TextEditingController(text: a?.description ?? '');
    final sub = a?.subCity;
    _subCity = sub != null && kAddisSubCities.contains(sub) ? sub : null;
  }

  @override
  void dispose() {
    _owner.dispose();
    _shop.dispose();
    _address.dispose();
    _phone.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = context.l10n;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final ShopApplication result;
      if (widget.editing) {
        result = await _service.update(
          ownerName: _owner.text,
          shopName: _shop.text,
          address: _address.text,
          subCity: _subCity ?? '',
          phone: _phone.text,
          description: _description.text,
        );
      } else {
        result = await _service.submit(
          ownerName: _owner.text,
          shopName: _shop.text,
          address: _address.text,
          subCity: _subCity ?? '',
          phone: _phone.text,
          description: _description.text,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.editing ? l.applUpdated : l.applSubmitted)),
      );
      widget.onDone(result);
    } catch (e) {
      if (mounted) setState(() => _error = l.applicationsErrorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.applFormIntro, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.35)),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('appl-owner'),
            controller: _owner,
            textCapitalization: TextCapitalization.words,
            maxLength: kApplicationOwnerNameMax,
            decoration: InputDecoration(
              labelText: l.applOwnerName,
              prefixIcon: const Icon(Icons.person_outline),
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('appl-shop'),
            controller: _shop,
            textCapitalization: TextCapitalization.words,
            maxLength: kApplicationShopNameMax,
            decoration: InputDecoration(
              labelText: l.applShopName,
              prefixIcon: const Icon(Icons.storefront_outlined),
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('appl-address'),
            controller: _address,
            maxLength: kApplicationAddressMax,
            decoration: InputDecoration(
              labelText: l.applAddress,
              prefixIcon: const Icon(Icons.place_outlined),
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const ValueKey('appl-subcity'),
            initialValue: _subCity,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l.applSubCity,
              prefixIcon: const Icon(Icons.map_outlined),
            ),
            items: [
              for (final s in kAddisSubCities) DropdownMenuItem(value: s, child: Text(l.placeName(s))),
            ],
            onChanged: (v) => setState(() => _subCity = v),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('appl-phone'),
            controller: _phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ \-]'))],
            decoration: InputDecoration(
              labelText: l.applPhone,
              hintText: l.applPhoneHint,
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('appl-description'),
            controller: _description,
            maxLength: kApplicationDescriptionMax,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: l.applDescription,
              prefixIcon: const Icon(Icons.notes_outlined),
              alignLabelWithHint: true,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(
              _error!,
              key: const ValueKey('appl-error'),
              style: TextStyle(color: AppTheme.danger, fontSize: 13),
            ),
          ],
          const SizedBox(height: 14),
          ElevatedButton(
            key: const ValueKey('appl-save'),
            onPressed: _saving ? null : _save,
            child: _saving
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.onInk),
                  )
                : Text(widget.editing
                    ? l.applSaveChanges
                    : (widget.initial?.isRejected ?? false)
                        ? l.applResubmit
                        : l.applSubmit),
          ),
          if (widget.onCancel != null)
            TextButton(
              onPressed: _saving ? null : widget.onCancel,
              child: Text(l.cancel, style: TextStyle(color: AppTheme.textSecondary)),
            ),
        ],
      ),
    );
  }
}
