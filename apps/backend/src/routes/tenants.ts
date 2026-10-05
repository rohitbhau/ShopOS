import { Router, Response } from 'express';
import { body, validationResult } from 'express-validator';
import { prisma } from '../lib/prisma';
import { authenticate, authenticateWithTenant, AuthRequest } from '../middleware/auth';

const router = Router();

// POST /api/tenants — Create a shop (first time)
router.post(
  '/',
  authenticate,
  [
    body('name').trim().notEmpty().withMessage('Shop name is required'),
    body('phone').optional().trim(),
    body('shopType').optional().trim(),
    body('address').optional().trim(),
    body('gstin').optional().trim(),
  ],
  async (req: AuthRequest, res: Response): Promise<void> => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      res.status(400).json({ errors: errors.array() });
      return;
    }

    const { name, phone, shopType, address, gstin, email } = req.body;

    try {
      // Check user doesn't already own a shop
      const existing = await prisma.membership.findFirst({
        where: { userId: req.userId!, isActive: true },
      });
      if (existing) {
        res.status(409).json({ error: 'You already have an active shop' });
        return;
      }

      // Create tenant and membership in a transaction
      const result = await prisma.$transaction(async (tx) => {
        const tenant = await tx.tenant.create({
          data: { name, phone, shopType: shopType || 'retail', address, gstin, email },
        });

        const membership = await tx.membership.create({
          data: { userId: req.userId!, tenantId: tenant.id, role: 'OWNER' },
        });

        return { tenant, membership };
      });

      res.status(201).json({
        message: 'Shop created successfully',
        tenant: result.tenant,
        role: result.membership.role,
      });
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

// GET /api/tenants/me — Get current tenant
router.get('/me', authenticateWithTenant, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const tenant = await prisma.tenant.findUnique({
      where: { id: req.tenantId },
    });

    if (!tenant) {
      res.status(404).json({ error: 'Shop not found' });
      return;
    }

    res.json({ tenant, role: req.role });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PUT /api/tenants/me — Update current tenant
router.put(
  '/me',
  authenticateWithTenant,
  [
    body('name').optional().trim().notEmpty(),
    body('phone').optional().trim(),
    body('address').optional().trim(),
    body('gstin').optional().trim(),
    body('email').optional().isEmail(),
  ],
  async (req: AuthRequest, res: Response): Promise<void> => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      res.status(400).json({ errors: errors.array() });
      return;
    }

    if (!['OWNER', 'MANAGER'].includes(req.role!)) {
      res.status(403).json({ error: 'Only owner or manager can update shop' });
      return;
    }

    const { name, phone, address, gstin, email, shopType, logoUrl } = req.body;

    try {
      const tenant = await prisma.tenant.update({
        where: { id: req.tenantId },
        data: {
          ...(name && { name }),
          ...(phone !== undefined && { phone }),
          ...(address !== undefined && { address }),
          ...(gstin !== undefined && { gstin }),
          ...(email !== undefined && { email }),
          ...(shopType && { shopType }),
          ...(logoUrl !== undefined && { logoUrl }),
        },
      });

      res.json({ message: 'Shop updated successfully', tenant });
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

// GET /api/tenants/members — List shop members
router.get('/members', authenticateWithTenant, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const members = await prisma.membership.findMany({
      where: { tenantId: req.tenantId, isActive: true },
      include: { user: { select: { id: true, email: true, name: true, phone: true } } },
    });

    res.json({ members });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
