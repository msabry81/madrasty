import 'package:flutter/material.dart';

import '../core/cairo_time.dart';
import 'ui.dart';

/// حقل تاريخ + وقت يُدخَلان بتوقيت القاهرة، ويُعيد DateTime بصيغة UTC.
class CairoDateTimeField extends StatefulWidget {
  const CairoDateTimeField({super.key, required this.label, this.initial, required this.onChanged});
  final String label;
  final DateTime? initial;
  final ValueChanged<DateTime?> onChanged;

  @override
  State<CairoDateTimeField> createState() => _CairoDateTimeFieldState();
}

class _CairoDateTimeFieldState extends State<CairoDateTimeField> {
  DateTime? _date;
  TimeOfDay? _time;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      final c = CairoTime.toCairo(i);
      _date = DateTime(c.year, c.month, c.day);
      _time = TimeOfDay(hour: c.hour, minute: c.minute);
    }
  }

  void _emit() {
    if (_date == null || _time == null) {
      widget.onChanged(null);
    } else {
      widget.onChanged(CairoTime.fromCairoWallClock(_date!.year, _date!.month, _date!.day, _time!.hour, _time!.minute));
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (d != null) {
      setState(() => _date = d);
      _emit();
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time ?? const TimeOfDay(hour: 18, minute: 0));
    if (t != null) {
      setState(() => _time = t);
      _emit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${widget.label} (بتوقيت القاهرة)', style: const TextStyle(fontSize: 12)),
      const SizedBox(height: 4),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: _pickDate, child: Text(_date == null ? 'التاريخ' : fmtDate(_date)))),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton(onPressed: _pickTime, child: Text(_time == null ? 'الوقت' : _time!.format(context)))),
      ]),
    ]);
  }
}
