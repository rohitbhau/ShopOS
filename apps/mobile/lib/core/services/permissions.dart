enum ShopRole { owner, manager, cashier, viewer }
enum ShopPermission { manageProducts, createInvoice, viewReports, manageStaff, manageSettings }

bool can(ShopRole role, ShopPermission permission) {
  const matrix = <ShopRole, Set<ShopPermission>>{
    ShopRole.owner: {ShopPermission.manageProducts, ShopPermission.createInvoice, ShopPermission.viewReports, ShopPermission.manageStaff, ShopPermission.manageSettings},
    ShopRole.manager: {ShopPermission.manageProducts, ShopPermission.createInvoice, ShopPermission.viewReports},
    ShopRole.cashier: {ShopPermission.createInvoice},
    ShopRole.viewer: {},
  };
  return matrix[role]!.contains(permission);
}
