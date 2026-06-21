require 'rufus-scheduler'
require_relative '../services/license/google_sheet_validator'

module LicenseScheduler
  GRACE_PERIOD = 24 * 3600
  REVALIDATE_INTERVAL = '7d'

  def self.start!
    scheduler = Rufus::Scheduler.new

    # Revalida a cada 7 dias
    scheduler.every REVALIDATE_INTERVAL, first: :now do
      perform_revalidation
    end

    scheduler
  end

  def self.perform_revalidation
    token = read_license_token_from_env
    unless token
      log('[LicenseScheduler] Nenhum token para revalidar')
      return
    end

    cache = GoogleSheetValidator.read_cache

    if GoogleSheetValidator.internet?
      result = GoogleSheetValidator.validate(token)
      if result[:valid] == false
        log("[LicenseScheduler] ❌ Revalidação falhou: #{result[:error]}")
        GoogleSheetValidator.clear_cache
        return
      end

      GoogleSheetValidator.write_cache(
        token_hash: Digest::SHA256.hexdigest(token),
        valid: true
      )
      log('[LicenseScheduler] ✅ Revalidação online concluída')
    else
      log('[LicenseScheduler] Sem internet — verificando cache')
      unless cache
        log('[LicenseScheduler] ❌ Sem cache disponível')
        return
      end

      cached_at = cache[:cached_at] || 0
      elapsed = Time.now.to_i - cached_at

      if elapsed > GRACE_PERIOD
        log("[LicenseScheduler] ❌ Carência de #{GRACE_PERIOD / 3600}h excedida (#{elapsed / 3600}h)")
      else
        remaining = GRACE_PERIOD - elapsed
        log("[LicenseScheduler] ✅ Dentro do período de carência (#{remaining / 3600}h restantes)")
      end
    end
  rescue => e
    log("[LicenseScheduler] ❌ Erro inesperado: #{e.message}")
  end

  def self.read_license_token_from_env
    prod_env = '/etc/gerenciador-erp/.env'
    path = if File.exist?(prod_env) && File.writable?(prod_env)
             prod_env
           else
              File.expand_path('../../.env', __dir__)
           end
    return nil unless File.exist?(path)
    File.readlines(path).each do |line|
      return $1.strip if line.strip =~ /\ALICENSE_TOKEN=(.+)\z/
    end
    nil
  rescue
    nil
  end

  def self.log(msg)
    puts "[#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}] #{msg}"
    $stdout.flush
  end
end
