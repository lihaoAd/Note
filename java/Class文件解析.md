 

`./hotspot/share/classfile/classFileParser.cpp/`



`````
void ClassFileParser::parse_stream(const ClassFileStream* const stream, TRAPS) {


  //1. magic, major, minor
  // BEGIN STREAM PARSING
  // 看看这个流里面还有没有8字节的数据，因为magic, major, minor三个加起来就是8字节
  stream->guarantee_more(8, CHECK);  // magic, major, minor
  const u4 magic = stream->get_u4_fast(); // 获取魔数
  // 0xCAFEBABE
  guarantee_property(magic == JAVA_CLASSFILE_MAGIC,  
                     "Incompatible magic value %u in class file %s",
                     magic, CHECK);


  // 2. Version numbers
  _minor_version = stream->get_u2_fast();
  _major_version = stream->get_u2_fast();
  ...

  // Check version numbers - we check this even with verifier off
  verify_class_version(_major_version, _minor_version, _class_name, CHECK);



  // 3.常量池项数量与解析常量池
  stream->guarantee_more(3, CHECK); // length, first cp tag
  u2 cp_size = stream->get_u2_fast(); // 数量

  guarantee_property(
    cp_size >= 1, "Illegal constant pool size %u in class file %s",
    cp_size, CHECK);

  _orig_cp_size = cp_size;
  if (int(cp_size) + _max_num_patched_klasses > 0xffff) {
    THROW_MSG(vmSymbols::java_lang_InternalError(), "not enough space for patched classes");
  }
  cp_size += _max_num_patched_klasses;
  // 分配常量池空间
  _cp = ConstantPool::allocate(_loader_data,cp_size,CHECK);
  ConstantPool* const cp = _cp;
  // 解析擦常量池
  parse_constant_pool(stream, cp, _orig_cp_size, CHECK);

  ...

  // 4. 类的访问标识 ACCESS FLAGS
  stream->guarantee_more(8, CHECK);  // flags, this_class, super_class, infs_len
  // Access flags
  jint flags;
  // JVM_ACC_MODULE is defined in JDK-9 and later.
  if (_major_version >= JAVA_9_VERSION) {
    flags = stream->get_u2_fast() & (JVM_RECOGNIZED_CLASS_MODIFIERS | JVM_ACC_MODULE);
  } else {
    flags = stream->get_u2_fast() & JVM_RECOGNIZED_CLASS_MODIFIERS;
  }

  if ((flags & JVM_ACC_INTERFACE) && _major_version < JAVA_6_VERSION) {
    // Set abstract bit for old class files for backward compatibility
    flags |= JVM_ACC_ABSTRACT;
  }

  verify_legal_class_modifiers(flags, CHECK);

  short bad_constant = class_bad_constant_seen();
  if (bad_constant != 0) {
    // Do not throw CFE until after the access_flags are checked because if
    // ACC_MODULE is set in the access flags, then NCDFE must be thrown, not CFE.
    classfile_parse_error("Unknown constant tag %u in class file %s", bad_constant, CHECK);
  }
  _access_flags.set_flags(flags);




  // 4. This class and superclass，这是一个索引，到常量池里找
  _this_class_index = stream->get_u2_fast();
  check_property(
    valid_cp_range(_this_class_index, cp_size) &&
      cp->tag_at(_this_class_index).is_unresolved_klass(),
    "Invalid this class index %u in constant pool in class file %s",
    _this_class_index, CHECK);

  Symbol* const class_name_in_cp = cp->klass_name_at(_this_class_index);
  assert(class_name_in_cp != NULL, "class_name can't be null");

  // Update _class_name to reflect the name in the constant pool
  update_class_name(class_name_in_cp);

  // Don't need to check whether this class name is legal or not.
  // It has been checked when constant pool is parsed.
  // However, make sure it is not an array type.
  if (_need_verify) {
    guarantee_property(_class_name->char_at(0) != JVM_SIGNATURE_ARRAY,
                       "Bad class name in class file %s",
                       CHECK);
  }

  // Checks if name in class file matches requested name
  if (_requested_name != NULL && _requested_name != _class_name) {
    ResourceMark rm(THREAD);
    Exceptions::fthrow(
      THREAD_AND_LOCATION,
      vmSymbols::java_lang_NoClassDefFoundError(),
      "%s (wrong name: %s)",
      _class_name->as_C_string(),
      _requested_name != NULL ? _requested_name->as_C_string() : "NoName"
    );
    return;
  }

  // if this is an anonymous class fix up its name if it's in the unnamed
  // package.  Otherwise, throw IAE if it is in a different package than
  // its host class.
  if (_unsafe_anonymous_host != NULL) {
    fix_unsafe_anonymous_class_name(CHECK);
  }

  // Verification prevents us from creating names with dots in them, this
  // asserts that that's the case.
  assert(is_internal_format(_class_name), "external class name format used internally");

  if (!is_internal()) {
    LogTarget(Debug, class, preorder) lt;
    if (lt.is_enabled()){
      ResourceMark rm(THREAD);
      LogStream ls(lt);
      ls.print("%s", _class_name->as_klass_external_name());
      if (stream->source() != NULL) {
        ls.print(" source: %s", stream->source());
      }
      ls.cr();
    }

#if INCLUDE_CDS
    if (DumpLoadedClassList != NULL && stream->source() != NULL && classlist_file->is_open()) {
      if (!ClassLoader::has_jrt_entry()) {
        warning("DumpLoadedClassList and CDS are not supported in exploded build");
        DumpLoadedClassList = NULL;
      } else if (SystemDictionaryShared::is_sharing_possible(_loader_data) &&
                 _unsafe_anonymous_host == NULL) {
        // Only dump the classes that can be stored into CDS archive.
        // Unsafe anonymous classes such as generated LambdaForm classes are also not included.
        oop class_loader = _loader_data->class_loader();
        ResourceMark rm(THREAD);
        bool skip = false;
        if (class_loader == NULL || SystemDictionary::is_platform_class_loader(class_loader)) {
          // For the boot and platform class loaders, skip classes that are not found in the
          // java runtime image, such as those found in the --patch-module entries.
          // These classes can't be loaded from the archive during runtime.
          if (!stream->from_boot_loader_modules_image() && strncmp(stream->source(), "jrt:", 4) != 0) {
            skip = true;
          }

          if (class_loader == NULL && ClassLoader::contains_append_entry(stream->source())) {
            // .. but don't skip the boot classes that are loaded from -Xbootclasspath/a
            // as they can be loaded from the archive during runtime.
            skip = false;
          }
        }
        if (skip) {
          tty->print_cr("skip writing class %s from source %s to classlist file",
            _class_name->as_C_string(), stream->source());
        } else {
          classlist_file->print_cr("%s", _class_name->as_C_string());
          classlist_file->flush();
        }
      }
    }
#endif
  }

  // SUPERKLASS
  _super_class_index = stream->get_u2_fast();
  _super_klass = parse_super_class(cp,
                                   _super_class_index,
                                   _need_verify,
                                   CHECK);

  // Interfaces
  _itfs_len = stream->get_u2_fast();
  parse_interfaces(stream,
                   _itfs_len,
                   cp,
                   &_has_nonstatic_concrete_methods,
                   CHECK);

  assert(_local_interfaces != NULL, "invariant");

  // Fields (offsets are filled in later)
  _fac = new FieldAllocationCount();
  parse_fields(stream,
               _access_flags.is_interface(),
               _fac,
               cp,
               cp_size,
               &_java_fields_count,
               CHECK);

  assert(_fields != NULL, "invariant");

  // Methods
  AccessFlags promoted_flags;
  parse_methods(stream,
                _access_flags.is_interface(),
                &promoted_flags,
                &_has_final_method,
                &_declares_nonstatic_concrete_methods,
                CHECK);

  assert(_methods != NULL, "invariant");

  // promote flags from parse_methods() to the klass' flags
  _access_flags.add_promoted_flags(promoted_flags.as_int());

  if (_declares_nonstatic_concrete_methods) {
    _has_nonstatic_concrete_methods = true;
  }

  // Additional attributes/annotations
  _parsed_annotations = new ClassAnnotationCollector();
  parse_classfile_attributes(stream, cp, _parsed_annotations, CHECK);

  assert(_inner_classes != NULL, "invariant");

  // Finalize the Annotations metadata object,
  // now that all annotation arrays have been created.
  create_combined_annotations(CHECK);

  // Make sure this is the end of class file stream
  guarantee_property(stream->at_eos(),
                     "Extra bytes at the end of class file %s",
                     CHECK);

  // all bytes in stream read and parsed
}
`````





