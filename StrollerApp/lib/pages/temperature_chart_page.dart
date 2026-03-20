import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import '../models/app_state.dart';
import '../services/temperature_history_service.dart';

/// Temperature chart page showing current and historical temperature data
class TemperatureChartPage extends StatefulWidget {
  const TemperatureChartPage({super.key});

  @override
  State<TemperatureChartPage> createState() => _TemperatureChartPageState();
}

class _TemperatureChartPageState extends State<TemperatureChartPage> {
  final TemperatureHistoryService _tempHistoryService = TemperatureHistoryService();
  List<Map<String, dynamic>> _chartData = [];
  bool _isLoading = true;
  int _selectedHours = 1; // Default: last 1 hour

  @override
  void initState() {
    super.initState();
    _loadChartData();
  }

  /// Load temperature data for chart
  Future<void> _loadChartData() async {
    setState(() => _isLoading = true);
    
    final readings = await _tempHistoryService.getReadingsForHours(_selectedHours);
    
    // Prepare data for chart (limit to reasonable number of points)
    final dataPoints = readings.length > 100 
        ? readings.sublist(0, 100) // Show last 100 points if too many
        : readings;
    
    setState(() {
      _chartData = dataPoints.map((reading) {
        return {
          'x': reading.timestamp.millisecondsSinceEpoch.toDouble(),
          'y': reading.temperature,
          'time': reading.timestamp,
        };
      }).toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MyAppState>();
    final fanState = appState.fanState;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Temperature & Humidity History'),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.filter_list),
            onSelected: (hours) {
              setState(() => _selectedHours = hours);
              _loadChartData();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 1, child: Text('Last 1 hour')),
              const PopupMenuItem(value: 6, child: Text('Last 6 hours')),
              const PopupMenuItem(value: 24, child: Text('Last 24 hours')),
              const PopupMenuItem(value: 168, child: Text('Last week')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _chartData.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.show_chart, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No temperature/humidity data yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Data will appear after connecting to device',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Current Temperature & Humidity Card
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem(
                                'Temp',
                                '${fanState.currentTemperature.toStringAsFixed(1)}°C',
                                Colors.blue,
                              ),
                              _buildStatItem(
                                'Threshold',
                                '${fanState.thresholdTemperature.toStringAsFixed(1)}°C',
                                Colors.orange,
                              ),
                              _buildStatItem(
                                'Status',
                                fanState.isFanOn ? 'ON' : 'OFF',
                                fanState.isFanOn ? Colors.green : Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Chart
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Temperature & Humidity Trend (Last $_selectedHours hour${_selectedHours > 1 ? 's' : ''})',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 300,
                                child: LineChart(
                                  _buildChartData(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Statistics
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Statistics',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildStatistics(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  LineChartData _buildChartData() {
    if (_chartData.isEmpty) {
      return LineChartData();
    }

    // Find min/max for scaling across temperature & humidity
    final temps = _chartData.map((d) => d['temp'] as double).toList();
    final hums = _chartData
        .where((d) => d['hum'] != null)
        .map((d) => d['hum'] as double)
        .toList();

    double minVal = temps.reduce((a, b) => a < b ? a : b);
    double maxVal = temps.reduce((a, b) => a > b ? a : b);

    if (hums.isNotEmpty) {
      final minHum = hums.reduce((a, b) => a < b ? a : b);
      final maxHum = hums.reduce((a, b) => a > b ? a : b);
      minVal = min(minVal, minHum);
      maxVal = max(maxVal, maxHum);
    }

    final range = maxVal - minVal;
    final padding = range > 0 ? range * 0.1 : 5.0; // padding

    // Get threshold from state
    final appState = context.read<MyAppState>();
    final threshold = appState.fanState.thresholdTemperature;

    // Calculate time range for x-axis
    final firstTime = _chartData.first['time'] as DateTime;
    final lastTime = _chartData.last['time'] as DateTime;
    final timeRange = max(1.0, lastTime.difference(firstTime).inSeconds.toDouble());

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 2.0,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: Colors.grey[300]!,
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: _chartData.length > 10 ? _chartData.length / 5 : 1,
          getTitlesWidget: (value, meta) {
            if (_chartData.isEmpty) return const Text('');
            // Find closest data point to this x value
            final seconds = value.toInt();
            final targetTime = firstTime.add(Duration(seconds: seconds));
            
            Map<String, dynamic>? closest;
            double minDiff = double.infinity;
            for (final data in _chartData) {
              final time = data['time'] as DateTime;
              final diff = (time.difference(targetTime).inSeconds).abs().toDouble();
              if (diff < minDiff) {
                minDiff = diff;
                closest = data;
              }
            }
            
            if (closest != null && minDiff < 60) { // Within 1 minute
              final time = closest['time'] as DateTime;
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 10),
                ),
              );
            }
            return const Text('');
          },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 50,
            interval: 2.0,
            getTitlesWidget: (value, meta) {
              return Text(
                '${value.toStringAsFixed(0)}°',
                style: const TextStyle(fontSize: 10),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: Colors.grey[300]!),
      ),
      minX: 0,
      maxX: timeRange > 0 ? timeRange : 1,
      minY: minVal - padding,
      maxY: maxVal + padding,
      lineBarsData: [
        // Temperature line
        LineChartBarData(
          spots: _chartData.asMap().entries.map((entry) {
            final index = entry.key;
            final data = entry.value;
            final time = data['time'] as DateTime;
            final secondsFromStart = time.difference(firstTime).inSeconds.toDouble();
            return FlSpot(secondsFromStart, data['temp'] as double);
          }).toList(),
          isCurved: true,
          color: Colors.blue,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
        // Humidity line (if present)
        if (_chartData.any((d) => d['hum'] != null))
          LineChartBarData(
            spots: _chartData
                .asMap()
                .entries
                .where((entry) => entry.value['hum'] != null)
                .map((entry) {
              final data = entry.value;
              final time = data['time'] as DateTime;
              final secondsFromStart =
                  time.difference(firstTime).inSeconds.toDouble();
              return FlSpot(secondsFromStart, data['hum'] as double);
            }).toList(),
            isCurved: true,
            color: Colors.teal,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
        // Threshold line
        LineChartBarData(
          spots: [
            FlSpot(0, threshold),
            FlSpot(timeRange, threshold),
          ],
          isCurved: false,
          color: Colors.orange,
          barWidth: 2,
          dashArray: [5, 5],
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (List<LineBarSpot> touchedSpots) {
            return touchedSpots.map((LineBarSpot touchedSpot) {
              // Find closest data point
              final seconds = touchedSpot.x.toInt();
              final targetTime = firstTime.add(Duration(seconds: seconds));
              
              Map<String, dynamic>? closest;
              double minDiff = double.infinity;
              for (final data in _chartData) {
                final time = data['time'] as DateTime;
                final diff = (time.difference(targetTime).inSeconds).abs().toDouble();
                if (diff < minDiff) {
                  minDiff = diff;
                  closest = data;
                }
              }
              
              if (closest != null) {
                final time = closest['time'] as DateTime;
                final tempVal = closest['temp'] as double;
                final humVal = closest['hum'] as double?;
                final sb = StringBuffer()
                  ..write('${tempVal.toStringAsFixed(1)}°C');
                if (humVal != null) {
                  sb.write('\n${humVal.toStringAsFixed(1)}% RH');
                }
                sb.write(
                    '\n${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}');

                return LineTooltipItem(
                  sb.toString(),
                  const TextStyle(color: Colors.white),
                );
              }
              return LineTooltipItem(
                '${touchedSpot.y.toStringAsFixed(1)}',
                const TextStyle(color: Colors.white),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  Widget _buildStatistics() {
    if (_chartData.isEmpty) {
      return const Text('No data available');
    }

    final temperatures = _chartData.map((d) => d['temp'] as double).toList();
    final minTemp = temperatures.reduce((a, b) => a < b ? a : b);
    final maxTemp = temperatures.reduce((a, b) => a > b ? a : b);
    final avgTemp = temperatures.reduce((a, b) => a + b) / temperatures.length;

    final hums = _chartData
        .where((d) => d['hum'] != null)
        .map((d) => d['hum'] as double)
        .toList();

    double? minHum, maxHum, avgHum;
    if (hums.isNotEmpty) {
      minHum = hums.reduce((a, b) => a < b ? a : b);
      maxHum = hums.reduce((a, b) => a > b ? a : b);
      avgHum = hums.reduce((a, b) => a + b) / hums.length;
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('T Min', '${minTemp.toStringAsFixed(1)}°C', Colors.blue),
            _buildStatItem('T Max', '${maxTemp.toStringAsFixed(1)}°C', Colors.red),
            _buildStatItem('T Avg', '${avgTemp.toStringAsFixed(1)}°C', Colors.green),
          ],
        ),
        const SizedBox(height: 12),
        if (minHum != null && maxHum != null && avgHum != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('H Min', '${minHum.toStringAsFixed(1)}%', Colors.teal),
              _buildStatItem('H Max', '${maxHum.toStringAsFixed(1)}%', Colors.teal),
              _buildStatItem('H Avg', '${avgHum.toStringAsFixed(1)}%', Colors.teal),
            ],
          ),
      ],
    );
  }
}
