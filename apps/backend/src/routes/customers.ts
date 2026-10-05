import { Router, Response } from 'express';
import { body, validationResult } from 'express-validator';
import { prisma } from '../lib/prisma';
import { authenticateWithTenant, AuthRequest } from '../middleware/auth';

const router = Router();

// GET /api/customers
router.get('/', authenticateWithTenant, async (req: AuthRequest, res: Response): Promise<void> => {
  const { search, page = '1', limit = '50' } = req.query as Record<string, string>;
  const skip = (parseInt(page) - 1) * parseInt(limit);

  try {
    const where = {
      tenantId: req.tenantId!,
      ...(search && {
        OR: [
          { name: { contains: search, mode: 'insensitive' as const } },
          { phone: { contains: search } },
          { email: { contains: search, mode: 'insensitive' as const } },
        ],
      }),
    };

    const [customers, total] = await Promise.all([
      prisma.customer.findMany({
        where,
        orderBy: { name: 'asc' },
        skip,
        take: parseInt(limit),
      }),
      prisma.customer.count({ where }),
    ]);

    res.json({ customers, total, page: parseInt(page), limit: parseInt(limit) });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /api/customers/:id
router.get('/:id', authenticateWithTenant, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const customer = await prisma.customer.findFirst({
      where: { id: req.params.id, tenantId: req.tenantId },
      include: {
        invoices: {
          orderBy: { createdAt: 'desc' },
          take: 10,
          select: {
            id: true, invoiceNumber: true, totalAmount: true,
            paidAmount: true, status: true, createdAt: true,
          },
        },
      },
    });

    if (!customer) {
      res.status(404).json({ error: 'Customer not found' });
      return;
    }

    res.json({ customer });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /api/customers
router.post(
  '/',
  authenticateWithTenant,
  [body('name').trim().notEmpty().withMessage('Customer name is required')],
  async (req: AuthRequest, res: Response): Promise<void> => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      res.status(400).json({ errors: errors.array() });
      return;
    }

    const { name, phone, email, address } = req.body;

    try {
      const customer = await prisma.customer.create({
        data: { tenantId: req.tenantId!, name, phone, email, address },
      });

      res.status(201).json({ message: 'Customer created', customer });
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

// PUT /api/customers/:id
router.put('/:id', authenticateWithTenant, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const existing = await prisma.customer.findFirst({
      where: { id: req.params.id, tenantId: req.tenantId },
    });

    if (!existing) {
      res.status(404).json({ error: 'Customer not found' });
      return;
    }

    const { name, phone, email, address } = req.body;

    const customer = await prisma.customer.update({
      where: { id: req.params.id },
      data: {
        ...(name !== undefined && { name }),
        ...(phone !== undefined && { phone }),
        ...(email !== undefined && { email }),
        ...(address !== undefined && { address }),
      },
    });

    res.json({ message: 'Customer updated', customer });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /api/customers/:id
router.delete('/:id', authenticateWithTenant, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const existing = await prisma.customer.findFirst({
      where: { id: req.params.id, tenantId: req.tenantId },
    });

    if (!existing) {
      res.status(404).json({ error: 'Customer not found' });
      return;
    }

    await prisma.customer.delete({ where: { id: req.params.id } });
    res.json({ message: 'Customer deleted' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
