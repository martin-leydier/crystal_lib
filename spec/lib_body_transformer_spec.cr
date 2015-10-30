require "./spec_helper"

private def assert_transform(header, input, output, file = __FILE__, line = __LINE__)
  it "transforms #{input.inspect} in #{header.inspect}", file: file, line: line do
    nodes = parse(File.read("#{__DIR__}/headers/#{header}.h"))
    transformer = LibBodyTransformer.new(nodes)

    lib_def = Crystal::Parser.parse(%(
      lib LibSome
        #{input}
      end
    )) as Crystal::LibDef
    lib_def.body = transformer.transform(lib_def.body)
    join_lines(lib_def.to_s).should eq(join_lines("lib LibSome\n#{output}\nend"))
  end
end

private def join_lines(string)
  string.split("\n").map(&.strip).reject(&.empty?).join("\n")
end

describe LibBodyTransformer do
  assert_transform "pcre",
                   "INFO_CAPTURECOUNT = PCRE_INFO_CAPTURECOUNT",
                   "INFO_CAPTURECOUNT = 2"

  assert_transform "pcre",
                   "fun compile = pcre_compile",
                   %(
    type Pcre = Void*
    fun compile = pcre_compile(x0 : LibC::Char*, x1 : LibC::Int, x2 : LibC::Char**, x3 : LibC::Int*, x4 : UInt8*) : Pcre
    )

  # Check that it only declares the Pcre type once
  assert_transform "pcre",
                   %(
    fun compile = pcre_compile
    fun get_stringnumber = pcre_get_stringnumber
    ),
                   %(
    type Pcre = Void*
    fun compile = pcre_compile(x0 : LibC::Char*, x1 : LibC::Int, x2 : LibC::Char**, x3 : LibC::Int*, x4 : UInt8*) : Pcre
    fun get_stringnumber = pcre_get_stringnumber(x0 : Pcre, x1 : LibC::Char*) : LibC::Int
    )

  [
    {"int", "LibC::Int"},
    {"short", "LibC::Short"},
    {"char", "LibC::Char"},
    {"long", "LibC::Long"},
    {"long_long", "LibC::LongLong"},
    {"unsigned_int", "LibC::UInt"},
    {"unsigned_short", "LibC::UShort"},
    {"unsigned_char", "UInt8"},
    {"unsigned_long", "LibC::ULong"},
    {"unsigned_long_long", "LibC::ULongLong"},
    {"signed_char", "LibC::Char"},
    {"float", "LibC::Float"},
    {"double", "LibC::Double"},
    {"long_double", "LibC::LongDouble"},
    {"size_t", "LibC::SizeT"},
  ].each do |pair|
    assert_transform "simple", "fun just_#{pair[0]}", "fun just_#{pair[0]} : #{pair[1]}"
  end

  assert_transform "simple", "fun just_void", "fun just_void"
  assert_transform "simple", "fun function_pointer", "fun function_pointer(x : LibC::Float, LibC::Char -> LibC::Int)"

  assert_transform "simple",
                   "fun function_pointer2",
                   %(
    alias FunPtr = LibC::Float, LibC::Char -> LibC::Int
    fun function_pointer2(x : FunPtr)
    )

  assert_transform "simple", "fun constant_array", "fun constant_array(x : LibC::Int[2])"

  assert_transform "simple", "fun variadic", "fun variadic(x : LibC::Int, ...)"

  assert_transform "simple", "$some_int : Void", "$some_int : LibC::Int"
  assert_transform "simple",
                   "$some_fun_ptr : Void", %(
    alias FunPtr = LibC::Float, LibC::Char -> LibC::Int
    $some_fun_ptr : FunPtr
  )
  assert_transform "simple", "$var = some_int : Void", "$var = some_int : LibC::Int"

  assert_transform "simple",
                   "fun just_opaque_reference", %(
      type OpaqueReference = Void*
      fun just_opaque_reference : OpaqueReference
    )

  assert_transform "simple",
                   "fun just_some_enum_1", %(
      enum SomeEnum1
        X = 0
        Y = 123
      end
      fun just_some_enum_1 : SomeEnum1
    )

  assert_transform "simple",
                   "fun just_some_enum_2", %(
      enum SomeEnum2
        Z = 456
      end
      fun just_some_enum_2 : SomeEnum2
    )

  assert_transform "simple",
                   "fun just_some_enum_3", %(
      enum SomeEnum3
        NodePara = 1
        NodeLink = 2
      end
      fun just_some_enum_3 : SomeEnum3
    )

  assert_transform "simple",
                   "fun just_some_struct_1", %(
      struct SomeStruct1
        x : LibC::Int
      end
      fun just_some_struct_1 : SomeStruct1
    )

  assert_transform "simple",
                   "fun just_some_struct_2", %(
      struct SomeStruct2
        y : LibC::Int
      end
      fun just_some_struct_2 : SomeStruct2
    )

  assert_transform "simple",
                   "fun just_some_union_1", %(
      union SomeUnion1
        x : LibC::Int
      end
      fun just_some_union_1 : SomeUnion1
    )

  assert_transform "simple",
                   "fun just_some_struct_3", %(
      struct SomeStruct3
        x : Void*
      end
      fun just_some_struct_3 : SomeStruct3
    )

  assert_transform "simple",
                   "fun just_some_incomplete_array", %(
      fun just_some_incomplete_array(argv : LibC::Char**)
    )

  assert_transform "simple",
                   "fun just_some_recursive_struct", %(
      struct SomeRecursiveStruct
        x : LibC::Int
        y : SomeRecursiveStruct*
      end
      fun just_some_recursive_struct : SomeRecursiveStruct
    )

  assert_transform "simple",
                   "fun just_some_forwarded_struct", %(
      struct ForwardedStruct
        x : LibC::Int
      end
      type ForwardedStructTypedef = ForwardedStruct
      fun just_some_forwarded_struct(handle : ForwardedStructTypedef*)
    )

  assert_transform "simple",
                   "fun just_some_underscore", %(
      alias X__Underscore = LibC::Int
      fun just_some_underscore : X__Underscore
    )
end
