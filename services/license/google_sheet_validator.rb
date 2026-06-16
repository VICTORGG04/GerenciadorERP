require 'google/apis/sheets_v4'
require 'googleauth'
require 'digest'
require 'securerandom'
require 'socket'
require 'json'
require 'fileutils'

class GoogleSheetValidator
  COLUMNS = %w[token cnpj company plan expires status machine_id hostname ip activated_at notes].freeze

  SHEET_ID         = ENV['GOOGLE_SHEET_ID']
  CREDENTIALS_PATH = ENV['GOOGLE_SHEET_CREDENTIALS']
  RANGE            = 'Licencas!A:K'

  STORAGE_DIR = File.expand_path('../../storage', __dir__)
  CACHE_FILE  = File.join(STORAGE_DIR, 'license_cache.json')
  MID_FILE    = File.join(STORAGE_DIR, 'machine_id')

  GRACE_PERIOD = 24 * 3600
  COLUMN_MAP   = COLUMNS.each_with_index.to_h.freeze

  class << self
    def validate(token)
      return { valid: false, error: 'GOOGLE_SHEET_ID não configurado' } unless SHEET_ID
      return { valid: false, error: 'GOOGLE_SHEET_CREDENTIALS não configurado' } unless CREDENTIALS_PATH
      return { valid: false, error: 'Arquivo de credenciais não encontrado' } unless File.exist?(CREDENTIALS_PATH.to_s)

      rows = read_sheet
      return { valid: false, error: 'Não foi possível acessar a planilha' } unless rows

      idx = rows.index { |r| r[0].to_s.strip == token }
      return { valid: false, error: 'Token não encontrado na planilha' } unless idx

      row = rows[idx]
      row_num = idx + 2
      row_data = row_to_hash(row)

      case row_data[:status]
      when 'available'
        now = Time.now
        expires = parse_date(row_data[:expires])
        if expires && now > expires
          update_cell(row_num, 'status', 'expired')
          return { valid: false, error: 'Licença expirada', expires: expires }
        end
        row_data[:row_num] = row_num
        row_data
      when 'active'
        mid = machine_id
        if row_data[:machine_id] == mid
          now = Time.now
          expires = parse_date(row_data[:expires])
          if expires && now > expires
            update_cell(row_num, 'status', 'expired')
            return { valid: false, error: 'Licença expirada', expires: expires }
          end
          row_data[:row_num] = row_num
          row_data
        else
          { valid: false, error: 'Este token já está ativo em outra máquina' }
        end
      when 'expired', 'revoked'
        { valid: false, error: "Licença #{row_data[:status]}" }
      else
        { valid: false, error: "Status desconhecido: #{row_data[:status]}" }
      end
    rescue => e
      { valid: false, error: "Erro na validação: #{e.message}" }
    end

    def activate!(token, row_num)
      mid = machine_id
      host = Socket.gethostname rescue 'unknown'
      ip   = local_ip rescue 'unknown'
      now  = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')

      update_cell(row_num, 'status', 'active')
      update_cell(row_num, 'machine_id', mid)
      update_cell(row_num, 'hostname', host)
      update_cell(row_num, 'ip', ip)
      update_cell(row_num, 'activated_at', now)
    end

    def register_free_trial!(token)
      return unless SHEET_ID && CREDENTIALS_PATH && File.exist?(CREDENTIALS_PATH.to_s)

      mid = machine_id
      host = Socket.gethostname rescue 'unknown'
      ip   = local_ip rescue 'unknown'
      now  = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
      expires = (Time.now + 30 * 86400).utc.strftime('%Y-%m-%d')

      append = [
        token, '', 'Free Trial - Auto', 'free', expires,
        'active', mid, host, ip, now, 'Trial automático de 30 dias'
      ]
      append_row(append)
    rescue => e
      log("[GoogleSheetValidator] Erro ao registrar trial: #{e.message}")
    end

    def internet?
      return false unless SHEET_ID

      service = build_service
      service.get_spreadsheet(SHEET_ID)
      true
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

    def read_sheet
      service = build_service
      response = service.get_spreadsheet_values(SHEET_ID, RANGE)
      response.values
    rescue => e
      log("[GoogleSheetValidator] Erro ao ler planilha: #{e.message}")
      nil
    end

    def update_cell(row_num, column, value)
      col_letter = ('A'.ord + COLUMN_MAP[column.to_s]).chr
      range = "Licencas!#{col_letter}#{row_num}"
      value_range = Google::Apis::SheetsV4::ValueRange.new(values: [[value]])
      service = build_service
      service.update_spreadsheet_value(SHEET_ID, range, value_range, value_input_option: 'USER_ENTERED')
    rescue => e
      log("[GoogleSheetValidator] Erro ao atualizar célula #{range}: #{e.message}")
    end

    def append_row(values)
      value_range = Google::Apis::SheetsV4::ValueRange.new(values: [values])
      service = build_service
      service.append_spreadsheet_value(
        SHEET_ID, RANGE, value_range,
        value_input_option: 'USER_ENTERED',
        insert_data_option: 'INSERT_ROWS'
      )
    rescue => e
      log("[GoogleSheetValidator] Erro ao adicionar linha: #{e.message}")
    end

    def build_service
      service = Google::Apis::SheetsV4::SheetsService.new
      service.authorization = Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: File.open(CREDENTIALS_PATH),
        scope: 'https://www.googleapis.com/auth/spreadsheets'
      )
      service
    end

    def row_to_hash(row)
      h = {}
      COLUMNS.each_with_index { |col, i| h[col.to_sym] = row[i].to_s.strip }
      h
    end

    def parse_date(str)
      return nil if str.nil? || str.empty?
      Time.parse(str)
    rescue
      nil
    end

    def local_ip
      orig = Socket.do_not_reverse_lookup
      Socket.do_not_reverse_lookup = true
      UDPSocket.open { |s| s.connect('8.8.8.8', 1); s.addr.last }
    ensure
      Socket.do_not_reverse_lookup = orig
    end

    def log(msg)
      puts "[#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}] #{msg}"
      $stdout.flush
    end
  end
end
