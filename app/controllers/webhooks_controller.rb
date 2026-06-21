def handle_stripe_webhook
  Stripe.api_key = ENV['STRIPE_SECRET_KEY']
  payload = request.body.read
  sig_header = request.env['HTTP_STRIPE_SIGNATURE']

  unless ENV['STRIPE_WEBHOOK_SECRET']
    status 500
    return 'STRIPE_WEBHOOK_SECRET não configurado'
  end

  begin
    event = Stripe::Webhook.construct_event(payload, sig_header, ENV['STRIPE_WEBHOOK_SECRET'])
  rescue JSON::ParserError
    status 400
    return 'Payload inválido'
  rescue Stripe::SignatureVerificationError
    status 400
    return 'Assinatura inválida'
  end

  case event['type']
  when 'checkout.session.completed'
    handle_checkout_completed(event['data']['object'])
  when 'invoice.paid'
    handle_invoice_paid(event['data']['object'])
  when 'invoice.payment_failed'
    handle_invoice_failed(event['data']['object'])
  when 'charge.dispute.created'
    handle_dispute_created(event['data']['object'])
  when 'charge.dispute.updated'
    handle_dispute_updated(event['data']['object'])
  when 'charge.dispute.closed'
    handle_dispute_closed(event['data']['object'])
  end

  status 200
  'ok'
end

post '/stripe' do
  handle_stripe_webhook
end

post '/webhooks/stripe' do
  handle_stripe_webhook
end

def generate_paid_token!(plan, interval, customer_email, company_name = nil)
  expires = calculate_expiry(plan, interval)
  identifier = "LIC-#{SecureRandom.hex(4).upcase}"
  data = "#{plan}.#{expires}.#{identifier}"
  sig = OpenSSL::HMAC.hexdigest('SHA256', LICENSE_SECRET, data)
  token = "#{data}.#{sig}"

  GoogleSheetValidator.register_license!(token, {
    plan: plan,
    company_name: company_name || customer_email,
    contact_email: customer_email,
    expires_at: Time.at(expires).strftime('%Y-%m-%d'),
    notes: "Comprado via Stripe"
  })

  log_webhook("Nova licença gerada: #{token[0..40]}... para #{customer_email}")
  token
end

def generate_receipt_file(token, plan, interval, customer_email, expires_at, session_id = nil)
  dir = File.join(STORAGE_DIR, 'receipts')
  FileUtils.mkdir_p(dir)
  plan_label = plan.capitalize
  interval_label = { 'monthly' => 'Mensal', 'semiannual' => 'Semestral', 'lifetime' => 'Vitalício' }[interval] || interval
  filename = "licenca_#{token[0..16].gsub(/[^a-zA-Z0-9]/, '_')}.txt"
  path = File.join(dir, filename)

  content = <<~TXT
    🆕 LICENÇA GERENCIADOR ERP
    ─────────────────────────
    Plano: #{plan_label}
    Intervalo: #{interval_label}
    Expira: #{expires_at.is_a?(Time) ? expires_at.strftime('%d/%m/%Y') : expires_at}
    Token: #{token}

    💳 PAGAMENTO
    ─────────────────────────
    Data: #{Time.now.strftime('%d/%m/%Y %H:%M')}
    Status: Confirmado
    Cliente: #{customer_email}
    #{session_id ? "Stripe Session: #{session_id}" : ''}

    📋 INSTRUÇÕES
    ─────────────────────────
    Copie o token acima e cole no campo de licença
    do sistema Gerenciador ERP para ativar seu plano.
  TXT

  File.write(path, content)
  log_webhook("Comprovante gerado: #{path}")
  path
end

def send_license_email(customer_email, new_token, plan, interval, expires_at, session = nil)
  amount = nil
  if session
    line_item = session&.[]('line_items')&.first
    amount_total = line_item&.[]('amount_total')
    amount = amount_total / 100.0 if amount_total
  end

  EmailService.send_license_email(
    to: customer_email,
    token: new_token,
    plan: plan,
    interval: interval,
    expires_at: expires_at,
    amount: amount,
    session_id: session ? (session['id'] || session&.id) : nil
  )
end

def handle_checkout_completed(session)
  plan = session['metadata']['plan']
  interval = session['metadata']['interval']
  customer_email = session['customer_details']['email']
  old_token = session['metadata']['company']

  new_token = generate_paid_token!(plan, interval, customer_email, customer_email)

  GoogleSheetValidator.update_status!(old_token, 'upgraded') if old_token

  expires_at = Time.at(calculate_expiry(plan, interval))

  sub = Subscription.find_by_session(session['id'])
  if sub
    Subscription.update_token(sub.id, new_token)
  else
    Subscription.create(
      stripe_subscription_id: session['subscription'],
      stripe_customer_id: session['customer'],
      stripe_session_id: session['id'],
      plan: plan,
      interval: interval,
      status: 'active',
      license_token: new_token,
      current_period_start: session['expires_at'] ? Time.at(session['expires_at']).strftime('%Y-%m-%d %H:%M:%S') : Time.now.strftime('%Y-%m-%d %H:%M:%S'),
      current_period_end: nil
    )
  end

  GoogleSheetValidator.update_payment_status!(new_token, 'pago')
  generate_receipt_file(new_token, plan, interval, customer_email, expires_at, session['id'])
  send_license_email(customer_email, new_token, plan, interval, expires_at, session)

  log_webhook("checkout.session.completed: #{new_token[0..40]}... gerado para #{customer_email}")
end

def handle_invoice_paid(invoice)
  sub_id = invoice['subscription'] || (invoice['parent']&.[]('subscription_details')&.[]('subscription') rescue nil) || ((invoice['lines']&.[]('data')&.first&.[]('parent')&.[]('subscription_item_details')&.[]('subscription')) rescue nil)

  if sub_id
    subscription = Stripe::Subscription.retrieve(sub_id)
  end

  customer = Stripe::Customer.retrieve(invoice['customer'])
  company = customer['metadata']['company'] || customer['email']

  old_token = find_token_for_company(company)
  return unless old_token

  GoogleSheetValidator.update_payment_status!(old_token, 'pago')
  log_webhook("invoice.paid: #{old_token} -> pago")

  sub = Subscription.find_by_subscription(sub_id) if sub_id
  if sub
    period_start = Time.at(invoice['period_start']).strftime('%Y-%m-%d %H:%M:%S') rescue nil
    period_end = Time.at(invoice['period_end']).strftime('%Y-%m-%d %H:%M:%S') rescue nil
    Subscription.update_period(sub.id, period_start, period_end)
    Subscription.update_status(sub.id, 'active')

    if sub.license_token.nil?
      plan = sub.plan
      interval = sub.interval
      customer_email = customer['email']
      new_token = generate_paid_token!(plan, interval, customer_email, customer_email)
      Subscription.update_token(sub.id, new_token)
      GoogleSheetValidator.update_status!(old_token, 'upgraded')
      GoogleSheetValidator.update_payment_status!(new_token, 'pago')
      expires_at = Time.at(calculate_expiry(plan, interval))
      generate_receipt_file(new_token, plan, interval, customer_email, expires_at)
      send_license_email(customer_email, new_token, plan, interval, expires_at)
      log_webhook("invoice.paid: nova licença #{new_token[0..40]}... gerada para #{customer_email}")
    end
  else
    plan = (subscription&.metadata&.[]('plan') rescue nil) || 'gold'
    interval = (subscription&.metadata&.[]('interval') rescue nil) || 'monthly'
    customer_email = customer['email']
    new_token = generate_paid_token!(plan, interval, customer_email, customer_email)
    Subscription.create(
      stripe_subscription_id: sub_id,
      stripe_customer_id: invoice['customer'],
      plan: plan,
      interval: interval,
      status: 'active',
      license_token: new_token
    )
    GoogleSheetValidator.update_status!(old_token, 'upgraded')
    GoogleSheetValidator.update_payment_status!(new_token, 'pago')
    expires_at = Time.at(calculate_expiry(plan, interval))
    generate_receipt_file(new_token, plan, interval, customer_email, expires_at)
    send_license_email(customer_email, new_token, plan, interval, expires_at)
    log_webhook("invoice.paid: subscription criada + licença #{new_token[0..40]}... para #{customer_email}")
  end
end

def handle_invoice_failed(invoice)
  sub_id = invoice['subscription'] || (invoice['parent']&.[]('subscription_details')&.[]('subscription') rescue nil) || ((invoice['lines']&.[]('data')&.first&.[]('parent')&.[]('subscription_item_details')&.[]('subscription')) rescue nil)

  if sub_id
    subscription = Stripe::Subscription.retrieve(sub_id)
  end

  customer = Stripe::Customer.retrieve(invoice['customer'])
  company = customer['metadata']['company'] || customer['email']

  token = find_token_for_company(company)
  return unless token

  GoogleSheetValidator.update_payment_status!(token, 'pendente')
  log_webhook("invoice.payment_failed: #{token} -> pendente")

  sub = Subscription.find_by_subscription(sub_id) if sub_id
  Subscription.update_status(sub.id, 'past_due') if sub
end

def handle_dispute_created(dispute)
  email = customer_email_from_dispute(dispute)
  unless email
    log_webhook("charge.dispute.created: não foi possível obter email do cliente (disputa: #{dispute['id']})")
    GoogleSheetValidator.register_dispute!(
      id: dispute['id'], charge_id: dispute['charge'],
      customer_email: '', license_token: '',
      amount: dispute['amount'], currency: dispute['currency'],
      reason: dispute['reason'], status: dispute['status'],
      evidence_submitted: 'nao',
      created_at: Time.at(dispute['created']).utc.iso8601
    ) rescue nil
    return
  end

  token = find_token_by_email(email)
  unless token
    log_webhook("charge.dispute.created: licença não encontrada para #{email}")
    GoogleSheetValidator.register_dispute!(
      id: dispute['id'], charge_id: dispute['charge'],
      customer_email: email, license_token: '',
      amount: dispute['amount'], currency: dispute['currency'],
      reason: dispute['reason'], status: dispute['status'],
      evidence_submitted: 'nao',
      created_at: Time.at(dispute['created']).utc.iso8601
    ) rescue nil
    return
  end

  GoogleSheetValidator.update_payment_status!(token, 'pendente')

  charge = Stripe::Charge.retrieve(dispute['charge']) rescue nil
  payment_intent = charge&.payment_intent

  auto_contestavel = DisputeEvidence.auto_contestable?(dispute['reason'])
  GoogleSheetValidator.register_dispute!(
    id: dispute['id'],
    charge_id: dispute['charge'],
    payment_intent: payment_intent,
    customer_email: email,
    license_token: token,
    amount: dispute['amount'],
    currency: dispute['currency'],
    reason: dispute['reason'],
    status: dispute['status'],
    evidence_submitted: auto_contestavel ? 'auto' : 'nao',
    created_at: Time.at(dispute['created']).utc.iso8601
  )
  log_webhook("charge.dispute.created: #{token} -> pendente (disputa: #{dispute['id']}, motivo: #{dispute['reason']})")

  if auto_contestavel
    result = DB.exec_params("SELECT * FROM licenses WHERE license_token ILIKE $1 LIMIT 1", ["%#{token}%"])
    lic = License.new(result[0]) if result.ntuples > 0
    if lic
      sub = Subscription.find_by_license(lic.id)

      evidence_data = {
        token: token,
        plan: lic.plan,
        company: lic.company_name,
        cnpj: lic.cnpj,
        contact_name: lic.contact_name,
        email: lic.contact_email,
        activated_at: lic.activated_at,
        expires_at: lic.expires_at,
        created_at: lic.created_at,
        stripe_session_id: sub&.stripe_session_id,
        stripe_subscription_id: sub&.stripe_subscription_id,
        receipt_url: charge&.receipt_url
      }

      if DisputeEvidence.submit(dispute['id'], license_data: evidence_data)
        log_webhook("charge.dispute.created: evidência enviada com sucesso para #{dispute['id']}")
      else
        log_webhook("charge.dispute.created: falha ao enviar evidência para #{dispute['id']}")
      end
    end
  else
    log_webhook("charge.dispute.created: motivo '#{dispute['reason']}' requer revisão manual")
  end
end

def handle_dispute_closed(dispute)
  GoogleSheetValidator.close_dispute!(dispute['id'], dispute['status'])

  email = customer_email_from_dispute(dispute)
  unless email
    log_webhook("charge.dispute.closed: não foi possível obter email do cliente (disputa: #{dispute['id']})")
    return
  end

  token = find_token_by_email(email)
  unless token
    log_webhook("charge.dispute.closed: licença não encontrada para #{email}")
    return
  end

  status = dispute['status']
  if status == 'lost'
    GoogleSheetValidator.update_payment_status!(token, 'nao_pago')
    log_webhook("charge.dispute.closed: #{token} -> nao_pago (perdemos a disputa #{dispute['id']})")
  elsif status == 'won'
    GoogleSheetValidator.update_payment_status!(token, 'pago')
    log_webhook("charge.dispute.closed: #{token} -> pago (ganhamos a disputa #{dispute['id']})")
  else
    log_webhook("charge.dispute.closed: #{token} status desconhecido: #{status}")
  end
end

def handle_dispute_updated(dispute)
  GoogleSheetValidator.update_dispute!(dispute['id'], dispute['status'])
  log_webhook("charge.dispute.updated: #{dispute['id']} -> #{dispute['status']}")
end

def customer_email_from_dispute(dispute)
  charge = Stripe::Charge.retrieve(dispute['charge'])
  return nil unless charge

  pi = Stripe::PaymentIntent.retrieve(charge['payment_intent'])
  return nil unless pi

  customer = Stripe::Customer.retrieve(pi['customer'])
  return nil unless customer

  customer['email']
rescue Stripe::StripeError => e
  log_webhook("Erro ao recuperar dados da disputa #{dispute['id']}: #{e.message}")
  nil
end

def find_token_for_company(company)
  return company if company =~ /\A[a-z]+\.[0-9]+\..+\z/

  result = DB.exec_params("SELECT license_token FROM licenses WHERE company_name ILIKE $1 LIMIT 1", ["%#{company}%"])
  return result[0]['license_token'] if result.ntuples > 0

  nil
end

def find_token_by_email(email)
  result = DB.exec_params("SELECT license_token FROM licenses WHERE contact_email ILIKE $1 LIMIT 1", ["%#{email}%"])
  return result[0]['license_token'] if result.ntuples > 0

  result = DB.exec_params("SELECT license_token FROM licenses WHERE company_name ILIKE $1 LIMIT 1", ["%#{email}%"])
  return result[0]['license_token'] if result.ntuples > 0

  nil
end

def log_webhook(msg)
  logger.info "[Webhook] #{msg}"
rescue
  puts "[Webhook] #{msg}"
end
