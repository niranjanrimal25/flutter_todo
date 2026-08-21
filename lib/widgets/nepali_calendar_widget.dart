import 'package:flutter/material.dart';
import 'package:nepali_utils/nepali_utils.dart';
import '../utils/constants.dart';

class NepaliCalendarWidget extends StatefulWidget {
  final Function(NepaliDateTime)? onDateSelected;
  final NepaliDateTime? initialDate;
  final bool initiallyExpanded;

  const NepaliCalendarWidget({
    super.key,
    this.onDateSelected,
    this.initialDate,
    this.initiallyExpanded = false,
  });

  @override
  State<NepaliCalendarWidget> createState() => _NepaliCalendarWidgetState();
}

class _NepaliCalendarWidgetState extends State<NepaliCalendarWidget> {
  late NepaliDateTime _currentMonth;
  late NepaliDateTime _selectedDate;
  late NepaliDateTime _today;
  late bool _expanded;

  final List<String> _nepaliMonths = [
    'बैशाख', 'जेठ', 'असार', 'श्रावण',
    'भदौ', 'असोज', 'कार्तिक', 'मंसिर',
    'पौष', 'माघ', 'फागुन', 'चैत्र',
  ];

  final List<String> _nepaliDays = [
    'आइत', 'सोम', 'मंगल', 'बुध', 'बिही', 'शुक्र', 'शनि',
  ];

  final List<String> _nepaliDigits = [
    '०', '१', '२', '३', '४', '५', '६', '७', '८', '९',
  ];

  @override
  void initState() {
    super.initState();
    _today = widget.initialDate ?? NepaliDateTime.now();
    _currentMonth = NepaliDateTime(_today.year, _today.month);
    _selectedDate = _today;
    _expanded = widget.initiallyExpanded;
  }

  String _toNepaliDigits(int number) {
    return number.toString().split('').map((d) {
      int digit = int.parse(d);
      return _nepaliDigits[digit];
    }).join();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeIn,
            switchOutCurve: Curves.easeOut,
            child: _expanded
                ? Column(
                    key: const ValueKey('calendar-grid'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDayLabels(),
                      _buildCalendarGrid(),
                      const SizedBox(height: 6),
                    ],
                  )
                : _buildCollapsedStrip(isDark, key: const ValueKey('calendar-strip')),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedStrip(bool isDark, {Key? key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(
            Icons.calendar_month_rounded,
            size: 18,
            color: AppColors.primary.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 10),
          Text(
            'आज: ${_nepaliMonths[_today.month - 1]} '
            '${_toNepaliDigits(_today.day)}, '
            '${_toNepaliDigits(_today.year)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textDark,
            ),
          ),
          const Spacer(),
          Text(
            'विस्तार गर्नुहोस्',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.primary, size: 20),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, Color(0xFF8B83FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () {
                setState(() {
                  if (_currentMonth.month == 1) {
                    _currentMonth = NepaliDateTime(
                        _currentMonth.year - 1, 12);
                  } else {
                    _currentMonth = NepaliDateTime(
                        _currentMonth.year, _currentMonth.month - 1);
                  }
                });
              },
              icon: const Icon(Icons.chevron_left_rounded,
                  color: Colors.white, size: 22),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    '${_nepaliMonths[_currentMonth.month - 1]} ${_toNepaliDigits(_currentMonth.year)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getEnglishMonthRange(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () {
                setState(() {
                  if (_currentMonth.month == 12) {
                    _currentMonth = NepaliDateTime(
                        _currentMonth.year + 1, 1);
                  } else {
                    _currentMonth = NepaliDateTime(
                        _currentMonth.year, _currentMonth.month + 1);
                  }
                });
              },
              icon: const Icon(Icons.chevron_right_rounded,
                  color: Colors.white, size: 22),
            ),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayLabels() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _nepaliDays.map((day) {
          final isSaturday = day == 'शनि';
          return SizedBox(
            width: 34,
            child: Text(
              day,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSaturday
                    ? AppColors.danger
                    : isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textGrey,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = NepaliDateTime(
        _currentMonth.year, _currentMonth.month, 1);
    // NepaliDateTime.weekday is 1=Sunday .. 7=Saturday, matching the
    // _nepaliDays label order (index 0 = Sunday). Convert to a 0-based
    // column index so Sunday lands in the first column.
    final startWeekday = firstDayOfMonth.weekday - 1;

    final daysInMonth = _currentMonth.totalDays;

    final prevMonth = _currentMonth.month == 1
        ? 12
        : _currentMonth.month - 1;
    final prevYear = _currentMonth.month == 1
        ? _currentMonth.year - 1
        : _currentMonth.year;
    final daysInPrevMonth = NepaliDateTime(prevYear, prevMonth).totalDays;

    List<Widget> dayWidgets = [];

    for (int i = 0; i < startWeekday; i++) {
      final day = daysInPrevMonth - startWeekday + 1 + i;
      dayWidgets.add(_buildDayCell(
        day: day,
        isCurrentMonth: false,
        isToday: false,
        isSelected: false,
        isSaturday: (i % 7) == 6,
        cellKey: ValueKey('prev-$day'),
      ));
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = NepaliDateTime(
          _currentMonth.year, _currentMonth.month, day);
      final isToday = date.year == _today.year &&
          date.month == _today.month &&
          date.day == _today.day;
      final isSelected = date.year == _selectedDate.year &&
          date.month == _selectedDate.month &&
          date.day == _selectedDate.day;
      final isSaturday = date.weekday == 7;

      dayWidgets.add(_buildDayCell(
        day: day,
        isCurrentMonth: true,
        isToday: isToday,
        isSelected: isSelected,
        isSaturday: isSaturday,
        onTap: () {
          setState(() => _selectedDate = date);
          widget.onDateSelected?.call(date);
        },
        cellKey: ValueKey('current-$day'),
      ));
    }

    final remaining = 42 - dayWidgets.length;
    for (int i = 1; i <= remaining; i++) {
      dayWidgets.add(_buildDayCell(
        day: i,
        isCurrentMonth: false,
        isToday: false,
        isSelected: false,
        isSaturday: ((startWeekday + daysInMonth + i - 1) % 7) == 6,
        cellKey: ValueKey('next-$i'),
      ));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Wrap(
        alignment: WrapAlignment.spaceAround,
        children: dayWidgets,
      ),
    );
  }

  Widget _buildDayCell({
    required int day,
    required bool isCurrentMonth,
    required bool isToday,
    required bool isSelected,
    required bool isSaturday,
    VoidCallback? onTap,
    Key? cellKey,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      key: cellKey,
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        margin: const EdgeInsets.symmetric(vertical: 1),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : isToday
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : Colors.transparent,
          shape: BoxShape.circle,
          border: isToday && !isSelected
              ? Border.all(color: AppColors.primary, width: 1.5)
              : null,
        ),
        child: Center(
          child: Text(
            _toNepaliDigits(day),
            style: TextStyle(
              fontSize: 14,
              fontWeight: isToday || isSelected
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: !isCurrentMonth
                  ? (isDark ? AppColors.darkTextSecondary : AppColors.textLight)
                  : isSelected
                      ? Colors.white
                      : isSaturday
                          ? AppColors.danger
                          : isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textDark,
            ),
          ),
        ),
      ),
    );
  }

  String _getEnglishMonthRange() {
    final adDate = _currentMonth.toDateTime();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[adDate.month - 1]} - ${months[(adDate.month) % 12]} ${adDate.year}';
  }
}
