import 'package:flutter/material.dart';
import 'package:nepali_utils/nepali_utils.dart';
import '../utils/constants.dart';

class NepaliCalendarWidget extends StatefulWidget {
  final Function(NepaliDateTime)? onDateSelected;
  final NepaliDateTime? initialDate;

  const NepaliCalendarWidget({super.key, this.onDateSelected, this.initialDate});

  @override
  State<NepaliCalendarWidget> createState() => _NepaliCalendarWidgetState();
}

class _NepaliCalendarWidgetState extends State<NepaliCalendarWidget> {
  late NepaliDateTime _currentMonth;
  late NepaliDateTime _selectedDate;
  late NepaliDateTime _today;

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
  }

  String _toNepaliDigits(int number) {
    return number.toString().split('').map((d) {
      int digit = int.parse(d);
      return _nepaliDigits[digit];
    }).join();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          _buildDayLabels(),
          _buildCalendarGrid(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, Color(0xFF8B83FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
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
                color: Colors.white, size: 28),
          ),
          Column(
            children: [
              Text(
                '${_nepaliMonths[_currentMonth.month - 1]} ${_toNepaliDigits(_currentMonth.year)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
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
          IconButton(
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
                color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildDayLabels() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _nepaliDays.map((day) {
          final isSaturday = day == 'शनि';
          return SizedBox(
            width: 40,
            child: Text(
              day,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSaturday ? AppColors.danger : AppColors.textGrey,
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
      padding: const EdgeInsets.symmetric(horizontal: 8),
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
    return GestureDetector(
      key: cellKey,
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.symmetric(vertical: 2),
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
                  ? AppColors.textLight
                  : isSelected
                      ? Colors.white
                      : isSaturday
                          ? AppColors.danger
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
