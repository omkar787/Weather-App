import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:weather_app/additional_information.dart';
import 'package:weather_app/hourly_forecast.dart';
import 'package:http/http.dart' as http;

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  String currentLocation = "London, UK";
  late Future<Map<String, dynamic>> weather;
  Position? _currentPosition;
  late List<Placemark> placemarks;

  Future<Map<String, dynamic>> getWeatherData() async {
    try {
      http.Response res;
      if (_currentPosition == null) {
        res = await http.get(
          Uri.parse(
            "https://api.openweathermap.org/data/2.5/forecast?q=$currentLocation&APPID=${dotenv.env["API_KEY"]}&units=metric",
          ),
        );
      } else {
        res = await http.get(
          Uri.parse(
            "https://api.openweathermap.org/data/2.5/forecast?lat=${_currentPosition?.latitude}&lon=${_currentPosition?.longitude}&APPID=${dotenv.env["API_KEY"]}&units=metric",
          ),
        );
      }

      final data = jsonDecode(res.body);

      if (data["cod"] != "200") {
        throw "An unexpected error occurred!";
      }

      return data;
    } catch (e) {
      throw e.toString();
    }
  }

  _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();

    try {
      if (serviceEnabled) {
        permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied ||
              permission == LocationPermission.deniedForever) {
            Fluttertoast.showToast(msg: "Please provide location access!");
          }
        }

        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          Position c = await Geolocator.getCurrentPosition(
              // desiredAccuracy: LocationAccuracy.high,
              );
          _currentPosition = c;
          placemarks = await placemarkFromCoordinates(c.latitude, c.longitude);

          setState(() {
            currentLocation =
                "${placemarks[0].locality}, ${placemarks[0].isoCountryCode}";
            // Fluttertoast.showToast(
            //     msg:
            //         "${placemarks[0].locality}, ${placemarks[0].isoCountryCode}");
            weather = getWeatherData();
          });
        }
      } else {
        Fluttertoast.showToast(msg: "Please enable location services!");
      }
    } catch (e) {
      print(e.toString());
    }
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    weather = getWeatherData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text(
              "Weather App",
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              currentLocation,
              style: const TextStyle(
                fontSize: 12,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _getCurrentLocation();
                weather = getWeatherData();
              });
            },
            icon: const Icon(Icons.refresh),
          )
        ],
      ),
      body: FutureBuilder(
        future: weather,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          final data = snapshot.data!;
          final currentWeatherData = data["list"][0];
          final currentTemp = currentWeatherData["main"]["temp"];
          final currentSky = currentWeatherData["weather"][0]["main"];
          final currentWindSpeed = currentWeatherData["wind"]["speed"];
          final currentHumidity = currentWeatherData["main"]["humidity"];
          final currentPressure = currentWeatherData["main"]["pressure"];

          String returnHours(int timeStamp) {
            final datetime =
                DateTime.fromMillisecondsSinceEpoch(timeStamp * 1000);
            return DateFormat.j().format(datetime).toString();
          }

          String returnDate(int timeStamp) {
            final datetime =
                DateTime.fromMillisecondsSinceEpoch(timeStamp * 1000);
            return DateFormat("dd/yy").format(datetime).toString();
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main Card
                SizedBox(
                  width: double.infinity,
                  child: Card(
                    elevation: 10,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Column(
                            children: [
                              Text(
                                "$currentTemp °C",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 32,
                                ),
                              ),
                              const SizedBox(height: 15),
                              Icon(
                                currentSky == "Clouds" || currentSky == "Rain"
                                    ? Icons.cloud
                                    : Icons.sunny,
                                size: 64,
                              ),
                              const SizedBox(height: 15),
                              Text(
                                currentSky,
                                style: const TextStyle(
                                  fontSize: 20,
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                // Weather Forecast
                const Text(
                  "Hourly Forecast",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
                SizedBox(
                  height: 155,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 39,
                    itemBuilder: (context, index) {
                      final dt = data["list"][index + 1];
                      return HourlyForecastItem(
                        time: returnHours(dt["dt"]),
                        date: returnDate(dt["dt"]),
                        icon: dt["weather"][0]["main"],
                        temperature: "${dt["main"]["temp"].toString()} °C",
                      );
                    },
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                // Additional Information
                const Text(
                  "Additional Information",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    AdditionalInformation(
                      icon: Icons.water_drop,
                      label: "Humidity",
                      value: "$currentHumidity",
                    ),
                    AdditionalInformation(
                      icon: Icons.air,
                      label: "Wind Speed",
                      value: "$currentWindSpeed km/hr",
                    ),
                    AdditionalInformation(
                      icon: Icons.beach_access,
                      label: "Pressure",
                      value: "$currentPressure",
                    ),
                  ],
                )
              ],
            ),
          );
        },
      ),
    );
  }
}
