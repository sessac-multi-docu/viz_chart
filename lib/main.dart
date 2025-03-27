import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';

void main() => runApp(InsuranceCsvApp());

class InsuranceCsvApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CSV 보험표',
      home: CsvTableScreen(),
    );
  }
}

String cleanTitle(String raw) {
  // "무)삼성화재 마이헬스" → "삼성화재"
  raw = raw.replaceAll('무)', '').trim(); // "삼성화재 마이헬스"
  List<String> parts = raw.split(' ');
  return parts.isNotEmpty ? parts[0] : raw; // "삼성화재"
}

class CsvTableScreen extends StatefulWidget {
  @override
  _CsvTableScreenState createState() => _CsvTableScreenState();
}

class _CsvTableScreenState extends State<CsvTableScreen> {
  List<List<dynamic>> csvTable = [];
  List<dynamic>? sumRowData;
  List<String> columnNames = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadCSV();
  }

  Future<void> loadCSV() async {
    final rawData = await rootBundle.loadString("assets/45m_nr_20y_100.csv");
    List<List<dynamic>> csvData = const CsvToListConverter().convert(rawData);

    final headers = csvData[0]; // 1행: 상품명 (DataTable용)
    final insurerNamesRow = csvData[1]; // 2행: 보험사명 (Chart 라벨용)
    final dataRows = csvData.skip(2).toList();

    final sumRowIndex =
        dataRows.indexWhere((row) => row[0].toString().contains('합계'));
    final sumRow = sumRowIndex != -1 ? dataRows.removeAt(sumRowIndex) : null;

    if (sumRow != null) {
      // 먼저 합계는 뺀 상태
      final targetIndex =
          dataRows.indexWhere((row) => row[0].toString().contains('상해후유장해'));

      // "상해후유장해" 위에 넣기
      if (targetIndex != -1) {
        dataRows.insert(targetIndex, sumRow);
      } else {
        dataRows.insert(2, sumRow); // 못 찾으면 그냥 2번째에 넣기
      }
    }

    setState(() {
      csvTable = [headers, ...dataRows];
      columnNames = insurerNamesRow.map((e) => e.toString()).toList(); // ✅ 여기!!
      sumRowData = sumRow;
      isLoading = false;
    });
  }

  Widget buildSumChart() {
    if (sumRowData == null || columnNames.isEmpty) return SizedBox();

    List<BarChartGroupData> barGroups = [];
    List<String> visibleLabels = [];
    List<double> values = [];

    int xIndex = 0;

    for (int i = 1; i < sumRowData!.length; i++) {
      final yValue = double.tryParse(
        sumRowData![i].toString().replaceAll(',', ''),
      );

      if (yValue != null && yValue > 0) {
        values.add(yValue);
        visibleLabels.add(columnNames[i]);

        barGroups.add(
          BarChartGroupData(
            x: xIndex,
            barRods: [
              BarChartRodData(
                toY: yValue,
                width: 18,
                borderRadius: BorderRadius.circular(6),
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.shade300,
                    Colors.blue.shade600,
                    Colors.indigo.shade700,
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ],
            showingTooltipIndicators: [0], // 👉 툴팁 표시할 인덱스
          ),
        );

        xIndex++;
      }
    }

    double chartWidth = visibleLabels.length * 120;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: chartWidth,
          height: 340,
          child: BarChart(
            BarChartData(
              barGroups: barGroups,
              alignment: BarChartAlignment.spaceAround,
              groupsSpace: 30,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  tooltipPadding: const EdgeInsets.all(8),
                  tooltipMargin: 8,
                  tooltipRoundedRadius: 8, // ✅ 둥글게
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final value = values[group.x.toInt()];
                    return BarTooltipItem(
                      '${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',')}원',
                      TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 80,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      final index = value.toInt();
                      if (index < visibleLabels.length) {
                        final label = cleanTitle(visibleLabels[index]);
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12, // ✅ 키움!
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        );
                      }
                      return SizedBox();
                    },
                  ),
                ),
                topTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 60,
                    interval: 100000,
                  ),
                ),
                rightTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(show: true),
              borderData: FlBorderData(show: false),
              maxY: values.isNotEmpty
                  ? values.reduce((a, b) => a > b ? a : b) + 50000
                  : 0,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final headers = csvTable.isNotEmpty ? csvTable.first : [];

    return Scaffold(
      appBar: AppBar(
        title: Text("김똘똘님 (남,19800101,보험연령:45세) 종합(무해지형)-20년/100세"),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ✅ 표 영역
                Expanded(
                  flex: 1,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        columns: headers.map((col) {
                          final colStr = col.toString();
                          final isInsuranceProduct =
                              colStr.startsWith('무)') || colStr.contains('무)');

                          return DataColumn(
                            label: Container(
                              constraints:
                                  BoxConstraints(minWidth: 80, maxWidth: 120),
                              child: isInsuranceProduct
                                  ? Tooltip(
                                      message: colStr,
                                      child: Text(
                                        colStr,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11),
                                        overflow: TextOverflow.ellipsis,
                                        softWrap: false,
                                      ),
                                    )
                                  : Text(
                                      colStr,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11),
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: false,
                                    ),
                            ),
                          );
                        }).toList(),
                        rows: csvTable.skip(1).map((row) {
                          final isSumRow = row[0].toString().contains('합계');

                          return DataRow(
                            cells: row.map((cell) {
                              return DataCell(
                                Container(
                                  constraints: BoxConstraints(
                                      minWidth: 80, maxWidth: 120),
                                  child: Text(
                                    cell.toString(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSumRow
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: false,
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),

                // ✅ 차트 영역
                if (sumRowData != null) ...[
                  SizedBox(height: 8),
                  Text(
                    "합계 금액 차트",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Expanded(
                    flex: 1,
                    child: buildSumChart(),
                  ),
                ],
              ],
            ),
    );
  }
}
