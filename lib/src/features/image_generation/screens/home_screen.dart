import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

/// Simple grid painter for the empty canvas area.
class CanvasGridPainter extends CustomPainter {
  final double spacing;
  final Color lineColor;
  CanvasGridPainter({this.spacing = 20, Color? lineColor}) : lineColor = lineColor ?? Colors.grey[400]!;
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
  String? groupId;
  _PlacedShape({
    required this.asset,
    required this.position,
    required this.size,
    double? rotation,
    this.locked = false,
    this.groupId,
  }) : rotation = rotation ?? 0;

  _PlacedShape copyWith({
    String? asset,
    Offset? position,
    double? size,
    double? rotation,
    bool? locked,
    String? groupId,
  }) => _PlacedShape(
        asset: asset ?? this.asset,
        position: position ?? this.position,
        size: size ?? this.size,
        rotation: rotation ?? this.rotation,
        locked: locked ?? this.locked,
        groupId: groupId ?? this.groupId,
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
    'Mecânica': true,
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
            // When none selected we still provide a valid index for the widget
            selectedIndex: _selectedIndex < 0 ? 0 : _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                if (_selectedIndex == index) {
                  _selectedIndex = -1; // toggle close
                } else {
                  _selectedIndex = index;
                }
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: [
              NavigationRailDestination(
                icon: const Icon(Icons.smart_toy),
                selectedIcon: Icon(
                  Icons.smart_toy,
                  color: AppTheme.colors.primary,
                ),
                label: const Text('IA'),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.category),
                selectedIcon: Icon(
                  Icons.category,
                  color: AppTheme.colors.primary,
                ),
                label: const Text('Formas'),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.settings),
                selectedIcon: Icon(
                  Icons.settings,
                  color: AppTheme.colors.primary,
                ),
                label: const Text('Configurações'),
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
                      LogicalKeySet(LogicalKeyboardKey.delete): const _DeleteShapeIntent(),
                      LogicalKeySet(LogicalKeyboardKey.backspace): const _DeleteShapeIntent(),
                      LogicalKeySet(LogicalKeyboardKey.escape): const _DeselectIntent(),
                      SingleActivator(LogicalKeyboardKey.keyD, control: true): const _DuplicateIntent(),
                      SingleActivator(LogicalKeyboardKey.keyC, control: true): const _CopyIntent(),
                      SingleActivator(LogicalKeyboardKey.keyV, control: true): const _PasteIntent(),
                      SingleActivator(LogicalKeyboardKey.keyG, control: true): const _GroupIntent(),
                      SingleActivator(LogicalKeyboardKey.keyG, control: true, shift: true): const _UngroupIntent(),
                      // Nudges
                      SingleActivator(LogicalKeyboardKey.arrowUp): const _NudgeIntent(Offset(0, -1)),
                      SingleActivator(LogicalKeyboardKey.arrowDown): const _NudgeIntent(Offset(0, 1)),
                      SingleActivator(LogicalKeyboardKey.arrowLeft): const _NudgeIntent(Offset(-1, 0)),
                      SingleActivator(LogicalKeyboardKey.arrowRight): const _NudgeIntent(Offset(1, 0)),
                      SingleActivator(LogicalKeyboardKey.arrowUp, shift: true): const _NudgeIntent(Offset(0, -10)),
                      SingleActivator(LogicalKeyboardKey.arrowDown, shift: true): const _NudgeIntent(Offset(0, 10)),
                      SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true): const _NudgeIntent(Offset(-10, 0)),
                      SingleActivator(LogicalKeyboardKey.arrowRight, shift: true): const _NudgeIntent(Offset(10, 0)),
                    },
                    child: Actions(
                      actions: <Type, Action<Intent>>{
                        _DeleteShapeIntent: CallbackAction<_DeleteShapeIntent>(
                          onInvoke: (intent) {
                            setState(() {
                              if (_selected.isNotEmpty) {
                                final toRemove = _selected.toList()..sort((a, b) => b.compareTo(a));
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
                            setState(() { _selectedShapeIndex = -1; _selected.clear(); });
                            return null;
                          },
                        ),
                        _DuplicateIntent: CallbackAction<_DuplicateIntent>(
                          onInvoke: (intent) { _duplicateSelected(); return null; },
                        ),
                        _CopyIntent: CallbackAction<_CopyIntent>(
                          onInvoke: (intent) { _copySelectedToClipboard(); return null; },
                        ),
                        _PasteIntent: CallbackAction<_PasteIntent>(
                          onInvoke: (intent) { _pasteClipboard(); return null; },
                        ),
                        _GroupIntent: CallbackAction<_GroupIntent>(
                          onInvoke: (intent) { _groupSelected(); return null; },
                        ),
                        _UngroupIntent: CallbackAction<_UngroupIntent>(
                          onInvoke: (intent) { _ungroupSelected(); return null; },
                        ),
                        _NudgeIntent: CallbackAction<_NudgeIntent>(
                          onInvoke: (intent) { _nudgeSelected(intent.delta); return null; },
                        ),
                      },
                      child: Focus(
                        focusNode: _canvasFocusNode,
                        autofocus: true,
                        child: DragTarget<String>(
                      onAcceptWithDetails: (details) {
                        final renderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                        if (renderBox != null) {
                          final local = renderBox.globalToLocal(details.offset);
                          _addShape(details.data, local - Offset(_shapeSize / 2, _shapeSize / 2));
                        } else {
                          _addShape(details.data, const Offset(120, 120));
                        }
                      },
                      builder: (context, candidates, rejects) {
                            return RepaintBoundary(
                          key: _canvasKey,
                              child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                                onTapDown: (_) {
                              setState(() => _selectedShapeIndex = -1);
                                  _selected.clear();
                              _canvasFocusNode.requestFocus();
                            },
                                onPanStart: (details) {
                                  // Inicia retângulo de seleção se começou em área vazia
                                  final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                                  if (box != null) {
                                    setState(() {
                                      _isMarquee = true;
                                      _marqueeStart = box.globalToLocal(details.globalPosition);
                                      _marqueeRect = Rect.fromLTWH(_marqueeStart!.dx, _marqueeStart!.dy, 0, 0);
                                    });
                                  }
                                },
                                onPanUpdate: (details) {
                                  if (_isMarquee) {
                                    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                                    if (box != null && _marqueeStart != null) {
                                      final current = box.globalToLocal(details.globalPosition);
                                      setState(() {
                                        _marqueeRect = Rect.fromPoints(_marqueeStart!, current);
                                      });
                                    }
                                  }
                                },
                                onPanEnd: (_) {
                                  if (_isMarquee) {
                                    setState(() {
                                      _applyMarqueeSelection();
                                      _isMarquee = false;
                                      _marqueeStart = null;
                                      _marqueeRect = null;
                                    });
                                  }
                                },
                            child: Container(
                              color: Colors.white,
                              child: CustomPaint(
                                painter: _showGrid ? CanvasGridPainter() : null,
                                child: Container(),
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

                // Shapes colocadas no canvas (arrastáveis, selecionáveis, redimensionáveis, rotacionáveis)
                ..._shapes.asMap().entries.map((entry) {
                  final index = entry.key;
                  final s = entry.value;
                  final isSelected = _selected.contains(index) || index == _selectedShapeIndex;
                  final handleSize = 16.0;
                  final outerPad = handleSize + 12.0; // área extra para desenhar e captar os handles fora do retângulo
                  return Positioned(
                    left: s.position.dx - outerPad,
                    top: s.position.dy - outerPad,
                    width: s.size + outerPad * 2,
                    height: s.size + outerPad * 2,
                    child: IgnorePointer(
                      ignoring: _selectedIndex >= 0,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () {
                          if (_interactingWithHandle) return;
                          final keys = HardwareKeyboard.instance.logicalKeysPressed;
                          final ctrl = keys.contains(LogicalKeyboardKey.controlLeft) || keys.contains(LogicalKeyboardKey.controlRight) || keys.contains(LogicalKeyboardKey.metaLeft) || keys.contains(LogicalKeyboardKey.metaRight);
                          setState(() {
                            if (ctrl) {
                              if (_selected.contains(index)) {
                                _selected.remove(index);
                              } else {
                                _selected.add(index);
                              }
                              _selectedShapeIndex = _selected.isNotEmpty ? _selected.last : -1;
                            } else {
                              _selected.clear();
                              // Se o shape fizer parte de um grupo, seleciona todo o grupo
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
                          // Trazer para frente
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
                            _selectedShapeIndex = newIndex; // agora último
                          });
                        },
                        onPanUpdate: (details) {
                          if (_interactingWithHandle) return;
                          if (_selected.contains(index)) {
                            setState(() {
                              // mover todas as selecionadas pelo mesmo delta
                              for (final sel in _selected) {
                                final shp = _shapes[sel];
                                if (shp.locked) continue;
                                shp.position += details.delta;
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
                            // Conteúdo rotacionado (no retângulo original, deslocado pelo outerPad)
                            Positioned(
                              left: outerPad,
                              top: outerPad,
                              width: s.size,
                              height: s.size,
                              child: Transform.rotate(
                                angle: s.rotation,
                                child: Container(
                                  decoration: isSelected
                                      ? BoxDecoration(
                                          border: Border.all(
                                            color: AppTheme.colors.primary,
                                            width: 1.2,
                                          ),
                                          borderRadius: BorderRadius.circular(4),
                                        )
                                      : null,
                                  padding: EdgeInsets.all(isSelected ? 2 : 0),
                                  child: Image.asset(
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
                              // Botão remover (canto superior direito, FORA do retângulo)
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
                                      // remove todos selecionados
                                      final toRemove = _selected.isNotEmpty ? _selected.toList() : [index];
                                      toRemove.sort((a,b)=>b.compareTo(a));
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
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent,
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                              // Handle de rotação (canto superior esquerdo, FORA do retângulo)
                              Positioned(
                                top: outerPad - (handleSize + 12),
                                left: outerPad - (handleSize / 2),
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onPanDown: (_) => _interactingWithHandle = true,
                                  onPanCancel: () => _interactingWithHandle = false,
                                  onPanEnd: (_) => _interactingWithHandle = false,
                                  onPanUpdate: (details) {
                                    setState(() {
                                      final center = s.position + Offset(s.size / 2, s.size / 2);
                                      final globalPos = details.globalPosition;
                                      final renderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                                      if (renderBox != null) {
                                        final local = renderBox.globalToLocal(globalPos);
                                        final vector = local - center;
                                        s.rotation = math.atan2(vector.dy, vector.dx);
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
                                    child: const Icon(Icons.rotate_right, size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                              // Handle de resize (canto inferior direito, FORA do retângulo)
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
                                      final keys = HardwareKeyboard.instance.logicalKeysPressed;
                                      final keepProportion = keys.contains(LogicalKeyboardKey.shiftLeft) || keys.contains(LogicalKeyboardKey.shiftRight);
                                      if (_selected.length <= 1) {
                                        // Para SHIFT, consideramos o maior deslocamento para manter efeito "uniforme"
                                        final delta = keepProportion
                                            ? (details.delta.dx.abs() >= details.delta.dy.abs() ? details.delta.dx : details.delta.dy)
                                            : details.delta.dx;
                                        double newSize = s.size + delta;
                                        newSize = newSize.clamp(24.0, 320.0);
                                        final renderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                                        if (renderBox != null) {
                                          final sizeCanvas = renderBox.size;
                                          if (s.position.dx + newSize > sizeCanvas.width) {
                                            newSize = sizeCanvas.width - s.position.dx;
                                          }
                                          if (s.position.dy + newSize > sizeCanvas.height) {
                                            newSize = sizeCanvas.height - s.position.dy;
                                          }
                                        }
                                        // Snap opcional quando Shift: múltiplos de 8 px
                                        if (keepProportion) {
                                          newSize = (newSize / 8).round() * 8;
                                        }
                                        s.size = newSize;
                                      } else {
                                        // Resize em grupo: escala uniforme em torno do centro do bounding box
                                        final bounds = _selectionBounds();
                                        if (bounds == null) return;
                                        final anchor = bounds.topLeft;
                                        final cur = bounds.bottomRight;
                                        final newBR = cur + details.delta;
                                        final newW = (newBR.dx - anchor.dx).clamp(24.0, double.infinity);
                                        final newH = (newBR.dy - anchor.dy).clamp(24.0, double.infinity);
                                        final sx = newW / bounds.width;
                                        final sy = newH / bounds.height;
                                        final scale = keepProportion ? math.min(sx, sy) : math.min(sx, sy); // shapes quadrados => escala uniforme
                                        final center = bounds.center;
                                        for (final idx in _selected) {
                                          final shp = _shapes[idx];
                                          if (shp.locked) continue;
                                          final rel = shp.position + Offset(shp.size/2, shp.size/2) - center;
                                          final relScaled = rel * scale;
                                          shp.size = (shp.size * scale).clamp(16.0, 640.0);
                                          shp.position = center + relScaled - Offset(shp.size/2, shp.size/2);
                                        }
                                      }
                                    });
                                  },
                                  child: Container(
                                    width: handleSize + 10,
                                    height: handleSize + 10,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(color: AppTheme.colors.primary, width: 1.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.open_in_full, size: 14, color: Colors.black87),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                // Marquee overlay
                if (_isMarquee && _marqueeRect != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _MarqueePainter(_marqueeRect!),
                      ),
                    ),
                  ),

                // Toolbar flutuante básica para seleção múltipla
                if (_selected.isNotEmpty)
                  ..._buildSelectionToolbar(),

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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelContent() {
    switch (_selectedIndex) {
      case 0: // IA
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'IA',
                  style: AppTheme.typography.title.copyWith(fontSize: 20),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _selectedIndex = -1),
                ),
              ],
            ),
            SizedBox(height: AppTheme.spacing.medium),
            DropdownButtonFormField<String>(
              initialValue: 'Estilo Padrão',
              items: [
                'Estilo Padrão',
                'Esboço',
                'Realista',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (_) {},
              decoration: const InputDecoration(labelText: 'Estilo'),
            ),
            SizedBox(height: AppTheme.spacing.medium),
            ElevatedButton(onPressed: () {}, child: const Text('Aplicar')),
          ],
        );

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
                    _buildSubSectionCollapsible(
                      'Textos',
                      'assets/forms/geral/textos',
                      6,
                    ),
                    _buildSubSectionCollapsible(
                      'Setas',
                      'assets/forms/geral/setas',
                      6,
                    ),
                  ],
                  const Divider(height: 24),
                  // Grupo Física
                  _buildMateriaHeaderCollapsible('Física'),
                  if (_materiaExpanded['Física'] ?? false) ...[
                    _buildSubSectionCollapsible(
                      'Mecânica',
                      'assets/forms/fisica/mecanica',
                      6,
                    ),
                    _buildSubSectionCollapsible(
                      'Óptica',
                      'assets/forms/fisica/optica',
                      5,
                    ),
                    _buildSubSectionCollapsible(
                      'Térmica',
                      'assets/forms/fisica/termica',
                      4,
                    ),
                  ],
                  const Divider(height: 24),
                  // Grupo Química
                  _buildMateriaHeaderCollapsible('Química'),
                  if (_materiaExpanded['Química'] ?? false) ...[
                    _buildSubSectionCollapsible(
                      'Orgânica',
                      'assets/forms/quimica/organica',
                      5,
                    ),
                    _buildSubSectionCollapsible(
                      'Inorgânica',
                      'assets/forms/quimica/inorganica',
                      5,
                    ),
                    _buildSubSectionCollapsible(
                      'Termoquímica',
                      'assets/forms/quimica/termoquimica',
                      4,
                    ),
                  ],
                ],
              ),
            ),
          ],
        );

      case 2: // Configurações
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
            Text('Canvas', style: AppTheme.typography.title.copyWith(fontSize: 16)),
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
                          errorBuilder: (c, e, s) => Icon(Icons.crop_square, size: _shapeSize * 0.6, color: Colors.grey[400]),
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
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[300]!),
        color: Colors.grey[50],
      ),
      padding: const EdgeInsets.all(6.0),
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) => Icon(
          Icons.crop_square,
          size: 20,
          color: Colors.grey[400],
        ),
      ),
    );
  }

  void _insertAtCenter(String asset) {
    final renderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final size = renderBox.size;
      final center = Offset(size.width / 2 - _shapeSize / 2, size.height / 2 - _shapeSize / 2);
      _addShape(asset, center);
    } else {
      _addShape(asset, const Offset(120, 120));
    }
  }

  void _addShape(String asset, Offset position) {
    setState(() {
      _shapes.add(_PlacedShape(asset: asset, position: position, size: _shapeSize));
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
      maxX = maxX == null ? s.position.dx + s.size : math.max(maxX, s.position.dx + s.size);
      maxY = maxY == null ? s.position.dy + s.size : math.max(maxY, s.position.dy + s.size);
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
      if (r.overlaps(rect) || r.contains(rect.topLeft) || r.contains(rect.bottomRight)) {
        _selected.add(i);
      }
    }
    _selectedShapeIndex = _selected.isNotEmpty ? _selected.last : -1;
  }

  List<Widget> _buildSelectionToolbar() {
    final bounds = _selectionBounds();
    if (bounds == null) return [];
  final toolbarY = (bounds.top - 84).clamp(0.0, double.infinity);
    final toolbarX = (bounds.center.dx - 120).clamp(0.0, double.infinity);
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
                  tooltip: 'Duplicar (Ctrl+D)',
                  icon: const Icon(Icons.copy_all, size: 18),
                  onPressed: _duplicateSelected,
                ),
                IconButton(
                  tooltip: 'Bloquear/Desbloquear',
                  icon: const Icon(Icons.lock_open, size: 18),
                  onPressed: _toggleLockSelected,
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
              ],
            ),
          ),
        ),
      ),
    ];
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
      final lock = !_shapes[_selected.first].locked;
      for (final i in _selected) {
        _shapes[i].locked = lock;
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
      _selected.addAll(Iterable<int>.generate(items.length, (k) => _shapes.length - items.length + k));
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
        _shapes[i].copyWith() // cópia superficial é suficiente (campos são primitivos)
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
        ) ?? false;
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
  bool shouldRepaint(covariant _MarqueePainter oldDelegate) => oldDelegate.rect != rect;
}

