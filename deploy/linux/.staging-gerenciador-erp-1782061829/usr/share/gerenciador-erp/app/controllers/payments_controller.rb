PLANS_DATA = [
  {
    id: 'gold',
    name: 'Gold',
    price_monthly: 19,
    price_semiannual: 97,
    price_lifetime: 297,
    products: 500,
    users: 3,
    highlight: false
  },
  {
    id: 'platinum',
    name: 'Platinum',
    price_monthly: 39,
    price_semiannual: 197,
    price_lifetime: 597,
    products: 'Ilimitados',
    users: 'Ilimitados',
    highlight: true
  },
  {
    id: 'enterprise',
    name: 'Enterprise',
    price_monthly: 89,
    price_semiannual: 449,
    price_lifetime: 1_497,
    products: 'Ilimitados',
    users: 'Ilimitados',
    highlight: false,
    whitelabel: true,
    source: true
  }
].freeze

get '/plans' do
  @plans = PLANS_DATA
  @current_plan_name = plan_label
  @current_plan_id = current_plan
  @current_holder = license_holder
  @current_license = license_info
  @current_expires = license_expires_at
  erb :'payments/plans'
end

post '/checkout' do
  plan = params[:plan]
  interval = params[:interval]

  unless %w[gold platinum enterprise].include?(plan)
    halt 400, 'Plano inválido'
  end
  unless %w[monthly semiannual lifetime].include?(interval)
    halt 400, 'Intervalo inválido'
  end

  unless ENV['STRIPE_SECRET_KEY'] && ENV['STRIPE_PUBLISHABLE_KEY']
    halt 503, 'Pagamentos via Stripe não configurados — contate o administrador'
  end

  price_env = "STRIPE_PRICE_#{plan.upcase}_#{interval.upcase}"
  price_id = ENV[price_env]

  unless price_id
    halt 503, "Preço #{price_env} não configurado — execute scripts/setup_stripe_prices.rb"
  end

  Stripe.api_key = ENV['STRIPE_SECRET_KEY']

  session_data = {
    mode: interval == 'lifetime' ? 'payment' : 'subscription',
    line_items: [{
      price: price_id,
      quantity: 1
    }],
    success_url: "#{request.base_url}/success?session_id={CHECKOUT_SESSION_ID}",
    cancel_url: "#{request.base_url}/cancel",
    metadata: {
      plan: plan,
      interval: interval
    }
  }

  session_data[:customer_creation] = 'always' if interval == 'lifetime'

  token = read_license_token
  if token
    session_data[:metadata][:company] = token
  end

  checkout = Stripe::Checkout::Session.create(session_data)
  redirect checkout.url
end

get '/success' do
  @session_id = params[:session_id]
  @new_token = nil
  @plan = nil
  @interval = nil
  @expires_at = nil
  @receipt_file = nil

  if @session_id
    sub = Subscription.find_by_session(@session_id)
    if sub && sub.license_token
      sub
      @new_token = sub.license_token
      @plan = sub.plan
      @interval = sub.interval
      @expires_at = Time.at(calculate_expiry(@plan, @interval)) rescue nil

      receipt_filename = "licenca_#{@new_token[0..16].gsub(/[^a-zA-Z0-9]/, '_')}.txt"
      receipt_path = File.join(STORAGE_DIR, 'receipts', receipt_filename)
      @receipt_file = receipt_filename if File.exist?(receipt_path)
    else
      Stripe.api_key = ENV['STRIPE_SECRET_KEY']
      begin
        session = Stripe::Checkout::Session.retrieve(@session_id)
        @plan = session['metadata']['plan']
        @interval = session['metadata']['interval']
      rescue
      end
    end
  end

  erb :'payments/success'
end

get '/cancel' do
  erb :'payments/cancel'
end

get '/payment' do
  erb :'payments/upload'
end

post '/payment/upload' do
  token = params[:token].to_s.strip
  status = params[:status].to_s.strip
  file = params[:receipt]

  unless token =~ /\A[a-z]+\.[0-9]+\..+\z/
    @error = 'Token inválido. Formato esperado: plano.timestamp.assinatura'
    return erb :'payments/upload'
  end

  unless %w[pago pendente].include?(status)
    @error = 'Status inválido'
    return erb :'payments/upload'
  end

  unless file && file[:tempfile]
    @error = 'Selecione um arquivo'
    return erb :'payments/upload'
  end

  ext = File.extname(file[:filename]).downcase
  unless %w[.pdf .png .jpg .jpeg].include?(ext)
    @error = 'Formato não suportado. Use PDF, PNG ou JPG'
    return erb :'payments/upload'
  end

  upload_dir = File.join(STORAGE_DIR, 'receipts')
  FileUtils.mkdir_p(upload_dir)
  filename = "#{Time.now.to_i}_#{token.gsub(/[^a-zA-Z0-9_]/, '_')}#{ext}"
  dest = File.join(upload_dir, filename)

  File.open(dest, 'wb') { |f| f.write(file[:tempfile].read) }

  ocr_result = `python3 #{File.join(STORAGE_DIR, '..', 'scripts', 'payment_processor.py')} "#{dest}" 2>/dev/null`.strip

  if ocr_result.empty? || ocr_result == '{}'
    logger.warn "[Payment] OCR não extraiu dados de #{filename}"
  else
    logger.info "[Payment] OCR: #{ocr_result}"
  end

  if GoogleSheetValidator.update_payment_status!(token, status)
    @success = "Status atualizado para '#{status}' — comprovante salvo."
  else
    @error = 'Token não encontrado no Google Sheets'
    return erb :'payments/upload'
  end

  erb :'payments/upload'
end
