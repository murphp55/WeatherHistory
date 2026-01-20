import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

void main() {
  runApp(const WeatherHistoryApp());
}

class WeatherHistoryApp extends StatelessWidget {
  const WeatherHistoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather History',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F7A8C),
          surface: const Color(0xFFFFF9F2),
        ),
        useMaterial3: true,
      ),
      home: const WeatherHistoryPage(),
    );
  }
}

class WeatherHistoryPage extends StatefulWidget {
  const WeatherHistoryPage({super.key});

  @override
  State<WeatherHistoryPage> createState() => _WeatherHistoryPageState();
}

class _WeatherHistoryPageState extends State<WeatherHistoryPage> {
  final List<CityOption> _cityOptions = const [
    CityOption(
      label: 'Seattle, WA',
      place: Place(name: 'Seattle, WA', latitude: 47.6062, longitude: -122.3321),
    ),
    CityOption(
      label: 'New York, NY',
      place: Place(name: 'New York, NY', latitude: 40.7128, longitude: -74.0060),
    ),
    CityOption(
      label: 'Chicago, IL',
      place: Place(name: 'Chicago, IL', latitude: 41.8781, longitude: -87.6298),
    ),
    CityOption(
      label: 'Miami, FL',
      place: Place(name: 'Miami, FL', latitude: 25.7617, longitude: -80.1918),
    ),
    CityOption(
      label: 'Denver, CO',
      place: Place(name: 'Denver, CO', latitude: 39.7392, longitude: -104.9903),
    ),
  ];

  late CityOption _selectedCity = _cityOptions.first;

  bool _loading = false;
  String? _errorMessage;
  TodayWeather? _today;
  List<HistoryEntry> _history = [];

  Future<void> _search() async {
    final place = _selectedCity.place;
    if (_selectedCity.label.isEmpty) {
      setState(() {
        _errorMessage = 'Select a city to continue.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final todayDate = DateTime.now();
      final historyDates = List.generate(
        5,
        (index) => DateTime(todayDate.year - (index + 1), todayDate.month, todayDate.day),
      );

      final service = WeatherService();
      final todayData = await service.fetchTodayWeather(place);
      final historyResults = await Future.wait(
        historyDates.map((date) => service.fetchHistoricalWeather(place, date)),
      );

      setState(() {
        _today = todayData;
        _history = historyResults;
      });
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final historyRange = _history.isNotEmpty
        ? '${_history.last.year} - ${_history.first.year}'
        : '${now.year - 5} - ${now.year - 1}';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.2,
            colors: [
              Color(0xFFFFE8C8),
              Color(0xFFFFF4E4),
              Color(0xFFF3FAFC),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Weather History',
                  style: TextStyle(
                    fontSize: 14,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F7A8C),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Today, then the last five years.',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'See today\'s conditions and the same date back through time.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 24),
                _SearchCard(
                  selectedCity: _selectedCity,
                  cities: _cityOptions,
                  loading: _loading,
                  errorMessage: _errorMessage,
                  onSearch: _search,
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedCity = value;
                    });
                  },
                ),
                const SizedBox(height: 28),
                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: [
                    _InfoPanel(
                      title: 'Today',
                      subtitle: formatReadableDate(now),
                      child: _buildTodayContent(),
                    ),
                    _InfoPanel(
                      title: 'Same date, five years back',
                      subtitle: historyRange,
                      child: _buildHistoryContent(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Data powered by Open-Meteo. Results depend on location accuracy and data availability.',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTodayContent() {
    if (_loading) {
      return const _PanelPlaceholder(message: 'Fetching weather...');
    }
    if (_today == null) {
      return const _PanelPlaceholder(message: 'Select a city to see today\'s conditions.');
    }

    final today = _today!;
    final metrics = [
      MetricRow(label: 'Location', value: today.place.name),
      MetricRow(label: 'Current temp', value: formatTemp(today.currentTemp)),
      MetricRow(label: 'Feels like', value: formatTemp(today.apparentTemp)),
      MetricRow(label: 'Wind', value: formatWind(today.windSpeed)),
      MetricRow(label: 'Precip', value: formatPrecip(today.precipitation)),
      MetricRow(label: 'Forecast high', value: formatTemp(today.highTemp)),
      MetricRow(label: 'Forecast low', value: formatTemp(today.lowTemp)),
      MetricRow(label: 'Conditions', value: today.condition),
    ];

    return Column(
      children: metrics.map((metric) => _MetricTile(metric: metric)).toList(),
    );
  }

  Widget _buildHistoryContent() {
    if (_loading) {
      return const _PanelPlaceholder(message: 'Loading history...');
    }
    if (_history.isEmpty) {
      return const _PanelPlaceholder(message: 'Historical data will appear here.');
    }

    return Column(
      children: _history
          .map(
            (entry) => _HistoryCard(entry: entry),
          )
          .toList(),
    );
  }
}

class _SearchCard extends StatelessWidget {
  const _SearchCard({
    required this.selectedCity,
    required this.cities,
    required this.loading,
    required this.errorMessage,
    required this.onSearch,
    required this.onChanged,
  });

  final CityOption selectedCity;
  final List<CityOption> cities;
  final bool loading;
  final String? errorMessage;
  final VoidCallback onSearch;
  final ValueChanged<CityOption?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F202836),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'City or place',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<CityOption>(
            value: selectedCity,
            items: cities
                .map(
                  (city) => DropdownMenuItem(
                    value: city,
                    child: Text(city.label),
                  ),
                )
                .toList(),
            onChanged: loading ? null : onChanged,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0x331F7A8C)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF1F7A8C), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton(
                onPressed: loading ? null : onSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F7A8C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: const StadiumBorder(),
                ),
                child: Text(loading ? 'Loading...' : 'Get weather'),
              ),
            ],
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              errorMessage!,
              style: const TextStyle(color: Color(0xFFEF8354), fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 520),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1C1F2933),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                subtitle,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE1E6ED)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric});

  final MetricRow metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE1F3F8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            metric.label,
            style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
          ),
          Flexible(
            child: Text(
              metric.value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x33EF8354)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.year.toString(),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${entry.condition} ? High ${formatTemp(entry.high)} ? Low ${formatTemp(entry.low)} ? Precip ${formatPrecip(entry.precip)}',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

class _PanelPlaceholder extends StatelessWidget {
  const _PanelPlaceholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
    );
  }
}

class MetricRow {
  const MetricRow({required this.label, required this.value});

  final String label;
  final String value;
}

class Place {
  const Place({required this.name, required this.latitude, required this.longitude});

  final String name;
  final double latitude;
  final double longitude;
}

class CityOption {
  const CityOption({required this.label, required this.place});

  final String label;
  final Place place;
}

class TodayWeather {
  const TodayWeather({
    required this.place,
    required this.currentTemp,
    required this.apparentTemp,
    required this.windSpeed,
    required this.precipitation,
    required this.highTemp,
    required this.lowTemp,
    required this.condition,
  });

  final Place place;
  final double? currentTemp;
  final double? apparentTemp;
  final double? windSpeed;
  final double? precipitation;
  final double? highTemp;
  final double? lowTemp;
  final String condition;
}

class HistoryEntry {
  const HistoryEntry({
    required this.year,
    required this.high,
    required this.low,
    required this.precip,
    required this.condition,
  });

  final int year;
  final double? high;
  final double? low;
  final double? precip;
  final String condition;
}

class WeatherService {
  final HttpClient _client = HttpClient();

  Future<Place> geocodeLocation(String query) async {
    final uri = Uri.parse(
      'https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(query)}&count=1&language=en&format=json',
    );
    final data = await _getJson(uri);
    final results = data['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) {
      throw Exception('No matching locations found.');
    }
    final place = results.first as Map<String, dynamic>;
    final name = place['name']?.toString() ?? 'Unknown';
    final admin = place['admin1']?.toString();
    final country = place['country']?.toString();
    final label = [name, admin, country].where((part) => part != null && part!.isNotEmpty).join(', ');
    return Place(
      name: label,
      latitude: (place['latitude'] as num).toDouble(),
      longitude: (place['longitude'] as num).toDouble(),
    );
  }

  Future<TodayWeather> fetchTodayWeather(Place place) async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast?latitude=${place.latitude}&longitude=${place.longitude}&current=temperature_2m,apparent_temperature,precipitation,weathercode,wind_speed_10m&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,weathercode&timezone=auto',
    );
    final data = await _getJson(uri);
    final current = data['current'] as Map<String, dynamic>?;
    final daily = data['daily'] as Map<String, dynamic>?;

    final weatherCode = current?['weathercode'] as num?;
    return TodayWeather(
      place: place,
      currentTemp: toDouble(current?['temperature_2m']),
      apparentTemp: toDouble(current?['apparent_temperature']),
      windSpeed: toDouble(current?['wind_speed_10m']),
      precipitation: toDouble(current?['precipitation']),
      highTemp: toDouble(listFirst(daily?['temperature_2m_max'])),
      lowTemp: toDouble(listFirst(daily?['temperature_2m_min'])),
      condition: weatherCodeLabel(weatherCode),
    );
  }

  Future<HistoryEntry> fetchHistoricalWeather(Place place, DateTime date) async {
    final formatted = formatIsoDate(date);
    final uri = Uri.parse(
      'https://archive-api.open-meteo.com/v1/archive?latitude=${place.latitude}&longitude=${place.longitude}&start_date=$formatted&end_date=$formatted&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,weathercode&timezone=auto',
    );
    final data = await _getJson(uri);
    final daily = data['daily'] as Map<String, dynamic>?;
    final weatherCode = listFirst(daily?['weathercode']) as num?;
    return HistoryEntry(
      year: date.year,
      high: toDouble(listFirst(daily?['temperature_2m_max'])),
      low: toDouble(listFirst(daily?['temperature_2m_min'])),
      precip: toDouble(listFirst(daily?['precipitation_sum'])),
      condition: weatherCodeLabel(weatherCode),
    );
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final request = await _client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Unable to reach the weather service.');
    }
    final body = await response.transform(utf8.decoder).join();
    return jsonDecode(body) as Map<String, dynamic>;
  }
}

String weatherCodeLabel(num? code) {
  const map = {
    0: 'Clear sky',
    1: 'Mainly clear',
    2: 'Partly cloudy',
    3: 'Overcast',
    45: 'Fog',
    48: 'Rime fog',
    51: 'Light drizzle',
    53: 'Drizzle',
    55: 'Dense drizzle',
    61: 'Slight rain',
    63: 'Rain',
    65: 'Heavy rain',
    71: 'Slight snow',
    73: 'Snow',
    75: 'Heavy snow',
    80: 'Rain showers',
    81: 'Heavy showers',
    82: 'Violent showers',
    95: 'Thunderstorm',
    96: 'Thunderstorm with hail',
    99: 'Severe hail',
  };
  return map[code] ?? 'Unknown';
}

String formatTemp(double? value) {
  if (value == null) {
    return '-';
  }
  return '${value.toStringAsFixed(1)}?C';
}

String formatWind(double? value) {
  if (value == null) {
    return '-';
  }
  return '${value.toStringAsFixed(1)} km/h';
}

String formatPrecip(double? value) {
  if (value == null) {
    return '-';
  }
  return '${value.toStringAsFixed(1)} mm';
}

String formatReadableDate(DateTime date) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String formatIsoDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

Object? listFirst(Object? value) {
  if (value is List && value.isNotEmpty) {
    return value.first;
  }
  return null;
}

double? toDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return null;
}
