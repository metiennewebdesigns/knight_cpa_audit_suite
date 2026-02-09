import 'package:flutter/material.dart';

class ClientAddressValue {
  final String line1;
  final String line2;
  final String city;
  final String state;
  final String zip;

  const ClientAddressValue({
    required this.line1,
    required this.line2,
    required this.city,
    required this.state,
    required this.zip,
  });

  Map<String, dynamic> toJson() => {
        'line1': line1.trim(),
        'line2': line2.trim(),
        'city': city.trim(),
        'state': state.trim(),
        'zip': zip.trim(),
      };
}

class ClientAddressFields extends StatefulWidget {
  const ClientAddressFields({
    super.key,
    this.initial,
    required this.onChanged,
  });

  final ClientAddressValue? initial;
  final ValueChanged<ClientAddressValue> onChanged;

  @override
  State<ClientAddressFields> createState() => _ClientAddressFieldsState();
}

class _ClientAddressFieldsState extends State<ClientAddressFields> {
  late final TextEditingController _line1;
  late final TextEditingController _line2;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _zip;

  @override
  void initState() {
    super.initState();
    _line1 = TextEditingController(text: widget.initial?.line1 ?? '');
    _line2 = TextEditingController(text: widget.initial?.line2 ?? '');
    _city = TextEditingController(text: widget.initial?.city ?? '');
    _state = TextEditingController(text: widget.initial?.state ?? '');
    _zip = TextEditingController(text: widget.initial?.zip ?? '');

    _line1.addListener(_emit);
    _line2.addListener(_emit);
    _city.addListener(_emit);
    _state.addListener(_emit);
    _zip.addListener(_emit);

    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  @override
  void dispose() {
    _line1.dispose();
    _line2.dispose();
    _city.dispose();
    _state.dispose();
    _zip.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(
      ClientAddressValue(
        line1: _line1.text,
        line2: _line2.text,
        city: _city.text,
        state: _state.text,
        zip: _zip.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _line1,
          decoration: const InputDecoration(
            labelText: 'Address Line 1',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _line2,
          decoration: const InputDecoration(
            labelText: 'Address Line 2 (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _city,
                decoration: const InputDecoration(
                  labelText: 'City',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _state,
                textCapitalization: TextCapitalization.characters,
                maxLength: 2,
                decoration: const InputDecoration(
                  labelText: 'State',
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _zip,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'ZIP',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}