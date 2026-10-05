import { Router, Response } from 'express';
import { body, query, validationResult } from 'express-validator';
import { prisma } from '../lib/prisma';
import { authenticateWithTenant, AuthRequest } from '../middleware/auth';

const router = Router();

// GET /api/products
router.get('/', authenticateWithTenant, async (req: AuthRequest, res: Response): Promise<void> => {
  const { search, categoryId, page = '1', limit = '50', lowStock } = req.query as Record<string, string>;

  const skip = (parseInt(page) - 1) * parseInt(limit);

  try {
    const where: Record<string, unknown> = {
      tenantId: req.tenantId,
      isActive: true,
      ...(search && { name: { contains: search, mode: 'insensitive' } }),
      ...(categoryId && { categoryId }),
      ...(lowStock === 'true' && { stock: { lte: prisma.product.fields.minStock } }),
    };

    const [products, total] = await Promise.all([
      prisma.product.findMany({
        where,
        include: { category: { select: { id: true, name: true } } },
        orderBy: { name: 'asc' },
        skip,
        take: parseInt(limit),
      }),
      prisma.product.count({ where }),
    ]);

    res.json({ products, total, page: parseInt(page), limit: parseInt(limit) });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /api/products/:id
router.get('/:id', authenticateWithTenant, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const product = await prisma.product.findFirst({
      where: { id: req.params.id, tenantId: req.tenantId },
      include: { category: true },
    });

    if (!product) {
      res.status(404).json({ error: 'Product not found' });
      return;
    }

    res.json({ product });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /api/products
router.post(
  '/',
  authenticateWithTenant,
  [
    body('name').trim().notEmpty().withMessage('Product name is required'),
    body('price').isFloat({ min: 0 }).withMessage('Price must be a positive number'),
    body('stock').optional().isInt({ min: 0 }),
    body('taxRate').optional().isFloat({ min: 0, max: 100 }),
  ],
  async (req: AuthRequest, res: Response): Promise<void> => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      res.status(400).json({ errors: errors.array() });
      return;
    }

    const {
      name, description, sku, barcode, price, costPrice,
      taxRate, stock, minStock, unit, imageUrl, categoryId,
    } = req.body;

    try {
      const product = await prisma.product.create({
        data: {
          tenantId: req.tenantId!,
          name,
          description,
          sku,
          barcode,
          price,
          costPrice,
          taxRate: taxRate || 0,
          stock: stock || 0,
          minStock: minStock || 0,
          unit: unit || 'pcs',
          imageUrl,
          categoryId,
        },
        include: { category: { select: { id: true, name: true } } },
      });

      res.status(201).json({ message: 'Product created', product });
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

// PUT /api/products/:id
router.put(
  '/:id',
  authenticateWithTenant,
  async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const existing = await prisma.product.findFirst({
        where: { id: req.params.id, tenantId: req.tenantId },
      });

      if (!existing) {
        res.status(404).json({ error: 'Product not found' });
        return;
      }

      const {
        name, description, sku, barcode, price, costPrice,
        taxRate, stock, minStock, unit, imageUrl, categoryId, isActive,
      } = req.body;

      const product = await prisma.product.update({
        where: { id: req.params.id },
        data: {
          ...(name !== undefined && { name }),
          ...(description !== undefined && { description }),
          ...(sku !== undefined && { sku }),
          ...(barcode !== undefined && { barcode }),
          ...(price !== undefined && { price }),
          ...(costPrice !== undefined && { costPrice }),
          ...(taxRate !== undefined && { taxRate }),
          ...(stock !== undefined && { stock }),
          ...(minStock !== undefined && { minStock }),
          ...(unit !== undefined && { unit }),
          ...(imageUrl !== undefined && { imageUrl }),
          ...(categoryId !== undefined && { categoryId }),
          ...(isActive !== undefined && { isActive }),
        },
        include: { category: { select: { id: true, name: true } } },
      });

      res.json({ message: 'Product updated', product });
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

// DELETE /api/products/:id (soft delete)
router.delete('/:id', authenticateWithTenant, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const existing = await prisma.product.findFirst({
      where: { id: req.params.id, tenantId: req.tenantId },
    });

    if (!existing) {
      res.status(404).json({ error: 'Product not found' });
      return;
    }

    await prisma.product.update({
      where: { id: req.params.id },
      data: { isActive: false },
    });

    res.json({ message: 'Product deleted' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── Categories ──────────────────────────────────────────────────────────────

// GET /api/products/categories/all
router.get('/categories/all', authenticateWithTenant, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const categories = await prisma.category.findMany({
      where: { tenantId: req.tenantId },
      orderBy: { name: 'asc' },
    });
    res.json({ categories });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /api/products/categories
router.post(
  '/categories/create',
  authenticateWithTenant,
  [body('name').trim().notEmpty()],
  async (req: AuthRequest, res: Response): Promise<void> => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      res.status(400).json({ errors: errors.array() });
      return;
    }

    try {
      const category = await prisma.category.create({
        data: { tenantId: req.tenantId!, name: req.body.name },
      });
      res.status(201).json({ category });
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

export default router;
