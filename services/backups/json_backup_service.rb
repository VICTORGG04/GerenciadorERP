require "json"
require "fileutils"

module Backups
  class JsonBackupService
    DIR = "backups"

    def self.call
      FileUtils.mkdir_p(DIR)
      filename = "backup_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json"
      path     = File.join(DIR, filename)

      data = {
        exported_at:     Time.now.iso8601,
        categories:      DB.exec("SELECT * FROM categories").map { |r| r },
        products:        DB.exec("SELECT * FROM products").map { |r| r },
        stock_movements: DB.exec("SELECT * FROM stock_movements ORDER BY created_at DESC LIMIT 1000").map { |r| r }
      }

      File.write(path, JSON.pretty_generate(data))
      { filename: filename, path: path, size: File.size(path) }
    end
  end
end
