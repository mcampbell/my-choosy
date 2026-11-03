require "minitest/autorun"
require "tmpdir"

# Never launch Chrome: capture system calls instead.
$calls = []
$system_ok = true
def system(*args) = ($calls << args) && $system_ok

load File.expand_path("../my-choosy", __dir__)

RULES = [
  { "profile" => "Default", "match" => ["Fallback.example"] },
  { "profile" => "Profile 1", "match" => ["github", "atlassian.net"] },
  { "profile" => "Profile 2", "match" => ["github.com/acme", "docs.google"] }
].freeze

GOOD = "- profile: Default\n  match: []\n- profile: Profile 1\n  match: [github]\n"

describe "pick_profile" do
  it "uses the first matching profile in list order" do
    assert_equal "Profile 1", pick_profile(RULES, "https://github.com/acme/repo")
  end

  it "falls back to the first profile when nothing matches" do
    assert_equal "Default", pick_profile(RULES, "https://news.example.org/a")
  end

  # The URL also contains "github", so only a real hit on the first entry gives Default.
  it "lets a fragment in the fallback entry win over later entries" do
    assert_equal "Default", pick_profile(RULES, "https://fallback.example/github")
  end

  it "ignores case in the URL and the fragment" do
    assert_equal "Profile 1", pick_profile(RULES, "https://GitHub.com/x")
    assert_equal "Profile 1", pick_profile([RULES[0], { "profile" => "Profile 1", "match" => ["GITHUB"] }], "https://github.com")
  end

  it "matches a fragment in the path or query" do
    assert_equal "Profile 1", pick_profile(RULES, "https://example.com/go?to=atlassian.net/wiki")
    assert_equal "Profile 2", pick_profile([RULES[0], RULES[2]], "https://example.com/r/docs.google/d/37")
  end
end

describe "web_url?" do
  it "accepts only http and https URLs" do
    assert web_url?("http://a.example")
    assert web_url?("HTTPS://a.example")
  end

  it "rejects other schemes and empty input" do
    ["file:///etc/hosts", "mailto:a@b.example", "javascript:alert(1)", "", nil, "https://"].each do |u|
      refute web_url?(u), u.inspect
    end
  end

  # A raw newline or escape byte would forge or garble log lines.
  it "rejects control characters and broken encoding" do
    ["https://a.example\n2026-01-01T00:00:00+00:00 Profile 9 https://evil.example",
     "https://a.example/\e[2J", "https://a.example/\t",
     "https://a.example/\xFF".dup.force_encoding("UTF-8")].each do |u|
      refute web_url?(u), u.inspect
    end
  end
end

describe "load_config" do
  def cfg(content)
    Dir.mktmpdir { |d| File.write(p = "#{d}/c.yml", content); yield p }
  end

  it "returns the rules from a valid file" do
    cfg("- profile: Default\n  match: []\n- profile: Profile 1\n  match: [github]\n") do |p|
      assert_equal [{ "profile" => "Default", "match" => [] }, { "profile" => "Profile 1", "match" => ["github"] }],
                   load_config(p)
    end
  end

  it "raises when the file is missing" do
    assert_raises(StandardError) { load_config("/nonexistent/c.yml") }
  end

  # Check the message: a NoMethodError from a missed check is also a StandardError.
  def assert_invalid(y)
    cfg(y) { |p| assert_match(/config must be/, assert_raises(RuntimeError, y) { load_config(p) }.message, y) }
  end

  it "raises on a scalar, an empty list, and an entry without a profile" do
    ["just text", "[]", "- match: [a]\n", "- profile: A\n"].each do |y|
      assert_invalid(y)
    end
  end

  it "raises on wrong types" do
    ["- profile: A\n  match: github\n", "- profile: 1\n  match: [a]\n",
     "- profile: A\n  match: [1]\n"].each { |y| assert_invalid(y) }
  end

  it "raises on malformed YAML" do
    cfg("- profile: [A\n") { |p| assert_raises(Psych::SyntaxError) { load_config(p) } }
  end

  it "raises when any one entry is invalid" do
    assert_invalid("- profile: Default\n  match: []\n- profile: B\n  match: github\n")
  end

  # An empty fragment would match every URL; an empty profile gives Chrome a bad flag.
  it "raises on an empty profile or an empty fragment" do
    ["- profile: \"\"\n  match: []\n", "- profile: A\n  match: [\"\"]\n"].each do |y|
      assert_invalid(y)
    end
  end
end

describe "launch_command" do
  it "passes the profile directory to Chrome" do
    assert_equal ["open", "-na", "Google Chrome", "--args", "--profile-directory=Profile 1", "https://a.example"],
                 launch_command("Profile 1", "https://a.example")
  end

  it "adds no profile flag when there is no profile" do
    cmd = launch_command(nil, "https://a.example")
    assert_equal ["open", "-a", "Google Chrome", "https://a.example"], cmd
    refute(cmd.any? { |a| a.include?("--profile-directory") })
  end
end

describe "main" do
  def run_main(url, config, log_name: "logs/my-choosy.log")
    Dir.mktmpdir do |d|
      cp = "#{d}/cfg/config.yml"
      lp = "#{d}/#{log_name}"
      if config
        Dir.mkdir("#{d}/cfg")
        File.write(cp, config)
      end
      calls = $calls.clear
      begin
        main([url], config_path: cp, log_path: lp)
      rescue SystemExit => e
        status = e.status
      end
      log = File.file?(lp) ? File.read(lp) : ""
      yield calls, log, status
    end
  end

  after { $system_ok = true }

  it "launches the chosen profile and logs the dispatch" do
    run_main("https://github.com/acme/r/pull/47", GOOD) do |calls, log, status|
      assert_nil status
      assert_equal [launch_command("Profile 1", "https://github.com/acme/r/pull/47")], calls
      assert_match(/\A\d{4}-\d\d-\d\dT\S+ Profile 1 https:\/\/github.com\/acme\/r\/pull\/47\n\z/, log)
    end
  end

  it "refuses a non-web URL, logs it, and exits non-zero" do
    run_main("file:///etc/passwd", GOOD) do |calls, log, status|
      assert_empty calls
      refute_equal 0, status
      refute_nil status
      assert_match(/ERROR .*file:\/\/\/etc\/passwd/, log)
    end
  end

  it "logs a bad config and still opens the link with no profile" do
    run_main("https://example.com/p?q=89", "just text") do |calls, log, _|
      assert_equal [launch_command(nil, "https://example.com/p?q=89")], calls
      assert_match(/ERROR .* https:\/\/example.com\/p\?q=89\n\z/, log)
    end
  end

  it "logs a failed launch and exits non-zero" do
    $system_ok = nil # what Kernel#system returns when the command cannot run
    run_main("https://github.com/acme/r", GOOD) do |_, log, status|
      refute_nil status
      refute_equal 0, status
      assert_match(/ERROR open failed.* https:\/\/github.com\/acme\/r\n\z/, log)
    end
  end

  # The log path sits under a regular file, so the log write fails.
  it "still opens the link when the log cannot be written" do
    _, err = capture_io do
      run_main("https://github.com/acme/r", GOOD, log_name: "cfg/config.yml/x.log") do |calls, _, status|
        assert_nil status
        assert_equal [launch_command("Profile 1", "https://github.com/acme/r")], calls
      end
    end
    assert_match(/cannot write log/, err)
  end

  it "refuses a missing URL argument" do
    [[], [nil]].each do |argv|
      Dir.mktmpdir do |d|
        $calls.clear
        e = assert_raises(SystemExit) { main(argv, config_path: "#{d}/c.yml", log_path: "#{d}/l.log") }
        refute_equal 0, e.status
        assert_empty $calls
        assert_match(/ERROR not a web URL: nil/, File.read("#{d}/l.log"))
      end
    end
  end

  it "appends one log line for each link" do
    Dir.mktmpdir do |d|
      File.write(cp = "#{d}/c.yml", GOOD)
      main(["https://github.com/a"], config_path: cp, log_path: "#{d}/l.log")
      main(["https://example.com/b"], config_path: cp, log_path: "#{d}/l.log")
      assert_equal ["Profile 1 https://github.com/a", "Default https://example.com/b"],
                   File.readlines("#{d}/l.log", chomp: true).map { |l| l.split(" ", 2).last }
    end
  end

  it "logs a missing config and still opens the link" do
    run_main("https://example.com/", nil) do |calls, log, _|
      assert_equal [launch_command(nil, "https://example.com/")], calls
      assert_match(/ERROR/, log)
    end
  end
end
