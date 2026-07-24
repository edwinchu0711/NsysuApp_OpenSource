import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/bus_service.dart';
import '../../models/bus_info.dart';
import '../../models/bus_time.dart';
import '../../theme/app_theme.dart';
import '../../theme/layout_style_notifier.dart';
import '../../widgets/glass/glass_page_scaffold.dart';
import '../../services/offline_error_handler.dart';

enum _BusTimeState { loading, success, error }

class BusTimePage extends StatefulWidget {
  final BusInfo busInfo;
  final bool showAppBarLeading;

  const BusTimePage({
    super.key,
    required this.busInfo,
    this.showAppBarLeading = true,
  });

  @override
  State<BusTimePage> createState() => _BusTimePageState();
}

class _BusTimePageState extends State<BusTimePage>
    with SingleTickerProviderStateMixin {
  _BusTimeState _state = _BusTimeState.loading;
  List<BusTime> _goList = [];
  List<BusTime> _backList = [];
  late TabController _tabController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
      _timer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchData());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (OfflineErrorHandler.isOffline) {
      _timer?.cancel();
      if (mounted) {
        setState(() => _state = _BusTimeState.error);
        await OfflineErrorHandler.show(context, const OfflineDisabledException());
      }
      return;
    }
    try {
      final list = await BusService.instance.fetchBusTime(
        widget.busInfo,
        Localizations.localeOf(context),
      );
      final goList = <BusTime>[];
      final backList = <BusTime>[];
      for (final item in list) {
        if (item.direction == BusDirection.back) {
          backList.add(item);
        } else {
          goList.add(item);
        }
      }
      if (mounted) {
        setState(() {
          _goList = goList;
          _backList = backList;
          _state = _BusTimeState.success;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _state = _BusTimeState.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GlassPageScaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.showAppBarLeading,
        title: Text(widget.busInfo.name),
        bottom: TabBar(
          controller: _tabController,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.subtitleText,
          indicatorColor: colorScheme.primary,
          tabs: [
            Tab(text: widget.busInfo.departure),
            Tab(text: widget.busInfo.destination),
          ],
        ),
      ),
      body: _buildBody(colorScheme),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    switch (_state) {
      case _BusTimeState.loading:
        return Center(
          child: CircularProgressIndicator(
            color: LayoutStyleNotifier.instance.isLiquidGlass
                ? colorScheme.primary
                : null,
          ),
        );
      case _BusTimeState.error:
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
      case _BusTimeState.success:
        if (_goList.isEmpty && _backList.isEmpty) {
          return InkWell(
            onTap: _fetchData,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline,
                      size: 48, color: colorScheme.subtitleText),
                  const SizedBox(height: 12),
                  Text('目前沒有班次資料',
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
        }
        return TabBarView(
          controller: _tabController,
          children: [
            _StopListView(stops: _goList, colorScheme: colorScheme),
            _StopListView(stops: _backList, colorScheme: colorScheme),
          ],
        );
    }
  }
}

class _StopListView extends StatelessWidget {
  final List<BusTime> stops;
  final ColorScheme colorScheme;

  const _StopListView({required this.stops, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        0,
        8,
        0,
        LayoutStyleNotifier.instance.isLiquidGlass ? 100 : 8,
      ),
      itemCount: stops.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: colorScheme.borderColor,
      ),
      itemBuilder: (context, index) {
        return _BusStopItem(
          busTime: stops[index],
          colorScheme: colorScheme,
        );
      },
    );
  }
}

class _BusStopItem extends StatelessWidget {
  final BusTime busTime;
  final ColorScheme colorScheme;

  const _BusStopItem({required this.busTime, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final bool isEnglish =
        Localizations.localeOf(context).languageCode.contains('en');

    String arrivedTimeText;
    Color arrivedColor;
    double? fontSize;

    switch (busTime.arrivalStatus) {
      case BusArrivalStatus.arriving:
        arrivedTimeText = isEnglish ? 'Arriving' : '進站中';
        arrivedColor = Colors.red;
      case BusArrivalStatus.comingSoon:
        arrivedTimeText = isEnglish ? 'Coming\nSoon' : '將到站';
        fontSize = 12.0;
        arrivedColor = Colors.green;
      case BusArrivalStatus.minutes:
        final postfix = isEnglish ? ' min' : ' 分鐘';
        arrivedTimeText = '${busTime.etaMinutes ?? 0}$postfix';
        arrivedColor = colorScheme.bodyText;
      case BusArrivalStatus.scheduled:
        arrivedTimeText = busTime.scheduledTime ?? '';
        arrivedColor = colorScheme.primary;
        fontSize = 12.0;
      case BusArrivalStatus.departed:
        arrivedTimeText = isEnglish ? 'Departed' : '已離站';
        arrivedColor = colorScheme.subtitleText;
        fontSize = 12.0;
      case BusArrivalStatus.notOperating:
        arrivedTimeText = isEnglish ? 'Out of\nservice' : '未行駛';
        arrivedColor = colorScheme.outline;
        fontSize = 12.0;
    }

    return ListTile(
      leading: Container(
        height: 40,
        width: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: arrivedColor),
          borderRadius: const BorderRadius.all(Radius.circular(32)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          arrivedTimeText,
          style: TextStyle(fontSize: fontSize, color: arrivedColor),
          textAlign: TextAlign.center,
        ),
      ),
      title: Text(
        busTime.name,
        style: TextStyle(color: colorScheme.primaryText),
      ),
    );
  }
}