require "fileutils"

module Banking
  # Provides the synthetic banking dataset's SQLite database under
  # tmp/banking. The repository ships it as db/data/bank_sqlite.db.tar.xz
  # (Kaggle: akrambelha/synthetic-banking-dataset, CC BY 4.0); when that
  # archive is missing, the public Kaggle download endpoint is the fallback.
  class Dataset
    SLUG = "akrambelha/synthetic-banking-dataset-csv-sql-sqlite"
    URL = "https://www.kaggle.com/api/v1/datasets/download/#{SLUG}".freeze
    ARCHIVE_MEMBER = "banking_dataset_kaggle/data/database/bank_sqlite.db"
    BUNDLED_ARCHIVE = Rails.root.join("db/data/bank_sqlite.db.tar.xz")

    attr_reader :dir

    def initialize(dir: Rails.root.join("tmp/banking"))
      @dir = Pathname(dir)
    end

    def database_path
      dir.join("bank_sqlite.db")
    end

    def kaggle_archive_path
      dir.join("banking.zip")
    end

    # Extracts the bundled archive (or downloads from Kaggle when the bundle
    # is absent) and returns the database path. Idempotent: an extracted
    # database is reused unless `force:`.
    def download(force: false)
      FileUtils.mkdir_p(dir)
      return database_path if database_path.exist? && !force

      if BUNDLED_ARCHIVE.exist?
        extract_bundled
      else
        download_from_kaggle
      end
      raise "no database at #{database_path} after extraction" unless database_path.exist?

      database_path
    end

    private

    # tar reads xz natively on macOS (bsdtar) and on Linux with xz installed.
    def extract_bundled
      run!("tar", "-xJf", BUNDLED_ARCHIVE.to_s, "-C", dir.to_s)
    end

    def download_from_kaggle
      unless kaggle_archive_path.exist?
        run!("curl", "--fail", "--location", "--silent", "--show-error", "--output", kaggle_archive_path.to_s, URL)
      end
      run!("unzip", "-o", "-j", kaggle_archive_path.to_s, ARCHIVE_MEMBER, "-d", dir.to_s)
    end

    def run!(*command)
      system(*command, exception: true)
    end
  end
end
