# Homebrew formula for obot
# To install: brew install --build-from-source obot.rb

class Obot < Formula
  desc "Local AI-powered code fixer CLI"
  homepage "https://github.com/cadenroberts/OllamaBot"
  url "https://github.com/cadenroberts/OllamaBot/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "REPLACE_WITH_ACTUAL_SHA256"
  license "MIT"
  head "https://github.com/cadenroberts/OllamaBot.git", branch: "main"

  depends_on "go" => :build

  def install
    ldflags = "-s -w -X main.Version=#{version} -X main.Commit=homebrew -X main.Date=#{Time.now.utc.iso8601} -X main.BuiltBy=homebrew"
    system "go", "build", *std_go_args(ldflags: ldflags), "./cmd/obot"
  end

  def caveats
    <<~EOS
      obot requires Ollama to be running.
      
      Start Ollama:
        ollama serve

      Pull a coder model (for 32GB RAM):
        ollama pull qwen2.5-coder:32b

      Or for 16GB RAM:
        ollama pull deepseek-coder:6.7b
    EOS
  end

  test do
    # Test version output
    assert_match "obot version", shell_output("#{bin}/obot --version")
    
    # Test help output
    assert_match "Local AI-powered code fixer", shell_output("#{bin}/obot --help")
  end
end
