import 'package:flutter/material.dart';
import 'package:nepali_utils/nepali_utils.dart';
import 'package:nepali_date_picker/nepali_date_picker.dart' as picker;
import '../utils/constants.dart';

class NepaliDatePickerHelper {
  static Future<NepaliDateTime?> showNepaliDatePicker(
    BuildContext context, {
    NepaliDateTime? initialDate,
  }) async {
    final picked = await picker.showNepaliDatePicker(
      context: context,
      initialDate: initialDate ?? NepaliDateTime.now(),
      firstDate: NepaliDateTime(2070),
      lastDate: NepaliDateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textDark,
            ),
          ),
          child: child!,
        );
      },
    );
    return picked;
  }

  static String formatNepaliDate(NepaliDateTime date) {
    final months = [
      'बैशाख', 'जेठ', 'असार', 'श्रावण',
      'भदौ', 'असोज', 'कार्तिक', 'मंसिर',
      'पौष', 'माघ', 'फागुन', 'चैत्र',
    ];
    final digits = ['०', '१', '२', '३', '४', '५', '६', '७', '८', '९'];

    String toNepali(int n) {
      return n.toString().split('').map((d) => digits[int.parse(d)]).join();
    }

    return '${toNepali(date.year)} ${months[date.month - 1]} ${toNepali(date.day)}';
  }
}
