namespace :getty do
  desc "Import Getty URLs from a text file: rails getty:import[urls.txt]"
  task :import, [:path] => :environment do |_, args|
    created, dupes, bad = GettyAsset.import_urls(File.read(args[:path]))
    puts "Queued #{created.size}, skipped #{dupes.size} duplicates, #{bad.size} unparseable"
    bad.each { puts "  ? #{_1}" }
  end

  desc "Export fetched assets to CSV: rails getty:export[out.csv]"
  task :export, [:path] => :environment do |_, args|
    path = args[:path] || "getty-metadata-#{Date.current}.csv"
    File.write(path, GettyAsset.to_csv(GettyAsset.done.order(:created_at)))
    puts "Wrote #{GettyAsset.done.count} rows to #{path}"
  end
end
