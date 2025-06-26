import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:numberpicker/numberpicker.dart';
import '../constants/app_colors.dart';

class DateSelector extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onChanged;
  final bool isSmallScreen;
  final bool isVerySmallScreen;

  const DateSelector({
    super.key,
    required this.selectedDate,
    required this.onChanged,
    this.isSmallScreen = false,
    this.isVerySmallScreen = false,
  });

  @override
  State<DateSelector> createState() => _DateSelectorState();
}

class _DateSelectorState extends State<DateSelector> {
  late List<int> _years;
  late int _selectedMonth;
  late int _selectedDay;
  late int _selectedYear;
  final List<String> _monthNames = [
    'January', 'February', 'March', 'April',
    'May', 'June', 'July', 'August',
    'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    // Create the years list
    final currentYear = DateTime.now().year;
    _years = List.generate(100, (index) => currentYear - index);

    // Initialize selected values
    _selectedMonth = widget.selectedDate.month;
    _selectedDay = widget.selectedDate.day;
    _selectedYear = widget.selectedDate.year;
  }

  @override
  void didUpdateWidget(DateSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      setState(() {
        _selectedMonth = widget.selectedDate.month;
        _selectedDay = widget.selectedDate.day;
        _selectedYear = widget.selectedDate.year;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Beautiful formatted date display at the top
        Container(
          margin: EdgeInsets.only(bottom: widget.isVerySmallScreen ? 16 : 24),
          padding: EdgeInsets.symmetric(
            horizontal: widget.isSmallScreen ? 16 : 20, 
            vertical: widget.isVerySmallScreen ? 12 : 16
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.08),
                blurRadius: 10,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            '${_getMonthFullName(_selectedMonth)} ${_selectedDay}, ${_selectedYear}',
            style: TextStyle(
              fontSize: widget.isVerySmallScreen 
                  ? 18 
                  : widget.isSmallScreen 
                      ? 20 
                      : 24,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        
        // Date pickers row
        Expanded(
          child: Row(
            children: [
              // Month selector
              Expanded(
                flex: 4,
                child: _buildMonthPicker(),
              ),
              // Day selector
              Expanded(
                flex: 3,
                child: _buildDayPicker(),
              ),
              // Year selector
              Expanded(
                flex: 4,
                child: _buildYearPicker(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMonthPicker() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: widget.isSmallScreen ? 2 : 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: widget.isVerySmallScreen ? 8 : 10
              ),
              color: AppColors.primary.withOpacity(0.1),
              child: Text(
                'Month',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: widget.isVerySmallScreen ? 14 : 16,
                ),
              ),
            ),
            
            // Picker
            Expanded(
              child: ListWheelScrollView.useDelegate(
                itemExtent: widget.isVerySmallScreen ? 32 : 40,
                perspective: 0.003,
                diameterRatio: 1.5,
                physics: const FixedExtentScrollPhysics(),
                squeeze: 0.95,
                useMagnifier: true,
                magnification: 1.2,
                overAndUnderCenterOpacity: 0.6,
                onSelectedItemChanged: (index) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    final newMonth = index + 1;
                    if (_selectedMonth != newMonth) {
                      _selectedMonth = newMonth;
                      
                      // Validate day with new month
                      final daysInMonth = _getDaysInMonth(_selectedYear, _selectedMonth);
                      if (_selectedDay > daysInMonth) {
                        _selectedDay = daysInMonth;
                      }
                      
                      _updateSelectedDate();
                    }
                  });
                },
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: 12,
                  builder: (context, index) {
                    final monthIndex = index + 1;
                    final isSelected = monthIndex == _selectedMonth;
                    
                    return Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: widget.isSmallScreen ? 6 : 10
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        widget.isSmallScreen 
                            ? _getMonthName(monthIndex) 
                            : _monthNames[index],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isSelected 
                              ? (widget.isVerySmallScreen ? 14 : 18) 
                              : (widget.isVerySmallScreen ? 12 : 16),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayPicker() {
    final daysInMonth = _getDaysInMonth(_selectedYear, _selectedMonth);
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: widget.isSmallScreen ? 2 : 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: widget.isVerySmallScreen ? 8 : 10
              ),
              color: AppColors.primary.withOpacity(0.1),
              child: Text(
                'Day',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: widget.isVerySmallScreen ? 14 : 16,
                ),
              ),
            ),
            
            // Picker
            Expanded(
              child: ListWheelScrollView.useDelegate(
                itemExtent: widget.isVerySmallScreen ? 32 : 40,
                perspective: 0.003,
                diameterRatio: 1.5,
                physics: const FixedExtentScrollPhysics(),
                squeeze: 0.95,
                useMagnifier: true,
                magnification: 1.2,
                overAndUnderCenterOpacity: 0.6,
                controller: FixedExtentScrollController(initialItem: _selectedDay - 1),
                onSelectedItemChanged: (index) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedDay = index + 1;
                    _updateSelectedDate();
                  });
                },
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: daysInMonth,
                  builder: (context, index) {
                    final day = index + 1;
                    final isSelected = day == _selectedDay;
                    
                    return Container(
                      alignment: Alignment.center,
                      child: Text(
                        day.toString(),
                        style: TextStyle(
                          fontSize: isSelected 
                              ? (widget.isVerySmallScreen ? 14 : 18) 
                              : (widget.isVerySmallScreen ? 12 : 16),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYearPicker() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: widget.isSmallScreen ? 2 : 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: widget.isVerySmallScreen ? 8 : 10
              ),
              color: AppColors.primary.withOpacity(0.1),
              child: Text(
                'Year',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: widget.isVerySmallScreen ? 14 : 16,
                ),
              ),
            ),
            
            // Picker
            Expanded(
              child: ListWheelScrollView.useDelegate(
                itemExtent: widget.isVerySmallScreen ? 32 : 40,
                perspective: 0.003,
                diameterRatio: 1.5,
                physics: const FixedExtentScrollPhysics(),
                squeeze: 0.95,
                useMagnifier: true,
                magnification: 1.2,
                overAndUnderCenterOpacity: 0.6,
                controller: FixedExtentScrollController(
                  initialItem: _years.indexOf(_selectedYear),
                ),
                onSelectedItemChanged: (index) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedYear = _years[index];
                    
                    // Check for leap year
                    final daysInMonth = _getDaysInMonth(_selectedYear, _selectedMonth);
                    if (_selectedDay > daysInMonth) {
                      _selectedDay = daysInMonth;
                    }
                    
                    _updateSelectedDate();
                  });
                },
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: _years.length,
                  builder: (context, index) {
                    final year = _years[index];
                    final isSelected = year == _selectedYear;
                    
                    return Container(
                      alignment: Alignment.center,
                      child: Text(
                        year.toString(),
                        style: TextStyle(
                          fontSize: isSelected 
                              ? (widget.isVerySmallScreen ? 14 : 18) 
                              : (widget.isVerySmallScreen ? 12 : 16),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateSelectedDate() {
    final newDate = DateTime(_selectedYear, _selectedMonth, _selectedDay);
    widget.onChanged(newDate);
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
  
  String _getMonthFullName(int month) {
    return _monthNames[month - 1];
  }

  int _getDaysInMonth(int year, int month) {
    // Return the number of days in the month for the given year
    return DateTime(year, month + 1, 0).day;
  }
}
