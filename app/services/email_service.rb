class EmailService
  SMTP_HOST     = ENV['SMTP_HOST']
  SMTP_PORT     = (ENV['SMTP_PORT'] || 587).to_i
  SMTP_USER     = ENV['SMTP_USER']
  SMTP_PASSWORD = ENV['SMTP_PASSWORD']
  SMTP_FROM     = ENV['SMTP_FROM'] || 'noreply@gerenciadorerp.com.br'
  SMTP_STARTTLS = ENV['SMTP_STARTTLS'] != 'false'

  class << self
    def send_license_email(to:, token:, plan:, interval:, expires_at:, amount: nil, session_id: nil)
      unless SMTP_HOST && SMTP_USER && SMTP_PASSWORD
        log("[EmailService] SMTP não configurado — envie as variáveis SMTP_HOST, SMTP_USER, SMTP_PASSWORD no .env")
        log("[EmailService] Licença NÃO foi enviada por email para #{to}")
        return false
      end

      plan_label = plan.capitalize
      interval_label = { 'monthly' => 'Mensal', 'semiannual' => 'Semestral', 'lifetime' => 'Vitalício' }[interval] || interval
      expires_str = expires_at.is_a?(Time) ? expires_at.strftime('%d/%m/%Y') : expires_at.to_s
      amount_str = amount ? "R$ #{format('%.2f', amount)}" : '—'

      subject = "🪪 Sua licença #{plan_label} — Gerenciador ERP"
      body_html = build_email_html(token, plan_label, interval_label, expires_str, amount_str)

      msg = <<~END
        From: Gerenciador ERP <#{SMTP_FROM}>
        To: #{to}
        Subject: #{subject}
        MIME-Version: 1.0
        Content-Type: text/html; charset=UTF-8

        #{body_html}
      END

      begin
        require 'net/smtp'
        Net::SMTP.start(SMTP_HOST, SMTP_PORT, 'localhost', SMTP_USER, SMTP_PASSWORD, :login) do |smtp|
          smtp.enable_starttls if SMTP_STARTTLS
          smtp.send_message msg, SMTP_FROM, to
        end
        log("[EmailService] Email enviado para #{to}")
        true
      rescue => e
        log("[EmailService] Erro ao enviar email para #{to}: #{e.message}")
        false
      end
    end

    private

    def build_email_html(token, plan_label, interval_label, expires_str, amount_str)
      token_hl = token[0..50]
      token_rest = token[51..-1]

      <<~HTML
        <!DOCTYPE html>
        <html>
        <head><meta charset="UTF-8"><style>
          body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f8fafc; margin: 0; padding: 0; }
          .container { max-width: 560px; margin: 0 auto; padding: 24px; }
          .card { background: #fff; border-radius: 12px; box-shadow: 0 2px 12px rgba(0,0,0,.06); padding: 32px; }
          h1 { font-size: 22px; color: #1e293b; margin: 0 0 8px; }
          .sub { font-size: 14px; color: #64748b; margin-bottom: 24px; }
          .license-box { background: #eef2ff; border: 1.5px solid #6366f1; border-radius: 8px; padding: 16px; margin-bottom: 24px; word-break: break-all; font-family: 'SFMono-Regular', Consolas, monospace; font-size: 13px; color: #1e293b; line-height: 1.6; }
          .license-box .hl { font-weight: 700; color: #4f46e5; }
          .details { margin-bottom: 24px; }
          .details table { width: 100%; border-collapse: collapse; }
          .details td { padding: 8px 0; border-bottom: 1px solid #f1f5f9; font-size: 14px; }
          .details td:last-child { text-align: right; font-weight: 600; color: #1e293b; }
          .footer { font-size: 12px; color: #94a3b8; text-align: center; margin-top: 24px; line-height: 1.6; }
        </style></head>
        <body>
          <div class="container">
            <div class="card">
              <h1>🪪 #{plan_label} #{interval_label}</h1>
              <p class="sub">Sua licença do Gerenciador ERP foi gerada com sucesso!</p>

              <div style="font-size:13px;color:#475569;margin-bottom:12px;">Copie o token abaixo e cole no campo de licença do sistema:</div>

              <div class="license-box">
                <span class="hl">#{token_hl}</span>#{token_rest}
              </div>

              <div class="details">
                <table>
                  <tr><td>Plano</td><td>#{plan_label}</td></tr>
                  <tr><td>Intervalo</td><td>#{interval_label}</td></tr>
                  <tr><td>Expira em</td><td>#{expires_str}</td></tr>
                  <tr><td>Valor pago</td><td>#{amount_str}</td></tr>
                </table>
              </div>

              <div style="background:#f0fdf4;border:1px solid #86efac;border-radius:8px;padding:12px 16px;font-size:13px;color:#166534;">
                ✅ Pagamento confirmado — sua licença já está ativa.
              </div>

              <div class="footer">
                Gerenciador ERP — Sistema de Gerenciamento de Estoque<br>
                Se tiver dúvidas, responda a este email.
              </div>
            </div>
          </div>
        </body>
        </html>
      HTML
    end

    def log(msg)
      puts "[#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}] #{msg}"
      $stdout.flush
    end
  end
end
