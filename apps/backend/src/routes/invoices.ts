import { Router, Response } from 'express';
import { body, validationResult } from 'express-validator';
import { prisma } from '../lib/prisma';
import { authenticateWithTenant, AuthRequest } from '../middleware/auth';

const router = Router();

// Generate sequential invoice number
const generateInvoiceNumber = async (tenantId: string): Promise<string> => {
  const count = await prisma.invoice.count({ where: { tenantId } });
  const num = String(count + 1).padStart(5, '0');
  return `INV-${num}`;
};

// GET /api/invoices
router.get('/', authenticateWithTenant, async (req: AuthRequest, res: Response): Promise<void> => {
  const { status, customerId, page = '1', limit = '20', from, to } = req.query as Record<string, string>;
  const skip = (parseInt(page) - 1) * parseInt(limit);

  try {
    const where: Record<string, unknown> = {
      tenantId: req.tenantId,
      ...(status && { status }),
      ...(customerId && { customerId }),
      ...(from || to
        ? {
            createdAt: {
              ...(from && { gte: new Date(from) }),
              ...(to && { lte: new Date(to) }),
            },
          }
        : {}),
    };

    const [invoices, total] = await Promise.all([
      prisma.invoice.findMany({
        where,
        include: {
          customer: { select: { id: true, name: true, phone: true } },
          items: true,
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take: parseInt(limit),
      }),
      prisma.invoice.count({ where }),
    ]);

    res.json({ invoices, total, page: parseInt(page), limit: parseInt(limit) });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /api/invoices/:id
router.get('/:id', authenticateWithTenant, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const invoice = await prisma.invoice.findFirst({
      where: { id: req.params.id, tenantId: req.tenantId },
      include: {
        customer: true,
        items: { include: { product: { select: { id: true, name: true, unit: true } } } },
      },
    });

    if (!invoice) {
      res.status(404).json({ error: 'Invoice not found' });
      return;
    }

    res.json({ invoice });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /api/invoices
router.post(
  '/',
  authenticateWithTenant,
  [
    body('items').isArray({ min: 1 }).withMessage('At least one item is required'),
    body('items.*.name').trim().notEmpty(),
    body('items.*.quantity').isFloat({ min: 0.001 }),
    body('items.*.price').isFloat({ min: 0 }),
  ],
  async (req: AuthRequest, res: Response): Promise<void> => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      res.status(400).json({ errors: errors.array() });
      return;
    }

    const { customerId, items, paymentMethod, notes, discountAmount = 0 } = req.body;

    try {
      const invoiceNumber = await generateInvoiceNumber(req.tenantId!);

      // Calculate totals
      let subtotal = 0;
      let taxAmount = 0;
      const lineItems = (items as Array<{
        productId?: string;
        name: string;
        quantity: number;
        price: number;
        taxRate?: number;
      }>).map((item) => {
        const lineTotal = item.quantity * item.price;
        const lineTax = lineTotal * ((item.taxRate || 0) / 100);
        subtotal += lineTotal;
        taxAmount += lineTax;
        return {
          productId: item.productId || null,
          name: item.name,
          quantity: item.quantity,
          price: item.price,
          taxRate: item.taxRate || 0,
          total: lineTotal,
        };
      });

      const totalAmount = subtotal + taxAmount - Number(discountAmount);
      const status = paymentMethod ? 'PAID' : 'DRAFT';

      const invoice = await prisma.$transaction(async (tx) => {
        const created = await tx.invoice.create({
          data: {
            tenantId: req.tenantId!,
            customerId: customerId || null,
            invoiceNumber,
            status,
            subtotal,
            taxAmount,
            discountAmount: Number(discountAmount),
            totalAmount,
            paidAmount: status === 'PAID' ? totalAmount : 0,
            paymentMethod: paymentMethod || null,
            notes: notes || null,
            items: { create: lineItems },
          },
          include: {
            customer: { select: { id: true, name: true, phone: true } },
            items: true,
          },
        });

        // Deduct stock for each product item
        for (const item of lineItems) {
          if (item.productId) {
            await tx.product.update({
              where: { id: item.productId },
              data: { stock: { decrement: Math.floor(Number(item.quantity)) } },
            });
          }
        }

        // Update customer outstanding if credit sale
        if (customerId && status !== 'PAID') {
          await tx.customer.update({
            where: { id: customerId },
            data: { outstanding: { increment: totalAmount } },
          });
        }

        return created;
      });

      res.status(201).json({ message: 'Invoice created', invoice });
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

// PATCH /api/invoices/:id/pay — Record payment
router.patch('/:id/pay', authenticateWithTenant, async (req: AuthRequest, res: Response): Promise<void> => {
  const { amount, paymentMethod } = req.body;

  if (!amount || !paymentMethod) {
    res.status(400).json({ error: 'Amount and payment method required' });
    return;
  }

  try {
    const invoice = await prisma.invoice.findFirst({
      where: { id: req.params.id, tenantId: req.tenantId },
    });

    if (!invoice) {
      res.status(404).json({ error: 'Invoice not found' });
      return;
    }

    if (invoice.status === 'CANCELLED') {
      res.status(400).json({ error: 'Cannot pay a cancelled invoice' });
      return;
    }

    const newPaid = Number(invoice.paidAmount) + Number(amount);
    const newStatus = newPaid >= Number(invoice.totalAmount) ? 'PAID' : 'PARTIAL';

    const updated = await prisma.$transaction(async (tx) => {
      const inv = await tx.invoice.update({
        where: { id: req.params.id },
        data: {
          paidAmount: newPaid,
          status: newStatus,
          paymentMethod,
        },
        include: { customer: true },
      });

      // Reduce outstanding
      if (inv.customerId) {
        await tx.customer.update({
          where: { id: inv.customerId },
          data: { outstanding: { decrement: Number(amount) } },
        });
      }

      return inv;
    });

    res.json({ message: 'Payment recorded', invoice: updated });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PATCH /api/invoices/:id/cancel
router.patch('/:id/cancel', authenticateWithTenant, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const invoice = await prisma.invoice.findFirst({
      where: { id: req.params.id, tenantId: req.tenantId },
    });

    if (!invoice) {
      res.status(404).json({ error: 'Invoice not found' });
      return;
    }

    if (invoice.status === 'PAID') {
      res.status(400).json({ error: 'Cannot cancel a paid invoice' });
      return;
    }

    const updated = await prisma.invoice.update({
      where: { id: req.params.id },
      data: { status: 'CANCELLED' },
    });

    res.json({ message: 'Invoice cancelled', invoice: updated });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
