import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Category } from '../categories/category.entity';
import {
  CategorizationResult,
  EMPTY_RESULT,
} from './interfaces/categorization-result.interface';

/** Each rule entry maps a category (by lowercase display name) to its keywords and merchant aliases */
interface RuleEntry {
  /** Partial keyword match → confidence 'medium' (unless whole-word) */
  keywords: string[];
  /** Exact or near-exact merchant/brand names → confidence 'high' */
  merchants: string[];
}

/**
 * Keyword + merchant dictionary keyed by category name (lowercase, no accents).
 * This maps to the existing Category.name in the database (case-insensitive).
 */
const RULES: Record<string, RuleEntry> = {
  // ── Food subcategories (map to leaf categories under "Comida") ───────────
  restaurante: {
    keywords: [
      'pizza', 'burger', 'hamburgesa', 'baleada', 'pollo', 'sushi', 'tacos',
      'taco', 'restaurante', 'buffet', 'almuerzo', 'cena', 'desayuno',
      'pupusa', 'fritanga', 'antojitos', 'mariscos', 'carne', 'asado',
      'bbq', 'fonda', 'loncheria', 'comida rapida',
    ],
    merchants: [
      'kfc', 'mcdonalds', 'mc donalds', 'burger king', 'subway', 'wendys',
      'pizza hut', 'dominos', 'little caesars', 'papa johns', 'popeyes',
      'dunkin donuts', 'starbucks', 'pollo campero', 'pollo rey',
    ],
  },
  delivery: {
    keywords: ['delivery', 'domicilio', 'pedido a domicilio'],
    merchants: ['uber eats', 'ubereats', 'pedidos ya', 'rappi', 'glovo'],
  },
  supermercado: {
    keywords: [
      'supermercado', 'despensa', 'abarrotes', 'pulperia', 'tienda',
      'mercado', 'bodega', 'miscelanea', 'mini super', 'minisuper',
    ],
    merchants: [
      'walmart', 'la colonia', 'pricesmart', 'maxi', 'supermaxi',
      'hiper paiz', 'pali', 'mas x menos', 'supermercados buen precio',
      'fresh market', 'corazon de jesus',
    ],
  },
  // generic food fallback (maps to parent "Comida" → first child returned)
  comida: {
    keywords: ['comida', 'cafeteria', 'panaderia'],
    merchants: [],
  },
  // ── Transport subcategories ──────────────────────────────────────────────
  taxi: {
    keywords: ['taxi', 'cab'],
    merchants: ['uber', 'didi'],
  },
  combustible: {
    keywords: ['gasolina', 'combustible', 'lubricante', 'aceite', 'neumatico', 'llanta'],
    merchants: ['shell', 'texaco', 'uno', 'puma', 'gaso express'],
  },
  // generic transport fallback
  transporte: {
    keywords: ['bus', 'parking', 'estacionamiento', 'transporte', 'pasaje', 'peaje', 'autopista', 'mecanico', 'taller'],
    merchants: ['inab', 'transacsa'],
  },
  // ── Entertainment subcategories ──────────────────────────────────────────
  streaming: {
    keywords: ['streaming', 'suscripcion digital'],
    merchants: [
      'netflix', 'spotify', 'amazon prime', 'disney plus', 'hbo max',
      'youtube premium', 'apple tv', 'crunchyroll', 'paramount',
    ],
  },
  // generic entertainment fallback
  entretenimiento: {
    keywords: ['cine', 'bar', 'discoteca', 'evento', 'concierto', 'entrada', 'boleto', 'tickets', 'teatro', 'museo', 'parque', 'juego', 'videojuego'],
    merchants: ['cinemark', 'city mall', 'altia smart city'],
  },
  // ── Utilities / Housing ──────────────────────────────────────────────────
  servicios: {
    keywords: ['luz', 'agua', 'electricidad', 'telefono', 'factura', 'recibo', 'gas', 'propano'],
    merchants: ['tigo', 'claro', 'hondutel', 'energisa', 'sanaa', 'enee'],
  },
  internet: {
    keywords: ['internet', 'wifi', 'cable', 'fibra optica'],
    merchants: ['cablevision', 'cabletica', 'columbus'],
  },
  salud: {
    keywords: [
      'farmacia', 'medicina', 'medicamento', 'doctor', 'clinica', 'hospital',
      'laboratorio', 'dentista', 'consulta', 'examen', 'analisis',
      'terapia', 'optometria', 'lentes', 'cirugia', 'inyeccion',
    ],
    merchants: [
      'kielsa', 'farmacia kielsa', 'farmacias cruz verde', 'cemesa',
      'farmahorro', 'san jose', 'instituto hondureno',
    ],
  },
  educacion: {
    keywords: [
      'colegio', 'universidad', 'libro', 'matricula', 'mensualidad',
      'pensionado', 'curso', 'taller', 'escuela', 'capacitacion',
      'beca', 'estudios', 'educacion', 'cuaderno', 'utiles',
    ],
    merchants: [
      'unah', 'unitec', 'upnfm', 'zamorano', 'jose cecilio del valle',
    ],
  },
  ropa: {
    keywords: [
      'ropa', 'zapatos', 'calzado', 'vestido', 'camisa', 'pantalon',
      'moda', 'boutique', 'zapateria',
    ],
    merchants: [
      'zara', 'h&m', 'mango', 'payless',
    ],
  },
  hogar: {
    keywords: [
      'alquiler', 'renta', 'hipoteca', 'mantenimiento', 'reparacion',
      'mueble', 'electrodomestico', 'ferreteria', 'pintura', 'plomero',
      'electricista', 'fumigacion', 'limpieza',
    ],
    merchants: [
      'ace hardware', 'do it', 'novaventa',
    ],
  },
  tecnologia: {
    keywords: [
      'celular', 'smartphone', 'laptop', 'computadora', 'tablet',
      'accesorio', 'forro', 'cargador', 'auricular', 'audifonos',
    ],
    merchants: [
      'apple', 'samsung', 'best buy', 'istore',
    ],
  },
};

@Injectable()
export class CategorizationRulesService {
  constructor(
    @InjectRepository(Category)
    private categoryRepo: Repository<Category>,
  ) {}

  // ── Text normalization ───────────────────────────────────────────────────

  normalize(text: string): string {
    return text
      .normalize('NFD')
      .replace(/\p{Mn}/gu, '')   // strip combining diacritical marks (tildes)
      .toLowerCase()
      .replace(/[^a-z0-9\s]/g, ' ')  // replace non-alphanumeric with space
      .replace(/\s+/g, ' ')       // collapse multiple spaces
      .trim();
  }

  // ── Main matching logic ──────────────────────────────────────────────────

  async matchGlobal(normalizedText: string): Promise<CategorizationResult> {
    const categories = await this.categoryRepo.find({
      where: { isSystem: true },
      select: ['id', 'name', 'parentId'],
    });

    // 1. Try merchant match first (high confidence)
    const merchantResult = this.matchMerchants(normalizedText, categories);
    if (merchantResult) return merchantResult;

    // 2. Try keyword whole-word match (high confidence)
    const wholeWordResult = this.matchKeywords(normalizedText, categories, true);
    if (wholeWordResult) return wholeWordResult;

    // 3. Try keyword partial match (medium confidence)
    const partialResult = this.matchKeywords(normalizedText, categories, false);
    if (partialResult) return partialResult;

    return { ...EMPTY_RESULT };
  }

  private matchMerchants(
    normalizedText: string,
    categories: Category[],
  ): CategorizationResult | null {
    for (const [ruleName, rule] of Object.entries(RULES)) {
      for (const merchant of rule.merchants) {
        const normalizedMerchant = this.normalize(merchant);
        if (normalizedText.includes(normalizedMerchant)) {
          const category = this.findCategoryByRuleName(ruleName, categories);
          if (!category) continue;
          return {
            suggestedCategoryId: category.id,
            suggestedCategoryName: category.name,
            confidence: 'high',
            source: 'merchant_rule',
            matchedKeyword: merchant,
            matchedRule: ruleName,
          };
        }
      }
    }
    return null;
  }

  private matchKeywords(
    normalizedText: string,
    categories: Category[],
    wholeWordOnly: boolean,
  ): CategorizationResult | null {
    for (const [ruleName, rule] of Object.entries(RULES)) {
      for (const keyword of rule.keywords) {
        const normalizedKeyword = this.normalize(keyword);
        const matches = wholeWordOnly
          ? this.matchesWholeWord(normalizedText, normalizedKeyword)
          : normalizedText.includes(normalizedKeyword);

        if (matches) {
          const category = this.findCategoryByRuleName(ruleName, categories);
          if (!category) continue;
          return {
            suggestedCategoryId: category.id,
            suggestedCategoryName: category.name,
            confidence: wholeWordOnly ? 'high' : 'medium',
            source: 'keyword_rule',
            matchedKeyword: keyword,
            matchedRule: ruleName,
          };
        }
      }
    }
    return null;
  }

  private matchesWholeWord(text: string, word: string): boolean {
    // Build a regex that checks word boundaries
    const escaped = word.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const re = new RegExp(`(?<![a-z0-9])${escaped}(?![a-z0-9])`);
    return re.test(text);
  }

  /**
   * Find the Category entity whose name (normalized) best corresponds to the
   * rule name key.
   *
   * Prefers LEAF categories (parentId != null, i.e. subcategories) over root
   * parent categories, because the Flutter dropdown only shows leaf categories.
   * Falls back to the parent if no leaf match is found.
   */
  private findCategoryByRuleName(
    ruleName: string,
    categories: Category[],
  ): Category | undefined {
    const normalizedRule = this.normalize(ruleName);

    const leaves  = categories.filter((c) => c.parentId != null);
    const parents = categories.filter((c) => c.parentId == null);

    const findExact   = (pool: Category[]) =>
      pool.find((c) => this.normalize(c.name) === normalizedRule);
    const findPartial = (pool: Category[]) =>
      pool.find((c) => this.normalize(c.name).includes(normalizedRule));

    // 1. Exact match in leaf categories first (preferred — selectable in UI)
    const leafExact = findExact(leaves);
    if (leafExact) return leafExact;

    // 2. Partial match in leaf categories
    const leafPartial = findPartial(leaves);
    if (leafPartial) return leafPartial;

    // 3. Found a parent category — return its first leaf child so the Flutter
    //    dropdown (which only shows leaf categories) can auto-select it.
    const parent = findExact(parents) ?? findPartial(parents);
    if (!parent) return undefined;

    const firstChild = leaves.find((c) => c.parentId === parent.id);
    return firstChild ?? parent; // fallback to parent when it has no children
  }
}
