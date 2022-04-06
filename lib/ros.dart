import 'dart:async';

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:roslib/roslib.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:vector_math/vector_math.dart' show radians, Quaternion;

late var map_pixel_data;
late var map_width;
late var map_hiegth;
late var robot_x;
late var robot_y;

late var x_or;
late var y_or;
late var z_or;
late var w_or;
var map;
double WaveRadius = 0.0;

class DataProvider extends StatefulWidget {
  const DataProvider({Key? key}) : super(key: key);

  @override
  State<DataProvider> createState() => _DataProviderState();
}

class _DataProviderState extends State<DataProvider> {
  Ros ros = Ros(url: 'ws://10.10.0.101:9090');
  late Topic maptopic;
  late Topic robotOdomtopic;
  @override
  void initState() {
    ros;
    maptopic = Topic(
        ros: ros,
        name: '/map',
        type: "nav_msgs/OccupancyGrid",
        reconnectOnClose: true,
        queueLength: 10,
        queueSize: 10);

    robotOdomtopic = Topic(
        ros: ros,
        name: '/odom',
        type: "nav_msgs/Odometry",
        reconnectOnClose: true,
        queueLength: 10,
        queueSize: 10);

    super.initState();
  }

  void initConnection() async {
    ros.connect();
    await maptopic.subscribe();
    await robotOdomtopic.subscribe();

    setState(() {});
  }

  void destroyConnection() async {
    await maptopic.unsubscribe();
    await robotOdomtopic.unsubscribe();

    await ros.close();
    setState(() {});
  }

  Future<ui.Image> getMapasImage(final Color fill, final Color border) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(toRGBA(border: border, fill: fill), map_width,
        map_hiegth, ui.PixelFormat.rgba8888, completer.complete);
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              const SizedBox(
                height: 100,
              ),
              SingleChildScrollView(
                child: StreamBuilder(
                  stream: ros.statusStream,
                  builder: (context, snapshot) {
                    return Column(
                      children: [
                        StreamBuilder(
                            stream: maptopic.subscription,
                            builder: (context, mapData) {
                              if (mapData.hasData) {
                                if (mapData != null) {
                                  var data = (((mapData.data as Map)["msg"])
                                      as Map)["data"];
                                  var width = ((((mapData.data as Map)["msg"])
                                      as Map)["info"] as Map)["width"];
                                  var height = ((((mapData.data as Map)["msg"])
                                      as Map)["info"] as Map)["height"];
                                  map_pixel_data = data;
                                  map_hiegth = height;
                                  map_width = width;

                                  return InteractiveViewer(
                                    maxScale: 10,
                                    child: Container(
                                      width: double.infinity,
                                      child: Center(
                                        child: FutureBuilder(
                                          future: getMapasImage(
                                              Colors.grey, Colors.black),
                                          builder: (_, imageData) {
                                            var imgMap = imageData.data;
                                            if (imgMap == null) {
                                              return SizedBox();
                                            } else {
                                              return MapViewer(map: imgMap);
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                  // return Text("Data");
                                }
                              }
                              return CircularProgressIndicator();
                            }),
                        ActionChip(
                            backgroundColor: snapshot.data == Status.CONNECTED
                                ? Colors.green[300]
                                : Colors.red,
                            label: Icon(Icons.power_settings_new_rounded),
                            onPressed: () {
                              if (snapshot.data != Status.CONNECTED) {
                                this.initConnection();
                              } else {
                                this.destroyConnection();
                              }
                            }),
                        StreamBuilder(
                          stream: robotOdomtopic.subscription,
                          builder: (context, odomdata) {
                            if (odomdata.hasData) {
                              if (odomdata.data != null) {
                                robot_x = (((((odomdata.data as Map)["msg"]
                                        as Map)["pose"] as Map)["pose"]
                                    as Map)["position"] as Map)["x"];
                                robot_y = (((((odomdata.data as Map)["msg"]
                                        as Map)["pose"] as Map)["pose"]
                                    as Map)["position"] as Map)["y"];
                                x_or = (((((odomdata.data as Map)["msg"]
                                        as Map)["pose"] as Map)["pose"]
                                    as Map)["orientation"] as Map)["x"];
                                y_or = (((((odomdata.data as Map)["msg"]
                                        as Map)["pose"] as Map)["pose"]
                                    as Map)["orientation"] as Map)["y"];
                                z_or = (((((odomdata.data as Map)["msg"]
                                        as Map)["pose"] as Map)["pose"]
                                    as Map)["orientation"] as Map)["z"];
                                w_or = (((((odomdata.data as Map)["msg"]
                                        as Map)["pose"] as Map)["pose"]
                                    as Map)["orientation"] as Map)["w"];
                                //print("Robot x =======${robot_y}");
                              }
                            }
                            return const SizedBox();
                          },
                        )
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MapViewer extends StatefulWidget {
  final map;
  const MapViewer({Key? key, required this.map}) : super(key: key);

  @override
  State<MapViewer> createState() => _MapViewerState();
}

class _MapViewerState extends State<MapViewer> with TickerProviderStateMixin {
  double waveRadius = 0.0;
  double waveGap = 7.0;
  late Animation<double> _animation;
  late AnimationController controller;
  @override
  void initState() {
    controller = AnimationController(
        duration: Duration(milliseconds: 1500), vsync: this);
    controller.forward();
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.reset();
      } else if (status == AnimationStatus.dismissed) {
        controller.forward();
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    _animation = Tween(begin: 0.0, end: 7.0).animate(controller)
      ..addListener(() {
        setState(() {
          waveRadius = _animation.value;
        });
      });

    return FittedBox(
      child: SizedBox(
        height: map_hiegth.toDouble(),
        width: map_width.toDouble(),
        child: CustomPaint(
          painter: MapPainter(map: widget.map),
        ),
      ),
    );
  }
}

class MapPainter extends CustomPainter {
  var map;

  MapPainter({required this.map});

  var wavePaint2 = Paint()
    ..color = Colors.red
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.5
    ..isAntiAlias = true;

  var wavePaint = Paint()
    ..color = Colors.redAccent
    ..style = PaintingStyle.fill
    ..strokeWidth = 0.5
    ..isAntiAlias = true;
  var solidPaint = Paint()
    ..color = Colors.red
    ..style = PaintingStyle.fill
    ..strokeWidth = 0.5
    ..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    {
      canvas.translate(map_width / 2, map_hiegth / 2.5);
      canvas.rotate(radians(180));
      canvas.translate(-map_width / 2, -map_hiegth / 2);
      canvas.scale(1, -1);
      canvas.translate(0, -map_hiegth.toDouble());

      canvas.save();
      {
        canvas.translate(-6, -6);
        canvas.drawImage(map, Offset.zero, Paint());
      }
      canvas.restore();

      canvas.save();
      {
        double centerX = map_width / 2;
        double centerY = map_hiegth / 2;
        canvas.translate(centerX, centerY);
        final resolution = 0.05;
        if (true) {
          for (var i = -20; i <= 20; i++) {
            canvas.drawLine(
              Offset(i / resolution, -20 / resolution),
              Offset(i / resolution, 20 / resolution),
              Paint()..color = Colors.grey.withOpacity(0.3),
            );
            canvas.drawLine(
              Offset(-10 / resolution, i / resolution),
              Offset(10 / resolution, i / resolution),
              Paint()..color = Colors.grey.withOpacity(0.3),
            );
          }
        }
        double robotPositionX = (robot_x) / resolution;
        double robotPositionY = (robot_y) / resolution;

        var robotCenter = Offset(0, 0);
        var currentRadius = WaveRadius;
        bool drawOnce = true;

        canvas.save();
        canvas.translate(robotPositionX, robotPositionY);

        if (drawOnce) {
          canvas.save();
          var robotRotation = Quaternion(x_or, y_or, z_or, w_or);
          canvas.rotate(
              x_or < 0 ? robotRotation.radians : -robotRotation.radians);
          var rect = Rect.fromCircle(center: Offset(0, 0), radius: 15.0);
          var gradient = RadialGradient(colors: [
            Colors.amberAccent.withOpacity(0),
            Colors.amberAccent.withOpacity(0),
            Colors.cyanAccent.withOpacity(0.7),
            Colors.cyanAccent.withOpacity(0.0)
          ], stops: const [
            0,
            0.25,
            0.251,
            1.0
          ]);
          var paint = Paint()..shader = gradient.createShader(rect);

          canvas.drawPath(drawCone(15, 25), paint..isAntiAlias = true);
          canvas.restore();
          drawOnce = false;
        }
        canvas.drawCircle(
            robotCenter,
            currentRadius,
            wavePaint
              ..color = wavePaint.color.withOpacity(1 - currentRadius / 15));
        canvas.drawCircle(
            robotCenter,
            currentRadius,
            wavePaint
              ..color = wavePaint2.color.withOpacity(1 - currentRadius / 15));
        canvas.drawCircle(robotCenter, 1.5, solidPaint);
        canvas.restore();
      }
      canvas.restore();
    }
    canvas.restore();
  }

  Path drawCone(double radius, double angle) {
    angle /= 2;
    final shape = Path();
    Offset firstPoint = Offset(0, 0);
    Offset secondPoint = Offset(
        radius * math.cos(radians(-angle)), radius * math.sin(radians(-angle)));
    Offset thirdPoint = Offset(
        radius * math.cos(radians(angle)), radius * math.sin(radians(angle)));
    var rect = Rect.fromCircle(
      center: Offset(0, 0),
      radius: radius,
    );

    shape.moveTo(firstPoint.dx, firstPoint.dy);
    shape.lineTo(secondPoint.dx, secondPoint.dy);
    shape.arcToPoint(thirdPoint, radius: Radius.circular(radius));

    shape.close();
    return shape;
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return oldDelegate.hashCode != map.hashCode;
  }
}

Uint8List toRGBA({required Color border, required Color fill}) {
  var buffor = BytesBuilder();
  for (var value in map_pixel_data) {
    switch (value) {
      case -1:
        {
          buffor.add([0, 0, 0, 0]);
          break;
        }
      case 0:
        {
          buffor.add([fill.red, fill.green, fill.blue, fill.alpha]);
          break;
        }
      default:
        {
          buffor.add([border.red, border.green, border.blue, border.alpha]);
          break;
        }
    }
  }

  return buffor.takeBytes();
}
