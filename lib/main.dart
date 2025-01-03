import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fl_chart/fl_chart.dart'; // Adicione esta linha para o gráfico
import 'dart:io';
import 'dart:convert'; // Add this line to import 'utf8'
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;

void main() {
  WidgetsFlutterBinding.ensureInitialized(); // Adicione esta linha
  runApp(const MyApp());
}

class Waypoint {
  final double latitude;
  final double longitude;
  final double altitude;
  final double speed;

  Waypoint({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.speed,
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flight Planner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final List<Waypoint> _waypoints = [];
  LatLng _initialPosition = LatLng(51.5, -0.09); // Valor padrão
  final MapController _mapController =
      MapController(); // Adicione o controlador do mapa

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _initialPosition = LatLng(position.latitude, position.longitude);
    });
  }

  void _addWaypoint(LatLng point) {
    setState(() {
      _waypoints.add(Waypoint(
        latitude: point.latitude,
        longitude: point.longitude,
        altitude: 0.0, // Placeholder value
        speed: 0.0, // Placeholder value
      ));
    });
  }

  void _editWaypoint(int index, double altitude, double speed) {
    setState(() {
      _waypoints[index] = Waypoint(
        latitude: _waypoints[index].latitude,
        longitude: _waypoints[index].longitude,
        altitude: altitude,
        speed: speed / 3.6, // Corrigir a conversão de km/h para m/s
      );
    });
  }

  void _deleteWaypoint(int index) {
    setState(() {
      _waypoints.removeAt(index);
    });
  }

  Future<void> _exportWaypointsToCSV() async {
    List<List<dynamic>> rows = [
      ["Latitude", "Longitude", "Altitude", "Speed"]
    ];
    for (var waypoint in _waypoints) {
      List<dynamic> row = [];
      row.add(waypoint.latitude);
      row.add(waypoint.longitude);
      row.add(waypoint.altitude);
      row.add(waypoint.speed * 3.6); // Convertendo m/s para km/h
      rows.add(row);
    }

    String csv = const ListToCsvConverter().convert(rows);
    String formattedDate = DateTime.now().toIso8601String().split('T').first;
    String fileName = "flight_plan_$formattedDate.csv";

    if (kIsWeb) {
      // Lógica específica para web
      final bytes = utf8.encode(csv);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      final directory = await getApplicationDocumentsDirectory();
      final path = "${directory.path}/$fileName";
      final file = File(path);
      await file.writeAsString(csv);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Waypoints exportados para $path')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flight Planner'),
        leading: IconButton(
          icon: const Icon(Icons.airplanemode_active), // Ícone de avião
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) {
                final modelController = TextEditingController();
                final registrationController = TextEditingController();
                final maxSpeedController = TextEditingController();
                return AlertDialog(
                  title: const Text('Informações da Aeronave'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: modelController,
                        decoration: const InputDecoration(labelText: 'Modelo'),
                      ),
                      TextField(
                        controller: registrationController,
                        decoration:
                            const InputDecoration(labelText: 'Registro'),
                      ),
                      TextField(
                        controller: maxSpeedController,
                        decoration: const InputDecoration(
                            labelText: 'Velocidade Máxima (km/h)'),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () {
                        // Lógica para salvar as informações da aeronave
                        Navigator.of(context).pop();
                      },
                      child: const Text('Salvar'),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController, // Adicione o controlador do mapa
            options: MapOptions(
              initialCenter: _initialPosition,
              initialZoom: 15.0,
              onTap: (tapPosition, point) => _addWaypoint(point),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: ['a', 'b', 'c'],
              ),
              PolylineLayer(
                polylines: _createPolylines(),
              ),
              MarkerLayer(
                markers: _waypoints.map((wp) {
                  return Marker(
                    width: 80.0,
                    height: 80.0,
                    point: LatLng(wp.latitude, wp.longitude),
                    child: const Icon(Icons.location_on, color: Colors.red),
                  );
                }).toList(),
              ),
            ],
          ),
          Positioned(
            right: 10,
            top: 10,
            bottom: 10,
            child: Container(
              width: 350, // Aumentar a largura
              decoration: BoxDecoration(
                color: Colors.white, // Remover transparência
                borderRadius: BorderRadius.circular(10), // Bordas arredondadas
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Waypoints',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(
                          bottom: 80), // Adicionar padding inferior
                      itemCount: _waypoints.length,
                      itemBuilder: (context, index) {
                        final waypoint = _waypoints[index];
                        return ListTile(
                          title: Text('Waypoint ${index + 1}'),
                          subtitle: Text(
                              'Lat: ${waypoint.latitude.toStringAsFixed(5)}, Lng: ${waypoint.longitude.toStringAsFixed(5)}\n'
                              'Alt: ${waypoint.altitude.toStringAsFixed(0)} m, Speed: ${(waypoint.speed * 3.6).toStringAsFixed(0)} km/h'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) {
                                      final altitudeController =
                                          TextEditingController(
                                              text:
                                                  waypoint.altitude.toString());
                                      final speedController =
                                          TextEditingController(
                                              text: (waypoint.speed * 3.6)
                                                  .toStringAsFixed(0));
                                      return AlertDialog(
                                        title: const Text('Edit Waypoint'),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TextField(
                                              controller: altitudeController,
                                              decoration: const InputDecoration(
                                                  labelText: 'Altitude'),
                                              keyboardType:
                                                  TextInputType.number,
                                            ),
                                            TextField(
                                              controller: speedController,
                                              decoration: const InputDecoration(
                                                  labelText: 'Speed (km/h)'),
                                              keyboardType:
                                                  TextInputType.number,
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              _editWaypoint(
                                                index,
                                                double.parse(
                                                    altitudeController.text),
                                                double.parse(
                                                    speedController.text),
                                              );
                                              Navigator.of(context).pop();
                                            },
                                            child: const Text('Save'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () {
                                  _deleteWaypoint(index);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 230, // Ajustar para garantir que o botão apareça
            left: 20,
            child: FloatingActionButton(
              onPressed: () async {
                Position position = await Geolocator.getCurrentPosition();
                setState(() {
                  _initialPosition =
                      LatLng(position.latitude, position.longitude);
                });
                _mapController.move(_initialPosition,
                    15.0); // Mova o mapa para a localização atual
              },
              child: const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            bottom:
                20, // Ajustar para garantir que o botão não sobreponha a lista
            right: 20,
            child: SizedBox(
              width: 330, // Ajustar a largura para não passar do limite do card
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, // Cor verde
                  padding: const EdgeInsets.symmetric(
                      vertical: 15), // Espessura do botão
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5), // Menos arredondado
                  ),
                ),
                onPressed: _exportWaypointsToCSV,
                child: const Text('Salvar',
                    style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),
          ),
          Positioned(
            bottom: 10, // Adicionar margem inferior
            left: 20, // Adicionar margem esquerda
            right: 380, // Ajustar para não sobrepor o card dos waypoints
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16.0), // Adicionar padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Altitude',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(show: false),
                        titlesData: FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _waypoints
                                .asMap()
                                .entries
                                .map((e) =>
                                    FlSpot(e.key.toDouble(), e.value.altitude))
                                .toList(),
                            isCurved: false, // Linhas retas
                            color: Colors.blue,
                            barWidth: 4,
                            belowBarData: BarAreaData(show: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Polyline> _createPolylines() {
    List<Polyline> polylines = [];
    for (int i = 0; i < _waypoints.length - 1; i++) {
      final start = _waypoints[i];
      final end = _waypoints[i + 1];
      final gradientColors = _getGradientColorsForSpeed(start.speed, end.speed);
      polylines.add(
        Polyline(
          points: [
            LatLng(start.latitude, start.longitude),
            LatLng(end.latitude, end.longitude)
          ],
          strokeWidth: 4.0,
          gradientColors: gradientColors,
        ),
      );
    }
    return polylines;
  }

  List<Color> _getGradientColorsForSpeed(double startSpeed, double endSpeed) {
    return [
      _getColorForSpeed(startSpeed),
      _getColorForSpeed((startSpeed + endSpeed) / 2),
      _getColorForSpeed(endSpeed),
    ];
  }

  Color _getColorForSpeed(double speed) {
    final maxSpeed = _waypoints.isNotEmpty
        ? _waypoints.map((wp) => wp.speed).reduce((a, b) => a > b ? a : b)
        : 0.0;
    final minSpeed = _waypoints.isNotEmpty
        ? _waypoints.map((wp) => wp.speed).reduce((a, b) => a < b ? a : b)
        : 0.0;

    if (speed <= minSpeed) {
      return Colors.cyan;
    } else if (speed >= maxSpeed) {
      return Colors.red;
    } else {
      final ratio = (speed - minSpeed) / (maxSpeed - minSpeed);
      if (ratio < 0.5) {
        return Color.lerp(Colors.cyan, Colors.yellow, ratio * 2)!;
      } else {
        return Color.lerp(Colors.yellow, Colors.red, (ratio - 0.5) * 2)!;
      }
    }
  }
}
