@# Included from rosidl_generator_py/resource/_idl_support.c.em
#define NPY_NO_DEPRECATED_API NPY_1_7_API_VERSION
@{
from rosidl_pycommon import convert_camel_case_to_lower_case_underscore
from rosidl_generator_py.generate_py_impl import SPECIAL_NESTED_BASIC_TYPES
from rosidl_parser.definition import AbstractNestedType
from rosidl_parser.definition import AbstractSequence
from rosidl_parser.definition import AbstractString
from rosidl_parser.definition import AbstractWString
from rosidl_parser.definition import Array
from rosidl_parser.definition import BasicType
from rosidl_parser.definition import EMPTY_STRUCTURE_REQUIRED_MEMBER_NAME
from rosidl_parser.definition import NamespacedType
from rosidl_parser.definition import SERVICE_RESPONSE_MESSAGE_SUFFIX
from rosidl_parser.definition import SERVICE_REQUEST_MESSAGE_SUFFIX


def primitive_msg_type_to_c(type_):
    from rosidl_generator_c import BASIC_IDL_TYPES_TO_C
    from rosidl_parser.definition import AbstractString
    from rosidl_parser.definition import AbstractWString
    from rosidl_parser.definition import BasicType
    if isinstance(type_, AbstractString):
        return 'rosidl_runtime_c__String'
    if isinstance(type_, AbstractWString):
        return 'rosidl_runtime_c__U16String'
    assert isinstance(type_, BasicType)
    return BASIC_IDL_TYPES_TO_C[type_.typename]


include_parts = [package_name] + list(interface_path.parents[0].parts) + [
    'detail', convert_camel_case_to_lower_case_underscore(interface_path.stem)]
include_base = '/'.join(include_parts)

header_files = [
    'Python.h',
    'stdbool.h',
    'stdint.h',
    'numpy/ndarrayobject.h',
    'rosidl_runtime_c/visibility_control.h',
    include_base + '__struct.h',
    include_base + '__functions.h',
]
}@
@[for header_file in header_files]@
@{
repeated_header_file = header_file in include_directives
}@
@[    if repeated_header_file]@
// already included above
// @
@[    else]@
@[      if header_file == 'numpy/ndarrayobject.h']@
#ifndef _WIN32
# pragma GCC diagnostic push
# pragma GCC diagnostic ignored "-Wunused-function"
#endif
@[      end if]@
@{include_directives.add(header_file)}@
@[    end if]@
@[    if '/' not in header_file]@
#include <@(header_file)>
@[    else]@
#include "@(header_file)"
@[    end if]@
@[    if header_file == 'numpy/ndarrayobject.h' and not repeated_header_file]@
#ifndef _WIN32
# pragma GCC diagnostic pop
#endif
@[    end if]@
@[end for]@
@{
needs_view_helper = False
for m in message.structure.members:
    if (isinstance(m.type, AbstractNestedType) and isinstance(m.type.value_type, BasicType) and
            (m.type.value_type.typename in SPECIAL_NESTED_BASIC_TYPES or
             (isinstance(m.type, AbstractSequence) and m.type.value_type.typename == 'boolean'))):
        needs_view_helper = True
emit_view_helper = needs_view_helper and 'rosidl_numpy_view' not in include_directives
if emit_view_helper:
    include_directives.add('rosidl_numpy_view')
}@
@[if emit_view_helper]@

static int rosidl_generator_py__import_numpy(void)
{
#if NPY_ABI_VERSION >= 0x02000000
  return _import_array();
#else
  // NumPy 1.x headers reject the NumPy 2 table, whose slots used here are unchanged.
  PyObject * module = PyImport_ImportModule("numpy._core._multiarray_umath");
  if (module == NULL && PyErr_ExceptionMatches(PyExc_ModuleNotFoundError)) {
    PyErr_Clear();
    module = PyImport_ImportModule("numpy.core._multiarray_umath");
  }
  if (module == NULL) {
    return -1;
  }
  PyObject * capsule = PyObject_GetAttrString(module, "_ARRAY_API");
  Py_DECREF(module);
  if (capsule == NULL) {
    return -1;
  }
  PyArray_API = (void **)PyCapsule_GetPointer(capsule, NULL);
  Py_DECREF(capsule);
  if (PyArray_API == NULL) {
    return -1;
  }
  if (PyArray_GetNDArrayCVersion() > 0x02000000 ||
    PyArray_GetNDArrayCFeatureVersion() < NPY_FEATURE_VERSION)
  {
    PyErr_Format(
      PyExc_ImportError, "unsupported NumPy C ABI 0x%x, C API 0x%x",
      PyArray_GetNDArrayCVersion(), PyArray_GetNDArrayCFeatureVersion());
    PyArray_API = NULL;
    return -1;
  }
  return 0;
#endif
}

static PyObject * rosidl_generator_py__numpy_view(
  void * data, size_t size, int type, PyObject * owner)
{
  if (PyArray_API == NULL && rosidl_generator_py__import_numpy() < 0) {
    return NULL;
  }
  static const uint64_t empty = 0;
  npy_intp shape[1] = {(npy_intp)size};
  PyObject * field = PyArray_SimpleNewFromData(1, shape, type, data ? data : (void *)&empty);
  if (field == NULL) {
    return NULL;
  }
  // An owner that exports a writable buffer, such as a publisher loan, gets writable views,
  // the rule NumPy applies to the bases of its own arrays.
  Py_buffer buffer;
  if (PyObject_CheckBuffer(owner) && PyObject_GetBuffer(owner, &buffer, PyBUF_WRITABLE) == 0) {
    PyBuffer_Release(&buffer);
  } else {
    PyErr_Clear();
    PyArray_CLEARFLAGS((PyArrayObject *)field, NPY_ARRAY_WRITEABLE);
  }
  Py_INCREF(owner);
  if (PyArray_SetBaseObject((PyArrayObject *)field, owner) < 0) {
    Py_DECREF(field);
    return NULL;
  }
  return field;
}
@[end if]@

@{
have_not_included_primitive_arrays = True
have_not_included_string = True
have_not_included_wstring = True
nested_types = set()
}@
@[for member in message.structure.members]@
@{
type_ = member.type
if isinstance(type_, AbstractNestedType):
    type_ = type_.value_type
header_files = []
if isinstance(member.type, AbstractNestedType) and have_not_included_primitive_arrays:
    have_not_included_primitive_arrays = False
    header_files += [
        'rosidl_runtime_c/primitives_sequence.h',
        'rosidl_runtime_c/primitives_sequence_functions.h']
if isinstance(type_, AbstractString) and have_not_included_string:
    have_not_included_string = False
    header_files += [
        'rosidl_runtime_c/string.h',
        'rosidl_runtime_c/string_functions.h']
if isinstance(type_, AbstractWString) and have_not_included_wstring:
    have_not_included_wstring = False
    header_files += [
        'rosidl_runtime_c/u16string.h',
        'rosidl_runtime_c/u16string_functions.h']
}@
@[if header_files]@
@[  for header_file in header_files]@
@[    if header_file in include_directives]@
// already included above
// @
@[    else]@
@{include_directives.add(header_file)}@
@[    end if]@
#include "@(header_file)"
@[  end for]@

@[end if]@
@{
if isinstance(member.type, AbstractNestedType) and isinstance(member.type.value_type, NamespacedType):
    nested_types.add((*member.type.value_type.namespaces, member.type.value_type.name))
}@
@[end for]@
@[if nested_types]@
// Nested array functions includes
@[  for type_ in sorted(nested_types)]@
@{
nested_header = '/'.join(type_[:-1] + ('detail', convert_camel_case_to_lower_case_underscore(type_[-1]),))
nested_header += '__functions.h'
}@
@[    if type_[-1].endswith(SERVICE_REQUEST_MESSAGE_SUFFIX) or type_[-1].endswith(SERVICE_RESPONSE_MESSAGE_SUFFIX)]
@# Service request/response messages are included in the srv__struct
@[continue]
@[    elif nested_header in include_directives]@
// already included above
// @
@[    else]@
@{include_directives.add(nested_header)}@
@[    end if]@
#include "@(nested_header)"
@[  end for]@
// end nested array functions include
@[end if]@
@{
msg_typename = '__'.join(message.structure.namespaced_type.namespaced_name())
}@
@
@{
declared_types = set()
}@
@[for member in message.structure.members]@
@{
type_ = member.type
if isinstance(type_, AbstractNestedType):
    type_ = type_.value_type
}@
@[  if isinstance(type_, NamespacedType)]@
@{
type_key = tuple(type_.namespaced_name())
already_declared = type_key in declared_types
declared_types.add(type_key)
}@
@[    if not already_declared]@
@[      if type_.namespaces[0] != package_name]@
ROSIDL_GENERATOR_C_IMPORT
@[      end if]@
bool @('__'.join(type_.namespaces + [convert_camel_case_to_lower_case_underscore(type_.name)]))__convert_from_py(PyObject * _pymsg, void * _ros_message);
@[      if type_.namespaces[0] != package_name]@
ROSIDL_GENERATOR_C_IMPORT
@[      end if]@
PyObject * @('__'.join(type_.namespaces + [convert_camel_case_to_lower_case_underscore(type_.name)]))__convert_to_py(void * raw_ros_message);
@{
owned_helper = '__'.join(type_.namespaces + [convert_camel_case_to_lower_case_underscore(type_.name)]) + '__convert_to_py_maybe_owned'
new_helper = owned_helper not in include_directives
include_directives.add(owned_helper)
}@
@[      if new_helper]@
static PyObject * @(owned_helper)(void * message, PyObject * owner)
{
  if (owner == NULL) {
    return @('__'.join(type_.namespaces + [convert_camel_case_to_lower_case_underscore(type_.name)]))__convert_to_py(message);
  }
  typedef PyObject * (*owned_converter)(void *, PyObject *);
  static owned_converter convert = NULL;
  static bool initialized = false;
  if (!initialized) {
    PyObject * module = PyImport_ImportModule("@(type_.namespaces[0]).@(type_.namespaces[0])_s__rosidl_typesupport_c");
    if (module == NULL) {
      return NULL;
    }
    PyObject * capsule = PyObject_GetAttrString(
      module, "convert_to_py_with_owner_msg__@('__'.join(type_.namespaces[1:] + [convert_camel_case_to_lower_case_underscore(type_.name)]))");
    Py_DECREF(module);
    if (capsule != NULL) {
      convert = (owned_converter)PyCapsule_GetPointer(capsule, NULL);
      Py_DECREF(capsule);
      if (convert == NULL) {
        return NULL;
      }
    } else if (PyErr_ExceptionMatches(PyExc_AttributeError)) {
      PyErr_Clear();
    } else {
      return NULL;
    }
    initialized = true;
  }
  if (convert != NULL) {
    return convert(message, owner);
  }
  return @('__'.join(type_.namespaces + [convert_camel_case_to_lower_case_underscore(type_.name)]))__convert_to_py(message);
}
@[      end if]@
@[    end if]@
@[  end if]@
@[end for]@

@{TEMPLATE('_msg_native.h.em', message=message)}@

@{
module_name = '_' + convert_camel_case_to_lower_case_underscore(interface_path.stem)
class_module = '%s.%s' % ('.'.join(message.structure.namespaced_type.namespaces), module_name)
namespaced_type = message.structure.namespaced_type.name
}@
ROSIDL_GENERATOR_C_EXPORT
bool @('__'.join(message.structure.namespaced_type.namespaces + [convert_camel_case_to_lower_case_underscore(message.structure.namespaced_type.name)]))__convert_from_py(PyObject * _pymsg, void * _ros_message)
{
  static PyObject * cached_expected_class = NULL;
  if (cached_expected_class == NULL) {
    PyObject * pymessage_module = PyImport_ImportModule("@(class_module)");
    if (pymessage_module == NULL) {
      return false;
    }
    cached_expected_class = PyObject_GetAttrString(pymessage_module, "@(namespaced_type)");
    Py_DECREF(pymessage_module);
    if (cached_expected_class == NULL) {
      return false;
    }
  }
  {
    int is_instance = PyObject_TypeCheck(_pymsg, (PyTypeObject *)cached_expected_class);
    if (is_instance < 0) {
      return false;
    }
    if (is_instance == 0) {
      PyErr_Format(
        PyExc_TypeError, "expected an instance of '@(class_module).@(namespaced_type)', got '%s'",
        Py_TYPE(_pymsg)->tp_name);
      return false;
    }
  }
  @('__'.join(message.structure.namespaced_type.namespaced_name()))__PyBase * base_msg =
    (@('__'.join(message.structure.namespaced_type.namespaced_name()))__PyBase *)_pymsg;
  (void)base_msg;
  @(msg_typename) * ros_message = _ros_message;
@[for member in message.structure.members]@
@[  if len(message.structure.members) == 1 and member.name == EMPTY_STRUCTURE_REQUIRED_MEMBER_NAME]@
  ros_message->@(member.name) = 0;
@[    continue]@
@[  end if]@
@{
type_ = member.type
if isinstance(type_, AbstractNestedType):
    type_ = type_.value_type
}@
  {  // @(member.name)
    PyObject * field = base_msg->_@(member.name);
    if (!field) {
      PyErr_SetString(PyExc_AttributeError, "uninitialized message field '@(member.name)'");
      return false;
    }
    Py_INCREF(field);
@[  if isinstance(type_, NamespacedType)]@
@{
nested_type = '__'.join(type_.namespaced_name())
}@
@[    if isinstance(member.type, AbstractNestedType)]@
    PyObject * seq_field = PySequence_Fast(field, "expected a sequence in '@(member.name)'");
    if (!seq_field) {
      Py_DECREF(field);
      return false;
    }
@[      if isinstance(member.type, AbstractSequence)]@
    Py_ssize_t size = PySequence_Fast_GET_SIZE(seq_field);
    if (!@(nested_type)__Sequence__init(&(ros_message->@(member.name)), size)) {
      PyErr_SetString(PyExc_RuntimeError, "unable to create @(nested_type)__Sequence ros_message");
      Py_DECREF(seq_field);
      Py_DECREF(field);
      return false;
    }
    @(nested_type) * dest = ros_message->@(member.name).data;
@[      else]@
    Py_ssize_t size = @(member.type.size);
    @(nested_type) * dest = ros_message->@(member.name);
@[      end if]@
    for (Py_ssize_t i = 0; i < size; ++i) {
      if (!@('__'.join(type_.namespaces + [convert_camel_case_to_lower_case_underscore(type_.name)]))__convert_from_py(PySequence_Fast_GET_ITEM(seq_field, i), &dest[i])) {
        Py_DECREF(seq_field);
        Py_DECREF(field);
        return false;
      }
    }
    Py_DECREF(seq_field);
@[    else]@
    if (!@('__'.join(type_.namespaces + [convert_camel_case_to_lower_case_underscore(type_.name)]))__convert_from_py(field, &ros_message->@(member.name))) {
      Py_DECREF(field);
      return false;
    }
@[    end if]@
@[  elif isinstance(member.type, Array) and isinstance(member.type.value_type, BasicType) and member.type.value_type.typename in SPECIAL_NESTED_BASIC_TYPES]@
    assert(field->ob_type != NULL);
    assert(field->ob_type->tp_name != NULL);
    assert(strcmp(field->ob_type->tp_name, "numpy.ndarray") == 0);
    PyArrayObject * seq_field = (PyArrayObject *)field;
    assert(PyArray_NDIM(seq_field) == 1);
    assert(PyArray_TYPE(seq_field) == @(SPECIAL_NESTED_BASIC_TYPES[member.type.value_type.typename]['dtype'].replace('numpy.', 'NPY_').upper()));
    @primitive_msg_type_to_c(member.type.value_type) * dest = ros_message->@(member.name);
    if (PyArray_DATA(seq_field) == (void *)dest) {
      // A view of this message's own buffer, as in a publisher loan, already holds the values.
    } else if (PyArray_IS_C_CONTIGUOUS(seq_field)) {
      memcpy(dest, PyArray_DATA(seq_field), @(member.type.size) * sizeof(*dest));
    } else {
      for (Py_ssize_t i = 0; i < @(member.type.size); ++i) {
        memcpy(&dest[i], PyArray_GETPTR1(seq_field, i), sizeof(*dest));
      }
    }
@[  elif isinstance(member.type, AbstractSequence) and isinstance(type_, BasicType) and type_.typename == 'octet']@
    char * data;
    Py_ssize_t size;
    if (PyBytes_AsStringAndSize(field, &data, &size) < 0) {
      Py_DECREF(field);
      return false;
    }
    if (!rosidl_runtime_c__octet__Sequence__init(&ros_message->@(member.name), size)) {
      PyErr_NoMemory();
      Py_DECREF(field);
      return false;
    }
    if (size > 0) {
      memcpy(ros_message->@(member.name).data, data, size);
    }
@[  elif isinstance(member.type, AbstractNestedType)]@
@[    if isinstance(member.type, AbstractSequence) and isinstance(member.type.value_type, BasicType)]@
    if (PyObject_CheckBuffer(field)) {
      // Optimization for converting arrays of primitives
      Py_buffer view;
      int rc = PyObject_GetBuffer(field, &view, PyBUF_SIMPLE);
      if (rc < 0) {
        Py_DECREF(field);
        return false;
      }
      Py_ssize_t size = view.len / sizeof(@primitive_msg_type_to_c(member.type.value_type));
      if (!rosidl_runtime_c__@(member.type.value_type.typename)__Sequence__init(&(ros_message->@(member.name)), size)) {
        PyErr_SetString(PyExc_RuntimeError, "unable to create @(member.type.value_type.typename)__Sequence ros_message");
        PyBuffer_Release(&view);
        Py_DECREF(field);
        return false;
      }
      @primitive_msg_type_to_c(member.type.value_type) * dest = ros_message->@(member.name).data;
      rc = PyBuffer_ToContiguous(dest, &view, view.len, 'C');
      if (rc < 0) {
        PyBuffer_Release(&view);
        Py_DECREF(field);
        return false;
      }
      PyBuffer_Release(&view);
    } else {
@[    else]@
    {
@[    end if]@
      PyObject * seq_field = PySequence_Fast(field, "expected a sequence in '@(member.name)'");
      if (!seq_field) {
        Py_DECREF(field);
        return false;
      }
@[    if isinstance(member.type, AbstractSequence)]@
      Py_ssize_t size = PySequence_Fast_GET_SIZE(seq_field);
@[      if isinstance(member.type.value_type, AbstractString)]@
      if (!rosidl_runtime_c__String__Sequence__init(&(ros_message->@(member.name)), size)) {
        PyErr_SetString(PyExc_RuntimeError, "unable to create String__Sequence ros_message");
        Py_DECREF(seq_field);
        Py_DECREF(field);
        return false;
      }
@[      elif isinstance(member.type.value_type, AbstractWString)]@
      if (!rosidl_runtime_c__U16String__Sequence__init(&(ros_message->@(member.name)), size)) {
        PyErr_SetString(PyExc_RuntimeError, "unable to create U16String__Sequence ros_message");
        Py_DECREF(seq_field);
        Py_DECREF(field);
        return false;
      }
@[      else]@
      if (!rosidl_runtime_c__@(member.type.value_type.typename)__Sequence__init(&(ros_message->@(member.name)), size)) {
        PyErr_SetString(PyExc_RuntimeError, "unable to create @(member.type.value_type.typename)__Sequence ros_message");
        Py_DECREF(seq_field);
        Py_DECREF(field);
        return false;
      }
@[      end if]@
      @primitive_msg_type_to_c(member.type.value_type) * dest = ros_message->@(member.name).data;
@[    else]@
      Py_ssize_t size = @(member.type.size);
      @primitive_msg_type_to_c(member.type.value_type) * dest = ros_message->@(member.name);
@[    end if]@
      for (Py_ssize_t i = 0; i < size; ++i) {
        PyObject * item = PySequence_Fast_GET_ITEM(seq_field, i);
        if (!item) {
          Py_DECREF(seq_field);
          Py_DECREF(field);
          return false;
        }
@[    if isinstance(member.type.value_type, BasicType) and member.type.value_type.typename == 'char']@
        assert(PyUnicode_Check(item));
        PyObject * encoded_item = PyUnicode_AsUTF8String(item);
        if (!encoded_item) {
          Py_DECREF(seq_field);
          Py_DECREF(field);
          return false;
        }
        @primitive_msg_type_to_c(member.type.value_type) tmp = PyBytes_AS_STRING(encoded_item)[0];
        Py_DECREF(encoded_item);
@[    elif isinstance(member.type.value_type, BasicType) and member.type.value_type.typename == 'octet']@
        assert(PyBytes_Check(item));
        @primitive_msg_type_to_c(member.type.value_type) tmp = PyBytes_AS_STRING(item)[0];
@[    elif isinstance(member.type.value_type, AbstractString)]@
        assert(PyUnicode_Check(item));
        PyObject * encoded_item = PyUnicode_AsUTF8String(item);
        if (!encoded_item) {
          Py_DECREF(seq_field);
          Py_DECREF(field);
          return false;
        }
        rosidl_runtime_c__String__assignn(&dest[i], PyBytes_AS_STRING(encoded_item), PyBytes_GET_SIZE(encoded_item));
        Py_DECREF(encoded_item);
@[    elif isinstance(member.type.value_type, AbstractWString)]@
        assert(PyUnicode_Check(item));
        // the returned string starts with a BOM mark and uses native byte order
        PyObject * encoded_item = PyUnicode_AsUTF16String(item);
        if (!encoded_item) {
          Py_DECREF(seq_field);
          Py_DECREF(field);
          return false;
        }
        char * buffer;
        Py_ssize_t length;
        int rc = PyBytes_AsStringAndSize(encoded_item, &buffer, &length);
        if (rc) {
          Py_DECREF(encoded_item);
          Py_DECREF(seq_field);
          Py_DECREF(field);
          return false;
        }
        // use offset of 2 to skip BOM mark
        bool succeeded = rosidl_runtime_c__U16String__assignn_from_char(&dest[i], buffer + 2, length - 2);
        Py_DECREF(encoded_item);
        if (!succeeded) {
          Py_DECREF(seq_field);
          Py_DECREF(field);
          return false;
        }
@[    elif isinstance(member.type.value_type, BasicType) and member.type.value_type.typename == 'boolean']@
        assert(PyBool_Check(item));
        @primitive_msg_type_to_c(member.type.value_type) tmp = (item == Py_True);
@[    elif isinstance(member.type.value_type, BasicType) and member.type.value_type.typename in ('float', 'double')]@
        assert(PyFloat_Check(item));
@[      if member.type.value_type.typename == 'float']@
        @primitive_msg_type_to_c(member.type.value_type) tmp = (float)PyFloat_AS_DOUBLE(item);
@[      else]@
        @primitive_msg_type_to_c(member.type.value_type) tmp = PyFloat_AS_DOUBLE(item);
@[      end if]@
@[    elif isinstance(member.type.value_type, BasicType) and member.type.value_type.typename in (
          'int8',
          'int16',
          'int32',
      )]@
        assert(PyLong_Check(item));
        @primitive_msg_type_to_c(member.type.value_type) tmp = (@(primitive_msg_type_to_c(member.type.value_type)))PyLong_AsLong(item);
@[    elif isinstance(member.type.value_type, BasicType) and member.type.value_type.typename in (
          'uint8',
          'uint16',
          'uint32',
      )]@
        assert(PyLong_Check(item));
@[      if isinstance(member.type.value_type, BasicType) and member.type.value_type.typename == 'uint32']@
        @primitive_msg_type_to_c(member.type.value_type) tmp = PyLong_AsUnsignedLong(item);
@[      else]@
        @primitive_msg_type_to_c(member.type.value_type) tmp = (@(primitive_msg_type_to_c(member.type.value_type)))PyLong_AsUnsignedLong(item);
@[      end if]
@[    elif isinstance(member.type.value_type, BasicType) and member.type.value_type.typename == 'int64']@
        assert(PyLong_Check(item));
        @primitive_msg_type_to_c(member.type.value_type) tmp = PyLong_AsLongLong(item);
@[    elif isinstance(member.type.value_type, BasicType) and member.type.value_type.typename == 'uint64']@
        assert(PyLong_Check(item));
        @primitive_msg_type_to_c(member.type.value_type) tmp = PyLong_AsUnsignedLongLong(item);
@[    end if]@
@[    if isinstance(member.type.value_type, BasicType)]@
        memcpy(&dest[i], &tmp, sizeof(@primitive_msg_type_to_c(member.type.value_type)));
@[    end if]@
      }
      Py_DECREF(seq_field);
    }
@[  elif isinstance(member.type, BasicType) and member.type.typename == 'char']@
    assert(PyUnicode_Check(field));
    PyObject * encoded_field = PyUnicode_AsUTF8String(field);
    if (!encoded_field) {
      Py_DECREF(field);
      return false;
    }
    ros_message->@(member.name) = PyBytes_AS_STRING(encoded_field)[0];
    Py_DECREF(encoded_field);
@[  elif isinstance(member.type, BasicType) and member.type.typename == 'octet']@
    assert(PyBytes_Check(field));
    ros_message->@(member.name) = PyBytes_AS_STRING(field)[0];
@[  elif isinstance(member.type, AbstractString)]@
    assert(PyUnicode_Check(field));
    PyObject * encoded_field = PyUnicode_AsUTF8String(field);
    if (!encoded_field) {
      Py_DECREF(field);
      return false;
    }
    rosidl_runtime_c__String__assignn(&ros_message->@(member.name), PyBytes_AS_STRING(encoded_field), PyBytes_GET_SIZE(encoded_field));
    Py_DECREF(encoded_field);
@[  elif isinstance(member.type, AbstractWString)]@
    assert(PyUnicode_Check(field));
    // the returned string starts with a BOM mark and uses native byte order
    PyObject * encoded_field = PyUnicode_AsUTF16String(field);
    if (!encoded_field) {
      Py_DECREF(field);
      return false;
    }
    char * buffer;
    Py_ssize_t length;
    int rc = PyBytes_AsStringAndSize(encoded_field, &buffer, &length);
    if (rc) {
      Py_DECREF(encoded_field);
      Py_DECREF(field);
      return false;
    }
    // use offset of 2 to skip BOM mark
    {
      bool succeeded = rosidl_runtime_c__U16String__assignn_from_char(&ros_message->@(member.name), buffer + 2, length - 2);
      Py_DECREF(encoded_field);
      if (!succeeded) {
        Py_DECREF(field);
        return false;
      }
    }
@[  elif isinstance(member.type, BasicType) and member.type.typename == 'boolean']@
    assert(PyBool_Check(field));
    ros_message->@(member.name) = (Py_True == field);
@[  elif isinstance(member.type, BasicType) and member.type.typename in ('float', 'double')]@
    assert(PyFloat_Check(field));
@[    if member.type.typename == 'float']@
    ros_message->@(member.name) = (float)PyFloat_AS_DOUBLE(field);
@[    else]@
    ros_message->@(member.name) = PyFloat_AS_DOUBLE(field);
@[    end if]@
@[  elif isinstance(member.type, BasicType) and member.type.typename in (
        'int8',
        'int16',
        'int32',
    )]@
    assert(PyLong_Check(field));
    ros_message->@(member.name) = (@(primitive_msg_type_to_c(member.type)))PyLong_AsLong(field);
@[  elif isinstance(member.type, BasicType) and member.type.typename in (
        'uint8',
        'uint16',
        'uint32',
    )]@
    assert(PyLong_Check(field));
@[    if member.type.typename == 'uint32']@
    ros_message->@(member.name) = PyLong_AsUnsignedLong(field);
@[    else]@
    ros_message->@(member.name) = (@(primitive_msg_type_to_c(member.type)))PyLong_AsUnsignedLong(field);
@[    end if]@
@[  elif isinstance(member.type, BasicType) and member.type.typename == 'int64']@
    assert(PyLong_Check(field));
    ros_message->@(member.name) = PyLong_AsLongLong(field);
@[  elif isinstance(member.type, BasicType) and member.type.typename == 'uint64']@
    assert(PyLong_Check(field));
    ros_message->@(member.name) = PyLong_AsUnsignedLongLong(field);
@[  else]@
    assert(false);
@[  end if]@
    Py_DECREF(field);
  }
@[end for]@

  return true;
}

ROSIDL_GENERATOR_C_EXPORT
PyObject * @('__'.join(message.structure.namespaced_type.namespaces + [convert_camel_case_to_lower_case_underscore(message.structure.namespaced_type.name)]))__convert_to_py_with_owner(void * raw_ros_message, PyObject * owner);

ROSIDL_GENERATOR_C_EXPORT
PyObject * @('__'.join(message.structure.namespaced_type.namespaces + [convert_camel_case_to_lower_case_underscore(message.structure.namespaced_type.name)]))__convert_to_py(void * raw_ros_message)
{
  return @('__'.join(message.structure.namespaced_type.namespaces + [convert_camel_case_to_lower_case_underscore(message.structure.namespaced_type.name)]))__convert_to_py_with_owner(raw_ros_message, NULL);
}

ROSIDL_GENERATOR_C_EXPORT
PyObject * @('__'.join(message.structure.namespaced_type.namespaces + [convert_camel_case_to_lower_case_underscore(message.structure.namespaced_type.name)]))__convert_to_py_with_owner(void * raw_ros_message, PyObject * owner)
{
  (void)owner;
  static PyObject * cached_pymessage_class = NULL;
  static PyObject * cached_check_fields_default = NULL;
  PyObject * _pymessage = NULL;
  if (cached_pymessage_class == NULL) {
    PyObject * pymessage_module = PyImport_ImportModule("@(class_module)");
    if (pymessage_module == NULL) {
      return NULL;
    }
    // __init__ stores this module global in _check_fields; Python reads the
    // environment variable once at import time.
    PyObject * check_fields_setting = PyObject_GetAttrString(pymessage_module, "ros_python_check_fields");
    if (check_fields_setting == NULL) {
      Py_DECREF(pymessage_module);
      return NULL;
    }
    cached_check_fields_default = PyBool_FromLong(
      PyUnicode_Check(check_fields_setting) &&
      PyUnicode_CompareWithASCIIString(check_fields_setting, "1") == 0);
    Py_DECREF(check_fields_setting);
    cached_pymessage_class = PyObject_GetAttrString(pymessage_module, "@(namespaced_type)");
    Py_DECREF(pymessage_module);
    if (cached_pymessage_class == NULL) {
      return NULL;
    }
  }
  // Fields are written to the private slots, not through the property setters,
  // whose type checks cannot fail for values built here. Everything is cached
  // before the instance is allocated, and the flag is set last so that a failed
  // attempt is retried.
@[for member in message.structure.members]@
@[  if len(message.structure.members) == 1 and member.name == EMPTY_STRUCTURE_REQUIRED_MEMBER_NAME]@
@[    continue]@
@[  end if]@
@[  if isinstance(member.type, AbstractNestedType) and isinstance(member.type.value_type, BasicType) and member.type.value_type.typename in SPECIAL_NESTED_BASIC_TYPES]@
@[    if isinstance(member.type, Array)]@
  static PyObject * cached_numpy_empty_@(member.name) = NULL;
  static PyObject * cached_numpy_args_@(member.name) = NULL;
  static PyObject * cached_numpy_kwargs_@(member.name) = NULL;
@[    elif isinstance(member.type, AbstractSequence)]@
  static PyObject * cached_array_type_@(member.name) = NULL;
  static PyObject * cached_array_typecode_@(member.name) = NULL;
  static PyObject * cached_array_frombytes_@(member.name) = NULL;
@[    end if]@
@[  end if]@
@[end for]@
  static bool cached_py_attrs_initialized = false;
  if (!cached_py_attrs_initialized) {
@[for member in message.structure.members]@
@[  if len(message.structure.members) == 1 and member.name == EMPTY_STRUCTURE_REQUIRED_MEMBER_NAME]@
@[    continue]@
@[  end if]@
@[  if isinstance(member.type, AbstractNestedType) and isinstance(member.type.value_type, BasicType) and member.type.value_type.typename in SPECIAL_NESTED_BASIC_TYPES]@
@[    if isinstance(member.type, Array)]@
    // numpy.empty because the numpy C API table is not initialized in this unit.
    if (cached_numpy_empty_@(member.name) == NULL) {
      PyObject * numpy_module = PyImport_ImportModule("numpy");
      if (numpy_module == NULL) {
        return NULL;
      }
      PyObject * dtype = PyObject_GetAttrString(numpy_module, "@(SPECIAL_NESTED_BASIC_TYPES[member.type.value_type.typename]['dtype'].replace('numpy.', ''))");
      PyObject * numpy_empty = PyObject_GetAttrString(numpy_module, "empty");
      Py_DECREF(numpy_module);
      if (dtype == NULL || numpy_empty == NULL) {
        Py_XDECREF(dtype);
        Py_XDECREF(numpy_empty);
        return NULL;
      }
      PyObject * numpy_args = Py_BuildValue("(n)", (Py_ssize_t)@(member.type.size));
      PyObject * numpy_kwargs = Py_BuildValue("{s:O}", "dtype", dtype);
      Py_DECREF(dtype);
      if (numpy_args == NULL || numpy_kwargs == NULL) {
        Py_XDECREF(numpy_args);
        Py_XDECREF(numpy_kwargs);
        Py_DECREF(numpy_empty);
        return NULL;
      }
      cached_numpy_args_@(member.name) = numpy_args;
      cached_numpy_kwargs_@(member.name) = numpy_kwargs;
      cached_numpy_empty_@(member.name) = numpy_empty;
    }
@[    elif isinstance(member.type, AbstractSequence)]@
    if (cached_array_type_@(member.name) == NULL) {
      PyObject * array_module = PyImport_ImportModule("array");
      if (array_module == NULL) {
        return NULL;
      }
      PyObject * array_type = PyObject_GetAttrString(array_module, "array");
      Py_DECREF(array_module);
      PyObject * array_typecode = PyUnicode_InternFromString("@(SPECIAL_NESTED_BASIC_TYPES[member.type.value_type.typename]['type_code'])");
      PyObject * array_frombytes = PyUnicode_InternFromString("frombytes");
      if (array_type == NULL || array_typecode == NULL || array_frombytes == NULL) {
        Py_XDECREF(array_type);
        Py_XDECREF(array_typecode);
        Py_XDECREF(array_frombytes);
        return NULL;
      }
      cached_array_typecode_@(member.name) = array_typecode;
      cached_array_frombytes_@(member.name) = array_frombytes;
      cached_array_type_@(member.name) = array_type;
    }
@[    end if]@
@[  end if]@
@[end for]@
    cached_py_attrs_initialized = true;
  }
  // __init__ is skipped: it would build a default for every field only for it to
  // be overwritten. The classes use __slots__, so every slot is assigned below.
  {
    PyTypeObject * message_type = (PyTypeObject *)cached_pymessage_class;
    _pymessage = message_type->tp_alloc(message_type, 0);
    if (!_pymessage) {
      return NULL;
    }
    @('__'.join(message.structure.namespaced_type.namespaced_name()))__PyBase * base =
      (@('__'.join(message.structure.namespaced_type.namespaced_name()))__PyBase *)_pymessage;
    Py_INCREF(cached_check_fields_default);
    base->_check_fields = cached_check_fields_default;
  }
  @('__'.join(message.structure.namespaced_type.namespaced_name()))__PyBase * base_msg =
    (@('__'.join(message.structure.namespaced_type.namespaced_name()))__PyBase *)_pymessage;
  (void)base_msg;
@[if len(message.structure.members) == 1 and member.name == EMPTY_STRUCTURE_REQUIRED_MEMBER_NAME]@
  (void)raw_ros_message;
@[else]@
  @(msg_typename) * ros_message = (@(msg_typename) *)raw_ros_message;
@[end if]@
@[for member in message.structure.members]@
@[  if len(message.structure.members) == 1 and member.name == EMPTY_STRUCTURE_REQUIRED_MEMBER_NAME]@
@[    continue]@
@[  end if]@
@{
type_ = member.type
if isinstance(type_, AbstractNestedType):
    type_ = type_.value_type
}@
  {  // @(member.name)
    PyObject * field = NULL;
@[ if isinstance(member.type, AbstractNestedType) and isinstance(member.type.value_type, BasicType) and member.type.value_type.typename in SPECIAL_NESTED_BASIC_TYPES]@
    if (owner != NULL) {
      field = rosidl_generator_py__numpy_view(
@[    if isinstance(member.type, Array)]@
        ros_message->@(member.name), @(member.type.size),
@[    else]@
        ros_message->@(member.name).data, ros_message->@(member.name).size,
@[    end if]@
        @(SPECIAL_NESTED_BASIC_TYPES[member.type.value_type.typename]['dtype'].replace('numpy.', 'NPY_').upper()), owner);
      if (field == NULL) {
        Py_DECREF(_pymessage);
        return NULL;
      }
      base_msg->_@(member.name) = field;
    } else {
@[    if isinstance(member.type, Array)]@
      field = PyObject_Call(
        cached_numpy_empty_@(member.name),
        cached_numpy_args_@(member.name),
        cached_numpy_kwargs_@(member.name));
      if (!field) {
        Py_DECREF(_pymessage);
        return NULL;
      }
      assert(field->ob_type != NULL);
      assert(field->ob_type->tp_name != NULL);
      assert(strcmp(field->ob_type->tp_name, "numpy.ndarray") == 0);
      PyArrayObject * seq_field = (PyArrayObject *)field;
      assert(PyArray_NDIM(seq_field) == 1);
      assert(PyArray_TYPE(seq_field) == @(SPECIAL_NESTED_BASIC_TYPES[member.type.value_type.typename]['dtype'].replace('numpy.', 'NPY_').upper()));
      assert(sizeof(@(SPECIAL_NESTED_BASIC_TYPES[member.type.value_type.typename]['dtype'].replace('numpy.', 'npy_'))) == sizeof(@primitive_msg_type_to_c(member.type.value_type)));
      @(SPECIAL_NESTED_BASIC_TYPES[member.type.value_type.typename]['dtype'].replace('numpy.', 'npy_')) * dst = (@(SPECIAL_NESTED_BASIC_TYPES[member.type.value_type.typename]['dtype'].replace('numpy.', 'npy_')) *)PyArray_GETPTR1(seq_field, 0);
      @primitive_msg_type_to_c(member.type.value_type) * src = &(ros_message->@(member.name)[0]);
      memcpy(dst, src, @(member.type.size) * sizeof(@primitive_msg_type_to_c(member.type.value_type)));
      {
        base_msg->_@(member.name) = field;
      }
@[    elif isinstance(member.type, AbstractSequence)]@
      field = PyObject_CallFunctionObjArgs(
        cached_array_type_@(member.name), cached_array_typecode_@(member.name), NULL);
      if (!field) {
        Py_DECREF(_pymessage);
        return NULL;
      }
      if (ros_message->@(member.name).size > 0) {
        // frombytes on a memoryview copies once; array.array(typecode, bytes) would copy twice
        PyObject * data = PyMemoryView_FromMemory(
          (char *)ros_message->@(member.name).data,
          ros_message->@(member.name).size * sizeof(@primitive_msg_type_to_c(member.type.value_type)),
          PyBUF_READ);
        if (!data) {
          Py_DECREF(field);
          Py_DECREF(_pymessage);
          return NULL;
        }
        PyObject * ret = PyObject_CallMethodObjArgs(field, cached_array_frombytes_@(member.name), data, NULL);
        Py_DECREF(data);
        if (!ret) {
          Py_DECREF(field);
          Py_DECREF(_pymessage);
          return NULL;
        }
        Py_DECREF(ret);
      }
      {
        base_msg->_@(member.name) = field;
      }
@[    end if]@
    }
@[ else]@
@[  if isinstance(type_, NamespacedType)]@
@{
nested_type = '__'.join(type_.namespaced_name())
}@
@[    if isinstance(member.type, AbstractNestedType)]@
@[      if isinstance(member.type, AbstractSequence)]@
    size_t size = ros_message->@(member.name).size;
@[      else]@
    size_t size = @(member.type.size);
@[      end if]@
    field = PyList_New(size);
    if (!field) {
      Py_DECREF(_pymessage);
      return NULL;
    }
    @(nested_type) * item;
    for (size_t i = 0; i < size; ++i) {
@[      if isinstance(member.type, AbstractSequence)]@
      item = &(ros_message->@(member.name).data[i]);
@[      else]@
      item = &(ros_message->@(member.name)[i]);
@[      end if]@
      PyObject * pyitem = @('__'.join(type_.namespaces + [convert_camel_case_to_lower_case_underscore(type_.name)]))__convert_to_py_maybe_owned(item, owner);
      if (!pyitem) {
        Py_DECREF(field);
        Py_DECREF(_pymessage);
        return NULL;
      }
      int rc = PyList_SetItem(field, i, pyitem);
      (void)rc;
      assert(rc == 0);
    }
    assert(PySequence_Check(field));
@[    else]@
    field = @('__'.join(type_.namespaces + [convert_camel_case_to_lower_case_underscore(type_.name)]))__convert_to_py_maybe_owned(&ros_message->@(member.name), owner);
    if (!field) {
      Py_DECREF(_pymessage);
      return NULL;
    }
@[    end if]@
@[  elif isinstance(member.type, AbstractSequence) and isinstance(type_, BasicType) and type_.typename == 'boolean']@
    if (owner != NULL) {
      field = rosidl_generator_py__numpy_view(
        ros_message->@(member.name).data, ros_message->@(member.name).size, NPY_BOOL, owner);
    } else {
      field = PyList_New(ros_message->@(member.name).size);
      if (field != NULL) {
        for (size_t i = 0; i < ros_message->@(member.name).size; ++i) {
          PyList_SET_ITEM(field, i, PyBool_FromLong(ros_message->@(member.name).data[i]));
        }
      }
    }
    if (field == NULL) {
      Py_DECREF(_pymessage);
      return NULL;
    }
@[  elif isinstance(member.type, AbstractSequence) and isinstance(type_, BasicType) and type_.typename == 'octet']@
    field = PyBytes_FromStringAndSize(
      (const char *)ros_message->@(member.name).data, ros_message->@(member.name).size);
    if (!field) {
      Py_DECREF(_pymessage);
      return NULL;
    }
@[  elif isinstance(member.type, AbstractNestedType)]@
@[    if isinstance(member.type, AbstractSequence)]@
    size_t size = ros_message->@(member.name).size;
    @primitive_msg_type_to_c(member.type.value_type) * src = ros_message->@(member.name).data;
@[    else]@
    size_t size = @(member.type.size);
    @primitive_msg_type_to_c(member.type.value_type) * src = ros_message->@(member.name);
@[    end if]@
    field = PyList_New(size);
    if (!field) {
      Py_DECREF(_pymessage);
      return NULL;
    }
    for (size_t i = 0; i < size; ++i) {
@[    if isinstance(member.type.value_type, BasicType) and member.type.value_type.typename == 'char']@
      int rc = PyList_SetItem(field, i, Py_BuildValue("C", src[i]));
      (void)rc;
      assert(rc == 0);
@[    elif isinstance(member.type.value_type, BasicType) and member.type.value_type.typename == 'octet']@
      int rc = PyList_SetItem(field, i, PyBytes_FromStringAndSize((const char *)&src[i], 1));
      (void)rc;
      assert(rc == 0);
@[    elif isinstance(member.type.value_type, AbstractString)]@
      PyObject * decoded_item = PyUnicode_DecodeUTF8(src[i].data, src[i].size, "replace");
      if (!decoded_item) {
        Py_DECREF(field);
        Py_DECREF(_pymessage);
        return NULL;
      }
      int rc = PyList_SetItem(field, i, decoded_item);
      (void)rc;
      assert(rc == 0);
@[    elif isinstance(member.type.value_type, AbstractWString)]@
      int byteorder = 0;
      PyObject * decoded_item = PyUnicode_DecodeUTF16((const char *)src[i].data, src[i].size * sizeof(uint16_t), NULL, &byteorder);
      if (!decoded_item) {
        Py_DECREF(field);
        Py_DECREF(_pymessage);
        return NULL;
      }
      int rc = PyList_SetItem(field, i, decoded_item);
      (void)rc;
      assert(rc == 0);
@[    elif isinstance(member.type.value_type, BasicType) and member.type.value_type.typename == 'boolean']@
@# using PyBool_FromLong because PyList_SetItem will steal ownership of the passed item
      int rc = PyList_SetItem(field, i, PyBool_FromLong(src[i] ? 1 : 0));
      (void)rc;
      assert(rc == 0);
@[    elif isinstance(member.type.value_type, BasicType) and member.type.value_type.typename in ('float', 'double')]@
      int rc = PyList_SetItem(field, i, PyFloat_FromDouble(src[i]));
      (void)rc;
      assert(rc == 0);
@[    elif isinstance(member.type.value_type, BasicType) and member.type.value_type.typename in (
        'int8',
        'int16',
        'int32',
    )]@
      int rc = PyList_SetItem(field, i, PyLong_FromLong(src[i]));
      (void)rc;
      assert(rc == 0);
@[    elif isinstance(member.type.value_type, BasicType) and member.type.value_type.typename in (
        'uint8',
        'uint16',
        'uint32',
    )]@
      int rc = PyList_SetItem(field, i, PyLong_FromUnsignedLong(src[i]));
      (void)rc;
      assert(rc == 0);
@[    elif isinstance(member.type.value_type, BasicType) and member.type.value_type.typename == 'int64']@
      int rc = PyList_SetItem(field, i, PyLong_FromLongLong(src[i]));
      (void)rc;
      assert(rc == 0);
@[    elif isinstance(member.type.value_type, BasicType) and member.type.value_type.typename == 'uint64']@
      int rc = PyList_SetItem(field, i, PyLong_FromUnsignedLongLong(src[i]));
      (void)rc;
      assert(rc == 0);
@[    end if]@
    }
    assert(PySequence_Check(field));
@[  elif isinstance(member.type, BasicType) and member.type.typename == 'char']@
    field = Py_BuildValue("C", ros_message->@(member.name));
@[  elif isinstance(member.type, BasicType) and member.type.typename == 'octet']@
    field = PyBytes_FromStringAndSize((const char *)&ros_message->@(member.name), 1);
@[  elif isinstance(member.type, AbstractString)]@
    field = PyUnicode_DecodeUTF8(
      ros_message->@(member.name).data,
      ros_message->@(member.name).size,
      "replace");
@[  elif isinstance(member.type, AbstractWString)]@
    int byteorder = 0;
    field = PyUnicode_DecodeUTF16(
      (const char *)ros_message->@(member.name).data,
      ros_message->@(member.name).size * sizeof(uint16_t),
      NULL, &byteorder);
@[  elif isinstance(member.type, BasicType) and member.type.typename == 'boolean']@
@# using PyBool_FromLong allows treating the variable uniformly by calling Py_DECREF on it later
    field = PyBool_FromLong(ros_message->@(member.name) ? 1 : 0);
@[  elif isinstance(member.type, BasicType) and member.type.typename in ('float', 'double')]@
    field = PyFloat_FromDouble(ros_message->@(member.name));
@[  elif isinstance(member.type, BasicType) and member.type.typename in (
        'int8',
        'int16',
        'int32',
    )]@
    field = PyLong_FromLong(ros_message->@(member.name));
@[  elif isinstance(member.type, BasicType) and member.type.typename in (
        'uint8',
        'uint16',
        'uint32',
    )]@
    field = PyLong_FromUnsignedLong(ros_message->@(member.name));
@[  elif isinstance(member.type, BasicType) and member.type.typename == 'int64']@
    field = PyLong_FromLongLong(ros_message->@(member.name));
@[  elif isinstance(member.type, BasicType) and member.type.typename == 'uint64']@
    field = PyLong_FromUnsignedLongLong(ros_message->@(member.name));
@[  else]@
    assert(false);
@[  end if]@
    if (!field) {
      Py_DECREF(_pymessage);
      return NULL;
    }
    {
      base_msg->_@(member.name) = field;
    }
@[ end if]@
  }
@[end for]@

  // ownership of _pymessage is transferred to the caller
  return _pymessage;
}
