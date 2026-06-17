require 'json'
require 'digest'
require 'securerandom'
require 'socket'
require 'fileutils'
require 'open3'

class GoogleSheetValidator
  COLUMNS = %w[token cnpj company plan expires status machine_id hostname ip activated_at address_street address_number address_complement address_neighborhood address_city address_state address_zip contact_name contact_email contact_phone notes].freeze

  SHEET_ID         = ENV['GOOGLE_SHEET_ID']
  CREDENTIALS_PATH = ENV['GOOGLE_SHEET_CREDENTIALS']

  STORAGE_DIR = File.expand_path('../../../storage', __dir__)
  CACHE_FILE  = File.join(STORAGE_DIR, 'license_cache.json')
  MID_FILE    = File.join(STORAGE_DIR, 'machine_id')

  GRACE_PERIOD = 24 * 3600

  PYTHON_SCRIPT = File.expand_path('../../../scripts/google_sheet_validator.py', __dir__)

  class << self
    def validate(token)
      return { valid: false, error: 'GOOGLE_SHEET_ID não configurado' } unless SHEET_ID
      return { valid: false, error: 'GOOGLE_SHEET_CREDENTIALS não configurado' } unless CREDENTIALS_PATH

      result = call_python('validate', { token: token })
      return { valid: false, error: result['error'] || 'Erro desconhecido' } unless result['success']

      row_data = {}
      COLUMNS.each { |col| row_data[col.to_sym] = result[col] || '' }
      row_data[:row_num] = result['row_num'] if result['row_num']
      row_data
    rescue => e
      { valid: false, error: "Erro na validação: #{e.message}" }
    end

    def activate!(token, row_num)
      call_python('activate', { token: token, row_num: row_num })
    end

    def register_license!(token, data)
      unless SHEET_ID && CREDENTIALS_PATH
        missing = []
        missing << 'GOOGLE_SHEET_ID' unless SHEET_ID
        missing << 'GOOGLE_SHEET_CREDENTIALS' unless CREDENTIALS_PATH
        log("[GoogleSheetValidator] Variáveis de ambiente ausentes: #{missing.join(', ')}")
        return false
      end

      params = {
        token: token,
        cnpj: data[:cnpj].to_s.strip,
        company_name: data[:company_name].to_s.strip,
        plan: data[:plan].to_s.strip,
        expires_at: data[:expires_at]&.to_s,
        address_street: data[:address_street].to_s.strip,
        address_number: data[:address_number].to_s.strip,
        address_complement: data[:address_complement].to_s.strip,
        address_neighborhood: data[:address_neighborhood].to_s.strip,
        address_city: data[:address_city].to_s.strip,
        address_state: data[:address_state].to_s.strip,
        address_zip: data[:address_zip].to_s.strip,
        contact_name: data[:contact_name].to_s.strip,
        contact_email: data[:contact_email].to_s.strip,
        contact_phone: data[:contact_phone].to_s.strip,
        notes: data[:notes].to_s.strip
      }

      result = call_python('register_license', params)
      if result['success']
        true
      else
        log("[GoogleSheetValidator] Erro ao registrar licença: #{result['error']}")
        false
      end
    rescue => e
      log("[GoogleSheetValidator] Erro ao registrar licença: #{e.message}")
      false
    end

    def revoke_token!(token)
      unless SHEET_ID && CREDENTIALS_PATH
        log("[GoogleSheetValidator] revoke_token: Variáveis de ambiente ausentes")
        return false
      end

      result = call_python('revoke_token', { token: token })
      if result['success']
        log("[GoogleSheetValidator] Token revogado na planilha")
        true
      else
        log("[GoogleSheetValidator] Erro ao revogar: #{result['error']}")
        false
      end
    rescue => e
      log("[GoogleSheetValidator] Erro ao revogar: #{e.message}")
      false
    end

    def register_free_trial!(token)
      unless SHEET_ID && CREDENTIALS_PATH
        log("[GoogleSheetValidator] register_free_trial: Variáveis de ambiente ausentes")
        return false
      end

      result = call_python('register_free_trial', { token: token })
      if result['success']
        true
      else
        log("[GoogleSheetValidator] Erro ao registrar trial: #{result['error']}")
        false
      end
    rescue => e
      log("[GoogleSheetValidator] Erro ao registrar trial: #{e.message}")
      false
    end

    def internet?
      return false unless SHEET_ID

      result = call_python('internet', {})
      result['success']
    rescue
      false
    end

    def machine_id
      FileUtils.mkdir_p(STORAGE_DIR)
      if File.exist?(MID_FILE)
        File.read(MID_FILE).strip
      else
        id = Digest::SHA256.hexdigest("#{Socket.gethostname}-#{SecureRandom.hex(16)}")
        File.write(MID_FILE, id)
        id
      end
    end

    def read_cache
      return nil unless File.exist?(CACHE_FILE)
      JSON.parse(File.read(CACHE_FILE), symbolize_names: true)
    rescue
      nil
    end

    def write_cache(data)
      FileUtils.mkdir_p(STORAGE_DIR)
      data[:cached_at] = Time.now.to_i
      File.write(CACHE_FILE, JSON.pretty_generate(data))
    end

    def clear_cache
      File.delete(CACHE_FILE) if File.exist?(CACHE_FILE)
    rescue
      nil
    end

    private

    def call_python(action, params)
      json_data = params.to_json
      env_vars = "GOOGLE_SHEET_ID=#{SHEET_ID} GOOGLE_SHEET_CREDENTIALS=#{CREDENTIALS_PATH}"
      cmd = "#{env_vars} python3 #{PYTHON_SCRIPT} #{action} '#{json_data}'"

      stdout, stderr, status = Open3.capture3(cmd)
      log("[GoogleSheetValidator] Python stdout: #{stdout.strip}") if stdout.strip.length > 0
      log("[GoogleSheetValidator] Python stderr: #{stderr.strip}") if stderr.strip.length > 0 && !status.success?

      JSON.parse(stdout.strip)
    rescue JSON::ParserError => e
      log("[GoogleSheetValidator] JSON parse error: #{e.message}, stdout: #{stdout}")
      { 'success' => false, 'error' => "Resposta inválida do Python: #{e.message}" }
    rescue => e
      log("[GoogleSheetValidator] Erro ao chamar Python: #{e.message}")
      { 'success' => false, 'error' => e.message }
    end

    def log(msg)
      puts "[#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}] #{msg}"
      $stdout.flush
    end
  end
end
