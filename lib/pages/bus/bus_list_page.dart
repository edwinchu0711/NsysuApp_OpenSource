import 'package:flutter/material.dart';
import '../../services/bus_service.dart';
import '../../models/bus_info.dart';
import '../../theme/app_theme.dart';
import '../../theme/layout_style_notifier.dart';
import '../../widgets/glass/glass_page_scaffold.dart';
import '../../services/offline_error_handler.dart';
import 'bus_time_page.dart';

enum _BusListState { loading, success, error }

class BusListPage extends StatefulWidget {
  const BusListPage({super.key});

  @override
  State<BusListPage> createState() => _BusListPageState();
}

class _BusListPageState extends State<BusListPage> {
  _BusListState _state = _BusListState.loading;
  List<BusInfo> _busList = [];
  BusInfo? _selectedBus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
  }

  Future<void> _fetchData() async {
    if (OfflineErrorHandler.isOffline) {
      if (mounted) {
        setState(() => _state = _BusListState.error);
        await OfflineErrorHandler.show(context, const OfflineDisabledException());
      }
      return;
    }
    try {
      final list = await BusService.instance.fetchBusInfoList(
        Localizations.localeOf(context),
      );
      if (mounted) {
        setState(() {
          _busList = list;
          _state = _BusListState.success;
          if (list.isNotEmpty && _selectedBus == null) {
            _selectedBus = list.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _state = _BusListState.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GlassPageScaffold(
      appBar: AppBar(
        title: const Text('校園公車'),
      ),
      body: _buildBody(colorScheme),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    final isWide = MediaQuery.of(context).size.width >= 800;

    switch (_state) {
      case _BusListState.loading:
        return Center(
          child: CircularProgressIndicator(
            color: LayoutStyleNotifier.instance.isLiquidGlass
                ? colorScheme.primary
                : null,
          ),
        );
      case _BusListState.error:
        return InkWell(
          onTap: _fetchData,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline,
                    size: 48, color: colorScheme.subtitleText),
                const SizedBox(height: 12),
                Text('載入失敗',
                    style: TextStyle(
                        fontSize: 16, color: colorScheme.subtitleText)),
                const SizedBox(height: 8),
                Text('點擊重試',
                    style: TextStyle(
                        fontSize: 14, color: colorScheme.primary)),
              ],
            ),
          ),
        );
      case _BusListState.success:
        if (_busList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.directions_bus_outlined,
                    size: 48, color: colorScheme.subtitleText),
                const SizedBox(height: 12),
                Text('目前沒有公車路線資料',
                    style: TextStyle(
                        fontSize: 16, color: colorScheme.subtitleText)),
              ],
            ),
          );
        }

        final listWidget = ListView.builder(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            LayoutStyleNotifier.instance.isLiquidGlass ? 100 : 8,
          ),
          itemCount: _busList.length,
          itemBuilder: (context, index) {
            final bus = _busList[index];
            final isSelected = isWide && _selectedBus?.routeId == bus.routeId;
            return _BusRouteCard(
              busInfo: bus,
              colorScheme: colorScheme,
              isSelected: isSelected,
              onTap: () {
                if (isWide) {
                  setState(() {
                    _selectedBus = bus;
                  });
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BusTimePage(busInfo: bus),
                    ),
                  );
                }
              },
            );
          },
        );

        if (isWide) {
          return Row(
            children: [
              Expanded(
                flex: 4,
                child: listWidget,
              ),
              Container(
                width: 1,
                color: colorScheme.borderColor,
              ),
              Expanded(
                flex: 5,
                child: _selectedBus != null
                    ? BusTimePage(
                        busInfo: _selectedBus!,
                        showAppBarLeading: false,
                        key: ValueKey(_selectedBus!.routeId),
                      )
                    : const Center(child: Text('請選擇路線')),
              ),
            ],
          );
        }

        return listWidget;
    }
  }
}

class _BusRouteCard extends StatelessWidget {
  final BusInfo busInfo;
  final ColorScheme colorScheme;
  final VoidCallback onTap;
  final bool isSelected;

  const _BusRouteCard({
    required this.busInfo,
    required this.colorScheme,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasCar = busInfo.isOperating;
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;
    final isDark = colorScheme.isDark;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primary.withValues(alpha: 0.05)
            : (isLiquidGlass
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.45))
                : colorScheme.cardBackground),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? colorScheme.primary
              : (isLiquidGlass
                  ? (isDark
                      ? Colors.white.withValues(alpha: 0.14)
                      : Colors.black.withValues(alpha: 0.05))
                  : colorScheme.borderColor),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (hasCar ? Colors.green : Colors.red).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.directions_bus_rounded,
                    size: 26,
                    color: hasCar ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        busInfo.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primaryText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${busInfo.departure} → ${busInfo.destination}',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.subtitleText,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      hasCar
                          ? busInfo.busIds.first
                          : (Localizations.localeOf(context)
                                      .languageCode
                                      .contains('en')
                                  ? 'Out of service'
                                  : '未行駛'),
                      style: TextStyle(
                        fontSize: 13,
                        color: hasCar ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    // Removed updateTime display as requested
                  ],
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded,
                    color: colorScheme.subtitleText.withValues(alpha: 0.7), size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}