import 'package:flutter/material.dart';

class MeasurementSelector extends StatefulWidget {
  final String label;
  final double selectedValue;
  final List<double> values;
  final Function(double) onChanged;
  final String Function(double) formatValue;
  final Color labelColor;
  final Color valueColor;
  final bool initialScrollToSelected;

  const MeasurementSelector({
    Key? key,
    required this.label,
    required this.selectedValue,
    required this.values,
    required this.onChanged,
    required this.formatValue,
    required this.labelColor,
    required this.valueColor,
    this.initialScrollToSelected = false,
  }) : super(key: key);

  @override
  State<MeasurementSelector> createState() => _MeasurementSelectorState();
}

class _MeasurementSelectorState extends State<MeasurementSelector> {
  late FixedExtentScrollController _scrollController;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.values.indexOf(widget.selectedValue);
    if (_selectedIndex < 0) _selectedIndex = 0;
    
    _scrollController = FixedExtentScrollController(
      initialItem: _selectedIndex,
    );
    
    // If initialScrollToSelected is true, scroll to selected value
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialScrollToSelected && mounted) {
        _scrollController.animateToItem(
          _selectedIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MeasurementSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedValue != widget.selectedValue) {
      _selectedIndex = widget.values.indexOf(widget.selectedValue);
      if (_selectedIndex < 0) _selectedIndex = 0;
      
      // Animate to the new selected value
      if (widget.initialScrollToSelected && mounted) {
        _scrollController.animateToItem(
          _selectedIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: widget.labelColor,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListWheelScrollView.useDelegate(
            controller: _scrollController,
            itemExtent: 60,
            diameterRatio: 1.2,
            physics: const FixedExtentScrollPhysics(
              parent: BouncingScrollPhysics(
                decelerationRate: ScrollDecelerationRate.fast,
              ),
            ),
            perspective: 0.002,
            magnification: 1.3,
            useMagnifier: true,
            squeeze: 0.95,
            onSelectedItemChanged: (index) {
              setState(() {
                _selectedIndex = index;
              });
              widget.onChanged(widget.values[index]);
            },
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: widget.values.length,
              builder: (context, index) {
                final isSelected = index == _selectedIndex;
                return Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? widget.valueColor.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      widget.formatValue(widget.values[index]),
                      style: TextStyle(
                        fontSize: isSelected ? 22 : 18,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? widget.valueColor : widget.labelColor.withOpacity(0.7),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
