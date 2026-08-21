import 'package:flutter/material.dart';

class NepaliCalendarWidget extends StatelessWidget {
  const NepaliCalendarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // This is a static representation. For a dynamic Nepali calendar,
    // you would use a package like 'nepali_utils' to get the current Nepali date.
    const String nepaliMonth = 'Jestha';
    const String nepaliDay = '15';
    const String dayOfWeek = 'Wednesday';
    const String gregorianDate = 'May 28, 2024';

    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Container(
        width: 150,
        height: 150,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text(
              nepaliMonth,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              nepaliDay,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(dayOfWeek, style: Theme.of(context).textTheme.bodyMedium),
            Text(gregorianDate, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
