import 'package:flutter/material.dart';
import 'package:chcg_iot_app/core/api_service.dart';
import 'package:chcg_iot_app/pages/home_tabs/disease_query/bug_usage_row_detail_page.dart';

class BugListPage extends StatefulWidget {
  const BugListPage({
    super.key,
    required this.farmParam,
    required this.bug,
    required this.cropName,
    required this.bugName,
  });

  /// 例： "101,102,103"
  final String farmParam;
  final String bug;
  final String cropName;
  final String bugName;

  @override
  State<BugListPage> createState() => _BugListPageState();
}

class _BugListPageState extends State<BugListPage> {
  final DiseaseApiService _api = DiseaseApiService();
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  bool _loading = false;
  String? _error;
  List<dynamic> _items = [];
  List<dynamic> _columns = [];
  String _title = '';

  static const Color _primaryColor = Color(0xFF7B4DBB);

  @override
  void initState() {
    super.initState();
    _loadBugList();
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  Future<void> _loadBugList() async {
    setState(() {
      _loading = true;
      _error = null;
      _items = [];
      _columns = [];
      _title = '';
    });

    try {
      final farmCodes =
          widget.farmParam
              .split(',')
              .map((farm) => farm.trim())
              .where((farm) => farm.isNotEmpty)
              .toList();
      if (farmCodes.isEmpty) {
        throw StateError('未提供有效的作物代碼。');
      }

      var bugCode = widget.bug.trim();
      final isBugCode = RegExp(r'^[A-Za-z][A-Za-z0-9]*$').hasMatch(bugCode);
      if (bugCode.isNotEmpty && !isBugCode) {
        final lookup = await _api.fetchBugs(bug: bugCode);
        final matches = lookup['items'];
        if (matches is! List) {
          throw const FormatException('病蟲查詢回應格式錯誤。');
        }

        final candidates =
            matches.whereType<Map>().where((match) {
              final name = match['instn1']?.toString().trim() ?? '';
              final id = match['instid']?.toString().trim() ?? '';
              return id.isNotEmpty && name.isNotEmpty;
            }).toList();
        if (candidates.isEmpty) {
          throw StateError('找不到「$bugCode」對應的病蟲代碼，請調整關鍵字後再試。');
        }

        final exactMatches =
            candidates
                .where((match) => match['instn1'].toString().trim() == bugCode)
                .toList();
        final selected =
            exactMatches.isNotEmpty ? exactMatches.first : candidates.first;
        bugCode = selected['instid'].toString().trim();
      }

      final responseRequests = <Future<Map<String, dynamic>?>>[];
      final responseLabels = <String>[];

      if (bugCode.isNotEmpty) {
        for (final farm in farmCodes) {
          responseRequests.add(
            _api.fetchBugFarmUserange(farm: farm, bug: bugCode),
          );
          responseLabels.add('作物代碼 $farm');
        }
      } else {
        final bugLists = await Future.wait(
          farmCodes.map((farm) => _api.fetchBugFarmList(farm: farm)),
        );

        for (var index = 0; index < bugLists.length; index++) {
          final bugList = bugLists[index];
          if (bugList == null) {
            throw Exception('查詢作物代碼 ${farmCodes[index]} 的病蟲清單失敗。');
          }

          final rawBugItems = bugList['items'];
          if (rawBugItems is! List) {
            throw const FormatException('病蟲清單回應格式錯誤。');
          }

          final bugCodes =
              rawBugItems
                  .whereType<Map>()
                  .map((item) => item['bug_code']?.toString().trim() ?? '')
                  .where((code) => code.isNotEmpty)
                  .toSet();

          for (final code in bugCodes) {
            responseRequests.add(
              _api.fetchBugFarmUserange(farm: farmCodes[index], bug: code),
            );
            responseLabels.add('作物代碼 ${farmCodes[index]}、病蟲代碼 $code');
          }
        }
      }

      final responses = await Future.wait(responseRequests);
      final items = <dynamic>[];
      final columns = <dynamic>[];
      final titles = <String>{};

      for (var index = 0; index < responses.length; index++) {
        final response = responses[index];
        if (response == null) {
          throw Exception('查詢${responseLabels[index]}的用藥資料失敗。');
        }

        final rawItems = response['items'];
        final rawColumns = response['columns'];
        if (rawItems is List) {
          items.addAll(rawItems);
        }
        if (columns.isEmpty && rawColumns is List) {
          columns.addAll(rawColumns);
        }
        final title = response['title']?.toString() ?? '';
        if (title.isNotEmpty) {
          titles.add(title);
        }
      }

      if (columns.isEmpty && items.isNotEmpty && items.first is Map) {
        final firstRow = items.first as Map;
        columns.addAll(
          firstRow.keys.map(
            (key) => {'key': key.toString(), 'label': key.toString()},
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        _items = items;
        _columns = columns;
        _title = bugCode.isEmpty ? '${widget.cropName} 用藥清單' : titles.join('、');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '查詢用藥資料失敗：$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _openRowDetail(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => BugUsageRowDetailPage(
              columns: _columns,
              rowData: item,
              cropName: widget.cropName,
              bugName: widget.bugName,
            ),
      ),
    );
  }

  Map<String, dynamic> _asRow(dynamic item) {
    if (item is! Map) return <String, dynamic>{};
    return item.map((key, value) => MapEntry(key.toString(), value));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
      appBar: AppBar(
        title: Text(
          _title.isEmpty ? '用藥清單' : _title,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
        ),
        centerTitle: true,
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 40, color: Colors.red.shade400),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                onPressed: _loadBugList,
                icon: const Icon(Icons.refresh),
                label: const Text('重新整理'),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return const Center(
        child: Text('查無用藥資料。', style: TextStyle(color: Colors.grey)),
      );
    }

    final columns = _columns.whereType<Map>().toList();
    return RefreshIndicator(
      onRefresh: _loadBugList,
      child: Scrollbar(
        controller: _verticalController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _verticalController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '共找到 ${_items.length} 筆用藥資料',
                      style: const TextStyle(
                        fontSize: 13,
                        color: _primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '點擊資料列可查看完整用藥資料。',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Scrollbar(
                  controller: _horizontalController,
                  thumbVisibility: true,
                  notificationPredicate:
                      (notification) =>
                          notification.metrics.axis == Axis.horizontal,
                  child: SingleChildScrollView(
                    controller: _horizontalController,
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: [
                        for (final column in columns)
                          DataColumn(
                            label: Text(
                              column['label']?.toString() ??
                                  column['key']?.toString() ??
                                  '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                      rows: [
                        for (var index = 0; index < _items.length; index++)
                          _buildDataRow(_asRow(_items[index]), columns),
                      ],
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 16, bottom: 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '資料來源：農業部動植物防疫檢疫署',
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  DataRow _buildDataRow(Map<String, dynamic> item, List<Map> columns) {
    return DataRow(
      onSelectChanged: (_) => _openRowDetail(item),
      cells: [
        for (final column in columns)
          DataCell(
            Text(
              (item[column['key']?.toString()] ?? '').toString(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}
