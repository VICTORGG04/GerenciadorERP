module Inventory
  class RemoveStockService
    def self.call(product_id, qty, reason: "Saida manual", reference: nil, user_id: nil)
      p   = Product.find(product_id.to_i)
      qty = qty.to_i
      raise ArgumentError, "Produto nao encontrado"                           unless p
      raise ArgumentError, "Quantidade deve ser positiva"                     unless qty.positive?
      raise ArgumentError, "Estoque insuficiente (#{p.quantity} disponivel)"  if qty > p.quantity

      before = p.quantity
      after  = before - qty

      DB.transaction do
        DB.exec_params("UPDATE products SET quantity = $1 WHERE id = $2", [after, p.id])
        Movement.create(product_id: p.id, kind: 'out', quantity: qty, reason: reason, reference: reference)

        if user_id
          AuditLog.record(
            user_id: user_id, action: 'update', table_name: 'products',
            record_id: p.id,             details: "Saida de estoque: -#{qty} (#{reason})", ip: nil
          )
        end
      end
    end
  end
end
