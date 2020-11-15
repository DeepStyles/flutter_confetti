import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:random_color/random_color.dart';
import 'package:vector_math/vector_math.dart' as vmath;

import 'package:confetti/src/helper.dart';
// import 'package:';
import 'enums/blast_directionality.dart';

enum ParticleSystemStatus {
  started,
  finished,
  stopped,
}

class ParticleSystem extends ChangeNotifier {
  ParticleSystem(
      {@required double emissionFrequency,
      @required int numberOfParticles,
      @required double maxBlastForce,
      @required double minBlastForce,
      @required double blastDirection,
      @required BlastDirectionality blastDirectionality,
      @required List<Color> colors,
      @required Size minimumSize,
      @required Size maximumsize,
      @required double particleDrag,
      @required double gravity})
      : assert(
          emissionFrequency != null &&
              numberOfParticles != null &&
              maxBlastForce != null &&
              minBlastForce != null &&
              blastDirection != null &&
              minimumSize != null &&
              maximumsize != null &&
              particleDrag != null &&
              blastDirectionality != null,
        ),
        assert(maxBlastForce > 0 &&
            minBlastForce > 0 &&
            emissionFrequency >= 0 &&
            emissionFrequency <= 1 &&
            numberOfParticles > 0 &&
            minimumSize.width > 0 &&
            minimumSize.height > 0 &&
            maximumsize.width > 0 &&
            maximumsize.height > 0 &&
            minimumSize.width <= maximumsize.width &&
            minimumSize.height <= maximumsize.height &&
            particleDrag >= 0.0 &&
            particleDrag <= 1 &&
            minimumSize.height <= maximumsize.height),
        assert(gravity >= 0 && gravity <= 1),
        _blastDirection = blastDirection,
        _blastDirectionality = blastDirectionality,
        _gravity = gravity,
        _maxBlastForce = maxBlastForce,
        _minBlastForce = minBlastForce,
        _frequency = emissionFrequency,
        _numberOfParticles = numberOfParticles,
        _colors = colors,
        _minimumSize = minimumSize,
        _maximumSize = maximumsize,
        _particleDrag = particleDrag,
        _rand = Random();

  ParticleSystemStatus _particleSystemStatus;

  final List<Particle> _particles = [];

  /// A frequency between 0 and 1 to determine how often the emitter
  /// should emit new particles.
  final double _frequency;
  final int _numberOfParticles;
  final double _maxBlastForce;
  final double _minBlastForce;
  final double _blastDirection;
  final BlastDirectionality _blastDirectionality;
  final double _gravity;
  final List<Color> _colors;
  final Size _minimumSize;
  final Size _maximumSize;
  final double _particleDrag;

  Offset _particleSystemPosition;
  Size _screenSize;

  double _bottomBorder;
  double _rightBorder;
  double _leftBorder;

  final Random _rand;

  set particleSystemPosition(Offset position) {
    _particleSystemPosition = position;
  }

  set screenSize(Size size) {
    _screenSize = size;
    _setScreenBorderPositions(); // needs to be called here to only set the borders once
  }

  void stopParticleEmission() {
    _particleSystemStatus = ParticleSystemStatus.stopped;
  }

  void startParticleEmission() {
    _particleSystemStatus = ParticleSystemStatus.started;
  }

  void finishParticleEmission() {
    _particleSystemStatus = ParticleSystemStatus.finished;
  }

  List<Particle> get particles => _particles;
  ParticleSystemStatus get particleSystemStatus => _particleSystemStatus;

  void update() {
    _clean();
    if (_particleSystemStatus != ParticleSystemStatus.finished) {
      _updateParticles();
    }

    if (_particleSystemStatus == ParticleSystemStatus.started) {
      // If there are no particles then immediately generate particles
      // This also ensures that particles are emitted on the first frame
      if (particles.isEmpty) {
        _particles.addAll(_generateParticles(number: _numberOfParticles));
        return;
      }

      // Determines whether to generate new particles based on the [frequency]
      final chanceToGenerate = _rand.nextDouble();
      if (chanceToGenerate < _frequency) {
        _particles.addAll(_generateParticles(number: _numberOfParticles));
      }
    }

    if (_particleSystemStatus == ParticleSystemStatus.stopped &&
        _particles.isEmpty) {
      finishParticleEmission();
      notifyListeners();
    }
  }

  void _setScreenBorderPositions() {
    _bottomBorder = _screenSize.height * 1.1;
    _rightBorder = _screenSize.width * 1.1;
    _leftBorder = _screenSize.width - _rightBorder;
  }

  void _updateParticles() {
    if (particles == null) {
      return;
    }
    for (final particle in _particles) {
      particle.update();
    }
  }

  void _clean() {
    if (_particleSystemPosition != null &&
        _screenSize != null &&
        particles != null) {
      _particles
          .removeWhere((particle) => _isOutsideOfBorder(particle.location));
    }
  }

  bool _isOutsideOfBorder(Offset particleLocation) {
    final globalParticlePosition = particleLocation + _particleSystemPosition;
    return (globalParticlePosition.dy >= _bottomBorder) ||
        (globalParticlePosition.dx >= _rightBorder) ||
        (globalParticlePosition.dx <= _leftBorder);
  }

  List<Particle> _generateParticles({int number = 1}) {
    return List<Particle>.generate(
        number,
        (i) => Particle(_generateParticleForce(), _randomColor(), _randomSize(),
            _gravity, _particleDrag));
  }

  double get _randomBlastDirection =>
      vmath.radians(Random().nextInt(359).toDouble());

  vmath.Vector2 _generateParticleForce() {
    var blastDirection = _blastDirection;
    if (_blastDirectionality == BlastDirectionality.explosive) {
      blastDirection = _randomBlastDirection;
    }
    final blastRadius = randomize(_minBlastForce, _maxBlastForce);
    final y = blastRadius * sin(blastDirection);
    final x = blastRadius * cos(blastDirection);
    return vmath.Vector2(x, y);
  }

  Color _randomColor() {
    if (_colors != null) {
      if (_colors.length == 1) {
        return _colors[0];
      }
      final index = _rand.nextInt(_colors.length);
      return _colors[index];
    }
    return RandomColor().randomColor();
  }

  Size _randomSize() {
    return Size(
      randomize(_minimumSize.width, _maximumSize.width),
      randomize(_minimumSize.height, _maximumSize.height),
    );
  }
}

class Particle {
  Particle(vmath.Vector2 startUpForce, Color color, Size size, double gravity,
      double particleDrag)
      : _startUpForce = startUpForce,
        _color = color,
        _mass = randomize(1, 11),
        _particleDrag = particleDrag,
        _location = vmath.Vector2.zero(),
        _acceleration = vmath.Vector2.zero(),
        _velocity = vmath.Vector2(randomize(-3, 3), randomize(-3, 3)),
        // _size = size,
        // _pathShape = createPath,
        _pathShape = functions[Random().nextInt(9)](size),
        _aVelocityX = randomize(-0.1, 0.1),
        _aVelocityY = randomize(-0.1, 0.1),
        _aVelocityZ = randomize(-0.1, 0.1),
        _gravity = lerpDouble(0.1, 5, gravity);

  final vmath.Vector2 _startUpForce;

  static List<Function> functions = [
    retPath1,
    retPath2,
    retPath3,
    retPath4,
    retPath5,
    retPath6,
    retPath7,
    retPath8,
    retPath9,
  ];

  final vmath.Vector2 _location;
  final vmath.Vector2 _velocity;
  final vmath.Vector2 _acceleration;

  final double _particleDrag;
  double _aX = 0;
  double _aVelocityX;
  double _aY = 0;
  double _aVelocityY;
  double _aZ = 0;
  double _aVelocityZ;
  final double _gravity;
  final _aAcceleration = 0.0001;

  final Color _color;
  final double _mass;
  final Path _pathShape;

  double _timeAlive = 0;

  static Path createPath(Size size) {
    final pathShape = Path();
    pathShape.moveTo(0, 0);
    pathShape.lineTo(-size.width, 0);
    pathShape.lineTo(-size.width, size.height);
    pathShape.lineTo(0, size.height);
    pathShape.close();
    return pathShape;
  }

  void applyForce(vmath.Vector2 force) {
    final f = force.clone();
    f.divide(vmath.Vector2.all(_mass));
    _acceleration.add(f);
  }

  void drag() {
    final speed = sqrt(pow(_velocity.x, 2) + pow(_velocity.y, 2));
    final dragMagnitude = _particleDrag * speed * speed;
    final drag = _velocity.clone();
    drag.multiply(vmath.Vector2.all(-1));
    drag.normalize();
    drag.multiply(vmath.Vector2.all(dragMagnitude));
    applyForce(drag);
  }

  void _applyStartUpForce() {
    applyForce(_startUpForce);
  }

  void _applyWindForceUp() {
    applyForce(vmath.Vector2(0, -1));
  }

  void update() {
    drag();

    if (_timeAlive < 5) {
      _applyStartUpForce();
    }
    if (_timeAlive < 25) {
      _applyWindForceUp();
    }

    _timeAlive += 1;

    applyForce(vmath.Vector2(0, _gravity));

    _velocity.add(_acceleration);
    _location.add(_velocity);
    _acceleration.setZero();

    _aVelocityX += _aAcceleration / _mass;
    _aVelocityY += _aAcceleration / _mass;
    _aVelocityZ += _aAcceleration / _mass;
    _aX += _aVelocityX;
    _aY += _aVelocityY;
    _aZ += _aVelocityZ;
  }

  Offset get location {
    if (_location.x.isNaN || _location.y.isNaN) {
      return const Offset(0, 0);
    }
    return Offset(_location.x, _location.y);
  }

  Color get color => _color;
  Path get path => _pathShape;

  double get angleX => _aX;
  double get angleY => _aY;
  double get angleZ => _aZ;

  static Path retPath9(Size size) {
    Path path_0 = Path();
    path_0.moveTo(size.width * 0.38, size.height * 0.75);
    path_0.quadraticBezierTo(size.width * 0.40, size.height * 0.75,
        size.width * 0.50, size.height * 0.75);
    path_0.cubicTo(size.width * 0.58, size.height * 0.73, size.width * 0.60,
        size.height * 0.68, size.width * 0.63, size.height * 0.63);
    path_0.cubicTo(size.width * 0.63, size.height * 0.54, size.width * 0.63,
        size.height * 0.46, size.width * 0.63, size.height * 0.38);
    path_0.cubicTo(size.width * 0.63, size.height * 0.30, size.width * 0.55,
        size.height * 0.25, size.width * 0.50, size.height * 0.25);
    path_0.cubicTo(size.width * 0.46, size.height * 0.25, size.width * 0.38,
        size.height * 0.28, size.width * 0.38, size.height * 0.38);
    path_0.cubicTo(size.width * 0.38, size.height * 0.45, size.width * 0.42,
        size.height * 0.50, size.width * 0.50, size.height * 0.50);
    path_0.quadraticBezierTo(size.width * 0.58, size.height * 0.50,
        size.width * 0.63, size.height * 0.38);

    path_0.close();
    return path_0;
  }

  static Path retPath8(Size size) {
    Path path_0 = Path();
    path_0.moveTo(size.width * 0.50, size.height * 0.13);
    path_0.quadraticBezierTo(size.width * 0.32, size.height * 0.18,
        size.width * 0.35, size.height * 0.38);
    path_0.quadraticBezierTo(size.width * 0.41, size.height * 0.48,
        size.width * 0.50, size.height * 0.50);
    path_0.quadraticBezierTo(size.width * 0.35, size.height * 0.54,
        size.width * 0.33, size.height * 0.70);
    path_0.cubicTo(size.width * 0.34, size.height * 0.78, size.width * 0.37,
        size.height * 0.81, size.width * 0.50, size.height * 0.88);
    path_0.cubicTo(size.width * 0.66, size.height * 0.83, size.width * 0.68,
        size.height * 0.78, size.width * 0.70, size.height * 0.70);
    path_0.quadraticBezierTo(size.width * 0.69, size.height * 0.53,
        size.width * 0.53, size.height * 0.50);
    path_0.quadraticBezierTo(size.width * 0.62, size.height * 0.47,
        size.width * 0.65, size.height * 0.38);
    path_0.quadraticBezierTo(size.width * 0.69, size.height * 0.18,
        size.width * 0.50, size.height * 0.13);
    path_0.close();
    return path_0;
  }

  static Path retPath7(Size size) {
    Path path_0 = Path();
    path_0.moveTo(size.width * 0.25, size.height * 0.25);
    path_0.quadraticBezierTo(size.width * 0.53, size.height * 0.25,
        size.width * 0.63, size.height * 0.25);
    path_0.quadraticBezierTo(size.width * 0.47, size.height * 0.42,
        size.width * 0.38, size.height * 0.75);

    return path_0;
  }

  static Path retPath6(Size size) {
    Path path_0 = Path();
    path_0.moveTo(size.width * 0.70, size.height * 0.23);
    path_0.quadraticBezierTo(size.width * 0.60, size.height * 0.11,
        size.width * 0.50, size.height * 0.13);
    path_0.cubicTo(size.width * 0.34, size.height * 0.14, size.width * 0.25,
        size.height * 0.31, size.width * 0.30, size.height * 0.55);
    path_0.quadraticBezierTo(size.width * 0.34, size.height * 0.72,
        size.width * 0.50, size.height * 0.75);
    path_0.quadraticBezierTo(size.width * 0.67, size.height * 0.72,
        size.width * 0.72, size.height * 0.57);
    path_0.cubicTo(size.width * 0.71, size.height * 0.49, size.width * 0.67,
        size.height * 0.39, size.width * 0.50, size.height * 0.38);
    path_0.quadraticBezierTo(size.width * 0.36, size.height * 0.42,
        size.width * 0.30, size.height * 0.55);
    return path_0;
  }

  static Path retPath5(Size size) {
    Path path_0 = Path();
    path_0.moveTo(size.width * 0.63, size.height * 0.25);
    path_0.lineTo(size.width * 0.25, size.height * 0.25);
    path_0.quadraticBezierTo(size.width * 0.25, size.height * 0.50,
        size.width * 0.25, size.height * 0.55);
    path_0.cubicTo(size.width * 0.39, size.height * 0.46, size.width * 0.54,
        size.height * 0.47, size.width * 0.60, size.height * 0.57);
    path_0.cubicTo(size.width * 0.62, size.height * 0.66, size.width * 0.62,
        size.height * 0.70, size.width * 0.57, size.height * 0.75);
    path_0.quadraticBezierTo(size.width * 0.45, size.height * 0.83,
        size.width * 0.25, size.height * 0.75);
    return path_0;
  }

  static Path retPath4(Size size) {
    Path path_0 = Path();
    path_0.moveTo(size.width * 0.63, size.height * 0.88);
    path_0.quadraticBezierTo(size.width * 0.63, size.height * 0.41,
        size.width * 0.63, size.height * 0.25);
    path_0.cubicTo(size.width * 0.52, size.height * 0.25, size.width * 0.28,
        size.height * 0.51, size.width * 0.25, size.height * 0.63);
    path_0.quadraticBezierTo(size.width * 0.38, size.height * 0.63,
        size.width * 0.75, size.height * 0.63);
    return path_0;
  }

  static Path retPath3(Size size) {
    Path path_0 = Path();
    path_0.moveTo(size.width * 0.30, size.height * 0.35);
    path_0.quadraticBezierTo(size.width * 0.36, size.height * 0.25,
        size.width * 0.50, size.height * 0.25);
    path_0.cubicTo(size.width * 0.60, size.height * 0.25, size.width * 0.66,
        size.height * 0.32, size.width * 0.68, size.height * 0.40);
    path_0.quadraticBezierTo(size.width * 0.69, size.height * 0.54,
        size.width * 0.42, size.height * 0.57);
    path_0.quadraticBezierTo(size.width * 0.69, size.height * 0.58,
        size.width * 0.68, size.height * 0.75);
    path_0.cubicTo(size.width * 0.67, size.height * 0.80, size.width * 0.61,
        size.height * 0.86, size.width * 0.50, size.height * 0.88);
    path_0.cubicTo(size.width * 0.40, size.height * 0.87, size.width * 0.37,
        size.height * 0.83, size.width * 0.30, size.height * 0.78);
    return path_0;
  }

  static Path retPath2(Size size) {
    Path path_0 = Path();
    path_0.moveTo(size.width * 0.25, size.height * 0.25);
    path_0.quadraticBezierTo(size.width * 0.27, size.height * 0.14,
        size.width * 0.47, size.height * 0.13);
    path_0.cubicTo(size.width * 0.65, size.height * 0.12, size.width * 0.72,
        size.height * 0.23, size.width * 0.72, size.height * 0.33);
    path_0.cubicTo(size.width * 0.72, size.height * 0.43, size.width * 0.61,
        size.height * 0.46, size.width * 0.25, size.height * 0.75);
    path_0.quadraticBezierTo(size.width * 0.38, size.height * 0.75,
        size.width * 0.75, size.height * 0.75);
    return path_0;
  }

  static Path retPath1(Size size) {
    Path path_0 = Path();
    path_0.moveTo(size.width * 0.45, size.height * 0.30);
    path_0.lineTo(size.width * 0.50, size.height * 0.20);
    path_0.lineTo(size.width * 0.50, size.height * 0.30);
    path_0.lineTo(size.width * 0.50, size.height * 0.40);
    path_0.lineTo(size.width * 0.50, size.height * 0.50);
    path_0.lineTo(size.width * 0.45, size.height * 0.50);
    path_0.lineTo(size.width * 0.55, size.height * 0.50);
    return path_0;
  }
}
