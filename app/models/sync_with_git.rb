# Every notebook gets stored locally in our git repo, which is handled by this
# class. SyncWithGit, given a notebook and optionally an entry, will write its
# contents into the local git repo and push them or pull them as appropriate.
#
# At present, it also acts as a thin presenter to the GitAdapter.
#
# It is the responsibility of the methods calling this class to check
# and see if !Rails.application.config.skip_local_sync is true
class SyncWithGit
  attr_reader :arquivo_path, :notebook, :notebook_path, :git_adapter

  def initialize(notebook, arquivo_path = nil)
    @notebook = notebook
    @notebook_path = @notebook.to_folder_path(arquivo_path)
    @arquivo_path = arquivo_path || File.dirname(@notebook_path)

    @git_adapter = GitAdapter.new(@arquivo_path)
  end

  # We need to "init" a repo and set up the appropriate git attributes
  # and custom merge driver in order to resolve conflicts appropriately.
  # TODO: Document this elsewhere? And more appropriately.
  def init!
    git_adapter.with_lock do
      repo = git_adapter.open_repo(notebook.to_folder_path(arquivo_path))

      FileUtils.cp(File.join(Rails.root, "lib", "assets", "git_defaults", ".gitattributes"), notebook_path)
      FileUtils.cp_r(File.join(Rails.root, "lib", "assets", "git_defaults", "script"), notebook_path)
      setup_git_config(repo)

      git_adapter.add_and_commit!(repo, notebook_path, "initialized repo with default settings")
    end
  end

  def setup_git_config(repo)
    repo.config("merge.newest-wins.name", "newest-wins")
    repo.config("merge.newest-wins.driver", "script/newest-wins.rb %O %A %B")
    repo.config("merge.newest-wins.recursive", "text")
  end

  def sync_entry!(entry)
    raise "wtf" if notebook != entry.parent_notebook

    git_adapter.with_lock do
      exporter = SyncToDisk.new(notebook, arquivo_path)
      entry_folder_path = exporter.export_entry!(entry)

      repo = git_adapter.open_repo(notebook.to_folder_path(arquivo_path))
      git_adapter.add_and_commit!(repo, entry_folder_path, entry.identifier)
    end
  end

  def sync!(msg_suffix = nil)
    git_adapter.with_lock do
      exporter = SyncToDisk.new(notebook, arquivo_path)
      exporter.export!

      if msg_suffix
        commit_msg = "import from #{msg_suffix}"
      else
        commit_msg = "#{notebook} notebook import"
      end

      repo = git_adapter.open_repo(notebook.to_folder_path(arquivo_path))
      git_adapter.add_and_commit!(repo, notebook.to_folder_path(arquivo_path), commit_msg)
    end
  end

  def entry_log(entry)
    if !File.exist?(notebook.to_folder_path(arquivo_path))
      return []
    else
      repo = git_adapter.open_repo(notebook.to_folder_path(arquivo_path))
      full_file_path = entry.to_full_file_path(arquivo_path)

      if File.exist?(full_file_path)
        repo.log.path(full_file_path).map { |c| [c.sha, c.date] }
      else
        []
      end
    end
  end

  def get_revision(entry, sha)
    repo = git_adapter.open_repo(notebook.to_folder_path(arquivo_path))
    full_file_path = entry.to_full_file_path(arquivo_path)

    if File.exist?(full_file_path)
      repo.object("#{sha}:#{entry.to_relative_file_path}").contents
    else
      nil
    end
  end

  # -- experimental
  def push!
    git_adapter.with_lock do
      rejected = false
      begin
        repo = git_adapter.open_repo(notebook.to_folder_path(arquivo_path))
        repo.push
      rescue Git::GitExecuteError => e
        rejected = e.message.lines.select {|s| s =~ /\[rejected\]\.*\(fetch first\)/}.any?
      end

      if rejected
        # yeah that's right, then what huh???
        binding.pry
      end
    end
  end

  def pull!
    result = nil
    begin
      repo = git_adapter.open_repo(notebook_path)
      setup_git_config(repo)
      result = repo.pull

      case result
      # when /Updating.*\nFast-forward/
      #   puts "ffwd"
      when /Already up to date\./
        puts "do nothing, hooray!"
      else
        SyncFromDisk.new(notebook_path).import!
      end

    rescue Git::GitExecuteError => e
      binding.pry
    end
    result
  end
  # -- end experimental
end
