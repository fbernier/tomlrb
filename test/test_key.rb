require 'minitest_helper'

describe 'table and key redefinition' do
  it 'can define a super-table afterward' do
    _(Tomlrb.parse("[x.y.z.w]\n[x]\n")).must_equal({"x"=>{"y"=>{"z"=>{"w"=>{}}}}})
  end

  it 'cannot define a table more than once' do
    _{ Tomlrb.parse("[fruit]\napple = 1\n[fruit]\n") }.must_raise Tomlrb::ParseError
  end

  it 'cannot define a table over a pair key' do
    _{ Tomlrb.parse("[fruit]\napple = 1\n[fruit.apple]\n") }.must_raise Tomlrb::ParseError
  end

  it 'can define tables out of order' do
    _(Tomlrb.parse("[fruit.apple]\n[animal]\n[fruit.orange]\n")).must_equal(
      {"fruit"=>{"apple"=>{}, "orange"=>{}}, "animal"=>{}}
    )
  end

  it 'can define sub-tables within tables defined via dotted keys' do
    toml = "[fruit]\napple.color = 'red'\napple.taste.sweet = true\n[fruit.apple.texture]\nsmooth = true\n"
    _(Tomlrb.parse(toml)).must_equal(
      {"fruit"=>{"apple"=>{"color"=>"red", "taste"=>{"sweet"=>true}, "texture"=>{"smooth"=>true}}}}
    )
  end

  it 'cannot define a table already defined via dotted keys' do
    toml = "[fruit]\napple.color = 'red'\napple.taste.sweet = true\n"
    _{ Tomlrb.parse(toml + "[fruit.apple]\n") }.must_raise Tomlrb::ParseError
    _{ Tomlrb.parse(toml + "[fruit.apple.taste]\n") }.must_raise Tomlrb::ParseError
  end

  it 'cannot extend a header-defined table with dotted keys from its parent' do
    _{ Tomlrb.parse("[a.b]\nx = 1\n[a]\nb.y = 2\n") }.must_raise Tomlrb::ParseError
  end

  it 'cannot extend an inline table' do
    _{ Tomlrb.parse("a = {b = 1}\na.c = 2\n") }.must_raise Tomlrb::ParseError
    _{ Tomlrb.parse("a = {b = 1}\n[a.c]\n") }.must_raise Tomlrb::ParseError
  end

  it 'cannot turn a static array into an array of tables' do
    _{ Tomlrb.parse("a = []\n[[a]]\n") }.must_raise Tomlrb::ParseError
  end

  it 'appends sub-tables to the latest array of tables element' do
    toml = "[[a]]\nx = 1\n[a.b]\ny = 2\n[[a]]\nx = 3\n[a.b]\ny = 4\n"
    _(Tomlrb.parse(toml)).must_equal({"a"=>[{"x"=>1, "b"=>{"y"=>2}}, {"x"=>3, "b"=>{"y"=>4}}]})
  end
end
