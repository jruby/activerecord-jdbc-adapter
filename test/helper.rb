module Kernel
  def find_executable?(name)
    ENV['PATH'].split(File::PATH_SEPARATOR).detect {|p| File.executable?(File.join(p, name))}
  end
end
