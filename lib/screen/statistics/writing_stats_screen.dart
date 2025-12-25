import 'dart:math';
import 'package:aiwriting_collection/api.dart';
import 'package:aiwriting_collection/model/common/type_enum.dart';
import 'package:aiwriting_collection/model/content/stats.dart';
import 'package:aiwriting_collection/model/provider/login_status.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum _MetricType { stepsPerDay, scoreTrend, clearRate }
enum _ScopeType { word, sentence, all }

class WritingStatsScreen extends StatefulWidget {
  const WritingStatsScreen({super.key});

  @override
  State<WritingStatsScreen> createState() => _WritingStatsScreenState();
}

class _WritingStatsScreenState extends State<WritingStatsScreen> {
  final Api _api = Api();
  bool _isLoading = false;
  String? _error;
  List<Stats> _stats = [];
  _MetricType _metric = _MetricType.stepsPerDay;
  _ScopeType _scope = _ScopeType.word;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    final userId = context.read<LoginStatus>().userId;
    if (userId == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _api.getUserStats(userId);
      setState(() {
        _stats = data;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Stats> get _filtered {
    switch (_scope) {
      case _ScopeType.word:
        return _stats.where((s) => s.stepType == WritingType.WORD).toList();
      case _ScopeType.sentence:
        return _stats.where((s) => s.stepType == WritingType.SENTENCE).toList();
      case _ScopeType.all:
        return _stats;
    }
  }

  List<_BarPoint> _buildBarPoints() {
    final list = _filtered;
    if (list.isEmpty) return [];
    final Map<String, List<Stats>> byDay = {};
    for (final s in list) {
      final key =
          '${s.submissionTime.month.toString().padLeft(2, '0')}/${s.submissionTime.day.toString().padLeft(2, '0')}';
      byDay.putIfAbsent(key, () => []).add(s);
    }
    final entries = byDay.entries.toList()
      ..sort(
        (a, b) => a.value.first.submissionTime.compareTo(
          b.value.first.submissionTime,
        ),
      );

    final points = <_BarPoint>[];
    for (final e in entries) {
      switch (_metric) {
        case _MetricType.stepsPerDay:
          points.add(_BarPoint(label: e.key, value: e.value.length.toDouble()));
          break;
        case _MetricType.scoreTrend:
          final avg =
              e.value.map((s) => s.score).reduce((a, b) => a + b) /
              e.value.length;
          points.add(_BarPoint(label: e.key, value: avg));
          break;
        case _MetricType.clearRate:
          final cleared = e.value.where((s) => s.isCleared).length;
          final double rate =
              e.value.isEmpty ? 0.0 : (cleared / e.value.length) * 100.0;
          points.add(_BarPoint(label: e.key, value: rate));
          break;
      }
    }
    if (points.length > 7) {
      return points.sublist(points.length - 7);
    }
    return points;
  }

  String _metricLabel(_MetricType type) {
    switch (type) {
      case _MetricType.stepsPerDay:
        return '일자별 스텝 개수';
      case _MetricType.scoreTrend:
        return '점수 추이 변화';
      case _MetricType.clearRate:
        return '클리어 확률';
    }
  }

  String _scopeLabel(_ScopeType type) {
    switch (type) {
      case _ScopeType.word:
        return '단어';
      case _ScopeType.sentence:
        return '문장';
      case _ScopeType.all:
        return '전체';
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    final basePortrait = 390.0;
    final baseLandscape = 844.0;
    final scale =
        isLandscape ? size.height / baseLandscape : size.width / basePortrait;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFBF3),
        elevation: 0,
        title: const Text('글씨 점수 통계', style: TextStyle(color: Colors.black87)),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Padding(
        padding: EdgeInsets.all(16 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMetricTabs(scale),
            SizedBox(height: 12 * scale),
            Row(
              children: [
                _SpeechBubble(scale: scale),
                SizedBox(width: 12 * scale),
                Expanded(
                  child: Text(
                    '얼마나 공부했는지 한 눈에 확인해 볼까요?',
                    style: TextStyle(
                      fontSize: 16 * scale,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
                _buildScopeSelector(scale),
              ],
            ),
            SizedBox(height: 16 * scale),
            Expanded(
              child: _buildGraphCard(scale),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTabs(double scale) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: _MetricType.values.map((m) {
        final selected = m == _metric;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4 * scale),
            child: GestureDetector(
              onTap: () => setState(() => _metric = m),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 10 * scale,
                  vertical: 12 * scale,
                ),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFCEEF91) : Colors.white,
                  border: Border.all(color: Colors.black26),
                  borderRadius: BorderRadius.circular(12 * scale),
                ),
                child: Center(
                  child: Text(
                    _metricLabel(m),
                    style: TextStyle(
                      fontSize: 14 * scale,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildScopeSelector(double scale) {
    return PopupMenuButton<_ScopeType>(
      onSelected: (v) => setState(() => _scope = v),
      itemBuilder: (context) {
        return _ScopeType.values
            .map(
              (e) => PopupMenuItem(
                value: e,
                child: Text(_scopeLabel(e)),
              ),
            )
            .toList();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 10 * scale),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black26),
          borderRadius: BorderRadius.circular(12 * scale),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_drop_down, color: Colors.black87),
            SizedBox(width: 6 * scale),
            Text(
              _scopeLabel(_scope),
              style: TextStyle(
                fontSize: 14 * scale,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraphCard(double scale) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(color: Colors.redAccent),
        ),
      );
    }
    final points = _buildBarPoints();
    if (points.isEmpty) {
      return Center(
        child: Text(
          '아직 통계가 없어요.',
          style: TextStyle(fontSize: 16 * scale, color: Colors.black54),
        ),
      );
    }
    final maxValue =
        points.map((p) => p.value).fold<double>(0, (p, e) => max(p, e));
    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16 * scale),
        border: Border.all(color: Colors.black12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${_metricLabel(_metric)} · ${_scopeLabel(_scope)}',
            style: TextStyle(
              fontSize: 16 * scale,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 12 * scale),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: points.map((p) {
                  final double h =
                      maxValue == 0 ? 0.0 : (p.value / maxValue) * 140.0 * scale;
                  final double barHeight = h < 12 * scale ? 12 * scale : h;
                  const double barBaseWidth = 32;
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8 * scale),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          p.value.toStringAsFixed(
                            _metric == _MetricType.clearRate ? 0 : 1,
                          ),
                          style: TextStyle(
                            fontSize: 12 * scale,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 6 * scale),
                        Container(
                          width: barBaseWidth * scale,
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCEEF91),
                            borderRadius: BorderRadius.circular(12 * scale),
                          ),
                        ),
                        SizedBox(height: 8 * scale),
                        Text(
                          p.label,
                          style: TextStyle(
                            fontSize: 12 * scale,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarPoint {
  final String label;
  final double value;
  _BarPoint({required this.label, required this.value});
}

class _SpeechBubble extends StatelessWidget {
  final double scale;
  const _SpeechBubble({required this.scale});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 50 * scale,
          height: 50 * scale,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(
              image: AssetImage('assets/character/bearTeacher_noblank.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ],
    );
  }
}
