import 'package:flutter/material.dart';

/// Modelo para templates de diagramas pré-prontos
class DiagramTemplate {
  final String id;
  final String name;
  final String description;
  final String category; // Ex: "Física", "Química", "Geral"
  final String subcategory; // Ex: "Mecânica", "Óptica", "Termodinâmica"
  final List<TemplateShape> shapes;
  final IconData icon; // Ícone para exibição

  DiagramTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.subcategory,
    required this.shapes,
    required this.icon,
  });
}

/// Forma individual dentro de um template de diagrama
class TemplateShape {
  final String asset; // Caminho do asset
  final double relativeX; // Posição X relativa ao centro do diagrama (-1 a 1)
  final double relativeY; // Posição Y relativa ao centro do diagrama (-1 a 1)
  final double size; // Tamanho da forma
  final double rotation; // Rotação em radianos
  final String? textContent; // Para formas de texto
  final double? fontSize; // Para formas de texto
  final String? customName; // Nome customizado

  TemplateShape({
    required this.asset,
    required this.relativeX,
    required this.relativeY,
    required this.size,
    this.rotation = 0,
    this.textContent,
    this.fontSize,
    this.customName,
  });
}

/// Biblioteca de templates pré-definidos
class DiagramTemplateLibrary {
  static final List<DiagramTemplate> templates = [
    // FISICA - MECANICA
    DiagramTemplate(
      id: 'plano_inclinado_forcas',
      name: 'Plano Inclinado com Forcas',
      description: 'Bloco em plano inclinado com vetores de forca',
      category: 'Fisica',
      subcategory: 'Mecanica',
      icon: Icons.timeline,
      shapes: [
        // Plano inclinado
        TemplateShape(
          asset: 'generated:plane',
          relativeX: 0,
          relativeY: 0.1,
          size: 120,
        ),
        // Bloco
        TemplateShape(
          asset: 'generated:block',
          relativeX: -0.2,
          relativeY: -0.15,
          size: 40,
        ),
        // Força Peso (P) - seta para baixo
        TemplateShape(
          asset: 'generated:vector',
          relativeX: -0.2,
          relativeY: 0.05,
          size: 50,
          rotation: 1.5708, // 90° para baixo
          customName: 'P',
        ),
        // Força Normal (N) - seta perpendicular ao plano
        TemplateShape(
          asset: 'generated:vector',
          relativeX: -0.2,
          relativeY: -0.35,
          size: 50,
          rotation: -0.785, // ~45° para ficar perpendicular
          customName: 'N',
        ),
      ],
    ),

    DiagramTemplate(
      id: 'sistema_forcas_bloco',
      name: 'Sistema de Forcas em Bloco',
      description: 'Bloco com forcas peso, normal, atrito e tracao',
      category: 'Fisica',
      subcategory: 'Mecanica',
      icon: Icons.grain,
      shapes: [
        // Bloco central
        TemplateShape(
          asset: 'generated:block',
          relativeX: 0,
          relativeY: 0,
          size: 50,
        ),
        // Força Peso (P) - abaixo
        TemplateShape(
          asset: 'generated:vector',
          relativeX: 0,
          relativeY: 0.15,
          size: 45,
          rotation: 1.5708, // 90°
          customName: 'P',
        ),
        // Força Normal (N) - acima
        TemplateShape(
          asset: 'generated:vector',
          relativeX: 0,
          relativeY: -0.15,
          size: 45,
          rotation: -1.5708, // -90°
          customName: 'N',
        ),
        // Força de Atrito (Fa) - esquerda
        TemplateShape(
          asset: 'generated:vector',
          relativeX: -0.15,
          relativeY: 0,
          size: 45,
          rotation: 3.14159, // 180°
          customName: 'Fa',
        ),
        // Força de Tração (T) - direita
        TemplateShape(
          asset: 'generated:vector',
          relativeX: 0.15,
          relativeY: 0,
          size: 45,
          rotation: 0, // 0°
          customName: 'T',
        ),
      ],
    ),

    DiagramTemplate(
      id: 'colisao_blocos',
      name: 'Colisao entre Blocos',
      description: 'Dois blocos com vetores de velocidade',
      category: 'Fisica',
      subcategory: 'Mecanica',
      icon: Icons.compare_arrows,
      shapes: [
        // Bloco 1
        TemplateShape(
          asset: 'generated:block',
          relativeX: -0.25,
          relativeY: 0,
          size: 45,
        ),
        // Velocidade 1 (V1)
        TemplateShape(
          asset: 'generated:vector',
          relativeX: -0.4,
          relativeY: 0,
          size: 40,
          rotation: 0, // Direita
          customName: 'V1',
        ),
        // Bloco 2
        TemplateShape(
          asset: 'generated:block',
          relativeX: 0.25,
          relativeY: 0,
          size: 45,
        ),
        // Velocidade 2 (V2)
        TemplateShape(
          asset: 'generated:vector',
          relativeX: 0.4,
          relativeY: 0,
          size: 40,
          rotation: 3.14159, // Esquerda
          customName: 'V2',
        ),
      ],
    ),

    // FISICA - OPTICA
    DiagramTemplate(
      id: 'reflexao_luz',
      name: 'Reflexao da Luz',
      description: 'Diagrama de reflexao com raio incidente e refletido',
      category: 'Fisica',
      subcategory: 'Optica',
      icon: Icons.lightbulb_outline,
      shapes: [
        // Linha horizontal (superfície)
        TemplateShape(
          asset: 'generated:line_solid',
          relativeX: 0,
          relativeY: 0,
          size: 100,
          rotation: 0,
        ),
        // Raio incidente
        TemplateShape(
          asset: 'generated:vector',
          relativeX: -0.15,
          relativeY: -0.15,
          size: 60,
          rotation: 0.785, // 45°
        ),
        // Raio refletido
        TemplateShape(
          asset: 'generated:vector',
          relativeX: 0.15,
          relativeY: -0.15,
          size: 60,
          rotation: -0.785, // -45°
        ),
        // Linha normal (perpendicular)
        TemplateShape(
          asset: 'generated:line_dashed',
          relativeX: 0,
          relativeY: -0.1,
          size: 80,
          rotation: 1.5708, // 90° vertical
        ),
      ],
    ),

    // QUIMICA - ORGANICA
    DiagramTemplate(
      id: 'molecula_carbono',
      name: 'Cadeia Carbonica Simples',
      description: 'Cadeia linear de carbonos',
      category: 'Quimica',
      subcategory: 'Organica',
      icon: Icons.hub,
      shapes: [
        // Carbono 1
        TemplateShape(
          asset: 'generated:circle',
          relativeX: -0.3,
          relativeY: 0,
          size: 30,
          customName: 'C',
        ),
        // Ligação 1-2
        TemplateShape(
          asset: 'generated:line_solid',
          relativeX: -0.15,
          relativeY: 0,
          size: 40,
          rotation: 0,
        ),
        // Carbono 2
        TemplateShape(
          asset: 'generated:circle',
          relativeX: 0,
          relativeY: 0,
          size: 30,
          customName: 'C',
        ),
        // Ligação 2-3
        TemplateShape(
          asset: 'generated:line_solid',
          relativeX: 0.15,
          relativeY: 0,
          size: 40,
          rotation: 0,
        ),
        // Carbono 3
        TemplateShape(
          asset: 'generated:circle',
          relativeX: 0.3,
          relativeY: 0,
          size: 30,
          customName: 'C',
        ),
      ],
    ),

    // GERAL - DIAGRAMAS BASICOS
    DiagramTemplate(
      id: 'sistema_coordenadas',
      name: 'Sistema de Coordenadas XY',
      description: 'Eixos cartesianos com origem',
      category: 'Geral',
      subcategory: 'Diagramas Basicos',
      icon: Icons.grid_on,
      shapes: [
        // Eixo X
        TemplateShape(
          asset: 'generated:vector',
          relativeX: 0.15,
          relativeY: 0,
          size: 100,
          rotation: 0, // Direita
        ),
        // Eixo Y
        TemplateShape(
          asset: 'generated:vector',
          relativeX: 0,
          relativeY: -0.15,
          size: 100,
          rotation: -1.5708, // Cima
        ),
        // Label X
        TemplateShape(
          asset: 'generated:text',
          relativeX: 0.3,
          relativeY: 0.05,
          size: 20,
          textContent: 'x',
          fontSize: 16,
        ),
        // Label Y
        TemplateShape(
          asset: 'generated:text',
          relativeX: 0.05,
          relativeY: -0.3,
          size: 20,
          textContent: 'y',
          fontSize: 16,
        ),
      ],
    ),

    DiagramTemplate(
      id: 'triangulo_forcas',
      name: 'Triangulo de Forcas',
      description: 'Tres vetores formando triangulo',
      category: 'Geral',
      subcategory: 'Diagramas Basicos',
      icon: Icons.change_history,
      shapes: [
        // Vetor 1 (base)
        TemplateShape(
          asset: 'generated:vector',
          relativeX: 0,
          relativeY: 0.15,
          size: 80,
          rotation: 0,
        ),
        // Vetor 2 (lateral direita)
        TemplateShape(
          asset: 'generated:vector',
          relativeX: 0.15,
          relativeY: 0,
          size: 80,
          rotation: -1.047, // ~-60°
        ),
        // Vetor 3 (lateral esquerda)
        TemplateShape(
          asset: 'generated:vector',
          relativeX: -0.15,
          relativeY: 0,
          size: 80,
          rotation: 2.094, // ~120°
        ),
      ],
    ),
  ];

  /// Retorna todas as categorias únicas
  static List<String> getCategories() {
    return templates.map((t) => t.category).toSet().toList()..sort();
  }

  /// Retorna subcategorias de uma categoria específica
  static List<String> getSubcategories(String category) {
    return templates
        .where((t) => t.category == category)
        .map((t) => t.subcategory)
        .toSet()
        .toList()
      ..sort();
  }

  /// Retorna templates de uma subcategoria específica
  static List<DiagramTemplate> getTemplatesBySubcategory(
    String category,
    String subcategory,
  ) {
    return templates
        .where((t) => t.category == category && t.subcategory == subcategory)
        .toList();
  }

  /// Busca template por ID
  static DiagramTemplate? getTemplateById(String id) {
    try {
      return templates.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }
}
