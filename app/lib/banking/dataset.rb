require "fileutils"

module Banking
  # Fetches the synthetic banking dataset (Kaggle: akrambelha/synthetic-banking-dataset,
  # CC BY 4.0) and unpacks its SQLite database under tmp/banking, outside git.
  # The Kaggle download endpoint serves this public dataset without a login.
  class Dataset
    SLUG = "akrambelha/synthetic-banking-dataset-csv-sql-sqlite"
    URL = "https://www.kaggle.com/api/v1/datasets/download/#{SLUG}".freeze
    ARCHIVE_MEMBER = "banking_dataset_kaggle/data/database/bank_sqlite.db"

    attr_reader :dir

    def initialize(dir: Rails.root.join("tmp/banking"))
      @dir = Pathname(dir)
    end

    def archive_path
      dir.join("banking.zip")
    end

    def database_path
      dir.join("bank_sqlite.db")
    end

    # Downloads the archive (about 170 MB) and extracts only the SQLite file.
    # Returns the extracted database path.
    def download(force: false)
      FileUtils.mkdir_p(dir)
      return database_path if database_path.exist? && !force

      unless archive_path.exist? && !force
        run!("curl", "--fail", "--location", "--silent", "--show-error", "--output", archive_path.to_s, URL)
      end
      run!("unzip", "-o", "-j", archive_path.to_s, ARCHIVE_MEMBER, "-d", dir.to_s)
      raise "#{ARCHIVE_MEMBER} missing from #{archive_path}" unless database_path.exist?

      database_path
    end

    private

    def run!(*command)
      system(*command, exception: true)
    end
  end
end
