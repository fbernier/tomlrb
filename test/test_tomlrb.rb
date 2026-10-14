# frozen_string_literal: true

require_relative "test_helper"

describe Tomlrb do
  it "parses a toml v0.4.0 file" do
    parsed_file = Tomlrb.load_file(File.join(__dir__, "example-v0.4.0.toml"))
    _(parsed_file).must_equal TomlExamples.example_v_0_4_0
  end

  it "parses a Cargo file" do
    parsed_file = Tomlrb.load_file(File.join(__dir__, "Cargo.toml"))
    _(parsed_file).must_equal TomlExamples.cargo_example
  end

  it "does not fail with a false table value (GitHub issue #23)" do
    _(Tomlrb.parse("table=[ {name='name1', visible=true}, {name='name2', visible=false} ]"))
      .must_equal({"table" => [{"name" => "name1", "visible" => true}, {"name" => "name2", "visible" => false}]})
  end

  it "symbolizes keys in a inline table if symbolize_keys: true" do
    _(Tomlrb.parse("table={a=1, b=2}", symbolize_keys: true))
      .must_equal({table: {a: 1, b: 2}})
  end

  it "rejects an unterminated basic string full of escapes without catastrophic backtracking" do
    Timeout.timeout(5) do
      _ { Tomlrb.parse("a = \"" + "\\a" * 10_000) }.must_raise(Tomlrb::ParseError)
    end
  end

  it "rejects an unterminated literal string full of backslashes without catastrophic backtracking" do
    Timeout.timeout(5) do
      _ { Tomlrb.parse("a = '" + "\\" * 10_000) }.must_raise(Tomlrb::ParseError)
    end
  end

  it "does not treat a backslash as an escape in literal strings" do
    _ { Tomlrb.parse(%q(a = 'x\'y')) }.must_raise(Tomlrb::ParseError)
  end

  it "parses a long run of whitespace without recursing per character" do
    Timeout.timeout(5) do
      _(Tomlrb.parse(" \t" * 100_000)).must_equal({})
    end
  end

  it "rejects spaced array of tables brackets regardless of indentation, line endings or preceding text" do
    _ { Tomlrb.parse("  [ [a]]\n") }.must_raise(Tomlrb::ParseError)
    _ { Tomlrb.parse("[[a] ]\r\n") }.must_raise(Tomlrb::ParseError)
    _ { Tomlrb.parse("x = \"ééé\"\n[ [a] ]\n") }.must_raise(Tomlrb::ParseError)
  end

  it "parses a multiline array whose line starts with a spaced nested array" do
    _(Tomlrb.parse("a = [\n[ [1, 2]]\n]\n")).must_equal({"a" => [[[1, 2]]]})
  end

  it "parses bare keys that start with a boolean or float keyword" do
    toml = "trueval = 1\nfalse_alarm = 2\ninf-x = 3\n[nan-table]\ntrue-ish = true\n"
    _(Tomlrb.parse(toml)).must_equal({"trueval" => 1, "false_alarm" => 2, "inf-x" => 3, "nan-table" => {"true-ish" => true}})
  end

  it "parses bare keys that look like dates or numbers" do
    _(Tomlrb.parse("1979-05-27a = 1\n0x1f = 2\n[[1e5]]\n")).must_equal({"1979-05-27a" => 1, "0x1f" => 2, "1e5" => [{}]})
    _ { Tomlrb.parse("07:32:00 = 1\n") }.must_raise(Tomlrb::ParseError)
  end

  it "requires a value in inline tables" do
    _ { Tomlrb.parse("a = {b = }\n") }.must_raise(Tomlrb::ParseError)
    _ { Tomlrb.parse("a = [{b = 1}, {c = }]\n") }.must_raise(Tomlrb::ParseError)
  end

  it "rejects an inline table that is not assigned to a key" do
    _ { Tomlrb.parse("{a = 1}\n") }.must_raise(Tomlrb::ParseError)
  end

  it "allows newlines inside arrays, and in TOML 1.0 not directly inside inline tables" do
    _(Tomlrb.parse("a = {b = [1,\n# c\n2]}\n", version: "1.0")).must_equal({"a" => {"b" => [1, 2]}})
    _ { Tomlrb.parse("a = {b = 1,\nc = 2}\n", version: "1.0") }.must_raise(Tomlrb::ParseError)
  end

  it "parses deeply nested inline tables and arrays in linear time" do
    Timeout.timeout(5) do
      parsed = Tomlrb.parse("a = " + "[{b=" * 50_000 + "1" + "}]" * 50_000)
      _(parsed["a"][0]["b"][0]["b"]).must_be_kind_of(Array)
    end
  end

  it "parses nesting far deeper than the VM stack allows for recursion" do
    parsed = Tomlrb.parse("a = " + "[" * 200_000 + "]" * 200_000)
    _(parsed["a"].flatten).must_equal([])
  end

  it "rejects a whitespace run followed by junk inside an array in linear time" do
    Timeout.timeout(5) do
      _ { Tomlrb.parse("a = [\"a\"" + " " * 1_000_000 + "x]") }.must_raise(Tomlrb::ParseError)
    end
  end

  it "trims a CRLF right after the opening delimiter of multi-line strings" do
    _(Tomlrb.parse("a = \"\"\"\r\nx\"\"\"\nb = '''\r\ny'''\n")).must_equal({"a" => "x", "b" => "y"})
  end

  it "rejects a carriage return without line feed" do
    _ { Tomlrb.parse("a = \"\"\"x\ry\"\"\"\n") }.must_raise(Tomlrb::ParseError)
    _ { Tomlrb.parse("a = '''x\ry'''\n") }.must_raise(Tomlrb::ParseError)
    _ { Tomlrb.parse("a = 1\r") }.must_raise(Tomlrb::ParseError)
  end

  it "rejects control characters in comments" do
    _ { Tomlrb.parse("# a\n# b \x01\na = 1\n") }.must_raise(Tomlrb::ParseError)
  end

  it "only separates date and time with T or a space" do
    _ { Tomlrb.parse("a = 1979-05-27\n07:32:00\n") }.must_raise(Tomlrb::ParseError)
    _ { Tomlrb.parse("a = 1979-05-27\t07:32:00\n") }.must_raise(Tomlrb::ParseError)
    _(Tomlrb.parse("a = 1979-05-27 07:32:00\n")["a"]).must_equal(Tomlrb::LocalDateTime.new(1979, 5, 27, 7, 32, 0.0))
  end

  it "rejects calendar dates that do not exist" do
    _ { Tomlrb.parse("a = 1979-06-31T05:43:47-00:00\n") }.must_raise(ArgumentError)
    _ { Tomlrb.parse("a = 2100-02-29\n") }.must_raise(ArgumentError)
    _(Tomlrb.parse("a = 2000-02-29\n")["a"].to_s).must_equal("2000-02-29")
  end

  it "decodes escapes in single-line and multi-line basic strings" do
    toml = %(a = "t\\tq\\"\\u00e9\\U0001F600\\\\"\nb = """x \\\n   y \\"""\nc"""\n)
    _(Tomlrb.parse(toml)).must_equal({"a" => "t\tq\"é😀\\", "b" => "x y \"\"\"\nc"})
    _ { Tomlrb.parse(%(a = "\\q"\n)) }.must_raise(Tomlrb::ParseError)
    _(Tomlrb.parse(%(a = """x\\\\"""\n))).must_equal({"a" => "x\\"})
  end

  it "reports the line and column of a syntax error" do
    error = _ { Tomlrb.parse("a = 1\nb = ?\n") }.must_raise(Tomlrb::ParseError)
    _(error.message).must_match(/line 2, column 5/)
  end

  it "counts error columns in characters after multi-byte text" do
    error = _ { Tomlrb.parse(%(s = "🍒"\nx = ?\n)) }.must_raise(Tomlrb::ParseError)
    _(error.message).must_match(/line 2, column 5\z/)
    error = _ { Tomlrb.parse(%(s = "é\\q"\n)) }.must_raise(Tomlrb::ParseError)
    _(error.message).must_match(/line 1, column 7\z/)
  end
end

describe "TOML versions" do
  {
    "\\e and \\xHH escapes" => [%(s = "\\e[\\x41\\x00"\n), {"s" => "\e[A\u0000"}],
    "times without seconds" => ["t = 07:32\nd = 1979-05-27T07:32Z\nl = 1979-05-27 07:32\n",
      {"t" => Tomlrb::LocalTime.new(7, 32, 0), "d" => Time.new(1979, 5, 27, 7, 32, 0, "+00:00"),
       "l" => Tomlrb::LocalDateTime.new(1979, 5, 27, 7, 32, 0)}],
    "inline tables over several lines, with comments and a trailing comma" =>
      ["t = {\n  a = 1, # one\n  b = { c = [2,\n3], },\n}\n", {"t" => {"a" => 1, "b" => {"c" => [2, 3]}}}]
  }.each do |feature, (toml, expected)|
    it "parses #{feature} by default, as TOML 1.1" do
      _(Tomlrb.parse(toml)).must_equal expected
    end

    it "rejects #{feature} with version: \"1.0\"" do
      _ { Tomlrb.parse(toml, version: "1.0") }.must_raise Tomlrb::ParseError
    end
  end

  it "still rejects what 1.1 does not allow in inline tables and times" do
    _ { Tomlrb.parse("t = {,}\n") }.must_raise Tomlrb::ParseError
    _ { Tomlrb.parse("t = {a = 1,,}\n") }.must_raise Tomlrb::ParseError
    _ { Tomlrb.parse("t = {a\n= 1}\n") }.must_raise Tomlrb::ParseError
    _ { Tomlrb.parse("t = 07:32.5\n") }.must_raise Tomlrb::ParseError
  end

  it "only knows versions 1.0 and 1.1" do
    _ { Tomlrb.parse("a = 1", version: "1.1.0") }.must_raise ArgumentError
    _ { Tomlrb.parse("a = 1", version: 1.1) }.must_raise ArgumentError
  end
end

class TomlExamples
  def self.example_v_0_4_0
    {"table" => {"key" => "value", "subtable" => {"key" => "another value"}, "inline" => {"name" => {"first" => "Tom", "last" => "Preston-Werner"}, "point" => {"x" => 1, "y" => 2}}},
     "x" => {"y" => {"z" => {"w" => {}}}},
     "1" => {"2" => {}, "2a" => {}},
     "a" => {"2" => {}},
     "2" => {"b" => {}},
     "string" =>
    {"basic" => {"basic" => "I'm a string. \"You can quote me\". Name\tJosé\nLocation\tSF."},
     "multiline" =>
    {"key1" => "One\nTwo",
     "key2" => "One\nTwo",
     "key3" => "One\nTwo",
     "continued" =>
    {"key1" => "The quick brown fox jumps over the lazy dog.",
     "key2" => "The quick brown fox jumps over the lazy dog.",
     "key3" => "The quick brown fox jumps over the lazy dog."}},
     "literal" =>
    {"winpath" => "C:\\Users\\nodejs\\templates",
     "winpath2" => "\\\\ServerX\\admin$\\system32\\",
     "quoted" => "Tom \"Dubs\" Preston-Werner",
     "regex" => "<\\i\\c*\\s*>",
     "multiline" => {"regex2" => "I [dw]on't need \\d{2} apples", "lines" => "The first newline is\ntrimmed in raw strings.\n   All other whitespace\n   is preserved.\n"}}},
     "integer" => {"key1" => 99, "key2" => 42, "key3" => 0, "key4" => -17, "underscores" => {"key1" => 1000, "key2" => 5349221, "key3" => 12345}},
     "float" =>
    {"fractional" => {"key1" => 1.0, "key2" => 3.1415, "key3" => -0.01},
     "exponent" => {"key1" => 5.0e+22, "key2" => 1000000.0, "key3" => -0.02},
     "both" => {"key" => 6.626e-34},
     "underscores" => {"key1" => 9224617.445991227, "key2" => 1e1_0_0}},
     "boolean" => {"True" => true, "False" => false},
     "datetime" => {"key1" => Time.utc(1979, 5, 27, 7, 32, 0), "key2" => Time.new(1979, 5, 27, 0, 32, 0, "-07:00"), "key3" => Time.new(1979, 5, 27, 0, 32, 0.999999r, "-07:00"), "key4" => Tomlrb::LocalDateTime.new(1979, 5, 27, 0, 32, 0.0), "key5" => Tomlrb::LocalDate.new(1979, 5, 27)}, "array" => {"key1" => [1, 2, 3], "key2" => ["red", "yellow", "green"], "key3" => [[1, 2], [3, 4, 5]], "key4" => [[1, 2], ["a", "b", "c"]], "key5" => [1, 2, 3], "key6" => [1, 2]},
     "products" => [{"name" => "Hammer", "sku" => 738594937}, {}, {"name" => "Nail", "sku" => 284758393, "color" => "gray"}],
     "fruit" =>
    [{"name" => "apple", "physical" => {"color" => "red", "shape" => "round"}, "variety" => [{"name" => "red delicious"}, {"name" => "granny smith"}]},
      {"name" => "banana", "variety" => [{"name" => "plantain"}]}]}
  end

  def self.cargo_example
    {"package" => {"name" => "uutils", "version" => "0.0.1", "authors" => [], "build" => "build.rs"}, "features" => {"unix" => ["arch", "chmod", "chown", "chroot", "du", "groups", "hostid", "hostname", "id", "install", "kill", "logname", "mkfifo", "mknod", "mv", "nice", "nohup", "pathchk", "pinky", "stat", "stdbuf", "timeout", "touch", "tty", "uname", "unlink", "uptime", "users"], "generic" => ["base64", "basename", "cat", "cksum", "comm", "cp", "cut", "dircolors", "dirname", "echo", "env", "expand", "expr", "factor", "false", "fmt", "fold", "hashsum", "head", "link", "ln", "ls", "mkdir", "mktemp", "nl", "nproc", "od", "paste", "printenv", "printf", "ptx", "pwd", "readlink", "realpath", "relpath", "rm", "rmdir", "seq", "shred", "shuf", "sleep", "sort", "split", "sum", "sync", "tac", "tail", "tee", "test", "tr", "true", "truncate", "tsort", "unexpand", "uniq", "wc", "whoami", "yes"], "test_unimplemented" => [], "nightly" => [], "default" => ["generic", "unix"]}, "dependencies" => {"uucore" => {"path" => "src/uucore"}, "arch" => {"optional" => true, "path" => "src/arch"}, "base64" => {"optional" => true, "path" => "src/base64"}, "basename" => {"optional" => true, "path" => "src/basename"}, "cat" => {"optional" => true, "path" => "src/cat"}, "chmod" => {"optional" => true, "path" => "src/chmod"}, "chown" => {"optional" => true, "path" => "src/chown"}, "chroot" => {"optional" => true, "path" => "src/chroot"}, "cksum" => {"optional" => true, "path" => "src/cksum"}, "comm" => {"optional" => true, "path" => "src/comm"}, "cp" => {"optional" => true, "path" => "src/cp"}, "cut" => {"optional" => true, "path" => "src/cut"}, "dircolors" => {"optional" => true, "path" => "src/dircolors"}, "dirname" => {"optional" => true, "path" => "src/dirname"}, "du" => {"optional" => true, "path" => "src/du"}, "echo" => {"optional" => true, "path" => "src/echo"}, "env" => {"optional" => true, "path" => "src/env"}, "expand" => {"optional" => true, "path" => "src/expand"}, "expr" => {"optional" => true, "path" => "src/expr"}, "factor" => {"optional" => true, "path" => "src/factor"}, "false" => {"optional" => true, "path" => "src/false"}, "fmt" => {"optional" => true, "path" => "src/fmt"}, "fold" => {"optional" => true, "path" => "src/fold"}, "groups" => {"optional" => true, "path" => "src/groups"}, "hashsum" => {"optional" => true, "path" => "src/hashsum"}, "head" => {"optional" => true, "path" => "src/head"}, "hostid" => {"optional" => true, "path" => "src/hostid"}, "hostname" => {"optional" => true, "path" => "src/hostname"}, "id" => {"optional" => true, "path" => "src/id"}, "install" => {"optional" => true, "path" => "src/install"}, "kill" => {"optional" => true, "path" => "src/kill"}, "link" => {"optional" => true, "path" => "src/link"}, "ln" => {"optional" => true, "path" => "src/ln"}, "ls" => {"optional" => true, "path" => "src/ls"}, "logname" => {"optional" => true, "path" => "src/logname"}, "mkdir" => {"optional" => true, "path" => "src/mkdir"}, "mkfifo" => {"optional" => true, "path" => "src/mkfifo"}, "mknod" => {"optional" => true, "path" => "src/mknod"}, "mktemp" => {"optional" => true, "path" => "src/mktemp"}, "mv" => {"optional" => true, "path" => "src/mv"}, "nice" => {"optional" => true, "path" => "src/nice"}, "nl" => {"optional" => true, "path" => "src/nl"}, "nohup" => {"optional" => true, "path" => "src/nohup"}, "nproc" => {"optional" => true, "path" => "src/nproc"}, "od" => {"optional" => true, "path" => "src/od"}, "paste" => {"optional" => true, "path" => "src/paste"}, "pathchk" => {"optional" => true, "path" => "src/pathchk"}, "pinky" => {"optional" => true, "path" => "src/pinky"}, "printenv" => {"optional" => true, "path" => "src/printenv"}, "printf" => {"optional" => true, "path" => "src/printf"}, "ptx" => {"optional" => true, "path" => "src/ptx"}, "pwd" => {"optional" => true, "path" => "src/pwd"}, "readlink" => {"optional" => true, "path" => "src/readlink"}, "realpath" => {"optional" => true, "path" => "src/realpath"}, "relpath" => {"optional" => true, "path" => "src/relpath"}, "rm" => {"optional" => true, "path" => "src/rm"}, "rmdir" => {"optional" => true, "path" => "src/rmdir"}, "seq" => {"optional" => true, "path" => "src/seq"}, "shred" => {"optional" => true, "path" => "src/shred"}, "shuf" => {"optional" => true, "path" => "src/shuf"}, "sleep" => {"optional" => true, "path" => "src/sleep"}, "sort" => {"optional" => true, "path" => "src/sort"}, "split" => {"optional" => true, "path" => "src/split"}, "stat" => {"optional" => true, "path" => "src/stat"}, "stdbuf" => {"optional" => true, "path" => "src/stdbuf"}, "sum" => {"optional" => true, "path" => "src/sum"}, "sync" => {"optional" => true, "path" => "src/sync"}, "tac" => {"optional" => true, "path" => "src/tac"}, "tail" => {"optional" => true, "path" => "src/tail"}, "tee" => {"optional" => true, "path" => "src/tee"}, "test" => {"optional" => true, "path" => "src/test"}, "timeout" => {"optional" => true, "path" => "src/timeout"}, "touch" => {"optional" => true, "path" => "src/touch"}, "tr" => {"optional" => true, "path" => "src/tr"}, "true" => {"optional" => true, "path" => "src/true"}, "truncate" => {"optional" => true, "path" => "src/truncate"}, "tsort" => {"optional" => true, "path" => "src/tsort"}, "tty" => {"optional" => true, "path" => "src/tty"}, "uname" => {"optional" => true, "path" => "src/uname"}, "unexpand" => {"optional" => true, "path" => "src/unexpand"}, "uniq" => {"optional" => true, "path" => "src/uniq"}, "unlink" => {"optional" => true, "path" => "src/unlink"}, "uptime" => {"optional" => true, "path" => "src/uptime"}, "users" => {"optional" => true, "path" => "src/users"}, "wc" => {"optional" => true, "path" => "src/wc"}, "whoami" => {"optional" => true, "path" => "src/whoami"}, "yes" => {"optional" => true, "path" => "src/yes"}}, "dev-dependencies" => {"time" => "*", "kernel32-sys" => "*", "winapi" => "*", "filetime" => "*", "libc" => "*", "memchr" => "*", "primal" => "*", "aho-corasick" => "*", "regex-syntax" => "*", "regex" => "*", "rand" => "*", "tempdir" => "*"}, "bin" => [{"name" => "uutils", "path" => "src/uutils/uutils.rs"}], "test" => [{"name" => "tests"}]}
  end
end
