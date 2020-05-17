class Exporter
  attr_accessor :export_path
  def initialize(export_path)
    @export_path = export_path
  end

  def export!
    FileUtils.mkdir_p(export_path)

    Entry.with_attached_files.find_each do |entry|
      puts "handling #{entry.notebook}/#{entry.identifier}"

      # set up folders
      entry_folder_path = entry.to_folder_path(export_path)
      FileUtils.mkdir_p(entry_folder_path)


      entry_files_path = File.join(entry_folder_path,
                                   "files")

      export_entry!(entry, entry_folder_path)
    end
  end

  def export_entry!(entry, entry_folder_path)
    File.write(File.join(entry_folder_path, entry.to_filename), entry.to_yaml)

    if entry.files.any?
      entry_files_path = File.join(entry_folder_path,
                                   "files")

      FileUtils.mkdir_p(entry_files_path)

      entry.files.each_with_index do |file, i|
        export_blob!(entry, file.blob, entry_files_path, i)
      end
    end
  end

  def export_blob!(entry, blob, entry_files_path, count)
    entry_file_filename = "file-#{count}.yaml"

    entry_file_path = File.join(entry_files_path,
                                entry_file_filename)
    File.write(entry_file_path, blob_attributes(entry, blob))


    puts "entry blob #{blob.id}"
    actual_file_path = File.join(entry_files_path,
                                 blob.filename.to_s)

    File.open(actual_file_path, "wb") do |io|
      io.puts blob.download
    end
  end

  def blob_attributes(entry, blob)
    {
      "notebook" => entry.notebook,
      "entry_identifier" => entry.identifier,
      "key" => blob.key,
      "filename" => blob.filename.to_s,
      "content_type" => blob.content_type,
      "metadata" => blob.metadata,
      "byte_size" => blob.byte_size,
      "checksum" => blob.checksum,
      "created_at" => blob.created_at
    }.to_yaml
  end
end