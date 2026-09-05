namespace :banking do
  desc "Extract the bundled dataset (db/data/bank_sqlite.db.tar.xz) into tmp/banking, or download it from Kaggle"
  task download: :environment do
    path = Banking::Dataset.new.download
    puts "dataset database at #{path}"
  end

  desc "Import the dataset into the app database (SOURCE=path/to/bank_sqlite.db overrides the default)"
  task import: :environment do
    counts = Banking::Importer.new(ENV["SOURCE"]).call
    counts.each { |table, count| puts format("%-13s %10d", table, count) }
  end

  desc "Extract and import the dataset (skips the import when the tables are already filled; FORCE=1 reimports)"
  task setup: :environment do
    Rake::Task["banking:download"].invoke
    if Customer.none? || ENV["FORCE"].present?
      Rake::Task["banking:import"].invoke
    else
      puts "dataset already imported (#{Customer.count} customers); FORCE=1 reimports"
    end
  end

  desc "Row counts per dataset table"
  task stats: :environment do
    Banking::Importer.new.counts.each { |table, count| puts format("%-13s %10d", table, count) }
  end
end
