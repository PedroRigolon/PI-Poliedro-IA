import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

/// Simple grid painter for the empty canvas area.
class CanvasGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;

    for (double x = 0; x < size.width; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
                Positioned.fill(
                  child: Container(
                    color: Colors.white,
                    child: CustomPaint(
                      painter: CanvasGridPainter(),
                      child: Container(),
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
              value: 'Estilo Padrão',
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
            SwitchListTile(
              value: true,
              onChanged: (_) {},
              title: const Text('Preferências de exportação'),
            ),
            SwitchListTile(
              value: false,
              onChanged: (_) {},
              title: const Text('Salvar histórico automaticamente'),
            ),
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
                  return GestureDetector(
                    onTap: () {
                      // TODO: inserir forma no canvas
                    },
                    child: Container(
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
        PopupMenuItem(child: const Text('Configurações'), onTap: () {}),
        PopupMenuItem(child: const Text('Coleção'), onTap: () {}),
        PopupMenuItem(child: const Text('Histórico'), onTap: () {}),
        PopupMenuItem(
          child: const Text('Sair'),
          onTap: () async {
            await context.read<AuthProvider>().logout();
            if (mounted) Navigator.pushReplacementNamed(context, '/login');
          },
        ),
      ],
    );
  }
}
