module Inventory
  class AdjustStockService
    def self.call(product_id, new_qty, reason: "Ajuste de inventario", user_id: nil)
      p       = Product.find(product_id.to_i)
      new_qty = new_qty.to_i
      raise ArgumentError, "Produto nao encontrado"      unless p
      raise ArgumentError, "Quantidade nao pode ser < 0" if new_qty.negative?

      before  = p.quantity
      diff    = (new_qty - before).abs
      diff    = 1 if diff.zero?

      DB.transaction do
        DB.exec_params("UPDATE products SET quantity = $1 WHERE id = $2", [new_qty, p.id])
        Movement.create(product_id: p.id, kind: 'adjust', quantity: diff, reason: reason, reference: 'AJUSTE MANUAL')

        if user_id
          AuditLog.record(
            user_id: user_id, action: 'update', table_name: 'products',
            record_id: p.id,             details: "Ajuste de estoque: #{before} -> #{new_qty} (#{reason})", ip: nil
          )
        end
      end
    end
  end
end
