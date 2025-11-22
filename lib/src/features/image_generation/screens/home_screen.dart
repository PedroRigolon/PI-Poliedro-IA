import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/rendering.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:file_saver/file_saver.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/gestures.dart';
import 'dart:ui' show PointerDeviceKind;
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/diagram_template.dart';

/// Simple grid painter for the empty canvas area.
class CanvasGridPainter extends CustomPainter {
  final double spacing;
  final Color lineColor;
  CanvasGridPainter({this.spacing = 20, Color? lineColor})
    : lineColor = lineColor ?? Colors.grey[400]!;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.8;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PlacedShape {
  final String asset;
  Offset position; // canto superior esquerdo
  double size; // lado do quadrado
  double rotation; // em radianos
  bool locked;
  bool visible;
  String? groupId;
  // Campos opcionais para shapes de texto
  String? textContent;
  double? fontSize;
  // Nome customizado (se null, usa nome padrão do asset)
  String? customName;
  _PlacedShape({
    required this.asset,
    required this.position,
    required this.size,
    double? rotation,
    this.locked = false,
    this.visible = true,
    this.groupId,
    this.textContent,
    this.fontSize,
    this.customName,
  }) : rotation = rotation ?? 0;

  _PlacedShape copyWith({
    String? asset,
    Offset? position,
    double? size,
    double? rotation,
    bool? locked,
    bool? visible,
    String? groupId,
    String? textContent,
    double? fontSize,
    String? customName,
  }) => _PlacedShape(
    asset: asset ?? this.asset,
    position: position ?? this.position,
    size: size ?? this.size,
    rotation: rotation ?? this.rotation,
    locked: locked ?? this.locked,
    visible: visible ?? this.visible,
    groupId: groupId ?? this.groupId,
    textContent: textContent ?? this.textContent,
    fontSize: fontSize ?? this.fontSize,
    customName: customName ?? this.customName,
  );
}

// Intents para atalhos de teclado
class _DeleteShapeIntent extends Intent {
  const _DeleteShapeIntent();
}

class _DeselectIntent extends Intent {
  const _DeselectIntent();
}

class _DuplicateIntent extends Intent {
  const _DuplicateIntent();
}

class _CopyIntent extends Intent {
  const _CopyIntent();
}

class _PasteIntent extends Intent {
  const _PasteIntent();
}

class _GroupIntent extends Intent {
  const _GroupIntent();
}

class _UngroupIntent extends Intent {
  const _UngroupIntent();
}

class _NudgeIntent extends Intent {
  final Offset delta;
  const _NudgeIntent(this.delta);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // -1 means panel closed
  int _selectedIndex = -1;
  final double _panelWidth = 360;
  final double _shapeSize = 56; // tamanho inicial padrão
  final GlobalKey _canvasKey = GlobalKey();
  final List<_PlacedShape> _shapes = [];
  int _selectedShapeIndex = -1; // principal (retrocompatibilidade)
  final Set<int> _selected = <int>{};
  final FocusNode _canvasFocusNode = FocusNode();
  bool _interactingWithHandle = false;
  List<_PlacedShape>? _clipboard;
  // Zoom & Pan
  double _zoom = 1.0;
  Offset _pan = Offset.zero;
  static const double _minZoom = 0.25;
  static const double _maxZoom = 4.0;
  bool _isPanning = false;
  bool _isMiddlePanning = false;
  Offset? _lastMiddlePanLocal;
  static const double _scrollPanFactor = 2.5; // velocidade do pan via scroll
  bool _ctrlHeld = false;
  bool _shiftHeld = false;
  bool _exportingTransparent = false;
  Uint8List? _lastPreviewBytes;
  // Flag para esconder grade durante capturas / preview
  bool _suppressGridDuringCapture = false;
  // Estado de rotação durante interação
  int? _rotatingShapeIndex;
  double _rotatingInitialRotation = 0.0;
  double _rotatingInitialAngle = 0.0;
  // Loading overlay
  bool _isBusy = false;
  String? _busyMessage;

  // Estado do painel de Assistente de Diagramas
  String _selectedDiagramCategory = '';
  String _selectedDiagramSubcategory = '';
  
  // Marquee selection
  bool _isMarquee = false;
  Offset? _marqueeStart;
  Rect? _marqueeRect;
  // Grid config
  bool _showGrid = true; // alterna a visualização da grade
  // Estado de expansão para materias e submaterias
  final Map<String, bool> _materiaExpanded = {
    'Geral': true,
    'Física': true,
    'Química': true,
  };
  final Map<String, bool> _subExpanded = {
    'Textos': true,
    'Setas': true,
    'Formas Básicas': true,
    'Mecânica': true,
    'Eletricidade': true,
    'Óptica': true,
    'Térmica': true,
    'Orgânica': true,
    'Inorgânica': true,
    'Termoquímica': true,
  };

  void _toggleMateria(String materia) => setState(
    () => _materiaExpanded[materia] = !(_materiaExpanded[materia] ?? true),
  );
  void _toggleSub(String sub) =>
      setState(() => _subExpanded[sub] = !(_subExpanded[sub] ?? true));

  bool _isCtrlPressed() {
    final keysH = HardwareKeyboard.instance.logicalKeysPressed;
    if (keysH.contains(LogicalKeyboardKey.controlLeft) ||
        keysH.contains(LogicalKeyboardKey.controlRight) ||
        keysH.contains(LogicalKeyboardKey.control) ||
        keysH.contains(LogicalKeyboardKey.metaLeft) ||
        keysH.contains(LogicalKeyboardKey.metaRight)) {
      return true;
    }
    final keysR = RawKeyboard.instance.keysPressed;
    return keysR.contains(LogicalKeyboardKey.controlLeft) ||
        keysR.contains(LogicalKeyboardKey.controlRight) ||
        keysR.contains(LogicalKeyboardKey.control) ||
        keysR.contains(LogicalKeyboardKey.metaLeft) ||
        keysR.contains(LogicalKeyboardKey.metaRight);
  }

  bool _isShiftPressed() {
    final keysH = HardwareKeyboard.instance.logicalKeysPressed;
    if (keysH.contains(LogicalKeyboardKey.shiftLeft) ||
        keysH.contains(LogicalKeyboardKey.shiftRight)) {
      return true;
    }
    final keysR = RawKeyboard.instance.keysPressed;
    return keysR.contains(LogicalKeyboardKey.shiftLeft) ||
        keysR.contains(LogicalKeyboardKey.shiftRight);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.colors.background,
      appBar: AppBar(
        backgroundColor: AppTheme.colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Image.asset('assets/images/logo.png', height: 40),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: _showProfileMenu,
          ),
        ],
      ),
      body: Row(
        children: [
          // Navigation rail
          NavigationRail(
            selectedIndex: _selectedIndex < 0 ? 0 : _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                if (_selectedIndex == index) {
                  _selectedIndex = -1; // fecha se clicar novamente
                } else {
                  _selectedIndex = index;
                }
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.smart_toy),
                selectedIcon: Icon(Icons.smart_toy),
                label: Text('IA'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.category),
                selectedIcon: Icon(Icons.category),
                label: Text('Formas'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.layers_outlined),
                selectedIcon: Icon(Icons.layers),
                label: Text('Camadas'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.tune),
                selectedIcon: Icon(Icons.tune),
                label: Text('Propriedades'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings),
                selectedIcon: Icon(Icons.settings),
                label: Text('Configurações'),
              ),
            ],
          ),

          // Main area: canvas + sliding panel
          Expanded(
            child: Stack(
              children: [
                // Canvas fills the available body area (below AppBar)
                // Área do canvas com foco para ouvir teclas (Delete)
                Positioned.fill(
                  child: Shortcuts(
                    shortcuts: <ShortcutActivator, Intent>{
                      LogicalKeySet(LogicalKeyboardKey.delete):
                          const _DeleteShapeIntent(),
                      LogicalKeySet(LogicalKeyboardKey.backspace):
                          const _DeleteShapeIntent(),
                      LogicalKeySet(LogicalKeyboardKey.escape):
                          const _DeselectIntent(),
                      SingleActivator(LogicalKeyboardKey.keyD, control: true):
                          const _DuplicateIntent(),
                      SingleActivator(LogicalKeyboardKey.keyC, control: true):
                          const _CopyIntent(),
                      SingleActivator(LogicalKeyboardKey.keyV, control: true):
                          const _PasteIntent(),
                      SingleActivator(LogicalKeyboardKey.keyG, control: true):
                          const _GroupIntent(),
                      SingleActivator(
                        LogicalKeyboardKey.keyG,
                        control: true,
                        shift: true,
                      ): const _UngroupIntent(),
                      // Nudges
                      SingleActivator(LogicalKeyboardKey.arrowUp):
                          const _NudgeIntent(Offset(0, -1)),
                      SingleActivator(LogicalKeyboardKey.arrowDown):
                          const _NudgeIntent(Offset(0, 1)),
                      SingleActivator(LogicalKeyboardKey.arrowLeft):
                          const _NudgeIntent(Offset(-1, 0)),
                      SingleActivator(LogicalKeyboardKey.arrowRight):
                          const _NudgeIntent(Offset(1, 0)),
                      SingleActivator(LogicalKeyboardKey.arrowUp, shift: true):
                          const _NudgeIntent(Offset(0, -10)),
                      SingleActivator(
                        LogicalKeyboardKey.arrowDown,
                        shift: true,
                      ): const _NudgeIntent(
                        Offset(0, 10),
                      ),
                      SingleActivator(
                        LogicalKeyboardKey.arrowLeft,
                        shift: true,
                      ): const _NudgeIntent(
                        Offset(-10, 0),
                      ),
                      SingleActivator(
                        LogicalKeyboardKey.arrowRight,
                        shift: true,
                      ): const _NudgeIntent(
                        Offset(10, 0),
                      ),
                    },
                    child: Actions(
                      actions: <Type, Action<Intent>>{
                        _DeleteShapeIntent: CallbackAction<_DeleteShapeIntent>(
                          onInvoke: (intent) {
                            setState(() {
                              if (_selected.isNotEmpty) {
                                final toRemove = _selected.toList()
                                  ..sort((a, b) => b.compareTo(a));
                                for (final i in toRemove) {
                                  _shapes.removeAt(i);
                                }
                                _selected.clear();
                                _selectedShapeIndex = -1;
                              } else if (_selectedShapeIndex != -1) {
                                _shapes.removeAt(_selectedShapeIndex);
                                _selectedShapeIndex = -1;
                              }
                            });
                            return null;
                          },
                        ),
                        _DeselectIntent: CallbackAction<_DeselectIntent>(
                          onInvoke: (intent) {
                            setState(() {
                              _selectedShapeIndex = -1;
                              _selected.clear();
                            });
                            return null;
                          },
                        ),
                        _DuplicateIntent: CallbackAction<_DuplicateIntent>(
                          onInvoke: (intent) {
                            _duplicateSelected();
                            return null;
                          },
                        ),
                        _CopyIntent: CallbackAction<_CopyIntent>(
                          onInvoke: (intent) {
                            _copySelectedToClipboard();
                            return null;
                          },
                        ),
                        _PasteIntent: CallbackAction<_PasteIntent>(
                          onInvoke: (intent) {
                            _pasteClipboard();
                            return null;
                          },
                        ),
                        _GroupIntent: CallbackAction<_GroupIntent>(
                          onInvoke: (intent) {
                            _groupSelected();
                            return null;
                          },
                        ),
                        _UngroupIntent: CallbackAction<_UngroupIntent>(
                          onInvoke: (intent) {
                            _ungroupSelected();
                            return null;
                          },
                        ),
                        _NudgeIntent: CallbackAction<_NudgeIntent>(
                          onInvoke: (intent) {
                            _nudgeSelected(intent.delta);
                            return null;
                          },
                        ),
                      },
                      child: Focus(
                        focusNode: _canvasFocusNode,
                        autofocus: true,
                        onKeyEvent: (node, event) {
                          final isDown = event is KeyDownEvent;
                          final isUp = event is KeyUpEvent;
                          final key = event.logicalKey;
                          if (key == LogicalKeyboardKey.shiftLeft || key == LogicalKeyboardKey.shiftRight || key == LogicalKeyboardKey.shift) {
                            setState(() { _shiftHeld = isDown ? true : (isUp ? false : _shiftHeld); });
                          }
                          if (key == LogicalKeyboardKey.controlLeft || key == LogicalKeyboardKey.controlRight || key == LogicalKeyboardKey.control || key == LogicalKeyboardKey.metaLeft || key == LogicalKeyboardKey.metaRight) {
                            setState(() { _ctrlHeld = isDown ? true : (isUp ? false : _ctrlHeld); });
                          }
                          // Não consome o evento para não atrapalhar Shortcuts/Actions
                          return KeyEventResult.ignored;
                        },
                        child: DragTarget<String>(
                          onAcceptWithDetails: (details) {
                            final renderBox =
                                _canvasKey.currentContext?.findRenderObject()
                                    as RenderBox?;
                            if (renderBox != null) {
                              final localWidget = renderBox.globalToLocal(
                                details.offset,
                              );
                              final canvasLocal = _widgetToCanvas(localWidget);
                              _addShape(
                                details.data,
                                canvasLocal -
                                    Offset(_shapeSize / 2, _shapeSize / 2),
                              );
                            } else {
                              _addShape(details.data, const Offset(120, 120));
                            }
                          },
                          builder: (context, candidates, rejects) {
                            return RepaintBoundary(
                              key: _canvasKey,
                              child: MouseRegion(
                                cursor: (_isMiddlePanning || _isPanning)
                                    ? SystemMouseCursors.grabbing
                                    : SystemMouseCursors.basic,
                                child: Listener(
                                  onPointerSignal: (event) {
                                    if (event is PointerScrollEvent) {
                                      final ctrl = _ctrlHeld || _isCtrlPressed();
                                      final shift = _shiftHeld || _isShiftPressed();
                                      final box =
                                          _canvasKey.currentContext
                                                  ?.findRenderObject()
                                              as RenderBox?;
                                      if (box == null) return;
                                      final local = box.globalToLocal(
                                        event.position,
                                      );
                                      if (shift) {
                                        // Shift + Scroll: pan horizontal
                                        final dx = event.scrollDelta.dx != 0
                                            ? event.scrollDelta.dx
                                            : event.scrollDelta.dy;
                                        setState(() {
                                          _pan += Offset(
                                            -dx * _scrollPanFactor,
                                            0,
                                          );
                                        });
                                      } else if (ctrl) {
                                        // Ctrl + Scroll: pan vertical
                                        setState(() {
                                          _pan += Offset(
                                            0,
                                            -event.scrollDelta.dy *
                                                _scrollPanFactor,
                                          );
                                        });
                                      } else {
                                        // Scroll: zoom por paradas discretas no ponto do cursor
                                        final zoomIn = event.scrollDelta.dy < 0;
                                        _zoomToNearestStep(
                                          zoomIn,
                                          widgetFocal: local,
                                        );
                                      }
                                    }
                                  },
                                  onPointerDown: (event) {
                                    // Botão do meio do mouse para pan estilo Figma
                                    if (event.kind == PointerDeviceKind.mouse &&
                                        (event.buttons & 0x04) != 0) {
                                      setState(() {
                                        _isMiddlePanning = true;
                                        _lastMiddlePanLocal =
                                            event.localPosition;
                                      });
                                    }
                                  },
                                  onPointerMove: (event) {
                                    if (_isMiddlePanning &&
                                        event.kind == PointerDeviceKind.mouse) {
                                      final last = _lastMiddlePanLocal;
                                      if (last != null) {
                                        final delta =
                                            event.localPosition - last;
                                        setState(() {
                                          _pan += delta;
                                        });
                                        _lastMiddlePanLocal =
                                            event.localPosition;
                                      }
                                    }
                                  },
                                  onPointerUp: (event) {
                                    if (_isMiddlePanning &&
                                        event.kind == PointerDeviceKind.mouse) {
                                      setState(() {
                                        _isMiddlePanning = false;
                                        _lastMiddlePanLocal = null;
                                      });
                                    }
                                  },
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTapDown: (_) {
                                      setState(() => _selectedShapeIndex = -1);
                                      _selected.clear();
                                      _canvasFocusNode.requestFocus();
                                    },
                                    onPanStart: (details) {
                                      final keys = HardwareKeyboard
                                          .instance
                                          .logicalKeysPressed;
                                      final space = keys.contains(
                                        LogicalKeyboardKey.space,
                                      );
                                      if (space) {
                                        setState(() {
                                          _isPanning = true;
                                        });
                                        return;
                                      }
                                      // Inicia retângulo de seleção (coords canvas)
                                      setState(() {
                                        _isMarquee = true;
                                        final start = _globalToCanvas(
                                          details.globalPosition,
                                        );
                                        _marqueeStart = start;
                                        _marqueeRect = Rect.fromLTWH(
                                          start.dx,
                                          start.dy,
                                          0,
                                          0,
                                        );
                                      });
                                    },
                                    onPanUpdate: (details) {
                                      if (_isPanning) {
                                        setState(() {
                                          _pan += details.delta;
                                        });
                                        return;
                                      }
                                      if (_isMarquee && _marqueeStart != null) {
                                        final current = _globalToCanvas(
                                          details.globalPosition,
                                        );
                                        setState(() {
                                          _marqueeRect = Rect.fromPoints(
                                            _marqueeStart!,
                                            current,
                                          );
                                        });
                                      }
                                    },
                                    onPanEnd: (_) {
                                      if (_isPanning) {
                                        setState(() {
                                          _isPanning = false;
                                        });
                                        return;
                                      }
                                      if (_isMarquee) {
                                        setState(() {
                                          _applyMarqueeSelection();
                                          _isMarquee = false;
                                          _marqueeStart = null;
                                          _marqueeRect = null;
                                        });
                                      }
                                    },
                                    child: ClipRect(
                                      child: Stack(
                                        children: [
                                          Transform(
                                            transform: Matrix4.identity()
                                              ..translate(_pan.dx, _pan.dy)
                                              ..scale(_zoom, _zoom),
                                            alignment: Alignment.topLeft,
                                            child: Stack(
                                              children: [
                                                Positioned.fill(
                                                  child: Container(
                                                    color: _exportingTransparent ? Colors.transparent : Colors.white,
                                                    child: CustomPaint(
                                                      painter: (_showGrid && !_suppressGridDuringCapture)
                                                          ? CanvasGridPainter()
                                                          : null,
                                                    ),
                                                  ),
                                                ),
                                                ..._buildShapesContent(),

                                                // Marquee overlay movido para fora se necessário
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                // Marquee overlay (convertida para tela)
                if (_isMarquee && _marqueeRect != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _MarqueePainter(
                          _canvasRectToScreen(_marqueeRect!),
                        ),
                      ),
                    ),
                  ),

                // Toolbar flutuante básica para seleção múltipla
                if (_selected.isNotEmpty) ..._buildSelectionToolbar(),

                // Controles de zoom (canto inferior direito)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Material(
                    elevation: 2,
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Diminuir zoom',
                            icon: const Icon(Icons.remove, size: 18),
                            onPressed: () => _zoomStep(false),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Text('${(_zoom * 100).round()}%'),
                          ),
                          IconButton(
                            tooltip: 'Aumentar zoom',
                            icon: const Icon(Icons.add, size: 18),
                            onPressed: () => _zoomStep(true),
                          ),
                          const SizedBox(width: 6),
                          TextButton(
                            onPressed: _fitToContent,
                            child: const Text('Ajustar'),
                          ),
                          const SizedBox(width: 4),
                          TextButton(
                            onPressed: _resetZoom100,
                            child: const Text('100%'),
                          ),
                          const SizedBox(width: 8),
                          const VerticalDivider(width: 12),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _saveImageFlow,
                            icon: const Icon(Icons.save_alt, size: 18),
                            label: const Text('Salvar imagem'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.colors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Backdrop: when panel is open, clicking outside closes it
                if (_selectedIndex >= 0)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedIndex = -1),
                      child: Container(color: Colors.transparent),
                    ),
                  ),

                // Sliding panel (no shadow/elevation, stretches top->bottom of body)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  left: _selectedIndex >= 0 ? 0 : -_panelWidth,
                  top: 0,
                  bottom: 0,
                  width: _panelWidth,
                  child: Material(
                    elevation: 0, // remove shadow
                    color: AppTheme.colors.white,
                    child: SafeArea(
                      top: false,
                      bottom: false,
                      child: Padding(
                        padding: EdgeInsets.all(AppTheme.spacing.medium),
                        child: _buildPanelContent(),
                      ),
                    ),
                  ),
                ),

                // Loading overlay
                if (_isBusy)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.35),
                      alignment: Alignment.center,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 260),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              Text(_busyMessage ?? 'Processando...', textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ======= Controles de Zoom =======
  void _zoomTo(double targetZoom, {Offset? focalInWidget}) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final focal = focalInWidget ?? (box.size.center(Offset.zero));
    _zoomAt(focal, targetZoom / _zoom);
  }

  static const List<double> _zoomStops = [
    0.25,
    0.33,
    0.5,
    0.66,
    0.75,
    0.8,
    0.9,
    1.0,
    1.25,
    1.5,
    2.0,
    3.0,
    4.0,
  ];

  void _zoomToNearestStep(bool zoomIn, {Offset? widgetFocal}) {
    const eps = 1e-6;
    double current = _zoom;
    // Encontra stop alvo
    double? target;
    if (zoomIn) {
      for (final z in _zoomStops) {
        if (z > current + eps) {
          target = z;
          break;
        }
      }
      target ??= _zoomStops.last;
    } else {
      for (int i = _zoomStops.length - 1; i >= 0; i--) {
        final z = _zoomStops[i];
        if (z < current - eps) {
          target = z;
          break;
        }
      }
      target ??= _zoomStops.first;
    }
    _zoomTo(target, focalInWidget: widgetFocal);
  }

  void _zoomStep(bool zoomIn) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final center = box.size.center(Offset.zero);
    _zoomToNearestStep(zoomIn, widgetFocal: center);
  }

  void _resetZoom100() {
    _zoomTo(1.0);
  }

  void _fitToContent() {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final viewportSize = box.size;
    if (_shapes.where((s) => s.visible).isEmpty) {
      // Sem conteúdo: volta para 100% e origem
      setState(() {
        _zoom = 1.0;
        _pan = Offset.zero;
      });
      return;
    }

    // Calcula bounds do conteúdo visível
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final s in _shapes.where((s) => s.visible)) {
      minX = math.min(minX, s.position.dx);
      minY = math.min(minY, s.position.dy);
      maxX = math.max(maxX, s.position.dx + s.size);
      maxY = math.max(maxY, s.position.dy + s.size);
    }
    final content = Rect.fromLTRB(minX, minY, maxX, maxY);
    if (content.width <= 0 || content.height <= 0) {
      _resetZoom100();
      return;
    }

    const padding = 32.0; // padding em tela ao redor do conteúdo
    final scaleX = (viewportSize.width - padding * 2) / content.width;
    final scaleY = (viewportSize.height - padding * 2) / content.height;
    final targetZoom = scaleX.isFinite && scaleY.isFinite
        ? math.min(scaleX, scaleY).clamp(_minZoom, _maxZoom)
        : 1.0;

    // Centraliza o conteúdo na viewport
    final contentCenter = content.center;
    setState(() {
      _zoom = targetZoom;
      final viewportCenter = viewportSize.center(Offset.zero);
      _pan = viewportCenter - contentCenter * _zoom;
    });
  }

  Widget _buildPanelContent() {
    switch (_selectedIndex) {
      case 0: // IA
        return _buildIaPanel();

      case 1: // Formas
        // Replace simple buttons with a scrollable list of sections (materia -> submateria -> grid of thumbnails)
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Formas',
                  style: AppTheme.typography.title.copyWith(fontSize: 20),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _selectedIndex = -1),
                ),
              ],
            ),
            SizedBox(height: AppTheme.spacing.medium),

            // Body: scrollable list of subjects and their subtopics
            Expanded(
              child: ListView(
                primary: false,
                children: [
                  // Grupo Geral
                  _buildMateriaHeaderCollapsible('Geral'),
                  if (_materiaExpanded['Geral'] ?? false) ...[
                    _buildGeneratedSection(
                      'Textos',
                      [
                        'generated:text',
                      ],
                    ),
                    _buildGeneratedSection(
                      'Setas',
                      [
                        'generated:vector',
                      ],
                    ),
                    _buildGeneratedSection(
                      'Formas Básicas',
                      [
                        'generated:rect',
                        'generated:circle',
                        'generated:triangle',
                        'generated:line_solid',
                        'generated:line_dashed',
                      ],
                    ),
                  ],
                  const Divider(height: 24),
                  // Grupo Física
                  _buildMateriaHeaderCollapsible('Física'),
                  if (_materiaExpanded['Física'] ?? false) ...[
                    _buildGeneratedSection(
                      'Mecânica',
                      [
                        'generated:block',
                        'generated:plane',
                        'generated:pulley',
                        'generated:spring',
                        'generated:vector',
                        'generated:pendulum',
                        'generated:balance',
                        'generated:cart',
                        'generated:friction_surface',
                        'generated:rope',
                      ],
                    ),
                    _buildGeneratedSection(
                      'Eletricidade',
                      [
                        'generated:resistor',
                        'generated:battery',
                        'generated:ammeter',
                        'generated:wire',
                        'generated:capacitor',
                        'generated:led',
                        'generated:diode',
                        'generated:switch',
                        'generated:ground',
                        'generated:ac_source',
                      ],
                    ),
                    _buildGeneratedSection(
                      'Óptica',
                      [
                        'generated:convergent_lens',
                        'generated:divergent_lens',
                        'generated:mirror',
                        'generated:light_ray',
                        'generated:prism',
                      ],
                    ),
                    _buildSubSectionCollapsible(
                      'Térmica',
                      'assets/forms/fisica/termica',
                      0,
                    ),
                  ],
                  const Divider(height: 24),
                  // Grupo Química
                  _buildMateriaHeaderCollapsible('Química'),
                  if (_materiaExpanded['Química'] ?? false) ...[
                    _buildGeneratedSection(
                      'Vidrarias',
                      [
                        'generated:beaker',
                        'generated:erlenmeyer',
                        'generated:test_tube',
                      ],
                    ),
                    _buildGeneratedSection(
                      'Orgânica',
                      [
                        'generated:benzene',
                      ],
                    ),
                    _buildSubSectionCollapsible(
                      'Inorgânica',
                      'assets/forms/quimica/inorganica',
                      0,
                    ),
                    _buildSubSectionCollapsible(
                      'Termoquímica',
                      'assets/forms/quimica/termoquimica',
                      0,
                    ),
                  ],
                ],
              ),
            ),
          ],
        );

      case 2: // Camadas
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Camadas',
                  style: AppTheme.typography.title.copyWith(fontSize: 20),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _selectedIndex = -1),
                ),
              ],
            ),
            SizedBox(height: AppTheme.spacing.medium),
            Expanded(child: _buildLayersPanel()),
          ],
        );

      case 3: // Propriedades
        return _buildPropertiesPanel();

      case 4: // Configurações
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Configurações',
                  style: AppTheme.typography.title.copyWith(fontSize: 20),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _selectedIndex = -1),
                ),
              ],
            ),
            SizedBox(height: AppTheme.spacing.medium),
            // Seção Canvas
            Text(
              'Canvas',
              style: AppTheme.typography.title.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _showGrid,
              onChanged: (v) => setState(() => _showGrid = v),
              title: const Text('Mostrar grade'),
              subtitle: const Text('Exibe linhas de apoio no canvas'),
            ),
            const Divider(height: 24),
            // Outras configurações (reservado para futuras opções)
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildLayersPanel() {
    // Exibir topo da pilha no topo da lista → usar lista reversa
    final reversed = _shapes.reversed.toList(growable: false);
    return ReorderableListView.builder(
      buildDefaultDragHandles: true,
      itemCount: reversed.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          // Ajuste padrão do ReorderableListView
          if (newIndex > oldIndex) newIndex -= 1;
          final rev = _shapes.reversed.toList();
          final item = rev.removeAt(oldIndex);
          rev.insert(newIndex, item);
          final newShapes = rev.reversed.toList();

          // Preserva seleção por identidade
          final selectedObjs = _selected.map((i) => _shapes[i]).toSet();
          _shapes
            ..clear()
            ..addAll(newShapes);
          _selected
            ..clear()
            ..addAll([
              for (int i = 0; i < _shapes.length; i++)
                if (selectedObjs.contains(_shapes[i])) i,
            ]);
          _selectedShapeIndex = _selected.isNotEmpty ? _selected.last : -1;
        });
      },
      itemBuilder: (context, i) {
        final s = reversed[i];
        final index = _shapes.indexOf(s); // índice real
        final isSel = _selected.contains(index) || index == _selectedShapeIndex;
        final displayName = _displayNameForShape(s);
        
        return ListTile(
          key: ValueKey('layer_$index'),
          selected: isSel,
          selectedTileColor: Colors.blue.withValues(alpha: 0.06),
          leading: s.asset.startsWith('generated:')
              ? Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: CustomPaint(
                    painter: _shapePainterForKey(s.asset),
                  ),
                )
              : Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    s.asset,
                    fit: BoxFit.contain,
                    errorBuilder: (c, e, st) =>
                        Icon(Icons.crop_square, size: 18, color: Colors.grey[400]),
                  ),
                ),
          title: InkWell(
            onTap: () => _showRenameDialog(index),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.edit, size: 14, color: Colors.grey[600]),
              ],
            ),
          ),
          subtitle: s.groupId != null ? const Text('Grupo') : null,
          trailing: Wrap(
            spacing: 8,
            children: [
              IconButton(
                tooltip: s.visible ? 'Ocultar' : 'Exibir',
                icon: Icon(
                  s.visible ? Icons.visibility : Icons.visibility_off,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    s.visible = !s.visible;
                    if (!s.visible) {
                      // Se estava selecionado, remover da seleção
                      _selected.remove(index);
                      if (_selectedShapeIndex == index) {
                        _selectedShapeIndex = -1;
                      }
                    }
                  });
                },
              ),
              IconButton(
                tooltip: s.locked ? 'Desbloquear' : 'Bloquear',
                icon: Icon(s.locked ? Icons.lock : Icons.lock_open, size: 20),
                onPressed: () {
                  setState(() {
                    s.locked = !s.locked;
                  });
                },
              ),
              const Icon(Icons.drag_indicator, size: 20, color: Colors.grey),
            ],
          ),
          onTap: () {
            setState(() {
              _selected.clear();
              if (s.groupId != null) {
                for (int j = 0; j < _shapes.length; j++) {
                  if (_shapes[j].groupId == s.groupId) {
                    _selected.add(j);
                  }
                }
              } else {
                _selected.add(index);
              }
              _selectedShapeIndex = index;
              _selected.removeWhere((i) => !_shapes[i].visible);
              if (_selected.isEmpty) _selectedShapeIndex = -1;
            });
          },
        );
      },
    );
  }

  // Header de matéria com comportamento de expandir/retrair
  Widget _buildMateriaHeaderCollapsible(String materia) {
    final expanded = _materiaExpanded[materia] ?? true;
    return InkWell(
      onTap: () => _toggleMateria(materia),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppTheme.spacing.small),
        child: Row(
          children: [
            Expanded(
              child: Text(
                materia,
                style: AppTheme.typography.title.copyWith(fontSize: 16),
              ),
            ),
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 20,
              color: Colors.grey[700],
            ),
          ],
        ),
      ),
    );
  }

  // Submatéria com expandir/retrair + grid de thumbnails
  Widget _buildSubSectionCollapsible(
    String submateria,
    String assetDir,
    int count,
  ) {
    final expanded = _subExpanded[submateria] ?? true;
    return Padding(
      padding: EdgeInsets.only(bottom: AppTheme.spacing.small),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _toggleSub(submateria),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      submateria,
                      style: AppTheme.typography.paragraph
                          .copyWith(fontSize: 13)
                          .copyWith(color: Colors.grey[700]),
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: EdgeInsets.only(top: AppTheme.spacing.small),
              child: GridView.count(
                crossAxisCount: 6,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: List.generate(count, (i) {
                  final asset = '$assetDir/shape1.png';
                  return LongPressDraggable<String>(
                    data: asset,
                    feedback: Material(
                      color: Colors.transparent,
                      child: Image.asset(
                        asset,
                        width: _shapeSize,
                        height: _shapeSize,
                        fit: BoxFit.contain,
                        errorBuilder: (c, e, s) => Icon(
                          Icons.crop_square,
                          size: _shapeSize * 0.6,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.4,
                      child: _thumbTile(asset),
                    ),
                    child: GestureDetector(
                      onTap: () => _insertAtCenter(asset),
                      child: _thumbTile(asset),
                    ),
                  );
                }),
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // Thumbnail tile UI
  Widget _thumbTile(String asset) {
    final isGenerated = asset.startsWith('generated:');
    final name = isGenerated
        ? _displayNameForKey(asset.replaceFirst('generated:', ''))
        : _displayNameForAsset(asset);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: name,
        waitDuration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 11),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey[300]!),
            color: Colors.grey[50],
          ),
          padding: const EdgeInsets.all(6.0),
          child: isGenerated
              ? CustomPaint(
                  painter: _shapePainterForKey(asset),
                  size: const Size(double.infinity, double.infinity),
                )
              : Image.asset(
                  asset,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stack) => Icon(
                    Icons.crop_square,
                    size: 20,
                    color: Colors.grey[400],
                  ),
                ),
        ),
      ),
    );
  }

  // Seção gerada (shapes desenhados dinamicamente)
  Widget _buildGeneratedSection(String submateria, List<String> keys) {
    final expanded = _subExpanded[submateria] ?? true;
    return Padding(
      padding: EdgeInsets.only(bottom: AppTheme.spacing.small),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _toggleSub(submateria),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      submateria,
                      style: AppTheme.typography.paragraph
                          .copyWith(fontSize: 13)
                          .copyWith(color: Colors.grey[700]),
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: EdgeInsets.only(top: AppTheme.spacing.small),
              child: GridView.count(
                crossAxisCount: 6,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final k in keys)
                    LongPressDraggable<String>(
                      data: k,
                      feedback: Material(
                        color: Colors.transparent,
                        child: SizedBox(
                          width: _shapeSize,
                          height: _shapeSize,
                          child: CustomPaint(
                            painter: _shapePainterForKey(k),
                          ),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.4,
                        child: _thumbTile(k),
                      ),
                      child: GestureDetector(
                        onTap: () => _insertAtCenter(k),
                        child: _thumbTile(k),
                      ),
                    ),
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // Mapeia chave generated:* para painter
  CustomPainter _shapePainterForKey(String key) {
    final base = key.replaceFirst('generated:', '');
    switch (base) {
      case 'rect':
        return _RectPainter();
      case 'circle':
        return _CirclePainter();
      case 'triangle':
        return _TrianglePainter();
      case 'line_solid':
        return _LinePainter(dashed: false);
      case 'line_dashed':
        return _LinePainter(dashed: true);
      case 'block':
        return _BlockPainter();
      case 'plane':
        return _InclinedPlanePainter();
      case 'pulley':
        return _PulleyPainter();
      case 'spring':
        return _SpringPainter();
      case 'vector':
        return _ForceVectorPainter();
      case 'resistor':
        return _ResistorPainter();
      case 'battery':
        return _BatteryPainter();
      case 'ammeter':
        return _AmmeterPainter();
      case 'wire':
        return _WirePainter();
      case 'text':
        return _TextShapePainter(text: 'Texto', fontSize: 16);
      // Circuitos expandidos
      case 'capacitor':
        return _CapacitorPainter();
      case 'led':
        return _LEDPainter();
      case 'diode':
        return _DiodePainter();
      case 'switch':
        return _SwitchPainter();
      case 'ground':
        return _GroundPainter();
      case 'ac_source':
        return _ACSourcePainter();
      // Mecânica expandida
      case 'pendulum':
        return _PendulumPainter();
      case 'balance':
        return _BalancePainter();
      case 'cart':
        return _CartPainter();
      case 'friction_surface':
        return _FrictionSurfacePainter();
      case 'rope':
        return _RopePainter();
      // Óptica
      case 'convergent_lens':
        return _ConvergentLensPainter();
      case 'divergent_lens':
        return _DivergentLensPainter();
      case 'mirror':
        return _MirrorPainter();
      case 'light_ray':
        return _LightRayPainter();
      case 'prism':
        return _PrismPainter();
      // Química
      case 'beaker':
        return _BeakerPainter();
      case 'erlenmeyer':
        return _ErlenmeyerPainter();
      case 'test_tube':
        return _TestTubePainter();
      case 'benzene':
        return _BenzenePainter();
      default:
        return _RectPainter();
    }
  }

  void _insertAtCenter(String asset) {
    final renderBox =
        _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final size = renderBox.size;
      final center = Offset(
        size.width / 2 - _shapeSize / 2,
        size.height / 2 - _shapeSize / 2,
      );
      _addShape(asset, center);
    } else {
      _addShape(asset, const Offset(120, 120));
    }
  }

  void _addShape(String asset, Offset position) {
    setState(() {
      if (asset == 'generated:text') {
        _shapes.add(
          _PlacedShape(
            asset: asset,
            position: position,
            size: _shapeSize,
            textContent: 'Texto',
            fontSize: 16,
          ),
        );
      } else {
        _shapes.add(
          _PlacedShape(asset: asset, position: position, size: _shapeSize),
        );
      }
    });
  }

  // Calcula bounding box da seleção
  Rect? _selectionBounds() {
    if (_selected.isEmpty) return null;
    double? minX, minY, maxX, maxY;
    for (final i in _selected) {
      final s = _shapes[i];
      minX = minX == null ? s.position.dx : math.min(minX, s.position.dx);
      minY = minY == null ? s.position.dy : math.min(minY, s.position.dy);
      maxX = maxX == null
          ? s.position.dx + s.size
          : math.max(maxX, s.position.dx + s.size);
      maxY = maxY == null
          ? s.position.dy + s.size
          : math.max(maxY, s.position.dy + s.size);
    }
    return Rect.fromLTRB(minX!, minY!, maxX!, maxY!);
  }

  void _applyMarqueeSelection() {
    if (_marqueeRect == null) return;
    final r = _marqueeRect!;
    _selected.clear();
    for (int i = 0; i < _shapes.length; i++) {
      final s = _shapes[i];
      final rect = Rect.fromLTWH(s.position.dx, s.position.dy, s.size, s.size);
      if (r.overlaps(rect) ||
          r.contains(rect.topLeft) ||
          r.contains(rect.bottomRight)) {
        _selected.add(i);
      }
    }
    _selectedShapeIndex = _selected.isNotEmpty ? _selected.last : -1;
  }

  List<Widget> _buildSelectionToolbar() {
    final bounds = _selectionBounds();
    if (bounds == null) return [];
    final topLeftScreen = _pan + Offset(bounds.left, bounds.top) * _zoom;
    final centerScreen = _pan + bounds.center * _zoom;
    final toolbarY = (topLeftScreen.dy - 84).clamp(0.0, double.infinity);
    final toolbarX = (centerScreen.dx - 120).clamp(0.0, double.infinity);

    // Estado de bloqueio da seleção
    final hasSel = _selected.isNotEmpty;
    final allLocked = hasSel && _selected.every((i) => _shapes[i].locked);
    final anyLocked = hasSel && _selected.any((i) => _shapes[i].locked);
    final mixed = hasSel && anyLocked && !allLocked;
    final lockIcon = allLocked
        ? Icons.lock
        : mixed
        ? Icons.lock_outline
        : Icons.lock_open;
    final lockColor = allLocked
        ? Colors.redAccent
        : mixed
        ? Colors.amber[800]
        : Colors.black87;
    final lockTooltip = allLocked
        ? 'Desbloquear seleção'
        : mixed
        ? 'Definir bloqueio (misto)'
        : 'Bloquear seleção';

    return [
      Positioned(
        left: toolbarX,
        top: toolbarY,
        child: Material(
          color: Colors.white,
          elevation: 2,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Propriedades',
                  icon: const Icon(Icons.tune, size: 18),
                  color: _selectedIndex == 3 ? AppTheme.colors.primary : Colors.black87,
                  onPressed: () {
                    setState(() {
                      _selectedIndex = 3; // abre painel de propriedades
                    });
                  },
                ),
                const VerticalDivider(width: 8),
                IconButton(
                  tooltip: 'Duplicar (Ctrl+D)',
                  icon: const Icon(Icons.copy_all, size: 18),
                  onPressed: _duplicateSelected,
                ),
                IconButton(
                  tooltip: lockTooltip,
                  icon: Icon(lockIcon, size: 18, color: lockColor),
                  onPressed: _toggleLockSelected,
                ),
                if (hasSel)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      allLocked
                          ? 'Bloqueado'
                          : mixed
                          ? 'Misto'
                          : 'Desbloqueado',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                const VerticalDivider(width: 8),
                IconButton(
                  tooltip: 'Trazer para frente',
                  icon: const Icon(Icons.keyboard_arrow_up, size: 18),
                  onPressed: _bringToFront,
                ),
                IconButton(
                  tooltip: 'Enviar para trás',
                  icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                  onPressed: _sendToBack,
                ),
                // Controles de texto (apenas se seleção for exatamente 1 texto)
                if (_selected.length == 1 && _shapes[_selected.first].asset == 'generated:text') ...[
                  const VerticalDivider(width: 8),
                  _smallRoundButton(
                    icon: Icons.remove,
                    onTap: () {
                      setState(() {
                        final shp = _shapes[_selected.first];
                        final cur = (shp.fontSize ?? 16) - 2;
                        shp.fontSize = cur.clamp(8, 160);
                        _autoResizeTextShape(shp);
                      });
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text('${(_shapes[_selected.first].fontSize ?? 16).round()}'),
                  ),
                  _smallRoundButton(
                    icon: Icons.add,
                    onTap: () {
                      setState(() {
                        final shp = _shapes[_selected.first];
                        final cur = (shp.fontSize ?? 16) + 2;
                        shp.fontSize = cur.clamp(8, 160);
                        _autoResizeTextShape(shp);
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                  _smallRoundButton(
                    icon: Icons.edit,
                    onTap: () => _editTextShape(_selected.first),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ];
  }

  // Helpers de transformação de coordenadas e zoom
  Offset _widgetToCanvas(Offset widgetPoint) {
    return (widgetPoint - _pan) / _zoom;
  }

  Offset _globalToCanvas(Offset globalPoint) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return globalPoint;
    final local = box.globalToLocal(globalPoint);
    return _widgetToCanvas(local);
  }

  void _zoomAt(Offset widgetFocal, double factor) {
    setState(() {
      final newZoom = (_zoom * factor).clamp(_minZoom, _maxZoom);
      final canvasPoint = (widgetFocal - _pan) / _zoom;
      _zoom = newZoom;
      _pan = widgetFocal - canvasPoint * _zoom;
    });
  }

  void _duplicateSelected() {
    if (_selected.isEmpty) return;
    setState(() {
      final sel = _selected.toList();
      sel.sort();
      _selected.clear();
      for (final i in sel) {
        final s = _shapes[i];
        final copy = s.copyWith(position: s.position + const Offset(16, 16));
        _shapes.add(copy);
        _selected.add(_shapes.length - 1);
      }
      _selectedShapeIndex = _selected.last;
    });
  }

  void _toggleLockSelected() {
    if (_selected.isEmpty) return;
    setState(() {
      final allLocked = _selected.every((i) => _shapes[i].locked);
      final target =
          !allLocked; // se todos bloqueados, desbloqueia; caso contrário, bloqueia todos
      for (final i in _selected) {
        _shapes[i].locked = target;
      }
    });
  }

  void _bringToFront() {
    if (_selected.isEmpty) return;
    setState(() {
      final selectedIndices = _selected.toList()..sort();
      final items = [for (final i in selectedIndices) _shapes[i]];
      // Remove dos antigos
      for (final i in selectedIndices.reversed) {
        _shapes.removeAt(i);
      }
      // Reinsere no topo mantendo ordem
      _shapes.addAll(items);
      _selected.clear();
      _selected.addAll(
        Iterable<int>.generate(
          items.length,
          (k) => _shapes.length - items.length + k,
        ),
      );
      _selectedShapeIndex = _selected.last;
    });
  }

  void _sendToBack() {
    if (_selected.isEmpty) return;
    setState(() {
      final selectedIndices = _selected.toList()..sort();
      final items = [for (final i in selectedIndices) _shapes[i]];
      for (final i in selectedIndices.reversed) {
        _shapes.removeAt(i);
      }
      _shapes.insertAll(0, items);
      _selected.clear();
      _selected.addAll(List<int>.generate(items.length, (i) => i));
      _selectedShapeIndex = _selected.last;
    });
  }

  void _copySelectedToClipboard() {
    if (_selected.isEmpty) return;
    final sel = _selected.toList()..sort();
    _clipboard = [
      for (final i in sel)
        _shapes[i]
            .copyWith(), // cópia superficial é suficiente (campos são primitivos)
    ];
  }

  void _pasteClipboard() {
    if (_clipboard == null || _clipboard!.isEmpty) return;
    setState(() {
      _selected.clear();
      for (final s in _clipboard!) {
        final pasted = s.copyWith(
          position: s.position + const Offset(16, 16),
          groupId: null,
        );
        _shapes.add(pasted);
        _selected.add(_shapes.length - 1);
      }
      _selectedShapeIndex = _selected.last;
    });
  }

  void _groupSelected() {
    if (_selected.length < 2) return;
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    setState(() {
      for (final i in _selected) {
        _shapes[i].groupId = id;
      }
    });
  }

  void _ungroupSelected() {
    if (_selected.isEmpty) return;
    setState(() {
      for (final i in _selected) {
        _shapes[i].groupId = null;
      }
    });
  }

  void _nudgeSelected(Offset delta) {
    if (_selected.isEmpty) return;
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    final sizeCanvas = box?.size;
    setState(() {
      for (final i in _selected) {
        final shp = _shapes[i];
        if (shp.locked) continue;
        shp.position += delta;
        if (sizeCanvas != null) {
          final maxX = sizeCanvas.width - shp.size;
          final maxY = sizeCanvas.height - shp.size;
          shp.position = Offset(
            shp.position.dx.clamp(0.0, maxX),
            shp.position.dy.clamp(0.0, maxY),
          );
        }
      }
    });
  }

  // Função de alinhamento removida da toolbar (mantida anteriormente); poderá ser reintroduzida em um painel dedicado.

  Rect _canvasRectToScreen(Rect r) {
    final tl = _pan + Offset(r.left, r.top) * _zoom;
    final br = _pan + Offset(r.right, r.bottom) * _zoom;
    return Rect.fromPoints(tl, br);
  }

  // Bounds de todo conteúdo visível no canvas (considera rotação)
  Rect? _visibleContentBoundsCanvas({double padding = 12.0}) {
    final visibles = _shapes.where((s) => s.visible).toList();
    if (visibles.isEmpty) return null;
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final s in visibles) {
      final c = s.position + Offset(s.size / 2, s.size / 2);
      final h = s.size / 2;
      final cosA = math.cos(s.rotation);
      final sinA = math.sin(s.rotation);
      // 4 cantos relativos ao centro
      final corners = <Offset>[
        Offset(-h, -h),
        Offset(h, -h),
        Offset(h, h),
        Offset(-h, h),
      ].map((p) => Offset(
            cosA * p.dx - sinA * p.dy,
            sinA * p.dx + cosA * p.dy,
          ) + c);
      for (final p in corners) {
        if (p.dx < minX) minX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy > maxY) maxY = p.dy;
      }
    }
    if (!minX.isFinite || !minY.isFinite || !maxX.isFinite || !maxY.isFinite) {
      return null;
    }
    final rect = Rect.fromLTRB(minX, minY, maxX, maxY)
        .inflate(padding);
    return rect;
  }

  List<Widget> _buildShapesContent() {
    return _shapes.asMap().entries.where((e) => e.value.visible).map((entry) {
      final index = entry.key;
      final s = entry.value;
      final isSelected =
          _selected.contains(index) || index == _selectedShapeIndex;
      const handleSize = 16.0;
      const outerPad = handleSize + 12.0;
      return Positioned(
        left: s.position.dx - outerPad,
        top: s.position.dy - outerPad,
        width: s.size + outerPad * 2,
        height: s.size + outerPad * 2,
        child: IgnorePointer(
          ignoring: _selectedIndex >= 0,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              if (_interactingWithHandle) return;
              final keys = HardwareKeyboard.instance.logicalKeysPressed;
              final ctrl =
                  keys.contains(LogicalKeyboardKey.controlLeft) ||
                  keys.contains(LogicalKeyboardKey.controlRight) ||
                  keys.contains(LogicalKeyboardKey.metaLeft) ||
                  keys.contains(LogicalKeyboardKey.metaRight);
              setState(() {
                if (ctrl) {
                  if (_selected.contains(index)) {
                    _selected.remove(index);
                  } else {
                    _selected.add(index);
                  }
                  _selectedShapeIndex = _selected.isNotEmpty
                      ? _selected.last
                      : -1;
                } else {
                  _selected.clear();
                  if (s.groupId != null) {
                    for (int i = 0; i < _shapes.length; i++) {
                      if (_shapes[i].groupId == s.groupId) {
                        _selected.add(i);
                      }
                    }
                    _selectedShapeIndex = index;
                  } else {
                    _selected.add(index);
                    _selectedShapeIndex = index;
                  }
                }
              });
              _canvasFocusNode.requestFocus();
            },
            onPanStart: (_) {
              if (_interactingWithHandle) return;
              setState(() {
                final moved = _shapes.removeAt(index);
                _shapes.add(moved);
                final newIndex = _shapes.length - 1;
                if (_selected.contains(index)) {
                  _selected.remove(index);
                  _selected.add(newIndex);
                } else {
                  _selected.clear();
                  _selected.add(newIndex);
                }
                _selectedShapeIndex = newIndex;
              });
            },
            onPanUpdate: (details) {
              if (_interactingWithHandle) return;
              if (_selected.contains(index)) {
                setState(() {
                  final delta = details.delta / _zoom;
                  for (final sel in _selected) {
                    final shp = _shapes[sel];
                    if (shp.locked) continue;
                    shp.position += delta;
                    final renderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                    if (renderBox != null) {
                      final sizeCanvas = renderBox.size;
                      final maxX = sizeCanvas.width - shp.size;
                      final maxY = sizeCanvas.height - shp.size;
                      shp.position = Offset(
                        shp.position.dx.clamp(0.0, maxX),
                        shp.position.dy.clamp(0.0, maxY),
                      );
                    }
                  }
                });
              }
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: outerPad,
                  top: outerPad,
                  width: s.size,
                  height: s.size,
                  child: Transform.rotate(
                    angle: s.rotation,
                    child: Container(
                      decoration: (isSelected && s.asset != 'generated:text')
                          ? BoxDecoration(
                              border: Border.all(
                                color: AppTheme.colors.primary,
                                width: 1.2,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            )
                          : null,
                      padding: EdgeInsets.all(isSelected ? 2 : 0),
                      child: s.asset.startsWith('generated:')
                          ? CustomPaint(
                              painter: s.asset == 'generated:text'
                                  ? _TextShapePainter(
                                      text: s.textContent ?? 'Texto',
                                      fontSize: s.fontSize ?? 16,
                                    )
                                  : _shapePainterForKey(s.asset),
                              size: Size.infinite,
                            )
                          : Image.asset(
                              s.asset,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stack) => Icon(
                                Icons.crop_square,
                                size: s.size * 0.6,
                                color: Colors.grey[400],
                              ),
                            ),
                    ),
                  ),
                ),
                if (isSelected) ...[
                  Positioned(
                    top: outerPad - (handleSize + 10),
                    right: outerPad - (handleSize / 2),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (_) => _interactingWithHandle = true,
                      onTapCancel: () => _interactingWithHandle = false,
                      onTapUp: (_) => _interactingWithHandle = false,
                      onTap: () {
                        setState(() {
                          final toRemove = _selected.isNotEmpty
                              ? _selected.toList()
                              : [index];
                          toRemove.sort((a, b) => b.compareTo(a));
                          for (final i in toRemove) {
                            _shapes.removeAt(i);
                          }
                          _selected.clear();
                          _selectedShapeIndex = -1;
                        });
                      },
                      child: Container(
                        width: handleSize + 10,
                        height: handleSize + 10,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: outerPad - (handleSize + 12),
                    left: outerPad - (handleSize / 2),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (details) {
                        _interactingWithHandle = true;
                        _rotatingShapeIndex = index;
                        _rotatingInitialRotation = s.rotation;
                        final center = s.position + Offset(s.size / 2, s.size / 2);
                        final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                        if (box != null) {
                          final local = box.globalToLocal(details.globalPosition);
                          final canvasPoint = _widgetToCanvas(local);
                          final vector = canvasPoint - center;
                          _rotatingInitialAngle = math.atan2(vector.dy, vector.dx);
                        } else {
                          _rotatingInitialAngle = 0.0;
                        }
                      },
                      onPanDown: (_) => _interactingWithHandle = true,
                      onPanCancel: () { _interactingWithHandle = false; _rotatingShapeIndex = null; },
                      onPanEnd: (_) { _interactingWithHandle = false; _rotatingShapeIndex = null; },
                      onPanUpdate: (details) {
                        setState(() {
                          final center = s.position + Offset(s.size / 2, s.size / 2);
                          final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                          if (box != null) {
                            final local = box.globalToLocal(details.globalPosition);
                            final canvasPoint = _widgetToCanvas(local);
                            final vector = canvasPoint - center;
                            final currentAngle = math.atan2(vector.dy, vector.dx);
                            if (_rotatingShapeIndex == index) {
                              final delta = currentAngle - _rotatingInitialAngle;
                              s.rotation = _rotatingInitialRotation + delta;
                            } else {
                              s.rotation = currentAngle;
                            }
                          }
                        });
                      },
                      child: Container(
                        width: handleSize + 10,
                        height: handleSize + 10,
                        decoration: BoxDecoration(
                          color: AppTheme.colors.primary,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.rotate_right,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: outerPad - (handleSize / 2),
                    right: outerPad - (handleSize / 2),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanDown: (_) => _interactingWithHandle = true,
                      onPanCancel: () => _interactingWithHandle = false,
                      onPanEnd: (_) => _interactingWithHandle = false,
                      onPanUpdate: (details) {
                        setState(() {
                          final keys =
                              HardwareKeyboard.instance.logicalKeysPressed;
                          final keepProportion =
                              keys.contains(LogicalKeyboardKey.shiftLeft) ||
                              keys.contains(LogicalKeyboardKey.shiftRight);
                          if (_selected.length <= 1) {
                            final rawDelta = keepProportion
                                ? (details.delta.dx.abs() >=
                                          details.delta.dy.abs()
                                      ? details.delta.dx
                                      : details.delta.dy)
                                : details.delta.dx;
                            double newSize = s.size + rawDelta / _zoom;
                            newSize = newSize.clamp(24.0, 320.0);
                            final renderBox =
                                _canvasKey.currentContext?.findRenderObject()
                                    as RenderBox?;
                            if (renderBox != null) {
                              final sizeCanvas = renderBox.size;
                              if (s.position.dx + newSize > sizeCanvas.width) {
                                newSize = sizeCanvas.width - s.position.dx;
                              }
                              if (s.position.dy + newSize > sizeCanvas.height) {
                                newSize = sizeCanvas.height - s.position.dy;
                              }
                            }
                            if (keepProportion) {
                              newSize = (newSize / 8).round() * 8;
                            }
                            s.size = newSize;
                          } else {
                            final bounds = _selectionBounds();
                            if (bounds == null) return;
                            final anchor = bounds.topLeft;
                            final cur = bounds.bottomRight;
                            final newBR = cur + details.delta / _zoom;
                            final newW = (newBR.dx - anchor.dx).clamp(
                              24.0,
                              double.infinity,
                            );
                            final newH = (newBR.dy - anchor.dy).clamp(
                              24.0,
                              double.infinity,
                            );
                            final sx = newW / bounds.width;
                            final sy = newH / bounds.height;
                            final scale = keepProportion
                                ? math.min(sx, sy)
                                : math.min(sx, sy);
                            final center = bounds.center;
                            for (final idx in _selected) {
                              final shp = _shapes[idx];
                              if (shp.locked) continue;
                              final rel =
                                  shp.position +
                                  Offset(shp.size / 2, shp.size / 2) -
                                  center;
                              final relScaled = rel * scale;
                              shp.size = (shp.size * scale).clamp(16.0, 640.0);
                              shp.position =
                                  center +
                                  relScaled -
                                  Offset(shp.size / 2, shp.size / 2);
                            }
                          }
                        });
                      },
                      child: Container(
                        width: handleSize + 10,
                        height: handleSize + 10,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: AppTheme.colors.primary,
                            width: 1.2,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.open_in_full,
                          size: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          ),
        ),
      );
    }).toList();
  }

  void _showProfileMenu() {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        MediaQuery.of(context).size.width,
        kToolbarHeight,
        0,
        0,
      ),
      items: [
        PopupMenuItem(
          child: const Text('Configurações'),
          onTap: () {
            // Necessário post-frame para não conflitar com o menu
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.pushNamed(context, '/settings');
            });
          },
        ),
        PopupMenuItem(
          child: const Text('Coleção'),
          onTap: () {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.pushNamed(context, '/collection');
            });
          },
        ),
        PopupMenuItem(
          child: const Text('Histórico'),
          onTap: () {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.pushNamed(context, '/history');
            });
          },
        ),
        PopupMenuItem(
          enabled: false,
          child: SizedBox(
            width: 180,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.logout, size: 18),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.colors.primary,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: () async {
                Navigator.pop(context); // fechar menu antes do diálogo
                final auth = context.read<AuthProvider>();
                final confirm = await _confirmLogout();
                if (confirm) {
                  await auth.logout();
                  if (mounted) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                }
              },
              label: const Text('Sair'),
            ),
          ),
        ),
      ],
    );
  }

  Future<bool> _confirmLogout() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: const Text('Confirmar saída'),
              content: const Text('Deseja realmente sair da conta?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.colors.primary,
                  ),
                  child: const Text('Sair'),
                ),
              ],
            );
          },
        ) ??
        false;
  }


  // ===== IA Panel =====
  Widget _buildIaPanel() {
    final categories = DiagramTemplateLibrary.getCategories();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Assistente de Diagramas',
              style: AppTheme.typography.title.copyWith(fontSize: 20),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _selectedIndex = -1),
            ),
          ],
        ),
        SizedBox(height: AppTheme.spacing.medium),
        
        // Lista de categorias e subcategorias
        Expanded(
          child: ListView(
            children: [
              for (final category in categories) ...[
                _buildDiagramCategoryHeader(category),
                if (_selectedDiagramCategory == category) ...[
                  for (final subcategory in DiagramTemplateLibrary.getSubcategories(category))
                    _buildDiagramSubcategorySection(category, subcategory),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDiagramCategoryHeader(String category) {
    final isExpanded = _selectedDiagramCategory == category;
    
    // Ícones por categoria
    IconData getCategoryIcon() {
      switch (category) {
        case 'Fisica':
          return Icons.science;
        case 'Quimica':
          return Icons.biotech;
        case 'Geral':
          return Icons.category;
        default:
          return Icons.folder;
      }
    }
    
    return InkWell(
      onTap: () {
        setState(() {
          if (isExpanded) {
            _selectedDiagramCategory = '';
            _selectedDiagramSubcategory = '';
          } else {
            _selectedDiagramCategory = category;
            _selectedDiagramSubcategory = '';
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isExpanded ? AppTheme.colors.primary.withOpacity(0.1) : null,
          border: Border(
            bottom: BorderSide(color: Colors.grey[300]!),
          ),
        ),
        child: Row(
          children: [
            Icon(
              getCategoryIcon(),
              color: AppTheme.colors.primary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Text(
              category,
              style: AppTheme.typography.label.copyWith(
                fontWeight: FontWeight.bold,
                color: isExpanded ? AppTheme.colors.primary : Colors.black87,
              ),
            ),
            const Spacer(),
            Icon(
              isExpanded ? Icons.expand_more : Icons.chevron_right,
              color: AppTheme.colors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagramSubcategorySection(String category, String subcategory) {
    final isExpanded = _selectedDiagramSubcategory == subcategory;
    
    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _selectedDiagramSubcategory = '';
              } else {
                _selectedDiagramSubcategory = subcategory;
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
            color: isExpanded
                ? AppTheme.colors.secondary.withOpacity(0.1)
                : Colors.grey[50],
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.expand_more : Icons.chevron_right,
                  size: 20,
                  color: AppTheme.colors.secondary,
                ),
                const SizedBox(width: 8),
                Text(
                  subcategory,
                  style: AppTheme.typography.paragraph.copyWith(
                    fontSize: 16,
                    fontWeight: isExpanded ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) ...[
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                for (final template in DiagramTemplateLibrary.getTemplatesBySubcategory(
                  category,
                  subcategory,
                ))
                  _buildDiagramTemplateCard(template),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDiagramTemplateCard(DiagramTemplate template) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _insertDiagramTemplate(template),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    template.icon,
                    color: AppTheme.colors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      template.name,
                      style: AppTheme.typography.paragraph.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                template.description,
                style: AppTheme.typography.paragraph.copyWith(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.layers,
                    size: 14,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${template.shapes.length} elementos',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.add_circle,
                    color: AppTheme.colors.primary,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Insere um template de diagrama no canvas
  void _insertDiagramTemplate(DiagramTemplate template) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    // Calcula o centro da viewport (considerando zoom e pan)
    final viewportSize = box.size;
    final viewportCenter = viewportSize.center(Offset.zero);
    
    // Converte para coordenadas do canvas (considerando zoom e pan)
    final canvasCenter = (viewportCenter - _pan) / _zoom;

    setState(() {
      // Limpa a seleção atual
      _selected.clear();
      _selectedShapeIndex = -1;
      
      // Índice inicial das novas formas
      final startIndex = _shapes.length;
      
      // Para cada forma no template
      for (final templateShape in template.shapes) {
        // Converte posição relativa (-1 a 1) para posição absoluta no canvas
        // Usamos um espaço de 200px como referência para o diagrama
        final diagramSpacing = 200.0;
        final absoluteX = canvasCenter.dx + (templateShape.relativeX * diagramSpacing);
        final absoluteY = canvasCenter.dy + (templateShape.relativeY * diagramSpacing);
        
        // Cria e adiciona a forma
        _shapes.add(
          _PlacedShape(
            asset: templateShape.asset,
            position: Offset(absoluteX - templateShape.size / 2, absoluteY - templateShape.size / 2),
            size: templateShape.size,
            rotation: templateShape.rotation,
            textContent: templateShape.textContent,
            fontSize: templateShape.fontSize,
            customName: templateShape.customName,
          ),
        );
      }
      
      // Seleciona automaticamente todas as formas recém-adicionadas
      final endIndex = _shapes.length;
      for (int i = startIndex; i < endIndex; i++) {
        _selected.add(i);
      }
      
      // Se houver apenas uma forma, define como seleção principal
      if (template.shapes.length == 1) {
        _selectedShapeIndex = startIndex;
      }
    });
  }

  // ===== Properties Panel =====
  Widget _buildPropertiesPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Propriedades',
              style: AppTheme.typography.title.copyWith(fontSize: 20),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _selectedIndex = -1),
            ),
          ],
        ),
        SizedBox(height: AppTheme.spacing.medium),
        Expanded(
          child: _selected.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.touch_app, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Selecione um elemento\npara editar propriedades',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(8),
                  children: [
                    _buildPropertySection('Dimensões', [
                      _buildNumberField(
                        'Tamanho',
                        _getCommonValue((s) => s.size),
                        (v) {
                          setState(() {
                            _updateSelectedShapes((s) => s.size = v.clamp(16.0, 640.0));
                          });
                        },
                      ),
                    ]),
                    const Divider(height: 24),
                    _buildPropertySection('Rotação', [
                      _buildNumberField(
                        'Graus',
                        _getCommonValue((s) => s.rotation * 180 / math.pi),
                        (v) {
                          setState(() {
                            _updateSelectedShapes((s) => s.rotation = v * math.pi / 180);
                          });
                        },
                        suffix: '°',
                      ),
                      const SizedBox(height: 8),
                      Slider(
                        value: (_getCommonValue((s) => s.rotation) ?? 0.0) * 180 / math.pi,
                        min: -180,
                        max: 180,
                        divisions: 72,
                        label: '${((_getCommonValue((s) => s.rotation) ?? 0.0) * 180 / math.pi).toStringAsFixed(0)}°',
                        onChanged: (v) => setState(() {
                          _updateSelectedShapes((s) => s.rotation = v * math.pi / 180);
                        }),
                      ),
                    ]),
                    const Divider(height: 24),
                    _buildPropertySection('Estado', [
                      SwitchListTile(
                        value: _getCommonBool((s) => s.locked) ?? false,
                        onChanged: (v) => setState(() {
                          _updateSelectedShapes((s) => s.locked = v);
                        }),
                        title: const Text('Bloqueado'),
                        subtitle: const Text('Impede edição'),
                      ),
                      SwitchListTile(
                        value: _getCommonBool((s) => s.visible) ?? true,
                        onChanged: (v) => setState(() {
                          _updateSelectedShapes((s) => s.visible = v);
                        }),
                        title: const Text('Visível'),
                        subtitle: const Text('Exibir no canvas'),
                      ),
                    ]),
                    // Propriedades específicas de texto
                    if (_selected.length == 1 && _shapes[_selected.first].asset == 'generated:text') ...[
                      const Divider(height: 24),
                      _buildPropertySection('Texto', [
                        TextFormField(
                          initialValue: _shapes[_selected.first].textContent ?? 'Texto',
                          decoration: const InputDecoration(
                            labelText: 'Conteúdo',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                          onChanged: (v) => setState(() {
                            final s = _shapes[_selected.first];
                            s.textContent = v.isEmpty ? 'Texto' : v;
                            _autoResizeTextShape(s);
                          }),
                        ),
                        const SizedBox(height: 12),
                        _buildNumberField(
                          'Tamanho da Fonte',
                          _shapes[_selected.first].fontSize ?? 16.0,
                          (v) => setState(() {
                            final s = _shapes[_selected.first];
                            s.fontSize = v.clamp(8.0, 72.0);
                            _autoResizeTextShape(s);
                          }),
                        ),
                      ]),
                    ],
                    const SizedBox(height: 100), // padding bottom
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildPropertySection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTheme.typography.title.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildNumberField(
    String label,
    double? value,
    void Function(double) onChanged, {
    String suffix = '',
  }) {
    final controller = TextEditingController(
      text: value != null ? value.toStringAsFixed(1) : '',
    );
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        suffix: suffix.isNotEmpty ? Text(suffix) : null,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (v) {
        final parsed = double.tryParse(v);
        if (parsed != null) {
          onChanged(parsed);
        }
      },
    );
  }

  double? _getCommonValue(double Function(_PlacedShape) getter) {
    if (_selected.isEmpty) return null;
    final first = getter(_shapes[_selected.first]);
    for (final i in _selected.skip(1)) {
      if ((getter(_shapes[i]) - first).abs() > 0.01) {
        return null; // valores mistos
      }
    }
    return first;
  }

  bool? _getCommonBool(bool Function(_PlacedShape) getter) {
    if (_selected.isEmpty) return null;
    final first = getter(_shapes[_selected.first]);
    for (final i in _selected.skip(1)) {
      if (getter(_shapes[i]) != first) {
        return null; // valores mistos
      }
    }
    return first;
  }

  void _updateSelectedShapes(void Function(_PlacedShape) updater) {
    for (final i in _selected) {
      if (!_shapes[i].locked) {
        updater(_shapes[i]);
      }
    }
  }

  // ===== Export helpers =====
  Future<Uint8List?> _captureCanvasPng({required double pixelRatio, required bool transparent}) async {
    final boundary = _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    // Alterna background para transparente se necessário
    final prev = _exportingTransparent;
    if (transparent != prev) {
      setState(() { _exportingTransparent = transparent; });
      await WidgetsBinding.instance.endOfFrame;
    }
    // Esconde grade se estiver ativa
    final prevSuppress = _suppressGridDuringCapture;
    setState(() { _suppressGridDuringCapture = true; });
    await WidgetsBinding.instance.endOfFrame;
    try {
      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      // Restaura estado
      if (transparent != prev) {
        setState(() { _exportingTransparent = prev; });
        await WidgetsBinding.instance.endOfFrame;
      }
      setState(() { _suppressGridDuringCapture = prevSuppress; });
      return bytes;
    } catch (_) {
      if (transparent != prev) {
        setState(() { _exportingTransparent = prev; });
      }
      setState(() { _suppressGridDuringCapture = prevSuppress; });
      return null;
    }
  }

  Future<void> _exportPng({required int dpi, required bool transparent}) async {
    final ratio = dpi / 72.0; // base aproximada
    final bytes = await _captureCroppedContentPng(pixelRatio: ratio, transparent: transparent);
    if (bytes == null) return;
    await FileSaver.instance.saveFile(
      name: 'canvas_${dpi}dpi',
      bytes: bytes,
      ext: 'png',
      mimeType: MimeType.png,
    );
  }

  Future<void> _exportSvg() async {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final contentRect = _visibleContentBoundsCanvas(padding: 24) ?? Rect.fromLTWH(0, 0, box.size.width, box.size.height);
    final size = Size(contentRect.width, contentRect.height);
    // Cache base64 por asset
    final Map<String, String> base64ByAsset = {};
    for (final s in _shapes.where((s) => s.visible)) {
      base64ByAsset[s.asset] ??= base64Encode((await rootBundle.load(s.asset)).buffer.asUint8List());
    }
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<svg xmlns="http://www.w3.org/2000/svg" version="1.1" width="${size.width}" height="${size.height}" viewBox="0 0 ${size.width} ${size.height}">');
    // Background branco (opcional); manter transparente por padrão
    for (final s in _shapes.where((s) => s.visible)) {
      final cx = (s.position.dx - contentRect.left) + s.size / 2;
      final cy = (s.position.dy - contentRect.top) + s.size / 2;
      final deg = s.rotation * 180 / math.pi;
      final b64 = base64ByAsset[s.asset]!;
      buffer.writeln('<g transform="rotate($deg $cx $cy)">');
      final adjX = s.position.dx - contentRect.left;
      final adjY = s.position.dy - contentRect.top;
      buffer.writeln('<image href="data:image/png;base64,$b64" x="$adjX" y="$adjY" width="${s.size}" height="${s.size}" />');
      buffer.writeln('</g>');
    }
    buffer.writeln('</svg>');

    final bytes = utf8.encode(buffer.toString());
    await FileSaver.instance.saveFile(
      name: 'canvas',
      bytes: Uint8List.fromList(bytes),
      ext: 'svg',
      mimeType: MimeType.other,
    );
  }

  Future<void> _exportPdf({int dpi = 300}) async {
    // Mitigação de travamento + recorte ao conteúdo
    final png = await _captureCroppedContentPng(pixelRatio: 2.0, transparent: false);
    if (png == null) return;
    final doc = pw.Document();
    final image = pw.MemoryImage(png);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Center(
            child: pw.FittedBox(
              child: pw.Image(image),
              fit: pw.BoxFit.contain,
            ),
          );
        },
      ),
    );
    final bytes = await doc.save();
    await FileSaver.instance.saveFile(
      name: 'canvas',
      bytes: Uint8List.fromList(bytes),
      ext: 'pdf',
      mimeType: MimeType.pdf,
    );
  }

  // ===== Fluxo de Salvar Imagem =====
  Future<void> _saveImageFlow() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Deseja salvar esta imagem?'),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: const Text('Sim'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.pinkAccent,
                side: const BorderSide(color: Colors.pinkAccent),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: const Text('Não'),
            ),
          ],
        );
      },
    ) ?? false;
    if (!confirm) return;
    // Mostra overlay primeiro (setState) e depois realiza captura assíncrona
    if (mounted) {
      setState(() {
        _isBusy = true;
        _busyMessage = 'Gerando preview...';
      });
    }
    // Pequeno atraso para permitir render do overlay antes da captura pesada
    await Future.delayed(const Duration(milliseconds: 50));
    await _captureContentPreview();
    if (mounted) {
      setState(() {
        _isBusy = false;
        _busyMessage = null;
      });
    }
    if (_lastPreviewBytes == null) return;
    _showSavePreviewPanel();
  }

  Future<void> _captureContentPreview({double pixelRatio = 2.0}) async {
    final boundary = _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    final contentRectCanvas = _visibleContentBoundsCanvas(padding: 24);
    if (contentRectCanvas == null) {
      _lastPreviewBytes = await _captureCanvasPng(pixelRatio: pixelRatio, transparent: false);
      return;
    }
    final cropped = await _captureCroppedContentPng(pixelRatio: pixelRatio, transparent: false);
    _lastPreviewBytes = cropped;
  }

  Future<Uint8List?> _captureCroppedContentPng({required double pixelRatio, required bool transparent}) async {
    final fullBytes = await _captureCanvasPng(pixelRatio: pixelRatio, transparent: transparent);
    if (fullBytes == null) return null;
    final contentRectCanvas = _visibleContentBoundsCanvas(padding: 24);
    if (contentRectCanvas == null) return fullBytes;
    final screenRect = _canvasRectToScreen(contentRectCanvas);
    // Decodificação & recorte em isolate para não travar UI
    final decoded = await compute(_decodeImage, fullBytes);
    if (decoded == null) return fullBytes;
    int cropLeft = (screenRect.left * pixelRatio).round();
    int cropTop = (screenRect.top * pixelRatio).round();
    int cropRight = (screenRect.right * pixelRatio).round();
    int cropBottom = (screenRect.bottom * pixelRatio).round();
    cropLeft = cropLeft.clamp(0, decoded.width - 1);
    cropTop = cropTop.clamp(0, decoded.height - 1);
    cropRight = cropRight.clamp(cropLeft + 1, decoded.width);
    cropBottom = cropBottom.clamp(cropTop + 1, decoded.height);
    final cropW = cropRight - cropLeft;
    final cropH = cropBottom - cropTop;
    if (cropW <= 0 || cropH <= 0) return fullBytes;
    final croppedBytes = await compute(_cropAndEncode, {
      'image': decoded,
      'x': cropLeft,
      'y': cropTop,
      'w': cropW,
      'h': cropH,
    });
    return croppedBytes ?? fullBytes;
  }

  // Funções puras para usar com compute
  static img.Image? _decodeImage(Uint8List bytes) {
    return img.decodeImage(bytes);
  }

  static Uint8List? _cropAndEncode(Map<String, dynamic> args) {
    final img.Image? image = args['image'] as img.Image?;
    if (image == null) return null;
    final int x = args['x'] as int;
    final int y = args['y'] as int;
    final int w = args['w'] as int;
    final int h = args['h'] as int;
    final cropped = img.copyCrop(image, x: x, y: y, width: w, height: h);
    return Uint8List.fromList(img.encodePng(cropped));
  }

  void _showSavePreviewPanel() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AspectRatio(
                      aspectRatio: 5/4,
                      child: Container(
                        color: Colors.grey[300],
                        alignment: Alignment.center,
                        child: _lastPreviewBytes == null
                            ? const SizedBox.shrink()
                            : Image.memory(_lastPreviewBytes!, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _showExportDialog();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pinkAccent,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        ),
                        child: const Text('Baixar'),
                      ),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _saveToCollection,
                            icon: const Icon(Icons.bookmark_border, size: 18),
                            label: const Text('Salvar'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.pinkAccent,
                              side: const BorderSide(color: Colors.pinkAccent),
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: _viewFullscreenPreview,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.pinkAccent,
                              side: const BorderSide(color: Colors.pinkAccent),
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            child: const Text('Visualizar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveToCollection() async {
    // Serializa composição simples (JSON) em SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('collection') ?? <String>[];
    final composition = {
      'createdAt': DateTime.now().toIso8601String(),
      'pan': {'x': _pan.dx, 'y': _pan.dy},
      'zoom': _zoom,
      'shapes': [
        for (final s in _shapes)
          {
            'asset': s.asset,
            'x': s.position.dx,
            'y': s.position.dy,
            'size': s.size,
            'rotation': s.rotation,
            'locked': s.locked,
            'visible': s.visible,
            'groupId': s.groupId,
            if (s.textContent != null) 'text': s.textContent,
            if (s.fontSize != null) 'fontSize': s.fontSize,
          }
      ],
    };
    list.add(jsonEncode(composition));
    await prefs.setStringList('collection', list);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Salvo na coleção')),
      );
    }
  }

  void _viewFullscreenPreview() {
    if (_lastPreviewBytes == null) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                child: Image.memory(_lastPreviewBytes!, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExportDialog() {
    int selectedDpi = 150;
    bool transparent = false;
    String format = 'PNG';
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSt) {
          return AlertDialog(
            title: const Text('Exportar'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Formato'),
                const SizedBox(height: 6),
                Wrap(spacing: 16, runSpacing: 12, children: [
                  ChoiceChip(
                    label: const Text('PNG'),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    selected: format == 'PNG',
                    onSelected: (_) => setSt(() => format = 'PNG'),
                  ),
                  ChoiceChip(
                    label: const Text('SVG'),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    selected: format == 'SVG',
                    onSelected: (_) => setSt(() => format = 'SVG'),
                  ),
                  ChoiceChip(
                    label: const Text('PDF'),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    selected: format == 'PDF',
                    onSelected: (_) => setSt(() => format = 'PDF'),
                  ),
                ]),
                const SizedBox(height: 16),
                if (format == 'PNG') ...[
                  const Text('Opções PNG'),
                  const SizedBox(height: 6),
                  DropdownButton<int>(
                    value: selectedDpi,
                    items: const [72, 150, 300]
                        .map((e) => DropdownMenuItem(value: e, child: Text('${e} DPI')))
                        .toList(),
                    onChanged: (v) => setSt(() => selectedDpi = v ?? selectedDpi),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: transparent,
                    onChanged: (v) => setSt(() => transparent = v ?? false),
                    title: const Text('Fundo transparente'),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.download),
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  if (format == 'PNG') {
                    await _runWithLoading('Exportando PNG...', () async {
                      await _exportPng(dpi: selectedDpi, transparent: transparent);
                    });
                  } else if (format == 'SVG') {
                    await _runWithLoading('Exportando SVG...', () async {
                      await _exportSvg();
                    });
                  } else {
                    await _runWithLoading('Exportando PDF...', () async {
                      await _exportPdf(dpi: 300);
                    });
                  }
                },
                label: const Text('Exportar'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<T?> _runWithLoading<T>(String message, Future<T> Function() action) async {
    if (mounted) {
      setState(() {
        _isBusy = true;
        _busyMessage = message;
      });
    }
    try {
      final res = await action();
      return res;
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _busyMessage = null;
        });
      }
    }
  }

  // Botão pequeno redondo para controles de texto
  Widget _smallRoundButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[400]!),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: Colors.black87),
      ),
    );
  }

  void _editTextShape(int index) async {
    if (index < 0 || index >= _shapes.length) return;
    final s = _shapes[index];
    if (s.asset != 'generated:text') return;
    final controller = TextEditingController(text: s.textContent ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Editar texto'),
            content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'Digite...'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
    if (result != null) {
      setState(() {
        s.textContent = result.isEmpty ? 'Texto' : result;
        _autoResizeTextShape(s);
      });
    }
  }

  void _showRenameDialog(int index) async {
    if (index < 0 || index >= _shapes.length) return;
    final s = _shapes[index];
    final currentName = s.customName ?? _displayNameForShape(s);
    final controller = TextEditingController(text: currentName);
    
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Renomear elemento'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Nome do elemento',
              labelText: 'Nome',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  s.customName = null; // resetar para nome padrão
                });
                Navigator.of(ctx).pop();
              },
              child: const Text('Resetar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
    
    if (result != null && result.isNotEmpty) {
      setState(() {
        s.customName = result;
      });
    }
  }

  void _autoResizeTextShape(_PlacedShape s) {
    final span = TextSpan(
      text: s.textContent ?? 'Texto',
      style: TextStyle(fontSize: s.fontSize ?? 16),
    );
    final tp = TextPainter(text: span, textDirection: TextDirection.ltr, maxLines: 10)..layout();
    final needed = math.max(tp.width, tp.height) + 12;
    s.size = needed.clamp(24.0, 640.0);
  }

  String _displayNameForShape(_PlacedShape s) {
    // Se tem nome customizado, usa ele
    if (s.customName != null && s.customName!.isNotEmpty) {
      return s.customName!;
    }
    // Senão, usa nome padrão baseado no asset
    if (s.asset.startsWith('generated:')) {
      final key = s.asset.substring('generated:'.length);
      return _displayNameForKey(key);
    }
    return _displayNameForAsset(s.asset);
  }

  String _displayNameForKey(String key) {
    switch (key) {
      case 'rect': return 'Retângulo';
      case 'circle': return 'Círculo';
      case 'triangle': return 'Triângulo';
      case 'line_solid': return 'Linha';
      case 'line_dashed': return 'Linha Tracejada';
      case 'block': return 'Bloco';
      case 'plane': return 'Plano Inclinado';
      case 'pulley': return 'Polia';
      case 'spring': return 'Mola';
      case 'vector': return 'Vetor';
      case 'resistor': return 'Resistor';
      case 'battery': return 'Bateria';
      case 'ammeter': return 'Amperímetro';
      case 'wire': return 'Fio';
      case 'text': return 'Texto';
      // Circuitos expandidos
      case 'capacitor': return 'Capacitor';
      case 'led': return 'LED';
      case 'diode': return 'Diodo';
      case 'switch': return 'Interruptor';
      case 'ground': return 'Terra';
      case 'ac_source': return 'Fonte AC';
      // Mecânica expandida
      case 'pendulum': return 'Pêndulo';
      case 'balance': return 'Balança';
      case 'cart': return 'Carrinho';
      case 'friction_surface': return 'Superfície com Atrito';
      case 'rope': return 'Corda';
      // Óptica
      case 'convergent_lens': return 'Lente Convergente';
      case 'divergent_lens': return 'Lente Divergente';
      case 'mirror': return 'Espelho';
      case 'light_ray': return 'Raio de Luz';
      case 'prism': return 'Prisma';
      // Química
      case 'beaker': return 'Béquer';
      case 'erlenmeyer': return 'Erlenmeyer';
      case 'test_tube': return 'Tubo de Ensaio';
      case 'benzene': return 'Benzeno';
      default: return 'Forma';
    }
  }

  String _displayNameForAsset(String assetPath) {
    final parts = assetPath.split('/');
    if (parts.length >= 3) {
      return parts[parts.length - 2];
    }
    return 'Forma';
  }

}

// Pintor do retângulo de seleção (marquee)
class _MarqueePainter extends CustomPainter {
  final Rect rect;
  _MarqueePainter(this.rect);

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = Colors.blue.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = Colors.blue.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    canvas.drawRect(rect, fill);
    canvas.drawRect(rect, stroke);
  }

  @override
  bool shouldRepaint(covariant _MarqueePainter oldDelegate) =>
      oldDelegate.rect != rect;
}

// ================= Painters para shapes gerados =================

class _RectPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(6)),
      paint,
    );
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(
      size.center(Offset.zero),
      size.shortestSide / 2,
      paint,
    );
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width/2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LinePainter extends CustomPainter {
  final bool dashed;
  _LinePainter({required this.dashed});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    if (!dashed) {
      canvas.drawLine(Offset(0, size.height/2), Offset(size.width, size.height/2), paint);
    } else {
      const dashWidth = 8.0;
      const dashSpace = 6.0;
      double x = 0;
      final y = size.height/2;
      while (x < size.width) {
        final x2 = math.min(x + dashWidth, size.width);
        canvas.drawLine(Offset(x, y), Offset(x2, y), paint);
        x += dashWidth + dashSpace;
      }
    }
  }
  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) => oldDelegate.dashed != dashed;
}

class _BlockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final r = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    canvas.drawRect(r, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InclinedPlanePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, 0)
      ..close();
    final paint = Paint()..color = Colors.grey.shade400;
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PulleyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final outer = Paint()..color = Colors.grey.shade300;
    final inner = Paint()..color = Colors.grey.shade600;
    final center = size.center(Offset.zero);
    canvas.drawCircle(center, size.shortestSide/2, outer);
    canvas.drawCircle(center, size.shortestSide/4, inner);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SpringPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.deepPurple
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    const turns = 6;
    final h = size.height;
    final w = size.width;
    for (int i = 0; i <= turns; i++) {
      final t = i / turns;
      final x = t * w;
      final y = (math.sin(t * math.pi * 2) * h/2 * 0.5) + h/2;
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ForceVectorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final start = Offset(size.width * 0.15, size.height * 0.85);
    final end = Offset(size.width * 0.85, size.height * 0.15);
    canvas.drawLine(start, end, paint);
    final headSize = 10.0;
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    final path = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - headSize * math.cos(angle - 0.35),
        end.dy - headSize * math.sin(angle - 0.35),
      )
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - headSize * math.cos(angle + 0.35),
        end.dy - headSize * math.sin(angle + 0.35),
      );
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ResistorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final midY = size.height / 2;
    final leftLead = 6.0;
    final rightLead = size.width - 6.0;
    final zigW = rightLead - leftLead;
    final segment = zigW / 7;
    final path = Path()
      ..moveTo(0, midY)
      ..lineTo(leftLead, midY);
    double x = leftLead;
    bool up = true;
    for (int i = 0; i < 7; i++) {
      x += segment;
      path.lineTo(x, midY + (up ? -8 : 8));
      up = !up;
    }
    path.lineTo(rightLead, midY);
    path.lineTo(size.width, midY);
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BatteryPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final midY = size.height / 2;
    final centerX = size.width / 2;
    final longHalf = 14.0;
    final shortHalf = 8.0;
    canvas.drawLine(
      Offset(centerX - 10, midY - longHalf),
      Offset(centerX - 10, midY + longHalf),
      paint,
    );
    canvas.drawLine(
      Offset(centerX + 10, midY - shortHalf),
      Offset(centerX + 10, midY + shortHalf),
      paint,
    );
    canvas.drawLine(Offset(0, midY), Offset(centerX - 10, midY), paint);
    canvas.drawLine(Offset(centerX + 10, midY), Offset(size.width, midY), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AmmeterPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final border = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final r = size.shortestSide / 2 - 2;
    final c = size.center(Offset.zero);
    canvas.drawCircle(c, r, border);
    final tp = TextPainter(
      text: const TextSpan(
        text: 'A',
        style: TextStyle(
          fontSize: 16,
          color: Colors.black,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width/2, tp.height/2));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WirePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, size.height/2), Offset(size.width, size.height/2), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Painter dinâmico para texto (sem borda / sem fundo)
class _TextShapePainter extends CustomPainter {
  final String text;
  final double fontSize;
  _TextShapePainter({required this.text, required this.fontSize});
  @override
  void paint(Canvas canvas, Size size) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: Colors.black,
        ),
      ),
      maxLines: 10,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    tp.paint(
      canvas,
      size.center(Offset.zero) - Offset(tp.width / 2, tp.height / 2),
    );
  }
  @override
  bool shouldRepaint(covariant _TextShapePainter oldDelegate) =>
      oldDelegate.text != text || oldDelegate.fontSize != fontSize;
}

// ================= CIRCUITOS ELÉTRICOS EXPANDIDOS =================

class _CapacitorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final midY = size.height / 2;
    final centerX = size.width / 2;
    final plateHeight = 20.0;
    // Placa esquerda
    canvas.drawLine(
      Offset(centerX - 4, midY - plateHeight / 2),
      Offset(centerX - 4, midY + plateHeight / 2),
      paint,
    );
    // Placa direita
    canvas.drawLine(
      Offset(centerX + 4, midY - plateHeight / 2),
      Offset(centerX + 4, midY + plateHeight / 2),
      paint,
    );
    // Fios
    canvas.drawLine(Offset(0, midY), Offset(centerX - 4, midY), paint);
    canvas.drawLine(Offset(centerX + 4, midY), Offset(size.width, midY), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LEDPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    // Triângulo (ânodo)
    final trianglePath = Path()
      ..moveTo(centerX - 8, centerY - 10)
      ..lineTo(centerX - 8, centerY + 10)
      ..lineTo(centerX + 6, centerY)
      ..close();
    canvas.drawPath(trianglePath, paint);
    // Barra vertical (cátodo)
    canvas.drawLine(
      Offset(centerX + 6, centerY - 10),
      Offset(centerX + 6, centerY + 10),
      paint,
    );
    // Fios
    canvas.drawLine(Offset(0, centerY), Offset(centerX - 8, centerY), paint);
    canvas.drawLine(Offset(centerX + 6, centerY), Offset(size.width, centerY), paint);
    // Setas de luz
    final arrowPaint = Paint()
      ..color = Colors.amber[700]!
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final arrow1Start = Offset(centerX + 12, centerY - 8);
    final arrow1End = Offset(centerX + 18, centerY - 14);
    canvas.drawLine(arrow1Start, arrow1End, arrowPaint);
    canvas.drawLine(arrow1End, Offset(arrow1End.dx - 3, arrow1End.dy + 2), arrowPaint);
    canvas.drawLine(arrow1End, Offset(arrow1End.dx - 2, arrow1End.dy + 3), arrowPaint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DiodePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    // Triângulo
    final trianglePath = Path()
      ..moveTo(centerX - 8, centerY - 10)
      ..lineTo(centerX - 8, centerY + 10)
      ..lineTo(centerX + 6, centerY)
      ..close();
    canvas.drawPath(trianglePath, paint);
    // Barra vertical
    canvas.drawLine(
      Offset(centerX + 6, centerY - 10),
      Offset(centerX + 6, centerY + 10),
      paint,
    );
    // Fios
    canvas.drawLine(Offset(0, centerY), Offset(centerX - 8, centerY), paint);
    canvas.drawLine(Offset(centerX + 6, centerY), Offset(size.width, centerY), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SwitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final midY = size.height / 2;
    final leftX = size.width * 0.2;
    final rightX = size.width * 0.8;
    // Pontos de contato
    canvas.drawCircle(Offset(leftX, midY), 2, Paint()..color = Colors.black);
    canvas.drawCircle(Offset(rightX, midY), 2, Paint()..color = Colors.black);
    // Alavanca (aberta)
    canvas.drawLine(
      Offset(leftX, midY),
      Offset(rightX - 5, midY - 12),
      paint,
    );
    // Fios
    canvas.drawLine(Offset(0, midY), Offset(leftX, midY), paint);
    canvas.drawLine(Offset(rightX, midY), Offset(size.width, midY), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final centerX = size.width / 2;
    final topY = size.height * 0.2;
    final bottomY = size.height * 0.8;
    // Linha vertical
    canvas.drawLine(Offset(centerX, topY), Offset(centerX, bottomY - 15), paint);
    // Três linhas horizontais (símbolo terra)
    canvas.drawLine(Offset(centerX - 12, bottomY - 15), Offset(centerX + 12, bottomY - 15), paint);
    canvas.drawLine(Offset(centerX - 8, bottomY - 10), Offset(centerX + 8, bottomY - 10), paint);
    canvas.drawLine(Offset(centerX - 4, bottomY - 5), Offset(centerX + 4, bottomY - 5), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ACSourcePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 4;
    // Círculo
    canvas.drawCircle(center, radius, paint);
    // Onda senoidal dentro
    final wavePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path();
    const points = 20;
    for (int i = 0; i <= points; i++) {
      final t = i / points;
      final x = center.dx - radius * 0.6 + t * radius * 1.2;
      final y = center.dy + math.sin(t * math.pi * 4) * radius * 0.3;
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, wavePaint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ================= MECÂNICA EXPANDIDA =================

class _PendulumPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    // Ponto de fixação
    final pivotX = size.width / 2;
    final pivotY = size.height * 0.1;
    canvas.drawCircle(Offset(pivotX, pivotY), 3, Paint()..color = Colors.black);
    // Fio
    final bobX = size.width * 0.7;
    final bobY = size.height * 0.8;
    canvas.drawLine(Offset(pivotX, pivotY), Offset(bobX, bobY), paint);
    // Massa (círculo)
    final bobPaint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(bobX, bobY), 8, bobPaint);
    canvas.drawCircle(Offset(bobX, bobY), 8, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BalancePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    // Fulcro (triângulo)
    final fulcrum = Path()
      ..moveTo(centerX - 10, centerY + 10)
      ..lineTo(centerX, centerY - 5)
      ..lineTo(centerX + 10, centerY + 10)
      ..close();
    canvas.drawPath(fulcrum, Paint()..color = Colors.grey.shade600);
    canvas.drawPath(fulcrum, paint);
    // Barra horizontal
    canvas.drawLine(
      Offset(size.width * 0.1, centerY - 5),
      Offset(size.width * 0.9, centerY - 5),
      paint..strokeWidth = 3,
    );
    // Pratos
    final platePaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.fill;
    final leftPlate = Rect.fromCenter(
      center: Offset(size.width * 0.2, centerY - 15),
      width: 20,
      height: 4,
    );
    final rightPlate = Rect.fromCenter(
      center: Offset(size.width * 0.8, centerY - 15),
      width: 20,
      height: 4,
    );
    canvas.drawRect(leftPlate, platePaint);
    canvas.drawRect(rightPlate, platePaint);
    canvas.drawRect(leftPlate, paint..strokeWidth = 1);
    canvas.drawRect(rightPlate, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    // Corpo do carrinho
    final body = Rect.fromLTWH(
      size.width * 0.15,
      size.height * 0.3,
      size.width * 0.7,
      size.height * 0.3,
    );
    canvas.drawRect(body, Paint()..color = Colors.grey.shade300);
    canvas.drawRect(body, paint);
    // Rodas
    final wheelPaint = Paint()
      ..color = Colors.grey.shade700
      ..style = PaintingStyle.fill;
    final leftWheel = Offset(size.width * 0.3, size.height * 0.75);
    final rightWheel = Offset(size.width * 0.7, size.height * 0.75);
    canvas.drawCircle(leftWheel, 8, wheelPaint);
    canvas.drawCircle(rightWheel, 8, wheelPaint);
    canvas.drawCircle(leftWheel, 8, paint);
    canvas.drawCircle(rightWheel, 8, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FrictionSurfacePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    // Linha de superfície
    final surfaceY = size.height * 0.7;
    canvas.drawLine(Offset(0, surfaceY), Offset(size.width, surfaceY), paint);
    // Padrão de rugosidade (dentinhos)
    final zigzagPaint = Paint()
      ..color = Colors.grey.shade600
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(0, surfaceY);
    const teeth = 12;
    for (int i = 0; i < teeth; i++) {
      final x = (i / teeth) * size.width;
      final nextX = ((i + 1) / teeth) * size.width;
      path.lineTo(x + (nextX - x) / 2, surfaceY + 4);
      path.lineTo(nextX, surfaceY);
    }
    canvas.drawPath(path, zigzagPaint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RopePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.brown.shade700
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    // Linha ondulada
    final path = Path();
    const points = 15;
    for (int i = 0; i <= points; i++) {
      final t = i / points;
      final x = t * size.width;
      final y = size.height / 2 + math.sin(t * math.pi * 3) * 3;
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ================= ÓPTICA =================

class _ConvergentLensPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final centerX = size.width / 2;
    final h = size.height;
    // Lente convergente (biconvexa)
    final path = Path()
      ..moveTo(centerX - 2, 0)
      ..quadraticBezierTo(centerX - 10, h / 2, centerX - 2, h)
      ..lineTo(centerX + 2, h)
      ..quadraticBezierTo(centerX + 10, h / 2, centerX + 2, 0)
      ..close();
    canvas.drawPath(path, paint);
    // Linha central
    final axisPaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, h / 2), Offset(size.width, h / 2), axisPaint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DivergentLensPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final centerX = size.width / 2;
    final h = size.height;
    // Lente divergente (bicôncava)
    final path = Path()
      ..moveTo(centerX - 2, 0)
      ..quadraticBezierTo(centerX + 6, h / 2, centerX - 2, h)
      ..lineTo(centerX + 2, h)
      ..quadraticBezierTo(centerX - 6, h / 2, centerX + 2, 0)
      ..close();
    canvas.drawPath(path, paint);
    // Linha central
    final axisPaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, h / 2), Offset(size.width, h / 2), axisPaint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MirrorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade700
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    // Espelho côncavo (arco)
    final path = Path()
      ..moveTo(size.width * 0.3, 0)
      ..quadraticBezierTo(
        size.width * 0.1,
        size.height / 2,
        size.width * 0.3,
        size.height,
      );
    canvas.drawPath(path, paint);
    // Lado reflexivo (mais grosso)
    final reflectivePaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final reflectivePath = Path()
      ..moveTo(size.width * 0.3, 0)
      ..quadraticBezierTo(
        size.width * 0.15,
        size.height / 2,
        size.width * 0.3,
        size.height,
      );
    canvas.drawPath(reflectivePath, reflectivePaint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LightRayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.yellow.shade700
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    // Raio de luz com ponta de seta
    final start = Offset(size.width * 0.1, size.height / 2);
    final end = Offset(size.width * 0.9, size.height / 2);
    canvas.drawLine(start, end, paint);
    // Seta
    final headSize = 8.0;
    final arrowPath = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(end.dx - headSize, end.dy - headSize / 2)
      ..lineTo(end.dx - headSize, end.dy + headSize / 2)
      ..close();
    canvas.drawPath(arrowPath, Paint()..color = Colors.yellow.shade700);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PrismPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    // Triângulo equilátero
    final path = Path()
      ..moveTo(size.width / 2, size.height * 0.1)
      ..lineTo(size.width * 0.1, size.height * 0.9)
      ..lineTo(size.width * 0.9, size.height * 0.9)
      ..close();
    final fillPaint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ================= QUÍMICA =================

class _BeakerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    // Béquer (forma trapezoidal)
    final path = Path()
      ..moveTo(size.width * 0.25, size.height * 0.1)
      ..lineTo(size.width * 0.15, size.height * 0.9)
      ..lineTo(size.width * 0.85, size.height * 0.9)
      ..lineTo(size.width * 0.75, size.height * 0.1)
      ..close();
    canvas.drawPath(path, paint);
    // Bico
    canvas.drawLine(
      Offset(size.width * 0.75, size.height * 0.3),
      Offset(size.width * 0.85, size.height * 0.25),
      paint,
    );
    // Líquido
    final liquidPath = Path()
      ..moveTo(size.width * 0.2, size.height * 0.5)
      ..lineTo(size.width * 0.17, size.height * 0.9)
      ..lineTo(size.width * 0.83, size.height * 0.9)
      ..lineTo(size.width * 0.8, size.height * 0.5)
      ..close();
    canvas.drawPath(
      liquidPath,
      Paint()..color = Colors.blue.withValues(alpha: 0.2),
    );
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ErlenmeyerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    // Erlenmeyer (cone + gargalo)
    final path = Path()
      ..moveTo(size.width * 0.4, size.height * 0.05)
      ..lineTo(size.width * 0.4, size.height * 0.3)
      ..lineTo(size.width * 0.1, size.height * 0.9)
      ..lineTo(size.width * 0.9, size.height * 0.9)
      ..lineTo(size.width * 0.6, size.height * 0.3)
      ..lineTo(size.width * 0.6, size.height * 0.05)
      ..close();
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TestTubePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    // Tubo de ensaio
    final path = Path()
      ..moveTo(size.width * 0.3, size.height * 0.05)
      ..lineTo(size.width * 0.3, size.height * 0.75)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.9,
        size.width * 0.5,
        size.height * 0.9,
      )
      ..quadraticBezierTo(
        size.width * 0.7,
        size.height * 0.9,
        size.width * 0.7,
        size.height * 0.75,
      )
      ..lineTo(size.width * 0.7, size.height * 0.05);
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BenzenePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 8;
    // Hexágono
    final hexPath = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 90) * math.pi / 180;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) hexPath.moveTo(x, y); else hexPath.lineTo(x, y);
    }
    hexPath.close();
    canvas.drawPath(hexPath, paint);
    // Círculo interno (ligações duplas)
    canvas.drawCircle(center, radius * 0.6, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
