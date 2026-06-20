class DisputeEvidence
  AUTO_CONTESTABLE = %w[
    product_not_received
    subscription_canceled
    unrecognized
    fraudulent
    duplicate
  ].freeze

  REFUND_POLICY = <<~POLICY.strip
    Política de reembolso: O cliente pode solicitar cancelamento a qualquer momento, sem multa.
    O reembolso é proporcional ao período não utilizado em assinaturas mensais.
    Assinaturas semestrais e vitalícias não são reembolsáveis após 7 dias da compra.
    Entre em contato pelo email de suporte para solicitar.
  POLICY

  PRODUCT_DESCRIPTION = 'Sistema de gestão empresarial ERP com licenciamento por assinatura. ' \
    'Inclui módulos de emissão de notas fiscais, gestão de estoque, financeiro, ' \
    'relatórios gerenciais e controle de licenças.'

  def self.submit(dispute_id, license_data: {})
    new(dispute_id, license_data).submit
  end

  def self.auto_contestable?(reason)
    AUTO_CONTESTABLE.include?(reason)
  end

  def initialize(dispute_id, license_data = {})
    @dispute_id = dispute_id
    @data = license_data
  end

  def submit
    evidence = build_evidence
    return false unless evidence

    Stripe.api_key = ENV['STRIPE_SECRET_KEY']
    Stripe::Dispute.update(
      @dispute_id,
      { evidence: evidence }
    )
    true
  rescue Stripe::StripeError => e
    log("Erro ao enviar evidência: #{e.message}")
    false
  end

  private

  def build_evidence
    {
      product_description: PRODUCT_DESCRIPTION,
      customer_email: @data[:email],
      customer_name: @data[:contact_name],
      service_date: @data[:activated_at] || @data[:created_at],
      service_documentation: service_documentation,
      refund_policy: REFUND_POLICY,
      receipt: @data[:receipt_url],
      customer_communication: communication_text,
      uncategorized_text: build_uncategorized
    }.compact
  end

  def service_documentation
    lines = []
    lines << "LICENSE INFORMATION"
    lines << "Token: #{@data[:token]}"
    lines << "Plano: #{@data[:plan]}"
    lines << "Empresa: #{@data[:company]}"
    lines << "CNPJ: #{@data[:cnpj]}"
    lines << "Ativado em: #{@data[:activated_at]}"
    lines << "Expira em: #{@data[:expires_at]}"
    lines << "Contato: #{@data[:contact_name]} (#{@data[:email]})"
    lines << "Checkout Stripe: #{@data[:stripe_session_id]}"
    lines << "Assinatura Stripe: #{@data[:stripe_subscription_id]}"
    lines << ""
    lines << "EVIDENCE OF SERVICE"
    lines << "O cliente ativou a licenca e teve acesso ininterrupto ao sistema."
    lines << "O servico foi prestado conforme contratado durante todo o periodo."
    lines << "O sistema registra logs de acesso do cliente."
    lines.compact.join("\n")
  end

  def communication_text
    if @data[:email]
      "O cliente foi contactado atraves do email #{@data[:email]} " \
        "para suporte e comunicacao durante todo o periodo contratado. " \
        "Nao houve reclamacao previa sobre o servico prestado."
    end
  end

  def build_uncategorized
    lines = []
    lines << "O cliente #{@data[:company] || 'sem empresa'} contratou o plano #{@data[:plan]} " \
      "e teve acesso completo ao sistema ERP."
    lines << "A licenca foi gerada em #{@data[:created_at]} e ativada em #{@data[:activated_at]}."
    lines << "O pagamento foi processado corretamente pelo Stripe."
    lines << "O servico foi prestado conforme as condicoes contratadas."
    lines << "O cliente nao entrou em contato para reportar problemas antes da contestacao."
    lines.compact.join(" ")
  end

  def log(msg)
    puts "[DisputeEvidence] #{msg}"
    $stdout.flush
  end
end
